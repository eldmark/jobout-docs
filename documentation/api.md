# API

> **Estado: contratos por definir.** Este archivo tiene las reglas y la frontera entre
> servicios, que aplican desde el primer endpoint. Los contratos concretos se llenan con cada
> fase.

## Las superficies

| Superficie | Servicio | Consumidor | Auth |
|---|---|---|---|
| `REST /api/v1` | `jobout-core-api` | `jobout-web` | JWT propio de `core-api` (MVP) |
| `WS /interview` | `jobout-interview` | `jobout-web` | **Token efímero de sesión** |
| Interna | `core-api` ↔ `interview` | Entre servicios | mTLS o secreto compartido |

## La frontera: qué NUNCA cruza a `jobout-interview`

Esta es la regla más importante del sistema.

**Nunca cruza:**

- Email, teléfono, dirección del usuario
- Nombre real
- El archivo del CV
- Credenciales de base de datos o de S3
- El JWT de acceso del usuario
- Cualquier id permanente de usuario

**Sí cruza:**

- Un **token efímero de sesión**
- El id del recruiter que va a conducir la entrevista
- El contexto de entrevista que `core-api` arma: puesto, seniority, temas a cubrir, y un
  resumen de sesiones anteriores **ya despersonalizado**
- Audio, en tiempo real

Si te encontrás necesitando pasar un dato de la primera lista, la solución no es cifrarlo: es
resolverlo del lado de `core-api`.

## Token efímero de entrevista

```
1. jobout-web            →  POST /api/v1/interviews          (JWT de acceso)
2. jobout-core-api       →  crea la sesión, arma el contexto
                            emite un token efímero de sesión
3. jobout-web            ←  { session_token, ws_url, recruiter }
4. jobout-web            →  WS /interview  (session_token)
5. jobout-interview      →  valida el token contra core-api
6. ... la entrevista ...
7. jobout-interview      →  POST interno: transcripción + señales de voz
8. jobout-core-api       →  persiste, calcula el score, invalida el token
```

Propiedades del token:

- Vigencia de **minutos**, no de horas.
- Alcance de **una sola sesión**. No sirve para otra.
- **No contiene identidad del usuario.** Solo el id de sesión.
- Se invalida al cerrar la sesión. Un token de una sesión terminada no abre nada.

## Reglas para todo endpoint

1. **Nace autenticado.** Si es público, va un comentario que lo justifique. Una ruta pública sin
   justificación es un bug.
2. **Consulta por id filtra por dueño**, igual que el listado. Es la falla de autorización más
   común y la más fácil de cometer.
3. **Nace con su prueba de integración**, escrita al implementarlo. Ver [test.md](test.md).
4. Errores sin PII: ni en el mensaje, ni en el detalle, ni en la traza.
5. Versionado en el path (`/api/v1`). Un cambio incompatible sube la versión, no rompe clientes.
6. Rate limiting por usuario en todo lo que consuma la API del proveedor de LLM: contiene abuso
   y contiene costo.

## Formato

- JSON. `snake_case` en los campos.
- Errores con forma estable: `{ "error": { "code": "...", "message": "..." } }`. El `code` es
  para la máquina, el `message` para la persona, y ninguno lleva PII.
- Paginación por cursor en todo listado que pueda crecer. Nada de devolver todo.
- Fechas en ISO 8601 con zona horaria.

## Endpoints

### Identidad (Fase 1)

Todas bajo `/api/v1`. Errores siempre `{"error": "<código>", "message": "<texto en español>"}`.
Cuerpo máximo 8 KB (413 si se excede). Nada de lo que entra o sale se escribe en logs.

| Ruta | Auth | Cuerpo → respuesta |
|---|---|---|
| `POST /auth/register` | pública (es la puerta de entrada) | `{email, password, first_name, last_name}` → 201 `{access_token, refresh_token, token_type: "Bearer", expires_in: 900}` · 409 `registro_no_disponible` · 422 `datos_invalidos` |
| `POST /auth/login` | pública | `{email, password}` → 200 mismos tokens · 401 `credenciales_invalidas` (igual para «no existe» y «clave incorrecta») · 403 `cuenta_no_disponible` (suspendido) · 429 `demasiados_intentos` (5 fallos en 15 min por email) |
| `POST /auth/refresh` | pública (el access puede haber expirado) | `{refresh_token}` → 200 tokens nuevos; el anterior queda revocado · 401 `sesion_invalida` para token desconocido, expirado, vacío o **reutilizado**; reusar uno rotado revoca todas las sesiones del usuario · 403 suspendido |
| `POST /auth/logout` | pública | `{refresh_token}` → 204, idempotente; solo revoca esa sesión |
| `GET /me` | Bearer | → 200 `{id, first_name, last_name, status, email, plan: {code, name} \| null}`. Nunca devuelve `email_hash`, hash de contraseña ni `clerk_user_id` |
| `DELETE /me` | Bearer | `{password}` → 204 · 403 `contrasena_incorrecta` (suma al contador de intentos; con bloqueo activo, 429) · 401 si la cuenta ya no existe · 422 sin contraseña |

`DELETE /me` es **borrado real** (HU-05): en una transacción deja una fila en `privacy_events`
(`account_deleted`, fecha y `subject_hash`, sin email, nombre ni id) y borra `users`; las FK en
cascada eliminan candidato, roles, credenciales, refresh tokens y suscripciones. El token de
acceso anterior pasa a 401 y el mismo email puede registrarse de nuevo como cuenta nueva.

**Las rutas se montan solo desde la tabla `src/routes/table.rs`.** Cada entrada declara su acceso:
`Access::Public("por qué")` exige una justificación real, y `Access::Authenticated` aplica la
autenticación **al montar la ruta**, aunque el handler se olvide de pedir `AuthUser`. Los módulos
de rutas no construyen `Router`s: devuelven `Vec<RouteSpec>`. `tests/route_table.rs` ejercita la
aplicación real (protegidas dan 401 con cualquier credencial inválida, los métodos declarados son
los reales, la lista de rutas esperadas está fija y obliga a que una ruta nueva se revise).
El límite de cuerpo (8 KB) es global, **salvo** que una ruta declare el suyo (`RouteSpec.body_limit`;
hoy solo `POST /cvs`, con 6 MiB). Un test impide declarar más de 6 MiB.

### Perfil y CV (Fase 2)

Bajo `/api/v1`, todas `Authenticated`. Los formatos exactos están en los tests de `tests/cvs.rs` y
`tests/profile.rs`.

| Ruta | Cuerpo → respuesta |
|---|---|
| `GET /catalogs/{nombre}` (`skills`, `languages`, `academic-levels`, `professions`, `job-hierarchies`) | → 200 `[{id, code, name}]` solo activos; nombre desconocido → 404 |
| `POST /cvs` | `multipart/form-data`, un único campo `file` → 201 `{id, version, is_primary, original_filename, size_bytes, created_at, extraction: {status: ready\|failed, reason, proposal}}` · 409 `limite_de_cvs` (5 por persona) · 413 `archivo_demasiado_grande` (5 MB) · 415 `tipo_no_permitido` · 422 |
| `GET /cvs` | → 200 lista de **mis** CVs (sin `storage_key`) |
| `GET /cvs/{id}/file` | → 200 los bytes, con `Content-Disposition: attachment`, `X-Content-Type-Options: nosniff` y `Cache-Control: private, no-store` |
| `PUT /cvs/{id}/primary` · `DELETE /cvs/{id}` | → 204 |
| `GET /cvs/{id}/extraction` | → 200 la propuesta (+ `reviewed`) |
| `POST /cvs/{id}/extraction/confirm` | cuerpo = perfil editado → 204; guarda **lo que la persona envió**, no lo propuesto |
| `GET /profile` · `PUT /profile` | perfil completo (en una cuenta nueva: vacío, nunca 404) · reemplazo **completo e idempotente** → 204 |

- **Un CV ajeno, inexistente o con id mal formado da siempre 404**, nunca 403.
- El tipo del archivo se decide **por su contenido** (`%PDF-`, o un ZIP con `word/document.xml`),
  nunca por la extensión ni por el `Content-Type` que diga el cliente.
- La propuesta (`extraction.proposal`) tiene `description`, `skills[]`, `languages[]` y
  `experiences[]`, cada elemento con su `confidence` (`alta` · `media` · `baja`). **Nunca** incluye
  teléfono, email ni dirección.
- Topes de confirmación y perfil: 60 skills, 10 idiomas, 30 experiencias, descripciones de hasta
  2000 caracteres. Los 422 llevan un texto fijo por causa y nunca repiten lo que envió la persona.

`DELETE /me` ahora también **borra los archivos** de los CVs: en la misma transacción que borra la
cuenta se encolan sus claves (cifradas) en `pending_storage_deletions`; después del commit se
intenta borrar cada archivo y, si el almacén falla, la cuenta igual queda borrada y una tarea
(`storage_cleanup`, cada 60 s) reintenta hasta 10 veces.

### Entrevista (Fase 3)

Bajo `/api/v1`. **Todas las rutas son `Authenticated`** (ninguna es pública; sin token o con uno
inválido, 401) y **filtran por dueño: una sesión, turno o score ajeno, inexistente o con id mal
formado en el path da siempre 404 `no_encontrado`**, nunca 403. Una cuenta suspendida recibe 403
`cuenta_no_disponible` en todas. Errores con la forma de Identidad:
`{"error": "<código>", "message": "<texto en español>"}`, más campos extra solo donde se indica.
Ningún error ni log lleva el texto de la persona, el del recruiter ni el desglose. Fechas ISO 8601
con zona. Los ids son UUID. Los formatos exactos quedan fijados por los tests de `tests/interviews.rs`.

| Ruta | Cuerpo → respuesta |
|---|---|
| `GET /recruiters` | → 200 `{items: [{id, code, display_name, role_title, personality, language}]}` (`language`: `es` \| `en`). Nunca `system_prompt` ni la rúbrica |
| `GET /levels` | → 200 `{items: [{id, code, name, position, available, unlocked, min_score_to_unlock, best_score, sessions_completed}]}` por `position` ascendente, para **mi** cuenta |
| `GET /progress` | → 200 `{items: [{session_id, completed_at, level, recruiter, score}]}` |
| `POST /interviews` | `{recruiter_id, level_id}` → 201 `Interview` con la primera pregunta · 403 `nivel_bloqueado` · 403 `limite_del_plan` · 404 · 409 `nivel_no_disponible` · 409 `sesion_en_curso` · 422 `datos_invalidos` · 503 `motor_no_disponible` |
| `GET /interviews` | `?limit&cursor&status` → 200 `{items: [InterviewSummary], next_cursor}` |
| `GET /interviews/{id}` | → 200 `Interview` con **todos** los turnos descifrados y en orden |
| `POST /interviews/{id}/pause` | → 204 · 409 `estado_invalido` |
| `POST /interviews/{id}/resume` | → 200 `{turn}` · 409 `estado_invalido` |
| `POST /interviews/{id}/abandon` | → 204 · 409 `estado_invalido` |
| `DELETE /interviews/{id}` | → 204 |
| `POST /interviews/{id}/turns` | `{text}` → 201 `{turn, done}` · 409 `estado_invalido` · 409 `turno_en_proceso` · 422 `datos_invalidos` · 429 `demasiados_intentos` · 503 `motor_no_disponible` |
| `POST /interviews/{id}/finish` | → 200 `Score` · 409 `estado_invalido` · 409 `turno_en_proceso` · 422 `entrevista_muy_corta` |
| `GET /interviews/{id}/score` | → 200 `Score` · 409 `estado_invalido` |

**Formas.**

```jsonc
// Turn: speaker es "recruiter" | "applicant" (el enum interview_speaker de db.md).
// Lo del recruiter lleva kind question|follow_up|closing; lo de la persona, kind "answer".
{ "seq": 2, "speaker": "recruiter", "kind": "follow_up", "text": "..." }
{ "seq": 3, "speaker": "applicant", "kind": "answer", "text": "..." }

// Interview (POST /interviews → 201, GET /interviews/{id} → 200)
{ "id": "uuid", "status": "in_progress",
  "recruiter": { "id": "uuid", "display_name": "Ana", "role_title": "RRHH" },
  "level": { "id": "uuid", "code": "junior", "name": "Junior" },
  "created_at": "...", "turns": [ /* Turn */ ] }

// InterviewSummary (sin transcripción)
{ "id": "uuid", "status": "completed",
  "level": { "id": "uuid", "code": "junior", "name": "Junior" },
  "recruiter": { "id": "uuid", "display_name": "Ana" },
  "score": 72, "created_at": "...", "completed_at": "..." }   // score y completed_at: null si no hay

// Score (finish y GET /score)
{ "score": 72, "clarity": 65, "confidence": null,
  "breakdown": [ { "criterion": "especificidad", "label": "Especificidad",
                   "score": 14, "max_points": 25, "why": "..." } ],
  "improvements": ["...", "..."], "rubric_version": 1, "computed_at": "..." }
```

**Decisiones que fija este contrato**

- **Listados**: siempre `{items: [...]}`. Solo `GET /interviews` pagina: por cursor opaco, más
  recientes primero (`created_at` desc), `limit` 1–50 (defecto 20), `next_cursor` es `null` en la
  última página; `status` opcional filtra por un estado (`in_progress` \| `paused` \| `completed` \|
  `abandoned`). Un `limit`, `status` o `cursor` inválido → 422 `datos_invalidos`. `GET /progress` no
  pagina: devuelve las **200 sesiones completadas más recientes**, en orden **cronológico ascendente**.
  `level` y `recruiter` en `progress` son el nombre del nivel y el `display_name`.
- **Estados**: la sesión nace `in_progress` (`created` existe en el enum pero no se ve por la API).
  `pause` solo desde `in_progress`; `resume`, solo desde `paused`; `abandon`, desde `in_progress` o
  `paused`; `turns` solo en `in_progress`; `finish` solo en `in_progress` (y `completed` es
  idempotente, ver abajo); `score`, solo en `completed`. Cualquier otro caso → **409 `estado_invalido`**
  sin tocar nada. `DELETE` vale en **cualquier** estado (incluso activa: libera el cupo) y no cambia el
  progreso ya acumulado.
- **Crear (`POST /interviews`)**: orden de validación: cuerpo (422; ids que no son UUID también, no
  404) → recruiter y nivel existen (404) → nivel `available` (409 `nivel_no_disponible`, antes que el
  bloqueo, para que Amazon, Google y McKinsey digan siempre lo mismo) → nivel desbloqueado (403
  `nivel_bloqueado`) → sin sesión activa (409 `sesion_en_curso`) → cuota (403 `limite_del_plan`).
  `sesion_en_curso` añade un campo `session_id` con la sesión activa:
  `{"error": "sesion_en_curso", "message": "...", "session_id": "uuid"}`. `limite_del_plan` añade
  `renews_at` (ISO 8601: primer instante del mes siguiente, UTC). Dos creaciones simultáneas dejan
  **una** sola sesión; la otra recibe `sesion_en_curso`.
- **Turnos (`POST .../turns`)**: `text` se recorta de espacios; vacío o de más de **4000 caracteres**
  (Unicode, no bytes) → 422 `datos_invalidos`, sin guardar nada. Esta ruta declara su propio tope de
  cuerpo (`RouteSpec.body_limit`, 32 KB): el global de 8 KB no alcanza. Responde 201 con el turno del
  recruiter y `done`; se guardan dos turnos con `seq` consecutivos, o ninguno. **Todo o nada**: si el
  motor falla → 503 `motor_no_disponible` y la respuesta de la persona **no** queda guardada (puede
  reenviar el mismo texto). Un turno simultáneo en la misma sesión → 409 `turno_en_proceso`.
  Límite de **20 turnos por minuto** por persona → 429 `demasiados_intentos` con `Retry-After`.
  Máximo **40 turnos** por sesión; al llegar, la sesión se cierra y `done` es `true`.
- **`done: true`** significa que la sesión ya está **`completed`** con su score calculado (el
  recruiter respondió con `kind: "closing"`). La respuesta no repite el score: se pide con
  `GET /interviews/{id}/score`.
- **`finish`** **devuelve el cuerpo `Score`** (200). Exige al menos **2 respuestas** de la persona;
  con menos → 422 `entrevista_muy_corta` y la sesión sigue abierta. Es **idempotente**: sobre una
  sesión ya `completed` devuelve el mismo `Score` sin recalcular, y dos `finish` simultáneos dejan un
  solo score. Sobre una sesión `paused` o `abandoned` → 409 `estado_invalido`; con un turno en vuelo,
  409 `turno_en_proceso`.
- **`Score`**: `score` y `clarity` son enteros 0–100; `confidence` es **siempre `null`** en modo
  texto; `breakdown` trae un elemento por criterio de la rúbrica **de la sesión** (no de la vigente),
  con `score` = puntos obtenidos, `max_points` y un `why` no vacío; la suma de los `score` del
  desglose es exactamente el `score` total; `improvements` tiene 2 o 3 textos ordenados por cuánto
  subirían el score; `rubric_version` es el entero de la versión fijada al empezar. Un `why` nunca
  copia más de 80 caracteres literales de la persona.
- **`resume`** devuelve el último turno del recruiter (`{turn}`), sin repetir ni saltar preguntas.
  Una sesión pausada más de 7 días pasa sola a `abandoned` y libera el cupo.
- **`Interview.turns`**: en `POST /interviews` trae solo la primera pregunta; en `GET` trae todos.
- **Desbloqueo**: terminar con `score` ≥ `min_score_to_unlock` del **siguiente** nivel lo desbloquea
  (un escalón por vez); `best_score` solo sube; `sessions_completed` cuenta solo `completed`. Un nivel
  no `available` siempre sale con `unlocked: false`.
- **Cuota**: cuenta sesiones **iniciadas** por mes calendario (UTC), así que abandonar o borrar no la
  devuelve; sin suscripción activa se trata como plan Gratis (1 al mes). Se puede apagar con
  `ENFORCE_PLAN_LIMITS=false`.

**Códigos de error del grupo**

| Estado | `error` |
|---|---|
| 401 | sin token o token inválido (igual que el resto de la API) |
| 403 | `nivel_bloqueado`, `limite_del_plan` (con `renews_at`), `cuenta_no_disponible` |
| 404 | `no_encontrado` (recurso ajeno, inexistente o id mal formado en el path) |
| 409 | `nivel_no_disponible`, `sesion_en_curso` (con `session_id`), `turno_en_proceso`, `estado_invalido` |
| 422 | `datos_invalidos`, `entrevista_muy_corta` |
| 429 | `demasiados_intentos` (con `Retry-After`) |
| 503 | `motor_no_disponible` |

_Por definir, fase por fase._ Áreas previstas:

| Área | Qué cubre |
|---|---|
| `/auth` | Sesión, perfil actual |
| `/profile` | Perfil, experiencia, habilidades |
| `/cvs` | Subida, extracción, URLs firmadas |
| `/recruiters` | El elenco disponible |
| `/interviews` | Crear sesión, listar, retomar, transcripción |
| `/scores` | Score y su desglose, progreso en el tiempo |
| `/offers` | Ofertas compatibles |
| `/applications` | Registro de aplicaciones |
| `/privacy` | Exportar datos, borrar cuenta |
