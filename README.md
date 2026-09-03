# jobout-docs

Documentación y reglas de trabajo de **JobOut**. Este repo no tiene código: tiene el contrato
que siguen los que sí lo tienen.

## Qué es JobOut

Una plataforma de preparación y matching para conseguir empleo. El usuario encuentra ofertas,
se prepara, practica con recruiters de IA que tienen personalidad y memoria, aplica, mejora su
CV y recibe feedback con puntuación. No es una bolsa de trabajo.

## Los repos

| Repo | Stack | Qué hace |
|---|---|---|
| `jobout-docs` | Markdown | Este |
| `jobout-core-api` | Rust · Axum · SeaORM · PostgreSQL | Datos, auth, scoring. Toda la PII vive acá |
| `jobout-interview` | Python · FastAPI | Entrevista en tiempo real y avatar. Sin acceso a la BD |
| `jobout-web` | Next.js | Interfaz |

## Por dónde empezar

- **Soy un agente de IA** → [AGENTS.md](AGENTS.md). Empezá ahí, sin excepción.
- **Vengo nuevo al proyecto** → [documentation/producto.md](documentation/producto.md), después
  [documentation/arquitectura.md](documentation/arquitectura.md).
- **Voy a retomar trabajo** → [docs/continue.md](docs/continue.md).
- **Voy a tocar la base de datos** → [documentation/db.md](documentation/db.md) y la regla 2 de
  [AGENTS.md](AGENTS.md).
- **Voy a tocar seguridad o PII** → [documentation/security.md](documentation/security.md).

## Estructura

```
AGENTS.md            reglas + índice. El punto de entrada
docs/                proceso: fases, bugs abiertos, traspaso de sesión
  continue.md        qué se hizo y qué sigue
  bugs.md            bugs abiertos
  working/           fases en curso
  archived/          fases cerradas
documentation/       referencia estable: cómo es el sistema hoy
```
