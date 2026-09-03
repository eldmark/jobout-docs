# Documentación de JobOut

Referencia estable y versionada: **cómo es el sistema hoy**. Si algo acá no coincide con el
código, **el código gana** y este documento tiene un bug: se arregla en el mismo PR.

> **`documentation/` no es `docs/`.** [`docs/`](../docs/README.md) es proceso: fases, bugs
> abiertos, traspaso de sesión. Sirve para entender el *porqué* y el *qué sigue*. Esta carpeta
> guarda las *conclusiones*, resumidas y al día. No copies archivos de una a otra: son formatos
> distintos.

## Índice

| Documento | Qué responde |
|---|---|
| [producto.md](producto.md) | Qué vendemos y a quién, objetivos, historias de usuario, los recruiters, gamificación |
| [investigacion.md](investigacion.md) | El usuario (Luis), el cuadro de alternativas y el benchmark contra LinkedIn. **De acá salen las decisiones de producto** |
| [arquitectura.md](arquitectura.md) | Los cuatro repos y sus fronteras, el flujo de entrevista en tiempo real, evolución del avatar |
| [db.md](db.md) | Esquema, migraciones SeaORM, qué columnas se cifran |
| [api.md](api.md) | Contratos entre servicios, token efímero de entrevista, qué nunca cruza la frontera |
| [frontend.md](frontend.md) | Next.js, sala de entrevista, capa de audio, Clerk |
| [security.md](security.md) | Modelo de amenazas, cifrado de PII, secretos, política de privacidad |
| [test.md](test.md) | Cómo correr y escribir pruebas en cada repo |
| [ci.md](ci.md) | Qué corre el CI, qué bloquea el merge, el ciclo rojo→verde |
| [desarrollo.md](desarrollo.md) | Levantar el entorno completo con un comando, Docker, `.example` contra local |
| [glossary.md](glossary.md) | Score, confianza, claridad, sesión, nivel, panel |

Las reglas de trabajo están en **[`AGENTS.md`](../AGENTS.md)** (agentes) y
**[`CONTRIBUTING.md`](../CONTRIBUTING.md)** (personas), en la raíz.

## Estado actual

| | |
|---|---|
| Etapa | **Pre-código.** Documentación y esquema de BD |
| Repos creados | `jobout-docs` (este). Los otros tres, pendientes |
| Core backend | Rust · Axum · SeaORM · PostgreSQL |
| Servicio de IA | Python · FastAPI |
| Frontend | Next.js |
| Auth | Clerk |
| Alcance | **Two-sided**: candidatos y empresas |
| Avatar | V1: foto estática con animación mínima |
| Esquema de BD | **Diseñado.** 40+ tablas en [db.md](db.md). Faltan las migraciones |

Al 2026-09-03. El detalle de qué se hizo y qué sigue está en
[`docs/continue.md`](../docs/continue.md).

## Por dónde empezar

- **Vengo nuevo al proyecto** → [producto.md](producto.md) primero. Sin entender por qué esto
  no es una bolsa de empleos, el resto no se entiende. Después [arquitectura.md](arquitectura.md).
- **Voy a tocar la base de datos** → [db.md](db.md) y la regla 2 de [`AGENTS.md`](../AGENTS.md).
- **Voy a tocar la API** → [api.md](api.md) y [security.md](security.md), en ese orden.
- **Voy a tocar pantallas** → [frontend.md](frontend.md).
- **Voy a manejar datos de usuario** → [security.md](security.md). Completo, no en diagonal.
- **Voy a escribir pruebas** → [test.md](test.md) y [ci.md](ci.md).
- **Quiero levantar el proyecto** → [desarrollo.md](desarrollo.md). Es `make dev`.
- **Voy a abrir un PR** → [`CONTRIBUTING.md`](../CONTRIBUTING.md).
- **Quiero saber por qué el producto es así** → [investigacion.md](investigacion.md).
- **Soy un agente de IA** → [`AGENTS.md`](../AGENTS.md), y antes de nada
  [`docs/continue.md`](../docs/continue.md).
