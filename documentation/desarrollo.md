# Levantar el entorno

Un comando levanta backend, frontend y base de datos.

## Los repos van como hermanos

```
jobout/
├── jobout-docs/        ← desde acá se levanta todo
├── jobout-core-api/    Rust · Axum · SeaORM
└── jobout-web/         Next.js
```

```bash
mkdir jobout && cd jobout
git clone git@github.com:eldmark/jobout-docs.git
git clone git@github.com:eldmark/jobout-core-api.git
git clone git@github.com:eldmark/jobout-web.git
```

Si falta alguno, `make dev` lo dice y no arranca a medias.

## El comando

```bash
cd jobout-docs
make dev
```

Eso hace tres cosas:

1. Verifica que los repos hermanos estén clonados
2. Copia los `.example` a sus versiones locales, **sin pisar lo que ya tengas**
3. `docker compose up --build`

```
http://localhost:3000   frontend
http://localhost:8080   backend
localhost:5432          PostgreSQL
```

Si alguno de esos puertos ya está tomado por otro proyecto, `make dev` lo detecta **antes** de
intentar levantar, te dice qué contenedor lo tiene y no arranca a medias:

```
El puerto 3000 (frontend) ya lo usa el contenedor 'apuntes-frontend-1'
  Cambialo en .env:  WEB_PORT=<otro>
```

**La primera vez tarda varios minutos**: compila Rust desde cero e instala `node_modules`. Las
siguientes son rápidas — las dependencias quedan en volúmenes.

## Comandos

| | |
|---|---|
| `make dev` | Levanta todo |
| `make down` | Apaga |
| `make logs` | Sigue los registros |
| `make ps` | Estado de los servicios |
| `make test` | Pruebas de los dos repos |
| `make migrate` | Aplica las migraciones |
| `make setup` | Solo prepara los archivos locales, sin levantar |
| `make ports` | Verifica que los puertos estén libres |
| `make shell-api` / `make shell-web` | Una terminal dentro del contenedor |
| `make clean` | Apaga y **borra los volúmenes** — se pierde la base de datos |

## `.example` versionado, local ignorado

Mismo patrón en los tres repos:

| Versionado | Local, en `.gitignore` |
|---|---|
| `docker-compose.example.yml` | `docker-compose.yml` |
| `.env.example` | `.env` · `.env.local` |

En `jobout-docs` el `.env` guarda solo los puertos; los secretos viven en los `.env` de cada
servicio.

**El archivo local es tuyo.** Cambiale los puertos, agregale un servicio, montá otra carpeta —
nadie más lo ve y nada lo pisa. `make dev` solo lo crea si no existe.

**El `.example` es el contrato.** Si agregás una variable de entorno que el proyecto necesita,
va al `.example` **en el mismo PR**, con un valor falso. Si no, el siguiente que clone levanta
un entorno roto y no sabe por qué.

El CI de los tres repos rechaza un `docker-compose.yml` o un `.env` versionado.

## Qué hay que completar a mano

Los valores por defecto sirven para desarrollo local. Estos no tienen default posible:

| Variable | Dónde | De dónde sale |
|---|---|---|
| `CLERK_SECRET_KEY` · `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` | ambos | dashboard.clerk.com → API Keys |
| `PII_ENCRYPTION_KEY` · `PII_HASH_KEY` | core-api | `openssl rand -base64 32`, **dos distintas** |
| `S3_*` | core-api | Bucket privado de desarrollo |

Las dos claves de PII son distintas a propósito: una cifra, la otra genera el hash con el que
se busca por email. Si se filtra una, la otra sigue protegiendo. Ver [security.md](security.md).

## Trabajar en un solo servicio

Cada repo levanta solo:

```bash
cd jobout-core-api
cp .env.example .env && cp docker-compose.example.yml docker-compose.yml
docker compose up
```

El compose de `jobout-core-api` trae su propio PostgreSQL. El de `jobout-web` no trae backend:
o lo levantás aparte, o apuntás `NEXT_PUBLIC_API_URL` a donde lo tengas.

## Recarga en caliente

Los dos contenedores montan el código del host:

- **Backend** — `cargo-watch` recompila y reinicia al guardar
- **Frontend** — el servidor de Next actualiza la página sola

`node_modules`, `.next` y `target/` viven en **volúmenes anónimos**: el contenedor usa los
suyos y no los pisa lo que tengas en el host. Por eso no hace falta tener Rust ni Node
instalados para trabajar.

## Las tres etapas de cada Dockerfile

| Etapa | Para qué |
|---|---|
| `dev` | Desarrollo. Recarga en caliente, herramientas incluidas |
| `builder` | Compila el artefacto de producción |
| `runtime` | Lo que se despliega. Sin compilador, sin código fuente, **sin root** |

La imagen de producción corre como usuario `jobout` (uid 10001), no como root: si alguien
escapa del proceso, no escapa a la máquina. Y trae `HEALTHCHECK`, así que el orquestador sabe
cuándo el servicio está listo de verdad y no solo cuándo el contenedor arrancó.

El CI de cada repo construye la etapa `runtime` en cada PR. Una imagen que no compila se
detecta ahí, no al desplegar.

## Problemas comunes

**El puerto ya está en uso.** No toques el compose: cambialo en `jobout-docs/.env`.

```bash
WEB_PORT=3100
API_PORT=8180
DB_PORT=5532
```

`make dev` lo verifica antes de levantar. Para ver quién tiene un puerto:

```bash
docker ps --format '{{.Names}}\t{{.Ports}}' | grep 3000
```

**El backend no encuentra la base de datos.** Dentro de la red de compose el host es el nombre
del servicio, `postgres`, no `localhost`. El compose ya fija `DATABASE_URL` con el valor
correcto, y gana sobre lo que tengas en el `.env`.

**El frontend no llega al backend.** Dos URLs distintas a propósito:
`NEXT_PUBLIC_API_URL` la usa el navegador (`localhost:8080`), `API_URL_INTERNA` la usa el
servidor de Next dentro de la red (`core-api:8080`).

**Cambié las dependencias y no se ven.** Los volúmenes anónimos las guardan:
`make down && make dev` reconstruye.

**Rust no compila con mi toolchain local.** El proyecto necesita **rustc ≥ 1.88**. Dentro de
Docker no importa: la imagen ya la trae.
