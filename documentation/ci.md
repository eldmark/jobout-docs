# CI y desarrollo guiado por pruebas

El CI existe para una sola cosa: **que nadie tenga que confiar en la palabra de nadie**. Si
dice verde, los casos de verdad pasan, no hay secretos en el diff y el esquema está
documentado.

Las reglas para personas están en [`CONTRIBUTING.md`](../CONTRIBUTING.md). Este archivo es el
contrato técnico: qué corre, en qué orden y qué bloquea el merge.

## El ciclo

```
1. Los casos de verdad se acuerdan en docs/working/faseN-*.md   ← antes de codear
2. Se escriben los tests                                        → rojo
3. Se implementa el mínimo que los pasa                         → verde
4. Se limpia sin cambiar comportamiento                         → sigue verde
```

El CI corre en cada push. **El rojo del paso 2 queda registrado en el historial del PR**, y eso
es lo que prueba que el test prueba algo. Un test que nunca falló no vale nada: es igual de
fácil escribir uno que pasa siempre.

## Qué bloquea el merge

Igual en los cuatro repos:

| Check | Falla cuando |
|---|---|
| **Rama** | El nombre no es `jb-##-slug` |
| **PR completo** | Falta alguna de las cuatro secciones obligatorias |
| **Secretos** | Hay un `.env`, una clave, o una credencial embebida en el diff |
| **Migración documentada** | El PR toca migraciones y no toca `documentation/db.md` |
| **Formato** | El formateador cambiaría algo |
| **Lint** | Hay advertencias tratadas como error |
| **Tests unitarios** | Alguno falla |
| **Tests de integración** | Alguno falla |
| **Pruebas de seguridad** | Acceso horizontal, 401 sin token, o PII en la respuesta o el log |

Ningún check es opcional ni se saltea con un merge administrativo. Si un check estorba, se
discute y se cambia el check — no se ignora.

## Por repo

### `jobout-core-api` — Rust

```yaml
- cargo fmt --check
- cargo clippy --all-targets -- -D warnings
- cargo test --lib                                    # unitarias
- cargo test --test integration                       # contra PostgreSQL de prueba
- cargo sqlx migrate run --dry-run                    # la migración aplica limpio
```

Con un servicio de PostgreSQL efímero por corrida:

```yaml
services:
  postgres:
    image: postgres:16
    env:
      POSTGRES_PASSWORD: postgres
    options: >-
      --health-cmd pg_isready --health-interval 10s
      --health-timeout 5s --health-retries 5
```

`-D warnings` no es rigor de más: en Rust, la advertencia de hoy es el `unwrap` que revienta en
producción el mes que viene.

**Check propio del repo:** toda migración implementa `down`. Un `up` sin su `down` no pasa.

### `jobout-interview` — Python

```yaml
- ruff check .
- ruff format --check .
- mypy .
- pytest -m "not integration"      # unitarias
- pytest -m integration            # con el proveedor simulado
```

**Nunca contra el proveedor real.** Una prueba que llame a OpenAI Realtime de verdad es lenta,
cara y da distinto cada vez. Se corre a mano cuando se cambia el prompt de un recruiter o el
modelo. Ver [test.md](test.md).

**Check propio del repo, y el más importante de los cuatro:**

```yaml
- name: Sin credenciales de base de datos
  run: |
    if grep -rInE 'DATABASE_URL|postgres://|sqlalchemy|psycopg|asyncpg' --include='*.py' --include='*.toml' --include='*.yml' .; then
      echo "::error::jobout-interview no habla con la base de datos"
      exit 1
    fi
```

Este servicio no tiene acceso a la base de datos **por diseño**, no por olvido de
configuración. Si alguien agrega un cliente de PostgreSQL acá, el CI lo frena. Es la frontera
de seguridad del sistema: ver [security.md](security.md).

### `jobout-web` — Next.js

```yaml
- npm ci
- npm run lint
- npx tsc --noEmit
- npm run test          # vitest
- npm run build
- npx playwright test   # flujos completos
```

`tsc --noEmit` aparte del build: el build de Next puede pasar con errores de tipo según la
configuración, y no queremos enterarnos en producción.

### `jobout-docs`

Este repo. Enlaces internos que resuelven, cero secretos, PR completo, migración documentada.
Está en [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).

## Pruebas de seguridad obligatorias

En todo endpoint que toque datos de usuario. No son opcionales y no son un check aparte: van
en la suite de integración y por eso bloquean el merge.

```
✅  El usuario A pide por id un recurso de B → 404, nunca el dato
✅  Sin token → 401
✅  Un error provocado con datos sensibles no filtra PII en la respuesta ni en el log
✅  Lo que core-api manda a jobout-interview no contiene ningún campo de PII
```

El último se prueba del lado de `core-api`: se arma la carga de una sesión de entrevista y se
verifica campo por campo. Es barato y evita la fuga más probable del sistema.

## Secretos del CI

Van en los secrets del repositorio, nunca en el workflow. Un workflow es un archivo
versionado: lo que escribas ahí queda en el historial para siempre.

Las credenciales de las bases de datos de prueba pueden ir en claro en el workflow: son
efímeras, viven lo que dura la corrida y no dan acceso a nada. Cualquier otra cosa, secret.

## Pendiente

- Cobertura mínima, si se decide poner una.
- Corrida programada contra el proveedor real, semanal, para detectar cambios de comportamiento
  del modelo antes que un usuario.
- Escaneo de dependencias.
