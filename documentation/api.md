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
| `GET /me` | Bearer | → 200 `{id, first_name, last_name, status, email, plan: {code, name} \| null, roles: [string], permissions: [string]}`. `roles` y `permissions` son **códigos** (sin ids), sin repetir y en orden alfabético, vigentes en esa petición (quitar un rol se ve en la siguiente); un candidato recién registrado trae `["applicant"]` y `[]`. Sirven para elegir menús, no para autorizar. Nunca devuelve `email_hash`, hash de contraseña ni `clerk_user_id` |
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
| `GET /catalogs/{nombre}` (`skills`, `languages`, `academic-levels`, `professions`, `job-hierarchies`; de la Fase 5, `countries`, `states`, `cities`, `salary-ranges`, `working-shifts`, `contract-types`, `employment-sectors`, `driver-licenses`) | → 200 `[{id, code, name}]` solo activos; nombre desconocido (también `zones` y `membership-types`, que no se sirven) → 404. `states` acepta `?country_id=<uuid>` y `cities` `?state_id=<uuid>`; un valor que no es uuid → 400 `parametro_invalido`, un padre sin hijos → `[]` |
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
| `POST /interviews` | `{recruiter_id, level_id, job_offer_id?}` → 201 `Interview` con la primera pregunta · 403 `nivel_bloqueado` · 403 `limite_del_plan` · 404 · 409 `nivel_no_disponible` · 409 `sesion_en_curso` · 422 `datos_invalidos` · 503 `motor_no_disponible` |
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
  "created_at": "...", "turns": [ /* Turn */ ],
  "offer": { "id": "uuid", "title": "Analista", "company_name": "Café Nuevo" } }  // solo si es práctica de una oferta

// InterviewSummary (sin transcripción)
{ "id": "uuid", "status": "completed",
  "level": { "id": "uuid", "code": "junior", "name": "Junior" },
  "recruiter": { "id": "uuid", "display_name": "Ana" },
  "score": 72, "created_at": "...", "completed_at": "...",     // score y completed_at: null si no hay
  "offer": { "id": "uuid", "title": "Analista", "company_name": null } }  // solo si es práctica de una oferta

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

### Ofertas y empresas (Fase 5a)

> **Contrato, todavía sin código.** Lo fija esta sección y los tests de la fase lo congelan
> (`tests/companies.rs`, `tests/offers.rs`, `tests/applications.rs`, `tests/panel.rs`). Cubre las
> HU-32 y HU-50 a HU-56. El matching (`sort=match`, `match`, `match_score`) es el paso 8 (5b): ver «Matching
> (Fase 5b)». La práctica de una oferta (HU-31) se hizo en la 5b con la alternativa mínima de la decisión 12: ver «Práctica de una oferta (Fase 5b)».
> Casos de verdad en [docs/working/fase5-ofertas-empresas.md](../docs/working/fase5-ofertas-empresas.md).

Bajo `/api/v1`. Reglas comunes, además de las de «Reglas para todo endpoint» y las de la Fase 3:

- **Nada es público.** Toda ruta es `Authenticated` o `Access::Permission("...")` (nuevo en la
  tabla de rutas: exige token **y** el permiso, y responde 403 `sin_permiso` aunque el handler no lo
  compruebe). Los permisos se leen de `role_permissions` en cada petición (la misma consulta que
  detecta cuentas suspendidas), así que **quitar un rol corta el acceso en la petición siguiente**.
- Errores: `{"error": "<código>", "message": "<texto en español>"}`, más campos extra solo donde se
  indica. Ningún error, log ni traza lleva datos del candidato, el texto de una oferta ni el nombre
  de una empresa confidencial. Los 422 usan un texto fijo por causa y no repiten lo enviado.
- **Una empresa es de quien pertenece a ella.** Las rutas del reclutador son `/company/...`
  (singular: «mi empresa»); la empresa sale de la membresía de quien llama, nunca del path ni del
  cuerpo. Un recurso (oferta, aplicación, invitación, reclutador) de **otra** empresa, inexistente o
  con id mal formado da siempre **404 `no_encontrado`**, con cuerpo idéntico en los tres casos (SX6).
  Una persona con el permiso pero sin empresa recibe también 404 `no_encontrado`.
- **Orden general de validación** (cada ruta lo concreta): 401 → 403 `cuenta_no_disponible` → 403
  `sin_permiso` → 413 → 422 del cuerpo o de la consulta (los ids del **cuerpo** que no son UUID
  también son 422) → 404 del recurso → 403 de la empresa (`empresa_no_verificada`,
  `membresia_vencida`) → 409 de estado → 422 de reglas de negocio que dependen del recurso
  (`oferta_incompleta`) → 429.
- **Cuerpos cerrados.** Un campo desconocido en el cuerpo → 422 `campo_no_permitido`; un parámetro
  desconocido en la consulta → 422 `parametro_no_permitido` (ver «No discriminación»). Valor inválido
  de un campo o parámetro conocido → 422 `datos_invalidos`.
- **Topes de cuerpo:** 8 KB (global) salvo `POST`/`PUT /company` (16 KB) y `POST`/`PUT
  /company/offers` (64 KB), que lo declaran con `RouteSpec.body_limit`. Excederlo → 413.
- **Textos de usuario como dato.** Títulos, descripciones y notas se guardan tal cual, se recortan de
  espacios y se devuelven como texto plano en JSON: nunca se interpretan como HTML ni se «limpian»
  en el servidor; el frontend los pinta escapados (OF10, SX7). Longitudes en caracteres Unicode.
- Ids UUID, fechas ISO 8601 con zona (las `date` de oferta, `YYYY-MM-DD`). Listados
  `{items: [...], next_cursor}` con cursor opaco y `limit` 1–50 (defecto 20); `limit`, `cursor` o
  `status` inválidos → 422 `datos_invalidos`.

#### Roles y permisos

| Rol | Permisos |
|---|---|
| `applicant` | ninguno propio (las rutas de candidato son solo `Authenticated`). Todo registro lo recibe |
| `recruiter` | `offer.create` · `offer.update` · `offer.publish` · `offer.close` · `application.read` · `application.review` · `favorite.manage` |
| `company_admin` | los de `recruiter` + `company.update` · `company.invite` |
| `admin` | `company.verify` **y nada más**: el admin de plataforma no lee aplicaciones ni ofertas ajenas |

- Una misma cuenta es candidato **y** reclutador (decisión 10): conserva `applicant` y suma
  `company_admin` o `recruiter`. Un reclutador **sí** usa sus rutas de candidato, y sus datos de
  candidato **nunca** aparecen en el panel de su propia empresa (no puede aplicar a las ofertas de
  su empresa: 409 `oferta_propia`).
- **Una persona pertenece a una sola empresa** en la 5a (índice único parcial sobre
  `company_recruiters.user_id` donde `deleted_at` es nulo).
- **Los roles de empresa solo se dan por dos caminos:** crear la empresa (`company_admin`) y aceptar
  una invitación (`company_admin` o `recruiter`). `admin` no se da por ninguna ruta (siembra o
  consola): nadie puede escalarse (RO6). Un rol de empresa sin fila en `company_recruiters` no sirve
  para nada (404).
- `GET /me` agrega `"roles": ["applicant", "company_admin"]` (códigos) y `"permissions":
  ["offer.create", ...]`, ambos ordenados alfabéticamente y sin ids. Es lo que usa el frontend para
  elegir menús; **no** sustituye al servidor, que comprueba en cada ruta.

#### Catálogos nuevos (paso 1)

`GET /catalogs/{nombre}` suma `countries`, `states`, `cities`, `salary-ranges`, `working-shifts`,
`contract-types`, `employment-sectors` y `driver-licenses`, con la misma forma y protección
(`[{id, code, name}]`, solo activos; `states` y `cities` agregan `country_id` y `state_id`).
`cities` admite `?state_id=<uuid>` (un `state_id` inválido → 422) porque trae todos los municipios.
`zones` y `membership-types` **no** se sirven. `salary-ranges` sale ordenado por monto, en
quetzales (`GTQ`).

#### Empresas, reclutadores e invitaciones

| Ruta | Acceso | Cuerpo → respuesta |
|---|---|---|
| `POST /companies` | `Authenticated` | `CompanyInput` → 201 `Company` · 409 `ya_tiene_empresa` · 409 `empresa_duplicada` · 422 · 429 |
| `GET /company` | `Authenticated` + membresía | → 200 `Company` · 404 |
| `PUT /company` | `company.update` | `CompanyInput` completo, idempotente → 204 · 409 `nit_inmutable` · 422 |
| `GET /company/recruiters` | `company.invite` | `?limit&cursor` → 200 `{items: [{id, display_name, position, role, joined_at}], next_cursor}` |
| `DELETE /company/recruiters/{id}` | `company.invite` | → 204 · 404 · 409 `ultimo_administrador` |
| `POST /company/invitations` | `company.invite` | `{email, role}` → 201 `Invitation` (con `token`, **una sola vez**) · 409 `ya_tiene_empresa` · 422 · 429 |
| `GET /company/invitations` | `company.invite` | `?limit&cursor` → 200 `{items: [Invitation sin token], next_cursor}` |
| `DELETE /company/invitations/{id}` | `company.invite` | → 204 (revoca) · 404 |
| `POST /invitations/accept` | `Authenticated` | `{token}` → 200 `{company: {id, name}, role}` · 404 `invitacion_invalida` · 409 `ya_tiene_empresa` · 429 |

```jsonc
// CompanyInput (POST /companies, PUT /company). Todo lo demás → 422 campo_no_permitido
{ "name": "Café Nuevo S.A.", "tax_id": "1234567-8", "website": "https://cafenuevo.example",
  "phone": "+502 5555 0000", "description": "Tostamos y vendemos café.",
  "country_id": "uuid", "employment_sector_id": "uuid" }
// website, phone y description pueden omitirse o ir null

// Company (POST /companies → 201, GET /company → 200)
{ "id": "uuid", "name": "Café Nuevo S.A.", "tax_id": "1234567-8", "website": "...", "phone": "...",
  "description": "...", "country_id": "uuid", "employment_sector_id": "uuid",
  "verified": false, "verified_at": null,
  "membership": null,   // o {"type": "business", "start_date": "2026-11-01", "expiration_date": "2027-11-01", "status": "active"}
  "my_role": "company_admin", "created_at": "..." }

// Invitation (POST → 201 con token; GET → sin token)
{ "id": "uuid", "role": "recruiter", "status": "pending", "expires_at": "...", "created_at": "...",
  "token": "…43 caracteres base64url…" }   // status: pending | used | expired
```

- **Límites de `CompanyInput`:** `name` 2–120 · `tax_id` 4–20 caracteres de letras, dígitos, guion y
  espacio (se normaliza: mayúsculas, sin guiones ni espacios, antes de comparar) · `website`
  `https://` de hasta 200 · `phone` hasta 20 · `description` hasta 2000 · `country_id` y
  `employment_sector_id` de sus catálogos y activos (id inactivo o desconocido → 422, como en el perfil).
- **Crear (`POST /companies`)**, orden: cuerpo (422) → la persona ya tiene empresa (409
  `ya_tiene_empresa`) → NIT ya usado por otra empresa (409 `empresa_duplicada`, texto genérico) →
  límite (429: 5 intentos por persona y día). En **una transacción** crea la empresa **sin verificar**
  (`verified_at` nulo), el `company_recruiters` y el rol `company_admin`. Sin verificar no publica.
  El NIT se guarda **cifrado** más un HMAC para la unicidad; solo lo ven los de la empresa y el
  admin de plataforma.
- `PUT /company` no cambia el NIT de una empresa ya verificada: si difiere → 409 `nit_inmutable`.
  Cambiar el `name` de una verificada **no** quita la verificación (queda como riesgo aceptado).
- `my_role` es `company_admin` o `recruiter`. `membership` es `null` si nunca tuvo; `status` es
  `active` o `expired` (calculado por fechas, no por la columna). `verified` es `verified_at != null`.
- **Reclutadores**: `display_name` es nombre + la inicial del apellido; **nunca** correo, teléfono, ni
  `married_last_name`. `DELETE /company/recruiters/{id}` (también uno mismo para salir): borra la fila
  `company_recruiters` (`deleted_at`), le quita los roles de empresa (efecto en la petición siguiente) y
  **no** toca a la empresa, sus ofertas ni el historial de decisiones. Si era el único `company_admin`
  → 409 `ultimo_administrador`. Quitar a quien sigue siendo candidato no afecta su cuenta (EM9).
- **Invitaciones.** `role` es `recruiter` o `company_admin`; `email` hasta 254 (solo se guarda su
  HMAC, el mismo de `users.email_hash`: la invitación solo sirve para **esa** cuenta). El `token` son
  256 bits aleatorios en base64url, **se devuelve una única vez** en el 201 (no hay correo en la 5a: el
  admin se lo pasa a la persona) y en la base solo queda su SHA-256 (`token_hash`). Vigencia **7 días**.
  **Un solo uso**: aceptar marca `used_at` con un `UPDATE ... WHERE used_at IS NULL AND expires_at >
  now()`, así dos aceptaciones simultáneas dejan una. Revocar la deja inservible. Máximo 20
  invitaciones por empresa y día (429, cuentan también las revocadas) y 50 pendientes (422
  `datos_invalidos`, que se comprueba antes); invitar a un correo que ya es de otra empresa responde
  igual que a uno nuevo (no revela cuentas): la 409 sale solo al aceptar. El 409 `ya_tiene_empresa` al
  invitar es solo para un correo que ya es de **la misma** empresa de quien invita. Una invitación ya
  usada o revocada no se revoca (404).
- `POST /invitations/accept`, orden: cuerpo (422) → límite (429: 10 intentos por persona y hora) →
  token desconocido, vencido, usado, revocado **o de otro correo** → 404 `invitacion_invalida`
  (misma respuesta en los cinco casos) → la persona ya tiene empresa → 409 `ya_tiene_empresa`.
  Crea `company_recruiters` y el rol en una transacción. No revela datos de la empresa antes de aceptar.
- **EM9 / borrado de cuenta:** un `company_admin` único no puede borrar su cuenta (`DELETE /me` →
  409 `ultimo_administrador`) mientras la empresa exista. En la 5a no hay ruta para cerrar una
  empresa: lo resuelve el equipo (ver «Pendiente»).

#### Verificación de la empresa y membresía (`company.verify`)

Solo el rol `admin` de plataforma. Es manual (decisiones 1 y 11): se revisa dominio de correo y
documento fuera de la API y se marca aquí. **Nunca un `UPDATE` a mano.**

| Ruta | Cuerpo → respuesta |
|---|---|
| `GET /admin/companies` | `?verified=true\|false&limit&cursor` → 200 `{items: [{id, name, tax_id, website, created_at, verified_at, creator_email_domain, recruiters_count}], next_cursor}` (más antiguas primero) |
| `POST /admin/companies/{id}/verify` | → 204, idempotente · 404 · 403 `sin_permiso` si el admin es miembro de esa empresa |
| `POST /admin/companies/{id}/unverify` | → 204, idempotente · 404 |
| `PUT /admin/companies/{id}/membership` | `{membership_type: "business", start_date, expiration_date}` → 204 · 404 · 422 |

- `creator_email_domain` es solo lo que va tras la `@` del correo de quien creó la empresa (para
  contrastarlo con el sitio); nunca el correo completo. La lista y cada acción dejan **una fila en
  `access_audit`** (`company.list`, `company.verify`, `company.unverify`, `company.membership_set`;
  `resource_type: company`, `resource_id` = la empresa o nulo en la lista; sin el contenido; IP
  hasheada). Si el insert de auditoría falla, la operación falla (500): no hay acción sin rastro.
  Repetir `verify` sobre una verificada responde 204 **sin** una segunda fila ni mover `verified_at`.
- `unverify` limpia `verified_at`: sus ofertas publicadas dejan de ser visibles y de aceptar
  aplicaciones (igual que EM7) y el panel responde 403 `empresa_no_verificada`; los borradores se
  conservan. Es la salida si se descubre un reclutador falso.
- **Membresía:** `membership_type` es el `code` de `membership_types` (solo `business` en la 5a, el `code` que sembró el paso 1; no hay
  cobro). `PUT` **reemplaza** la vigente (la anterior queda `cancelled`). `expiration_date` ≥
  `start_date` y a lo sumo 400 días después; fuera de eso → 422 `datos_invalidos`. Verificar no crea
  membresía: una empresa verificada sin membresía vigente no publica.

**Efectos de la vigencia (EM6, EM7).** «Vigente» = `start_date ≤ hoy ≤ expiration_date` (fecha UTC) y
`status = active`. Con la empresa verificada **y** la membresía vigente:

| Acción | Sin verificar | Membresía no vigente |
|---|---|---|
| Crear y editar borradores, ver su panel de ofertas | sí | sí |
| Publicar (`publish`), reanudar una pausada | 403 `empresa_no_verificada` | 403 `membresia_vencida` |
| Pausar, cerrar | sí | sí |
| Ofertas ya publicadas visibles para candidatos y aceptando aplicaciones | **no** | **no** |
| Panel: ver aplicaciones, mover estados, favoritos | 403 `empresa_no_verificada` | 403 `membresia_vencida` |

Las ofertas **conservan** su estado: al renovar, las `published` vuelven a ser visibles solas.
Mientras tanto las aplicaciones existentes siguen en su estado y el candidato las sigue viendo en
«mis aplicaciones». Se comprueban en cada petición, no en una tarea. Si la empresa no está verificada
**y** la membresía no es vigente, gana `empresa_no_verificada`.

#### Ofertas del reclutador

Todas bajo `/company/offers`, de **mi** empresa. Las lecturas piden `offer.update`.

| Ruta | Permiso | Cuerpo → respuesta |
|---|---|---|
| `POST /company/offers` | `offer.create` | `OfferInput` → 201 `OfferDetail` en `draft` · 422 · 429 |
| `GET /company/offers` | `offer.update` | `?limit&cursor&status` → 200 `{items: [OfferRow], next_cursor}` |
| `GET /company/offers/{id}` | `offer.update` | → 200 `OfferDetail` · 404 |
| `PUT /company/offers/{id}` | `offer.update` | `OfferInput` completo, idempotente → 204 · 404 · 409 · 422 |
| `DELETE /company/offers/{id}` | `offer.update` | → 204 · 404 · 409 `estado_invalido` (solo un `draft` sin aplicaciones) |
| `POST /company/offers/{id}/publish` | `offer.publish` | → 200 `{id, status, publication_date}` · 403 · 404 · 409 · 422 `oferta_incompleta` |
| `POST /company/offers/{id}/pause` | `offer.publish` | → 204 · 404 · 409 `estado_invalido` |
| `POST /company/offers/{id}/close` | `offer.close` | → 204 · 404 · 409 `estado_invalido` |

```jsonc
// OfferInput. Cualquier otro campo (edad, género, estado civil, featured, status…) → 422 campo_no_permitido
{ "title": "Desarrollador backend", "description": "Construirás APIs en Rust...",
  "is_confidential": false,
  "is_experience_required": true, "required_experience": 2,      // años; null si no se exige
  "main_language_id": "uuid", "schedule": "Lunes a viernes, 8 a 17", "required_availability_to_travel": false,
  "vacancies": 2, "hiring_date": "2027-02-01",
  "profession_id": "uuid", "employment_sector_id": "uuid", "job_hierarchy_id": "uuid",
  "minimum_academic_level_id": "uuid", "state_id": "uuid", "city_id": "uuid",
  "salary_range_id": "uuid", "working_shift_id": "uuid", "contract_type_id": "uuid",
  "skills": [ { "skill_id": "uuid", "is_required": true, "min_level": "intermediate" } ],
  "languages": [ { "language_id": "uuid", "min_proficiency": "intermediate" } ],
  "driver_license_ids": [] }

// OfferDetail = OfferInput + lo calculado por el servidor
{ "id": "uuid", "status": "draft", "required_driver_license": false,
  "publication_date": null, "closed_at": null, "created_at": "...", "updated_at": "...",
  "applications_count": 0, "created_by": { "id": "uuid", "display_name": "Ana P." }, /* …OfferInput… */ }

// OfferRow (listado)
{ "id": "uuid", "title": "...", "status": "published", "is_confidential": true, "vacancies": 2,
  "publication_date": "2026-11-12", "applications_count": 14, "created_at": "..." }

// 422 oferta_incompleta
{ "error": "oferta_incompleta", "message": "Faltan datos para publicar la oferta.",
  "fields": ["description", "requirements"] }
```

- **Campos.** Solo `title` es obligatorio al crear (un borrador puede estar casi vacío); el resto
  puede omitirse o ir `null`. `title` 3–120 · `description` 20–5000 (existe **una sola vez**, OF2) ·
  `required_experience` 0–50, obligatorio si `is_experience_required` es `true` y `null` si es `false` ·
  `schedule` hasta 120 · `vacancies` 1–999 · `hiring_date` hoy o futura, a lo sumo en 2 años ·
  `skills` hasta 30 (sin skill repetida), `languages` hasta 5 (sin idioma repetido),
  `driver_license_ids` hasta 5 · `min_level` es `beginner`·`intermediate`·`advanced`·`expert` y
  `min_proficiency` es `native`·`advanced`·`intermediate`·`basic` (los enums del perfil). Todos los
  `*_id` salen de sus catálogos y deben estar activos (id inactivo o desconocido → 422, OF11/OF12), y
  `city_id` debe ser de `state_id` (422 si no). **No hay** columnas JSON: los requisitos van en
  `job_offer_skills`, `job_offer_languages` y `job_offer_driver_licenses` (OF3).
- **Derivados, no enviables:** `required_driver_license` es verdadero si hay licencias;
  `publication_date` la pone el servidor en la **primera** publicación; `featured` es de plataforma y no
  se envía; `status` solo cambia por las rutas de transición; `company_visible` es
  `is_confidential = false` y no sale de la API.
- **Estados** (OF6): `draft → published ⇄ paused`, `published|paused → closed`. `closed` es final:
  `publish` sobre una cerrada → 409 `estado_invalido`; un `draft` no se cierra (se borra). `publish` solo
  desde `draft` o `paused`, `pause` solo desde `published`, `close` desde `published` o `paused`;
  cualquier otro caso → 409 `estado_invalido` sin tocar nada, incluido repetir la misma transición (no
  son idempotentes; dos simultáneas dejan una y la otra recibe 409).
- **`publish`**, orden: 404 → 409 `estado_invalido` → 403 `empresa_no_verificada` → 403
  `membresia_vencida` → 422 `oferta_incompleta` → 429 (el límite de 20 ofertas por empresa y hora, SX5,
  se cuenta en `POST /company/offers`, no aquí; `publish` no consume cupo). Mínimo para publicar (OF5): `title`,
  `description`, `vacancies`, `profession_id`, `state_id`, `city_id` y **al menos un requisito** (skill,
  idioma o licencia); `fields` lista los que faltan (`requirements` agrupa los tres).
  `hiring_date` pasada también es `oferta_incompleta`.
- **Editar (`PUT`).** Reemplazo completo. En `closed` → 409 `estado_invalido`. **Congelado desde la primera
  aplicación recibida** (OF7): todo menos `description`, `schedule`, `vacancies` y `hiring_date`; si la
  oferta ya tiene aplicaciones y el cuerpo cambia algo congelado → 409 `oferta_con_aplicaciones` (para
  cambiar los requisitos se cierra y se crea otra: no se versiona). **`is_confidential` queda
  congelado desde la primera publicación** → 409 `confidencial_inmutable`, para no deanonimizar ni
  esconder una empresa a posteriori.
- **Cierre automático (OF9):** una tarea diaria cierra las `published`/`paused` cuya `hiring_date` ya
  pasó (fecha UTC) y fija `closed_at`. Cerrar a mano también fija `closed_at`. Cerrar **no** toca las
  aplicaciones existentes (siguen en el panel mientras dure la retención).
- `OfferRow`/`GET` filtran por `status`; un `offer` de otra empresa → 404. Cada petición del listado
  hace un número fijo de consultas (sin N+1, CA7).

#### Ofertas para candidatos

`Authenticated`, sin permiso de rol (un reclutador también puede mirar ofertas). Visible =
`status = published` **y** empresa verificada y activa **y** membresía vigente. Todo lo demás
(borrador, pausada, cerrada, empresa sin verificar o con membresía vencida, inexistente, id mal
formado) → **404 `no_encontrado` idéntico** (CA5).

| Ruta | Cuerpo → respuesta |
|---|---|
| `GET /offers` | `?limit&cursor&sort&profession_id&state_id&city_id&contract_type_id&salary_range_id&working_shift_id&employment_sector_id&job_hierarchy_id` → 200 `{items: [OfferSummary], next_cursor}` |
| `GET /offers/{id}` | → 200 `OfferPublic` · 404 |

```jsonc
// OfferSummary
{ "id": "uuid", "title": "Desarrollador backend", "confidential": false,
  "company": { "id": "uuid", "name": "Café Nuevo S.A.", "website": "https://..." },  // null si confidential
  "profession": { "id": "uuid", "code": "software_engineer", "name": "..." },
  "employment_sector": { "id": "uuid", "code": "...", "name": "..." },
  "state": { "id": "uuid", "code": "...", "name": "Guatemala" }, "city": { "id": "uuid", "code": "...", "name": "Mixco" },
  "contract_type": { }, "salary_range": { }, "working_shift": { },   // cada uno {id, code, name} o null
  "vacancies": 2, "publication_date": "2026-11-12",
  "my_application": { "id": "uuid", "status": "applied" } }            // null si no apliqué

// OfferPublic = OfferSummary + requisitos
{ /* …OfferSummary… */ "description": "...", "schedule": "...", "hiring_date": "2027-02-01",
  "required_experience": 2, "required_availability_to_travel": false, "required_driver_license": false,
  "main_language": { }, "job_hierarchy": { }, "minimum_academic_level": { },
  "skills": [ { "skill": { "id": "uuid", "code": "rust", "name": "Rust" }, "is_required": true, "min_level": "intermediate" } ],
  "languages": [ { "language": { }, "min_proficiency": "intermediate" } ],
  "driver_licenses": [ { } ] }
```

- **Qué implementa el paso 5 (HU-30, sin matching).** Visible también exige que la `hiring_date` no
  haya pasado (una oferta vencida por fecha se oculta aunque la tarea diaria aún no la cierre). Hasta
  el paso 6 `my_application` es siempre `null` (no existen aplicaciones). Los criterios de orden que
  no existen (`sort=name`, `company`, `age`...) son `parametro_no_permitido`; un `sort` vacío
  o repetido es `datos_invalidos`. El cursor es opaco y solo sirve para el
  `sort` con el que se emitió (otro → 422 `datos_invalidos`). Mirar ofertas no escribe nada ni
  tiene límite de lecturas propio: la tabla de «Tasas y límites» no lo prevé.
- Orden fijo: `publication_date` descendente, con `id` de desempate. `sort` acepta `recent`
  (defecto), `oldest` y `match` (ver «Matching (Fase 5b)»). Todos los filtros son
  ids de catálogo; cada uno puede venir una sola vez.
- **Nunca** se devuelve `created_by`, datos de reclutadores (nombre, correo), `status`,
  `applications_count`, `featured` ni el `tax_id`/teléfono de la empresa (CA4).
- **Confidencial.** `company` es `null` y `confidential` es `true`; queda visible el sector, la
  ubicación y todos los requisitos, que ya son públicos. No existe filtro, búsqueda ni orden por empresa
  (con uno se deanonimizaría) y `q` de texto libre tampoco existe en la 5a, porque la descripción puede
  nombrar a la empresa. El texto de `description` lo escribe quien publica: el servidor **no** puede
  detectar un nombre ahí (ver `security.md`).

#### Aplicar, ver y retirar (candidato)

`Authenticated`. Todo filtra por dueño: una aplicación ajena, inexistente o con id mal formado → 404.

| Ruta | Cuerpo → respuesta |
|---|---|
| `POST /offers/{id}/applications` | `{consent, shared_fields}` → 201 `Application` · 404 · 409 `ya_aplicaste` · 409 `oferta_propia` · 422 · 429 |
| `GET /me/applications` | `?limit&cursor&status` → 200 `{items: [ApplicationSummary], next_cursor}` (por `applied_at` descendente) |
| `GET /me/applications/{id}` | → 200 `Application` con `history` · 404 |
| `POST /me/applications/{id}/withdraw` | → 204 · 404 · 409 `estado_invalido` |

##### El contrato de consentimiento (HU-52, decisión 2)

Es la primera vez que los datos de una persona los ve otra. Reglas, de la más a la menos
importante:

1. **El consentimiento es explícito, por aplicación y nunca se asume.** `consent` debe ser el booleano
   `true`. Falta, `false`, `null` o de otro tipo (`"true"`, `1`) → 422 `consentimiento_requerido`, sin
   crear nada. No hay valor por defecto, ni «recordar mi elección», ni consentimiento heredado de una
   aplicación anterior.
2. **`shared_fields` es una lista de nombres de un conjunto cerrado**, no valores. Los nombres son:

   | Nombre | Qué ve el reclutador | Obligatorio |
   |---|---|---|
   | `display_name` | nombre y la inicial del apellido ("Ana P.") | **sí** |
   | `skills` | skills con `level` y `years_of_experience` | **sí** |
   | `experience` | experiencias: empresa, cargo, fechas (sin la descripción) | **sí** |
   | `experience_descriptions` | la `description` de cada experiencia | no |
   | `languages` | idiomas con su nivel | no |
   | `education` | último nivel académico, profesión y jerarquía del perfil | no |
   | `profile_description` | la descripción profesional del perfil | no |
   | `email` | correo (**contacto**) | no |
   | `phone` | teléfono (**contacto**) | no |
   | `match_score` | tu puntaje de coincidencia con esta oferta, calculado **solo con lo que marcaste** (ver «Matching (Fase 5b)») | no |

   El mínimo (`display_name`, `skills`, `experience`) siempre va: sin él el reclutador no tiene con
   qué evaluar y la aplicación se reduciría a un nombre. Cualquier nombre fuera de la tabla, repetido,
   o una lista que no sea de cadenas → 422 `datos_invalidos`; **faltan** los obligatorios → 422
   `datos_invalidos`. Hasta 10 elementos (el cuerpo cabe en el tope de 8 KB). `interview_score` sigue
   siendo desconocido (no está decidido qué entrevista contaría).
3. **Qué puede ver el reclutador, jamás más que eso:** solo lo marcado. Lo no marcado **no viaja** en la
   respuesta (la clave no existe, no es `null`). **Nunca**, marque lo que marque la persona: el archivo
   del CV (no hay ruta para ello, ni URL firmada ni `storage_key`), dirección, documento de identidad,
   fecha de nacimiento ni edad, género, estado civil (ni `married_last_name`, ni segundo apellido),
   foto, transcripciones ni resultados de entrevistas, el plan, ni el id permanente de la persona.
4. **Contacto solo si se comparte** (`email`, `phone`): sin ellos el reclutador no tiene forma de
   escribirle, y la plataforma no ofrece chat. Es decisión de la persona, por aplicación.
5. **Se ve en vivo, no es una copia.** `shared_fields` guarda *nombres* (para poder auditar qué aceptó),
   y el panel lee el perfil actual filtrado por esos nombres. Si la persona borra un teléfono, deja de
   verse; si lo cambia, se ve el nuevo. Lo que se compartió se deja de ver al retirar la aplicación,
   al borrar la cuenta, o a los **90 días de cerrada la oferta** (retención, decisión 5). **La lista es
   inmutable**: no hay ruta para ampliar lo compartido después, y compartir más obliga a retirar (y no
   se puede reaplicar).
   `consented_at` se fija en el servidor, nunca viene del cliente.
6. **Una aplicación nunca comparte con nadie más que la empresa de esa oferta,** ni siquiera con otros
   reclutadores de otra empresa ni con el admin de plataforma.

##### Aplicar (`POST /offers/{id}/applications`)

Orden: cuerpo (422 `datos_invalidos`; `consent` mal tipado → `consentimiento_requerido`) →
`consent` verdadero (422 `consentimiento_requerido`) → `shared_fields` válidos (422 `datos_invalidos`)
→ la oferta existe y es visible, tal como la ve el listado (404 `no_encontrado`, igual para ajena,
borrador, cerrada, pausada, de empresa vencida o id mal formado) → la oferta **es de mi propia
empresa** (409 `oferta_propia`) → ya apliqué (409 `ya_aplicaste` con `application_id`) → límite
(429). Si la oferta se cierra o se pausa entre que la persona abrió la pantalla y envió, el 404 es el
mismo (AP5): no hay un código distinto para «cerrada».

- **Una sola vez por oferta**, para siempre: `UNIQUE(applicant_id, job_offer_id)`. Un segundo `POST`, o
  uno tras haber **retirado** o haber sido rechazada, → 409 `ya_aplicaste`
  (`{"error": "ya_aplicaste", "message": "...", "application_id": "uuid"}`), sin segunda fila. Dos
  simultáneas dejan **una**; la otra recibe `ya_aplicaste` (AP3, AP4). Reaplicar tras retirar no existe.
- **Límite (SX5):** 20 aplicaciones creadas por persona en 24 horas móviles (cuentan las retiradas) →
  429 `demasiados_intentos` con `Retry-After`. Las rechazadas por 409 no cuentan.
- Crea en **una transacción** la aplicación (`applied`), el evento `null → applied` (`changed_by` = la
  persona) y el `consented_at`. No envía correo ni avisa a nadie.

```jsonc
// POST /offers/{id}/applications
{ "consent": true, "shared_fields": ["display_name", "skills", "experience", "email"] }

// 201 Application (GET /me/applications/{id} es igual, con history; ApplicationSummary no lleva history ni shared_fields)
{ "id": "uuid", "status": "applied", "applied_at": "...", "status_changed_at": "...",
  "consented_at": "...", "shared_fields": ["display_name", "skills", "experience", "email"],
  "offer": { "id": "uuid", "title": "Desarrollador backend", "status": "published",   // published | paused | closed
             "confidential": true,
             "company": null,   // {id, name, website} solo si no es confidencial o ya se reveló
             "state": { }, "city": { } },
  "history": [ { "status": "applied", "at": "..." } ] }
```

##### Ofertas confidenciales (HU-55, decisión 3)

- La oferta se ve y se aplica **sin empresa**: en el listado, el detalle, la aplicación, «mis
  aplicaciones» y **en cualquier error** (los textos de error nunca nombran empresa). No hay otra
  ruta que la devuelva.
- **Se revela cuando el reclutador mueve esa aplicación a `shortlisted`**, no antes: en ese momento se
  fija `company_revealed_at` y desde entonces `offer.company` trae `{id, name, website}` **en la
  aplicación de esa persona** (en `GET /me/applications` y `/{id}`). La revelación es **por aplicación**:
  el listado público y las demás personas siguen sin ver la empresa. Una vez revelada no se esconde otra
  vez, aunque después pase a `rejected` o la persona retire.
- **No se revela** en `applied`, `under_review`, `rejected` (si nunca fue `shortlisted`) ni `withdrawn`;
  tampoco cuando `hired` llega sin pasar por `shortlisted` (no puede: ver la máquina de estados).
- Lo que la persona **sí** sabe antes de aplicar: título, descripción, requisitos, sector, ubicación,
  salario y contrato. Es la apuesta que ya declaran los riesgos de la fase, y la pantalla de
  aplicar la dice con todas las letras.
- Al reclutador **sí** se le muestra siempre su propia oferta con el aviso «confidencial»: la oferta es
  confidencial solo frente a candidatos.

##### Máquina de estados de una aplicación

```
(aplicar) ──► applied ──► under_review ──► shortlisted ──► hired
                 │            │               │
                 │            └──► rejected ◄─┘
   applied | under_review | shortlisted ──► withdrawn   (solo la persona)
```

| De | A | Quién |
|---|---|---|
| — | `applied` | la persona, al aplicar |
| `applied` | `under_review` | reclutador (`application.review`) |
| `under_review` | `shortlisted` | reclutador (`application.review`) — revela la empresa si es confidencial |
| `under_review` | `rejected` | reclutador |
| `shortlisted` | `hired` | reclutador |
| `shortlisted` | `rejected` | reclutador |
| `applied`, `under_review`, `shortlisted` | `withdrawn` | **solo** la persona |

`hired`, `rejected` y `withdrawn` son **finales** (PA5): ninguna otra transición. El reclutador no puede
retirar y la persona no puede mover nada más que a `withdrawn`. No hay salto de `applied` a
`shortlisted`, `rejected` ni `hired`, ni de `rejected` a `hired` (la cadena del plan quedaba ambigua y se
resolvió así). Cualquier transición que no está en la tabla, o repetir el estado actual → 409
`estado_invalido` con el estado vigente (`{"error": "estado_invalido", "message": "...", "status":
"applied"}`) sin tocar nada. Cada transición que sí ocurre escribe en **la misma transacción** una fila
en `job_application_events` (`from_status`, `to_status`, `changed_by`, `note`, `created_at`) y actualiza
`status`/`status_changed_at` con `UPDATE ... WHERE status = <de>`: dos movimientos simultáneos dejan uno.
`hired` no cierra la oferta ni descuenta vacantes (lo decide quien publica).

**Retirar** (`POST /me/applications/{id}/withdraw`): desde `applied`, `under_review` o `shortlisted` →
204; sobre una ya `withdrawn` → 204 (idempotente, sin segundo evento); desde `hired` o `rejected` → 409
`estado_invalido`. Al retirar, el panel deja de mostrar lo compartido (AP8) y se borra el favorito de
la empresa sobre esa persona si no le queda otra aplicación viva con ella. El historial queda.

**Lo que la persona ve del historial:** `history` = `[{status, at}]` en orden cronológico. **Nunca** el
`changed_by`, la `note` ni qué reclutador decidió. El motivo de un rechazo no existe para la persona en
la 5a (AP7): la `note` es interna del reclutador.

#### Registro de aplicaciones externas (HU-32, decisión 6)

Manual y **privado**: lo que la persona anota de aplicaciones hechas fuera de la plataforma. Nadie más
lo ve ni se comparte con ninguna empresa; no es una aplicación (no pasa por la máquina de estados ni
por el consentimiento). `Authenticated`, filtra por dueño (ajeno, inexistente o id mal formado → 404).

| Ruta | Cuerpo → respuesta |
|---|---|
| `POST /me/external-applications` | `ExternalInput` → 201 `External` · 409 `limite_de_registros` · 422 |
| `GET /me/external-applications` | `?limit&cursor&status` → 200 `{items: [External], next_cursor}` (por `applied_on` desc) |
| `GET /me/external-applications/{id}` | → 200 `External` · 404 |
| `PUT /me/external-applications/{id}` | `ExternalInput` completo, idempotente → 204 · 404 · 422 |
| `DELETE /me/external-applications/{id}` | → 204 · 404 |

```jsonc
{ "company_name": "Banco X", "position": "Analista", "applied_on": "2026-11-05",
  "status": "interviewing", "notes": "Hablé con RRHH, esperan al 20." }
// External = lo anterior + "id", "created_at"
```

`company_name` y `position` 2–120; `applied_on` hasta hoy y no antes de 5 años; `status` ∈ `applied` ·
`interviewing` · `offer` · `rejected` · `withdrawn` · `accepted`; `notes` hasta 2000, opcional, **cifrada**.
Máximo **200** registros por persona (409 `limite_de_registros`). El `status` es libre: no hay máquina.

#### Panel del reclutador

De **mi** empresa y de la oferta indicada. La empresa debe estar verificada y con membresía vigente
(403 `empresa_no_verificada` / `membresia_vencida`, tras el 404).

| Ruta | Permiso | Cuerpo → respuesta |
|---|---|---|
| `GET /company/offers/{id}/applications` | `application.read` | `?limit&cursor&status&favorite&sort` → 200 `{items: [PanelRow], next_cursor}` |
| `GET /company/applications/{id}` | `application.read` | → 200 `PanelApplication` · 404 |
| `POST /company/applications/{id}/status` | `application.review` | `{to, note?}` → 200 `PanelApplication` · 404 · 409 `estado_invalido` · 422 |
| `PUT /company/applications/{id}/favorite` | `favorite.manage` | → 204, idempotente · 404 · 409 `estado_invalido` |
| `DELETE /company/applications/{id}/favorite` | `favorite.manage` | → 204, idempotente · 404 |

```jsonc
// PanelRow (lista: lo mínimo, sin contacto ni detalle)
{ "id": "uuid", "status": "under_review", "applied_at": "...", "status_changed_at": "...",
  "is_favorite": true, "availability": "available",
  "applicant": { "display_name": "Ana P." },
  "shared_fields": ["display_name", "skills", "experience"] }

// PanelApplication (detalle): solo lo marcado, claves ausentes si no se compartió
{ "id": "uuid", "status": "shortlisted", "applied_at": "...", "status_changed_at": "...",
  "is_favorite": true, "availability": "available",
  "offer": { "id": "uuid", "title": "..." },
  "shared_fields": ["display_name", "skills", "experience", "email"],
  "applicant": {
    "display_name": "Ana P.",
    "skills": [ { "skill": { "id": "uuid", "code": "rust", "name": "Rust" }, "level": "advanced", "years_of_experience": 3 } ],
    "experience": [ { "company": "...", "title": "...", "start_date": "2022-01-01", "end_date": null } ],
    "email": "ana@example.com" },
  "history": [ { "from": "applied", "to": "under_review", "at": "...", "note": null } ] }
```

- **`availability`**: `available` · `withdrawn` (la persona retiró) · `deleted` (borró su cuenta) ·
  `retention_expired` (pasaron 90 días del cierre de la oferta). Salvo en `available`, `applicant` es
  `null`, no hay `shared_fields` y el resto (estado, fechas, historial) se conserva: es la
  entrada **anónima** (PA10, BO2).
- **Qué ve y qué no** (PA2, PA3): solo las claves de `shared_fields`; nunca el CV, el id de la persona
  ni los datos de la lista «nunca» del consentimiento. La **lista** (`PanelRow`) solo trae
  `display_name`; el contacto y el resto salen únicamente de `GET /company/applications/{id}`.
- **Orden y filtros cerrados** (PA9): `sort` ∈ `recent` (por `applied_at` desc, defecto) · `oldest`;
  `status` uno de los seis; `favorite` `true`/`false`; `limit` y `cursor`. Nada más (ver «No
  discriminación»).
- **Auditoría (PA8, SX4):** cada llamada que devuelve datos de una persona escribe en `access_audit`,
  **sin el dato**: la lista, **una** fila (`application.list`, `resource_type: job_offer`, `resource_id` la
  oferta); el detalle y el cambio de estado, una fila (`application.view` / `application.review`,
  `resource_type: job_application`, `resource_id` la aplicación), con `actor_user_id` e `ip_hash`. Si
  el insert falla, la petición falla (500) y no se devuelve el dato. Los candidatos no ven esta tabla en
  la 5a.
- **Límite anti-raspado (SX5):** 120 lecturas de detalle por reclutador y hora → 429
  `demasiados_intentos` con `Retry-After`.
- **Cambiar de estado**, orden: cuerpo (422: `to` desconocido, `note` de más de **500** caracteres; `to`
  `withdrawn` o `applied` → 422 `datos_invalidos`) → 404 (aplicación de otra empresa o inexistente,
  SX2/SX6) → 403 empresa → 409 `estado_invalido` (la máquina de arriba). `note` es opcional,
  interna, **se guarda cifrada** (puede traer cualquier cosa) y solo la ven los reclutadores de esa
  empresa en `history`. Quien mueve a `shortlisted` una oferta confidencial dispara la revelación
  de su empresa a esa persona: la UI lo avisa **antes** de confirmar.
- **Favoritos** (PA6, PA7): una fila única por `(empresa, persona)`; `PUT` repetido → 204 sin duplicar.
  Se marca sobre una aplicación pero vale para la persona en toda la empresa (todas sus aplicaciones en
  ella salen `is_favorite`). Sobre una aplicación no `available` → 409 `estado_invalido`. El favorito
  de una empresa nunca lo ve otra ni la persona. No hay un listado propio de favoritos: se usa
  `favorite=true`.
- **Quién ve qué dentro de la empresa:** todos los reclutadores de la empresa ven todas las aplicaciones
  de sus ofertas (no hay «mis ofertas» por reclutador en la 5a).

**Precisiones del paso 7** (`jb-67-recruiter-panel`; lo que el contrato dejaba abierto):

- Fuera de `available`, `applicant` es `null` y la clave `shared_fields` **no viaja**, ni en la lista
  ni en el detalle. `history[].from` es `null` en el primer paso (`applied`).
- **Una aplicación no `available` no se mueve** (candidato eliminado o retención vencida; la retirada
  ya era final): 409 `estado_invalido` con su estado. Sin datos que ver no hay nada que decidir.
- `note` se recorta; vacía o solo espacios equivale a no mandarla. El tope de 500 es en caracteres.
- `sort` vacío → `datos_invalidos`; cualquier otro valor fuera de `recent`·`oldest` (incluido `match`,
  que en el panel no es un valor futuro) → `parametro_no_permitido`. `favorite` acepta solo `true` o
  `false` (otro valor → `datos_invalidos`).
- Los **favoritos** también exigen la empresa vigente (403) y **no** escriben en `access_audit`: no
  devuelven datos de la persona. `DELETE` sobre una entrada anónima → 204 sin efecto.
- **Retirar** borra el favorito de la empresa si a la persona no le queda otra aplicación **viva**
  (`applied`, `under_review` o `shortlisted`) en ella.
- El tope de 120 detalles se cuenta sobre las filas `application.view` de `access_audit` de la última
  hora, con un candado por reclutador (no se pasa con peticiones en paralelo). `Retry-After` = hasta que
  la más vieja salga de la ventana.
- El cambio de estado, su evento y su fila de auditoría van en **una** transacción: si la auditoría
  falla, el estado no cambia.

#### No discriminación (HU-52, caso PA9, CA2, OF4)

Es una regla de contrato y se prueba con tests que fallan si aparece un criterio prohibido.

- **Edad, fecha de nacimiento, género, estado civil, nombre, apellido, foto, dirección, nacionalidad y
  documento no existen** como campo de oferta ni como filtro, orden o búsqueda de **ningún** listado
  (candidato, panel ni admin).
- **Conjuntos cerrados.** Ofertas: filtros `profession_id`, `state_id`, `city_id`, `contract_type_id`,
  `salary_range_id`, `working_shift_id`, `employment_sector_id`, `job_hierarchy_id`; orden `sort` ∈
  `recent`·`oldest`. Panel: filtros `status`, `favorite`; orden `sort` ∈ `recent`·`oldest`. Más
  `limit` y `cursor`. Admin: `verified`. El panel **no** filtra por habilidades ni por texto.
- **Parámetro fuera del conjunto → 422 `parametro_no_permitido`** (`?age=…`, `?gender=…`,
  `?marital_status=…`, `?name=…`, `?photo=…`, `?sort=name`, `?q=…`), **antes** de tocar la base y sin
  repetir el nombre ni el valor. Campo de cuerpo fuera del contrato → 422 `campo_no_permitido`
  (`age_range_from`, `gender_preference_id`, `marital_status_id`, etc.), y no se guarda nada.
  Los valores ilegales de un parámetro **permitido** son `datos_invalidos`.
- **Orden estable:** siempre por fecha (`publication_date` o `applied_at`) con `id` de desempate; el
  panel nunca ordena por nombre ni por nada que se pueda inferir de la persona.
- **Lo que sí queda abierto** (y se dice): `display_name` va al reclutador, y un nombre puede delatar
  género u origen. Es lo que la decisión 2 recomienda y el riesgo está en `security.md`.

#### Borrado y retención (BO1–BO4, decisión 5)

- **`DELETE /me` de un candidato** borra, en la misma transacción que ya existe, sus matches (5b: no hay tabla que borrar, el puntaje no se guarda),
  los favoritos que las empresas tenían sobre ella (`company_favorite_applicants`) y sus registros
  externos (`external_applications`). Sus **aplicaciones no se borran**: pierden `applicant_id` y
  `shared_fields` (queda `[]`) y quedan en el panel como **«candidato eliminado»**
  (`availability: "deleted"`, `applicant: null`), con estado, fechas e historial; el `changed_by` de los
  eventos hechos por la persona pasa a `null`. Así el reclutador no pierde su cuenta de aplicaciones y
  no queda ningún dato de la persona. Las ofertas y empresas quedan intactas (BO1, BO2, PA10).
- **`DELETE /me` de un reclutador** conserva sus decisiones como anónimas (BO3): `changed_by` de sus
  eventos y `created_by` de sus ofertas pasan a `null` (`created_by: null` en `OfferDetail`; el historial
  del panel no lleva quién decidió). Su `company_recruiters` y sus roles se borran en cascada. Si era el
  único `company_admin` → 409 `ultimo_administrador` y **no** se borra nada.
- **Constancia (BO4):** la misma fila `account_deleted` de `privacy_events`, sin nombre, correo ni id; no
  hay tipo nuevo.
- **Retención (decisión 5):** el panel deja de ver los datos compartidos a los **90 días** de
  `closed_at` de la oferta (`availability: "retention_expired"`, calculado al leer) y de inmediato al
  retirar o borrar. No hay copia que purgar: el dato nunca salió del perfil de la persona.

#### Tasas y límites (SX5)

| Qué | Límite | Respuesta |
|---|---|---|
| Aplicaciones creadas | 20 por persona en 24 h | 429 `demasiados_intentos` + `Retry-After` |
| Ofertas creadas | 20 por empresa y hora | ídem |
| Empresas creadas | 5 intentos por persona y día | ídem |
| Invitaciones creadas | 20 por empresa y día (50 pendientes) | ídem |
| Aceptar invitaciones | 10 intentos por persona y hora (acierte o no) | ídem |
| Detalles del panel leídos | 120 por reclutador y hora | ídem |
| Cualquier cuerpo | 8 KB (salvo 16 KB y 64 KB arriba) | 413 |

Los contadores salen de filas ya existentes (aplicaciones, ofertas, invitaciones, `access_audit`) o de
una tabla de intentos, como `login_attempts`; nunca de memoria del proceso. Todo 429 lleva `Retry-After`
en segundos enteros.

### Práctica de una oferta (Fase 5b)

Paso 9 de `working/fase5-ofertas-empresas.md` (HU-31, casos PR1–PR6). Es `POST /interviews` con un
campo más; todo lo demás de «Entrevista (Fase 3)» sigue igual. Se adoptó la **alternativa mínima** de la
decisión 12, no aplazarla a la Fase 4. Los tests están en `tests/interview_offer_practice.rs` (API) y
`tests/interview_offer_engine.rs` (motor).

- **`job_offer_id`** (UUID, opcional; ausente o `null` = entrevista de siempre). Solo vale una oferta que un
  candidato **ve hoy**: la misma regla de `GET /offers/{id}` (publicada, con fecha de contratación vigente,
  de una empresa verificada, activa y con membresía vigente). Borrador, pausada, cerrada, vencida, de una
  empresa sin verificar, inexistente o con un id que no es UUID → **404 `no_encontrado`**, idéntico en todos
  los casos y sin gastar cuota. Un valor que no es texto (número, objeto, lista, booleano) → 422
  `datos_invalidos`.
- **Orden de validación**: cuerpo (422) → recruiter, nivel y **oferta** existen/visible (404) → nivel
  disponible (409) → desbloqueado (403) → sin sesión activa (409) → cuota (403). Practicar gasta la cuota
  del plan igual que cualquier sesión y respeta «una sesión activa».
- **Las preguntas.** El motor recibe solo el título de la oferta y los **nombres** de sus habilidades
  obligatorias y de sus idiomas (`OfferFocus`): nunca la empresa, ningún id ni dato de la persona. La
  entrevista es la del recruiter y nivel elegidos, con tres cambios: la apertura del recruiter lleva una
  frase con el puesto (`Hoy practicaremos la entrevista para el puesto «…»`); justo después de la
  apertura va **una pregunta por habilidad obligatoria** (las 3 primeras por código) y **una por idioma**
  (los 2 primeros) con una plantilla fija; y el resto del banco sigue igual y en orden. Sigue siendo
  determinista. Títulos y nombres se limpian (espacios) y se cortan a 80 caracteres.
  Una oferta sin requisitos solo cambia la apertura. Las habilidades deseables no se preguntan.
- **`offer` en la respuesta**: `Interview` e `InterviewSummary` traen `offer: {id, title, company_name}`
  cuando la sesión está vinculada; la clave **no aparece** si no. `company_name` es `null` si la oferta es
  confidencial (PR2: la empresa no sale ni en la respuesta ni en las preguntas).
- **Nunca es una aplicación ni llega a la empresa** (PR3): no crea `job_applications`, no entra al panel
  ni a ninguna lectura del reclutador, y la persona puede aplicar después como si nada.
- **La sesión sobrevive a la oferta.** Si la oferta se cierra, la sesión conserva `offer` (con el título).
  Si se borra, la FK es `ON DELETE SET NULL`: la sesión sigue, sin `offer`, y las preguntas que quedan son
  las del banco base.

#### Desviaciones

- **`job_offer_id` mal formado es 404, no 422**, a diferencia de `recruiter_id` y `level_id`: PR4 lo pide
  así (un id que no es de una oferta visible es siempre el mismo 404).
- **La oferta se lee otra vez en cada turno** (no se copia a la sesión: no hay migración). Si un
  reclutador edita los requisitos a mitad de una práctica, las preguntas que faltan se calculan con los
  nuevos. Si la oferta se borra, vuelve el banco base.

### Matching (Fase 5b)

Paso 8 de `working/fase5-ofertas-empresas.md` (HU-30, casos MA1–MA10). Decisión 4 (el reclutador ve el
puntaje **solo si la persona lo comparte**) y 14 (sin `job_preferences`) con la opción recomendada. La
decisión 8 se resolvió de otra forma: ver «Desviaciones».

#### El puntaje

`score` entero 0–100 = puntos de los componentes que **aplican** ÷ suma de sus pesos × 100, redondeado.
Un componente que la oferta no pide, o cuyo dato la persona no compartió con el reclutador, **no aplica**
y su peso no entra en la cuenta.

| Componente | Peso | Aplica si la oferta… | Puntos |
|---|---|---|---|
| `skills` | 50 | tiene habilidades | Cada una pesa 2 si es obligatoria y 1 si no. Con nivel ≥ `min_level` (o sin `min_level`): completa; por debajo, o sin nivel cuando se pide uno: la mitad; no la tiene: 0 |
| `languages` | 15 | tiene idiomas | Cada idioma: dominio ≥ `min_proficiency` completo; menor, la mitad; ausente, 0. Orden `basic` < `intermediate` < `advanced` < `native` |
| `experience` | 20 | `is_experience_required` y `required_experience` > 0 | `min(1, años ÷ requeridos)`. Años = **unión** de los periodos de `applicant_experiences` (dos empleos a la vez no suman doble); un empleo actual cuenta hasta hoy |
| `academic_level` | 15 | fija `minimum_academic_level_id` | Completo si el `sort_order` del nivel de la persona ≥ el pedido; si no, 0 |

- Ningún componente aplica (la oferta solo pide licencias, por ejemplo): `score` 0 y
  `breakdown.reason = "sin_requisitos_comparables"`.
- Perfil vacío: puntaje bajo con su explicación (`empty_profile: true`), nunca error ni `NaN` (MA10).
- **Lo que el matching no puede leer** (MA4, MA5): edad, género, estado civil, nombre, foto, dirección,
  correo, teléfono, CV. La función pura recibe solo habilidades, idiomas, periodos de experiencia y el
  `sort_order` del nivel académico; pruebas la alimentan con esos datos de más y exigen el mismo
  puntaje, y otra recorre su código y falla si nombra uno.
- Mismo perfil y misma oferta → mismo puntaje y desglose (MA1). «Hoy» entra como parámetro.
- Criterios del plan sin dato en el perfil (ubicación, expectativa salarial, turno, tipo de contrato,
  licencia de conducir): **no entran**. `job_preferences` no está migrada (decisión 14) y la licencia
  de la persona no está en su perfil. Entrarán cuando exista dónde guardarlos.

```jsonc
// match: en cada oferta del listado y en el detalle de /offers, de quien llama. Siempre presente.
{ "score": 67,
  "breakdown": {
    "reason": null,                         // o "sin_requisitos_comparables"
    "empty_profile": false,
    "components": [                         // siempre los cuatro, en este orden
      { "key": "skills", "weight": 50, "points": 33.3, "applies": true,
        "matched": [ { "skill": {id, code, name}, "required": true } ],
        "partial": [ { "skill": {...}, "required": false, "min_level": "advanced", "level": "intermediate" } ],  // level puede ser null
        "missing": [ { "skill": {...}, "required": true } ] },
      { "key": "languages", "weight": 15, "points": 15, "applies": true,
        "matched": [ { "language": {...}, "min_proficiency": "intermediate", "proficiency": "advanced" } ],
        "partial": [], "missing": [ { "language": {...}, "min_proficiency": "basic" } ] },
      { "key": "experience", "weight": 20, "points": 10, "applies": true, "required_years": 4, "years": 2 },
      { "key": "academic_level", "weight": 15, "points": 0, "applies": false, "reason": "no_pedido" } ] } }
```

`points` y `years` llevan a lo sumo un decimal. Un componente que no aplica trae `points: 0`, `applies:
false` y `reason`: `no_pedido` (la oferta no lo pide) o `no_compartido` (solo en la vista del
reclutador). Solo los que aplican traen `matched`/`partial`/`missing` (`skills`, `languages`) o
`required_years`/`years` (`experience`).

#### Cálculo y recálculo (MA7, MA8)

El puntaje **no se guarda**: se calcula al leer, con el perfil de ese momento y los requisitos de la
oferta de ese momento, así que cambiar el perfil o la oferta se refleja en la lectura siguiente
(MA7) y no hay recálculo que bloquee nada ni que repetir (MA8). Leer no escribe. Cada petición hace un
número fijo de consultas, sin importar cuántas ofertas trae.

#### `GET /offers?sort=match` (MA6)

- Ordena por `match.score` descendente; empate por `publication_date` e `id`, descendentes. El cursor es
  propio de este orden (guarda el último puntaje, fecha e id) y no sirve en otro.
- Si la persona **no tiene perfil** (ni habilidades, ni idiomas, ni experiencia, ni nivel académico)
  ordena por fecha y lo dice: `sorted_by: "recent"`, `match_unavailable: "perfil_vacio"`.
- Toda respuesta del listado lleva `sorted_by` (`recent` · `oldest` · `match`) y `match_unavailable`
  (`null` salvo el caso anterior): `{items, next_cursor, sorted_by, match_unavailable}`.
- `match` es **el de quien llama**; nunca el de otra persona. Los filtros existentes se combinan con
  `sort=match`.

#### El reclutador (MA9, decisión 4)

- El conjunto cerrado del consentimiento suma **`match_score`** (opcional, desmarcado por defecto): «Tu
  puntaje de coincidencia con esta oferta». Sigue sin poder ampliarse después de aplicar.
- En el detalle del panel, si se compartió y la aplicación está disponible: `applicant.match_score =
  {score, breakdown}` (la misma forma), calculado **únicamente** con los campos que la persona
  compartió en esa aplicación (`applications::shared_view`): `skills` y `experience` siempre; `languages`
  y `education` solo si los marcó. Lo no marcado no aplica (`reason: "no_compartido"`) y no cuenta como
  faltante. Se ve en vivo, como el resto de lo compartido.
- Sin compartirlo, ningún dato de matching cruza al reclutador: ni en el detalle, ni en la lista del
  panel, ni en `/company/offers`.

#### Desviaciones y límites del MVP

- **Sin `job_matches` ni `match_refresh` ni tarea de recálculo** (decisión 8 recomendaba una tarea con
  límite): se calcula al leer. No hay migración. Costo: `sort=match` calcula el puntaje de **todas** las
  ofertas visibles (con los filtros) en cada petición. Es aceptable mientras haya cientos de ofertas; con
  miles conviene precalcular (`job_matches`, tarea en segundo plano) sin cambiar este contrato.
- Sin `computed_at` en `match`: no hay momento de cálculo que mostrar.
- Los pesos 50 · 15 · 20 · 15 son una primera versión, sin ofertas reales con las que ajustarlos
  (riesgo de la decisión 13).
- Un perfil que la persona no compartió completo da, al reclutador, un puntaje sobre menos
  componentes que el que ve la propia persona. Es a propósito: el reclutador nunca recibe un dato
  inferido de algo no consentido.

#### Códigos de error del grupo

| Estado | `error` |
|---|---|
| 401 | sin token o token inválido |
| 403 | `sin_permiso` · `cuenta_no_disponible` · `empresa_no_verificada` · `membresia_vencida` |
| 404 | `no_encontrado` (recurso ajeno, inexistente o id mal formado) · `invitacion_invalida` |
| 409 | `estado_invalido` (con `status` en las aplicaciones) · `ya_tiene_empresa` · `empresa_duplicada` · `nit_inmutable` · `ultimo_administrador` · `oferta_con_aplicaciones` · `confidencial_inmutable` · `ya_aplicaste` (con `application_id`) · `oferta_propia` · `limite_de_registros` |
| 413 | cuerpo demasiado grande |
| 422 | `datos_invalidos` · `campo_no_permitido` · `parametro_no_permitido` · `consentimiento_requerido` · `oferta_incompleta` (con `fields`) |
| 429 | `demasiados_intentos` (con `Retry-After`) |

#### Cambios de esquema que este contrato exige a `db.md`

Para que el paso de cada recurso los migre y actualice `db.md` en el mismo PR: `companies.verified_at`;
`companies.tax_id` cifrado + `tax_id_hash` único; `company_invitations` (`token_hash`, `email_hash`,
`role`, `expires_at`, `used_at`, `revoked_at`, `created_by`); índice único parcial en
`company_recruiters(user_id)`; `external_applications` (con `notes` cifrada); `job_offers.closed_at`; `job_offers.created_by` **nullable** con
`ON DELETE SET NULL`; `job_applications.applicant_id` **nullable** con `ON DELETE SET NULL`,
`shared_fields jsonb`, `consented_at`, `company_revealed_at`; `job_application_events.note` cifrada y
`changed_by` nullable; `access_audit` con `ip_hash` y sin contenido. Roles `recruiter` y
`company_admin` y los permisos de arriba, sembrados.

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
