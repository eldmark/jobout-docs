# Base de datos

**PostgreSQL. ORM: SeaORM. Migraciones en Rust, dentro de `jobout-core-api`.**

> **Estado: el esquema todavía no está diseñado.** Este archivo tiene las reglas que aplican
> desde el primer día; el esquema llega en la sesión siguiente. Ver
> [`docs/continue.md`](../docs/continue.md).

## La regla que no se negocia

**Cambio de esquema ⇒ migración SeaORM + este archivo actualizado, en el mismo PR.**

Sin excepción, sin «lo documento después». Un esquema documentado a medias es peor que uno no
documentado: el siguiente agente le cree y construye encima.

Corolarios:

- Ningún `ALTER TABLE` a mano contra un servidor. Si no está en una migración, no pasó.
- Las migraciones son **hacia adelante y reversibles**. Toda migración implementa `up` y `down`.
- Una migración no se edita después de haber corrido en cualquier entorno compartido. Se
  escribe otra.
- Todo modelo declara explícitamente su tabla. Nada de inferencia por convención cuando la
  convención se puede romper con un rename.

## Cifrado de columnas

Estas columnas se cifran **a nivel de aplicación**, antes de llegar a PostgreSQL:

| Dato | Por qué |
|---|---|
| email | PII directa |
| teléfono | PII directa |
| dirección | PII directa |
| contacto extraído del CV | PII directa, entra por una vía distinta y se olvida |

El cifrado en reposo del disco no reemplaza esto: protege contra el robo físico del disco, no
contra un dump ni contra una inyección. Ver [security.md](security.md).

Consecuencia práctica a tener presente al diseñar: **una columna cifrada no se puede indexar ni
buscar por contenido**. Si hace falta buscar por email, va un índice sobre un hash
determinístico del email, separado del valor cifrado.

## Convenciones

- Nombres de tablas en **plural, snake_case**: `interview_sessions`, no `InterviewSession`.
- Claves primarias **UUID v7**, no enteros autoincrementales: no filtran cuántos usuarios hay ni
  permiten enumerar.
- `created_at` y `updated_at` en toda tabla, con zona horaria (`timestamptz`).
- Borrado lógico solo donde haga falta auditar. **La cuenta de un usuario se borra de verdad**
  (HU-05).
- Las claves foráneas se declaran en la base, no solo en el código.

## Acceso

Solo **`jobout-core-api`** habla con PostgreSQL.

`jobout-interview` **no tiene credenciales de base de datos**. No es una omisión de
configuración: es la frontera de seguridad del sistema. Si aparece un `DATABASE_URL` en ese
repo, es un bug crítico.

## Esquema

_Por diseñar._ Las entidades previstas, para orientar el diseño:

| Entidad | Qué guarda |
|---|---|
| `users` | Cuenta, vinculada al id de Clerk. PII cifrada |
| `profiles` | Experiencia, habilidades, preferencias |
| `cvs` | Referencia al archivo en S3 más lo extraído |
| `recruiters` | El elenco: prompt, voz, foto, rúbrica. Configuración versionada |
| `interview_sessions` | Una sesión: recruiter, nivel, estado, tiempos |
| `interview_turns` | Turnos de la conversación con su transcripción |
| `scores` | Score, confianza, claridad, y el desglose que los explica |
| `job_offers` | Ofertas ingestadas |
| `applications` | Dónde aplicó el usuario y en qué estado va |
| `levels` | Progreso de gamificación y desbloqueos |
| `access_audit` | Quién accedió a qué dato sensible y cuándo, sin el contenido |

Al diseñar hay que resolver, entre otras: cómo se guarda la memoria del recruiter entre
sesiones (HU-13), cómo se versiona la rúbrica sin invalidar scores viejos, y cómo se busca por
email estando cifrado.
