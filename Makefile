# JobOut — un comando para levantar todo.
#
#   make dev     backend + frontend + base de datos
#   make down    apagar
#   make logs    seguir los registros
#   make test    pruebas de los dos repos
#   make setup   solo preparar los archivos locales, sin levantar

SHELL := /bin/bash
COMPOSE := docker compose
API  := ../jobout-core-api
WEB  := ../jobout-web

.PHONY: help dev up down logs ps test test-api test-web setup check ports clean reset migrate shell-api shell-web

help:
	@echo "JobOut — desarrollo"
	@echo ""
	@echo "  make dev       levanta backend + frontend + base de datos"
	@echo "  make down      apaga todo"
	@echo "  make logs      sigue los registros"
	@echo "  make ps        estado de los servicios"
	@echo "  make test      corre las pruebas de los dos repos (levanta PostgreSQL para el backend)"
	@echo "  make test-api  solo el backend, contra PostgreSQL real"
	@echo "  make test-web  solo el frontend"
	@echo "  make migrate   aplica las migraciones"
	@echo "  make setup     prepara los archivos locales, sin levantar"
	@echo "  make clean     apaga y borra los volúmenes (SE PIERDE LA BASE DE DATOS)"
	@echo ""
	@echo "  http://localhost:$${WEB_PORT:-3000}   frontend"
	@echo "  http://localhost:$${API_PORT:-8080}   backend"

# --- Verifica que los repos hermanos estén clonados ---
check:
	@falta=0; \
	for d in $(API) $(WEB); do \
	  if [ ! -d "$$d" ]; then \
	    echo "FALTA el repo $$d"; falta=1; \
	  fi; \
	done; \
	if [ $$falta -eq 1 ]; then \
	  echo ""; \
	  echo "Los tres repos van clonados como hermanos:"; \
	  echo ""; \
	  echo "  jobout/"; \
	  echo "  ├── jobout-docs/     <- estás acá"; \
	  echo "  ├── jobout-core-api/"; \
	  echo "  └── jobout-web/"; \
	  echo ""; \
	  echo "  cd .. && git clone git@github.com:eldmark/jobout-core-api.git"; \
	  echo "         && git clone git@github.com:eldmark/jobout-web.git"; \
	  exit 1; \
	fi

# --- Avisa si un puerto ya está tomado, antes de que compose falle feo ---
ports:
	@set -a; [ -f .env ] && . ./.env; set +a; \
	choque=0; \
	for par in "WEB_PORT $${WEB_PORT:-3000} frontend" "API_PORT $${API_PORT:-8080} backend" "DB_PORT $${DB_PORT:-5432} postgres"; do \
	  set -- $$par; var=$$1; puerto=$$2; nombre=$$3; \
	  quien=$$(docker ps --format '{{.Names}}\t{{.Ports}}' 2>/dev/null | grep -E ":$$puerto->" | cut -f1 | head -1); \
	  if [ -n "$$quien" ]; then \
	    echo "El puerto $$puerto ($$nombre) ya lo usa el contenedor '$$quien'"; \
	    echo "  Cambialo en .env:  $$var=<otro>"; \
	    choque=1; \
	  fi; \
	done; \
	[ $$choque -eq 0 ] || { echo ""; echo "Corregí los puertos en .env y volvé a correr make dev."; exit 1; }

# --- Copia los .example a sus versiones locales, sin pisar lo que ya exista ---
setup: check
	@[ -f docker-compose.yml ]     || { cp docker-compose.example.yml docker-compose.yml; echo "creado docker-compose.yml"; }
	@[ -f .env ]                   || { cp .env.example .env; echo "creado .env"; }
	@[ -f $(API)/.env ]            || { cp $(API)/.env.example $(API)/.env; echo "creado $(API)/.env"; }
	@[ -f $(WEB)/.env.local ]      || { cp $(WEB)/.env.example $(WEB)/.env.local; echo "creado $(WEB)/.env.local"; }
	@echo ""
	@echo "Listo. Los valores por defecto sirven para desarrollo local."
	@echo "Para S3 hay que completar los .env; JWT_SECRET y las claves de PII ya traen valores falsos de desarrollo — ver documentation/desarrollo.md"

dev: setup ports
	@echo ""
	@echo "Levantando JobOut. La primera vez tarda: compila Rust e instala node_modules."
	@echo ""
	$(COMPOSE) up --build

up: dev

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

# El backend prueba contra PostgreSQL real (nunca SQLite): cada prueba crea y borra su propia
# base. Se levanta solo el servicio postgres y se le pasa el puerto del .env (DB_PORT).
test-api: setup
	@$(COMPOSE) up -d --wait postgres
	@set -a; [ -f .env ] && . ./.env; set +a; \
	  cd $(API) && TEST_DATABASE_URL="postgres://jobout:jobout@localhost:$${DB_PORT:-5432}/postgres" cargo test --workspace

test-web:
	$(COMPOSE) run --rm web npm test

test: test-api test-web

migrate:
	$(COMPOSE) run --rm core-api cargo run -p migration -- up

shell-api:
	$(COMPOSE) exec core-api bash

shell-web:
	$(COMPOSE) exec web sh

# Borra los volúmenes: se pierden la base de datos y los cachés de compilación
clean:
	$(COMPOSE) down -v

reset: clean dev
