# Fase 1 — Identidad: cuenta, sesión y borrado

**Estado:** en curso (v2: autenticación propia con JWT; casos pendientes de revisión del equipo)
**Repos que toca:** jobout-core-api, jobout-web, jobout (documentación)
**Abierta:** 2026-11-04

## Objetivo

Una persona se registra con email y contraseña, entra, ve una pantalla suya protegida, y puede
borrar su cuenta y todos sus datos. Detrás: el bloque de esquema «identidad», los planes de
suscripción de usuario, el cifrado de PII que el resto de las fases va a reutilizar, y la
emisión y validación de JWT propios.

Es la fase que fija los cimientos de seguridad. Todo lo que venga después (CV, entrevista,
scores) cuelga de un `users.id` y de una ruta autenticada, así que los errores acá se pagan en
todas las fases siguientes.

## Decisión de MVP: autenticación propia, sin Clerk

**Cambio respecto de v1 de este archivo** (decidido 2026-11-04). Para el MVP, `jobout-core-api`
emite y valida sus propios JWT. Razón: un solo lugar donde viven los datos de la persona, sin
una segunda base de identidades en un tercero ni su credencial.

Consecuencias que el equipo tiene que saber:

- **Ahora guardamos credenciales.** Esto sube el listón: hash **Argon2id** (ya previsto en
  `security.md` para este caso), mensajes de error que no revelen si un email existe, y límite
  de intentos. Las credenciales viven en una tabla aparte, `user_credentials`, nunca en `users`.
- **Se pierde por ahora** MFA, recuperación de contraseña y «entrar con Google». Que HU-01 diga
  «Google o email» queda **parcialmente cubierta** (solo email) hasta que se decida: volver a
  Clerk (el diseño deja `users.clerk_user_id` nullable para eso) o implementar OAuth propio.
- **Clerk queda como camino de escala**, no descartado. `arquitectura.md`, `security.md`,
  `api.md` y `frontend.md` hoy dicen «Clerk»: se actualizan en el PR de auth (paso 3) para
  decir «MVP: JWT propio; Clerk si escala».
- Las decisiones abiertas v1 sobre claims de Clerk y borrado en Clerk **dejan de aplicar**.

## Historias de usuario que cubre

- HU-01 — Como candidato, quiero registrarme con Google o email, para empezar sin fricción
  *(MVP: solo email. **La parte «Google» está aplazada**, ver paso 9)*
- HU-05 — Como candidato, quiero borrar mi cuenta y mis datos, para irme cuando quiera

## Alcance

**Dentro:**

- Migraciones SeaORM del bloque identidad: `users`, `user_credentials`, `refresh_tokens`,
  `roles`, `permissions`, `role_permissions`, `user_roles`, `applicants`, `privacy_events`.
- **Planes de usuario** (lo que faltaba): `plans` y `user_subscriptions`, con los planes
  Gratis, Estudiantil y Estándar sembrados (ver [`negocio.md`](../../documentation/negocio.md)).
  Todo registro nace con una suscripción activa al plan Gratis.
- Módulo de cifrado de PII a nivel de aplicación (AES-256-GCM) y `email_hash` (HMAC-SHA256 con
  clave separada).
- Contraseñas con Argon2id; JWT de acceso corto (15 min) y refresh token rotativo guardado
  solo como hash.
- Endpoints: `POST /api/v1/auth/register`, `/auth/login`, `/auth/refresh`, `/auth/logout`,
  `GET /api/v1/me`, `DELETE /api/v1/me`.
- Extractor de Axum `AuthUser` que entrega el usuario autenticado a cada ruta.
- Frontend: páginas de registro e ingreso, protección de `/dashboard`, pantalla `/dashboard`
  mínima y botón «Borrar mi cuenta» con confirmación.
- Los tokens de la identidad visual
  ([`identidad-visual.md`](../../documentation/identidad-visual.md)) como variables CSS.
- Textos en español (tuteo) en un archivo de mensajes, no dentro de los componentes, para que
  el inglés entre después sin reescribir pantallas.

**Fuera (y por qué):**

- `admins` y `company_recruiters`: ninguna historia de esta fase los usa, y
  `company_recruiters` necesita `companies`.
- Catálogos geográficos y de perfil: entran en la fase de perfil/CV.
- **Cobro real, verificación `.edu` y programa de mentores.** Esta fase deja la *estructura* de
  planes (`user_subscriptions.source`) pero no cobra ni verifica a nadie.
- Entrar con Google, MFA y recuperación de contraseña: ver «Decisión de MVP».
- Verificación de email al registrarse: `users.status` nace `active`. Se agrega con el envío
  de correos.
- Panel de administración.

## Cambios de esquema

Tablas nuevas (9 + 2 de planes): `users`, `user_credentials`, `refresh_tokens`, `roles`,
`permissions`, `role_permissions`, `user_roles`, `applicants`, `privacy_events`, `plans`,
`user_subscriptions`, `login_attempts` (esta última se añadió en el paso 4: el límite de intentos
necesita dónde contar). Enums de PostgreSQL: `user_status`, `privacy_event_kind`,
`subscription_status`, `subscription_source`.

Migraciones (cada una con `up` y `down`):

- `m20261104_000001_create_identity` (users, credenciales, tokens, roles, applicants)
- `m20261104_000002_create_privacy_events`
- `m20261104_000003_create_plans_and_subscriptions`

> `documentation/db.md` se actualiza en el mismo PR que cada migración.

Decisiones de diseño que `db.md` todavía no dice:

- `users.clerk_user_id` pasa a **nullable** (hoy es `not null`): en el MVP no hay Clerk, y se
  deja para el camino de escala.
- `privacy_events` **no tiene FK a `users`**. Si la tuviera, borrar al usuario borraría su
  propia constancia de borrado. Guarda `subject_hash` (el HMAC del email), nunca el id ni el
  email.
- `user_subscriptions`: `user_id`, `plan_id`, `status` (`active` · `expired` · `cancelled`),
  `source` (`free` · `paid` · `student_trial` · `mentor`), `started_at`, `expires_at` null.
  **Un solo registro `active` por usuario**, garantizado por un índice único parcial.
- `plans`: `code` (`free` · `student` · `standard` · `business`), `monthly_price_gtq`
  (numeric), `monthly_simulations` (int, null = sin tope). El plan Empresarial se siembra pero
  se asigna a empresas por `memberships`, que se queda como está.

## Pasos

Cada paso es una rama `jb-##-slug` y un PR.

- [ ] 0. **Este documento**: el equipo revisa y acuerda los casos de verdad.
- [x] 1. Módulo `crypto` (cifrado + HMAC + carga de claves). Solo pruebas unitarias. *(2026-11-04, rama `jb-05-pii-crypto` en core-api)*
- [x] 2. Migraciones + `db.md`. Pruebas contra PostgreSQL real. *(2026-11-04, rama `jb-06-identity-migrations`; las entidades SeaORM quedan para el primer paso que las consuma)*
- [ ] 3. Contraseñas (Argon2id) y JWT: emisión y validación. Actualiza los docs de Clerk.
- [ ] 4. `register`, `login`, `refresh`, `logout`. **Hechos `register` y `login`** (2026-11-04, rama `jb-09-register-login`); faltan `refresh` y `logout` (R12–R15).
- [ ] 5. `GET /me`, `DELETE /me` y `privacy_events`.
- [ ] 6. Frontend: tokens de marca, ingreso/registro, protección de `/dashboard`.
- [ ] 7. Frontend: borrado de cuenta.
- [ ] 8. Recorrido completo en navegador y cierre.
- [ ] 9. ⏸ **APLAZADO — OAuth / «Entrar con Google»** (parte de HU-01). Fuera de esta fase por decisión del equipo; abrir fase propia cuando se retome.

## Casos de verdad

> **Se acuerdan ANTES de implementar.** El equipo los revisa acá; discutir qué es correcto
> sobre código ya escrito sale mucho más caro. Cada caso tiene que poder convertirse en un
> test uno a uno.

### Cifrado y hash (paso 1)

Las variables son `PII_ENCRYPTION_KEY` y `PII_HASH_KEY` (ya están en `.env.example`), cada una
de 32 bytes en base64.

| # | Caso | Tipo |
|---|---|---|
| C1 | Cifrar `"ana@mail.com"` y descifrar con la misma clave devuelve `"ana@mail.com"` | unitaria |
| C2 | Cifrar dos veces el mismo texto produce dos resultados distintos (nonce aleatorio) | unitaria |
| C3 | Descifrar con una clave distinta devuelve error, no basura | unitaria |
| C4 | Descifrar un resultado con un byte alterado devuelve error (autenticación GCM) | unitaria |
| C5 | `email_hash` es determinístico: el mismo email da el mismo hash | unitaria |
| C6 | `email_hash` normaliza antes de calcular: `" Ana@Mail.COM "` y `"ana@mail.com"` dan el mismo hash | unitaria |
| C7 | `email_hash` con otra clave de HMAC da otro hash | unitaria |
| C8 | Si falta cualquiera de las dos variables, cargar las claves falla y el error nombra la variable pero **nunca imprime un valor de clave** | unitaria |
| C9 | Una clave que no es base64 válido, o que no mide 32 bytes, se rechaza al cargarla | unitaria |
| C10 | Si `PII_ENCRYPTION_KEY` y `PII_HASH_KEY` son iguales, se rechaza (deben ser distintas) | unitaria |
| C11 | Descifrar un dato más corto que nonce + etiqueta devuelve error, no `panic` | unitaria |
| C12 | Cifrar y descifrar texto con tildes, `ñ` y emoji lo devuelve idéntico | unitaria |
| C13 | `Debug` de las claves no imprime ningún valor (un `{:?}` perdido en un log no las filtra) | unitaria |

### Esquema (paso 2)

| # | Caso | Tipo |
|---|---|---|
| E1 | Correr las migraciones sobre una base vacía crea todas las tablas | integración |
| E2 | `down` seguido de `up` deja el mismo esquema (reversible) | integración |
| E3 | Dos `users` con el mismo `email_hash` fallan | integración |
| E4 | `applicants` con un `user_id` inexistente falla (FK en la base) | integración |
| E5 | Dos `applicants` para el mismo `user_id` fallan | integración |
| E6 | `users.status` fuera de `active`/`suspended`/`pending_verification` falla (enum) | integración |
| E7 | Los ids generados son UUID v7 | unitaria |
| E8 | La columna `users.email` guardada en la base **no contiene** el email en claro | integración |
| E9 | Borrar un `users` borra en cascada `applicants`, `user_roles`, `user_credentials`, `refresh_tokens` y `user_subscriptions` | integración |
| E10 | Borrar un `users` **no** borra filas de `privacy_events` | integración |
| E11 | Las migraciones siembran los planes `free` (Q0), `student` (Q60), `standard` (Q75) y `business` (Q487.50) | integración |
| E12 | Un usuario no puede tener dos `user_subscriptions` activas a la vez (índice parcial) | integración |
| E13 | Sí puede tener una activa y varias `expired`/`cancelled` | integración |
| E14 | `plans.code` es único | integración |
| E15 | Se siembran los roles `applicant` y `admin` | integración |
| E16 | Existe `login_attempts` (PK `email_hash`, sin FK a `users`) y `down` la elimina | integración |

### Contraseñas y JWT (paso 3)

| # | Caso | Tipo |
|---|---|---|
| P1 | Hashear una contraseña produce una cadena Argon2id (`$argon2id$`), no la contraseña | unitaria |
| P2 | Verificar la contraseña correcta devuelve verdadero; una incorrecta, falso | unitaria |
| P3 | El mismo texto hasheado dos veces da hashes distintos (sal aleatoria) | unitaria |
| P4 | Una contraseña de menos de 10 caracteres se rechaza; una de 10 se acepta | unitaria |
| P5 | Una contraseña de más de 128 caracteres se rechaza (evita abuso de CPU) | unitaria |
| J1 | Un token emitido para un usuario se valida y devuelve su `user_id` | unitaria |
| J2 | Un token firmado con otra clave → rechazado | unitaria |
| J3 | Un token expirado → rechazado | unitaria |
| J4 | Un token con `alg: none` → rechazado | unitaria |
| J5 | Un token con `iss` o `aud` distinto → rechazado | unitaria |
| J6 | El token de acceso expira a los 15 minutos de emitido | unitaria |
| J7 | El secreto JWT de menos de 32 bytes se rechaza al arrancar; si falta, el servicio no arranca | unitaria |
| J8 | El token no contiene email, nombre ni ningún dato personal: solo `sub`, `iat`, `exp`, `iss`, `aud` | unitaria |

### Registro, ingreso y sesión (paso 4)

| # | Caso | Tipo |
|---|---|---|
| R1 | `register` con datos válidos → 201, devuelve token de acceso y refresh, crea `users` + `user_credentials` + `applicants` + rol `applicant` + suscripción activa `free` | integración |
| R2 | `register` con un email ya existente → 409 con mensaje genérico, sin crear nada | integración |
| R3 | `register` con `ANA@Mail.com` cuando existe `ana@mail.com` → 409 (normalizado) | integración |
| R4 | `register` con email inválido o contraseña corta → 422 | integración |
| R5 | En la base, el email está cifrado y la contraseña hasheada: ninguno aparece en claro | integración |
| R6 | Dos `register` simultáneos con el mismo email: uno 201, el otro 409, una sola fila | integración |
| R7 | `login` correcto → 200 con tokens | integración |
| R8 | `login` con contraseña incorrecta y `login` con email inexistente devuelven **exactamente** la misma respuesta (401, mismo cuerpo) | integración |
| R9 | `login` con email inexistente ejecuta igual una verificación Argon2 (sin atajo medible de tiempo) | unitaria |
| R10 | Cinco `login` fallidos seguidos del mismo email en 15 min → el siguiente responde 429, incluso con la contraseña correcta | integración |
| R11 | Un `login` correcto reinicia el contador de fallos | integración |
| R12 | `refresh` válido → 200, entrega un refresh **nuevo** y el anterior queda inutilizable | integración |
| R13 | Reusar un refresh ya rotado → 401 y se revocan **todos** los refresh de ese usuario (señal de robo) | integración |
| R14 | `refresh` expirado o desconocido → 401 | integración |
| R15 | `logout` revoca el refresh; usarlo después → 401 | integración |
| R16 | El refresh token se guarda como hash; la base no contiene el valor entregado | integración |
| R17 | Un usuario `suspended` recibe 403 al ingresar y en cualquier ruta autenticada | integración |
| R18 | `/health` sigue pública y sin token | integración |

### `GET /me` y borrado de cuenta (paso 5)

| # | Caso | Tipo |
|---|---|---|
| M1 | `GET /me` con token válido → 200 con `id`, `first_name`, `last_name`, `status`, plan activo y el email descifrado | integración |
| M2 | `GET /me` **no** devuelve `email_hash`, `password_hash`, `clerk_user_id` ni `deleted_at` | integración |
| B1 | `DELETE /me` con token válido y la contraseña en el cuerpo → 204; `users`, `applicants`, `user_roles`, credenciales, refresh y suscripciones del usuario dejan de existir (borrado real) | integración |
| B2 | `DELETE /me` con contraseña incorrecta → 403 y no se borra nada | integración |
| B3 | Tras el borrado queda **una** fila en `privacy_events` con `kind = account_deleted`, fecha y `subject_hash`; sin email, nombre ni `users.id` | integración |
| B4 | Tras el borrado, el token de acceso anterior responde 401 en `GET /me` y el `login` con las mismas credenciales falla | integración |
| B5 | `DELETE /me` borra solo al usuario del token: los datos de otro siguen intactos | integración |
| B6 | Si el borrado falla a mitad (error forzado), no queda nada borrado a medias: todo o nada | integración |
| B7 | Tras borrar, se puede registrar de nuevo el mismo email y es una cuenta nueva y vacía | integración |

### Seguridad transversal (obligatorios de la plantilla)

| # | Caso | Tipo |
|---|---|---|
| S1 | El usuario A no puede ver ni borrar a B: no existe ruta por id; `/me` siempre resuelve desde el token. Test con dos usuarios | integración |
| S2 | Sin token en `GET /me` y `DELETE /me` → 401. Encabezado malformado (`Bearer` vacío, sin esquema) → 401 | integración |
| S3 | Un error provocado (token inválido, fallo de base, registro duplicado) no filtra email, contraseña ni claves en el cuerpo **ni en el log** (se captura el log y se busca) | integración |
| S4 | El log de una petición exitosa a `register`, `login` y `/me` no contiene email, contraseña, JWT ni refresh token | integración |
| S5 | Un test recorre todas las rutas registradas y exige `AuthUser`, salvo una lista explícita y justificada (`/health`, `register`, `login`, `refresh`) | integración |
| S6 | `register` y `login` limitan el tamaño del cuerpo (rechazan > 8 KB con 413) | integración |

### Frontend (pasos 6 y 7)

| # | Caso | Tipo |
|---|---|---|
| F1 | `/dashboard` sin sesión redirige a `/sign-in` | unitaria (middleware) |
| F2 | `/sign-in`, `/sign-up` y `/health` son accesibles sin sesión | unitaria (middleware) |
| F3 | El cliente de la API envía `Authorization: Bearer <jwt>` en cada llamada autenticada | unitaria |
| F4 | Ante un 401, el cliente intenta **un** `refresh`; si funciona repite la llamada, si falla lleva a `/sign-in` | unitaria |
| F5 | Los tokens se guardan en cookies `HttpOnly`, `Secure` y `SameSite=Lax`, nunca en `localStorage` | unitaria |
| F6 | `/dashboard` muestra el nombre que devolvió `GET /me` | componente |
| F7 | El formulario de registro valida en el cliente (email, contraseña ≥ 10) y muestra el error de `409` sin revelar nada más | componente |
| F8 | «Borrar mi cuenta» **no** llama a la API al primer clic: abre una confirmación que dice qué se pierde | componente |
| F9 | Confirmar queda deshabilitado hasta escribir la contraseña; confirmar llama a `DELETE /me` una sola vez (doble clic no duplica) y cierra la sesión | componente |
| F10 | Si el borrado falla, se muestra un mensaje en español y la cuenta **no** se da por borrada | componente |
| F11 | Ningún texto visible está escrito dentro de un componente: todos salen del archivo de mensajes | unitaria |
| F12 | Los colores de marca se declaran una sola vez como variables CSS y el texto sobre coral usa tinta, nunca blanco | unitaria |
| F13 | Ninguna variable `NEXT_PUBLIC_*` contiene `SECRET`, `TOKEN`, `PASSWORD` ni `KEY` (ya lo vigila el CI) | CI |

## Criterios de cierre

- [ ] Todos los casos de verdad tienen su test, y fallaron antes de pasar
- [ ] Todas las pruebas verdes, en los dos repos y en CI
- [ ] `clippy -D warnings`, `cargo fmt --check`, `tsc`, `eslint` limpios
- [ ] Recorrido manual en navegador: registrarse → ver `/dashboard` → cerrar sesión → entrar →
      borrar la cuenta → confirmar que el mismo email se puede registrar de nuevo
- [ ] `documentation/db.md`, `api.md`, `frontend.md`, `security.md` y `arquitectura.md`
      actualizados (el cambio de Clerk a JWT propio se refleja ahí)
- [ ] `docs/continue.md` actualizado y esta fase movida a `docs/archived/`

## Decisiones abiertas

1. **Proveedor de clave maestra.** Dos claves por variable de entorno sirven para desarrollo.
   Producción necesita KMS (pendiente en `db.md`); el módulo `crypto` queda detrás de una
   interfaz estrecha para poder cambiarlo sin tocar las rutas.
2. **Prueba contra PostgreSQL real.** Las pruebas de esquema necesitan una base. Propuesta:
   `docker compose up postgres` en local y un servicio `postgres` en el CI, con una base
   distinta por corrida. No SQLite: enums y FK se comportan distinto.
3. **Firma del JWT.** HS256 con un secreto de ≥ 32 bytes basta mientras solo `core-api` valida
   tokens. Si otro servicio tuviera que validarlos, se pasa a una clave asimétrica.
4. **«Entrar con Google» — APLAZADO (decidido 2026-11-04).** No se hace OAuth en el MVP. Queda
   marcado: HU-01 se cubre solo con email. Antes de salir a usuarios reales hay que decidir
   entre volver a Clerk u OAuth propio.

## Desvíos y hallazgos

- **2026-11-04 — v2.** Cambio de Clerk a autenticación propia por decisión del equipo; se
  agregan `user_credentials`, `refresh_tokens`, `plans` y `user_subscriptions`, y se
  reescriben los casos de autenticación y borrado.
- **2026-11-04 — paso 1.** 17 pruebas en `tests/crypto.rs` (C1–C13 más variantes). Se
  comprobó que fallan: se rompió a propósito la normalización del email, el nonce aleatorio y
  la regla de claves distintas, y cada mutación fue detectada por su test. Se agregó C13, que
  no estaba en el plan.
- **Carga de claves en `main`: aplazada al paso 4.** `PiiKeys::from_env` existe y falla si
  falta una clave, pero `main.rs` todavía no lo llama. Cablearlo ahora obligaría a poner
  claves válidas en `.env.example` (hoy dicen `reemplazar`) sin que nada las use. Se cablea
  cuando `register` las necesite, junto con los valores de desarrollo.
- **Deuda ajena a la fase:** `cargo fmt --check` falla en `tests/health.rs` de `main`. Lo
  corrige la rama `jb-02-fix-dev-stale-binary`, que sigue sin mergear.
- **2026-11-04 — paso 2.** Tres migraciones con `up`/`down` y 15 pruebas de integración
  (`tests/schema.rs`, E1–E6 y E8–E15; E7 es unitaria en `migration/src/lib.rs`) contra
  PostgreSQL real, una base `test_<uuid>` por prueba, borrada al terminar. URL de
  administración en `TEST_DATABASE_URL` (CI la define). Se comprobó el rojo antes de migrar:
  12 de 15 fallaban; E2, E4 y E14 pasaban en falso (sin tablas, «no insertar» también es
  error), así que E4 y E14 ahora exigen el tipo de error (FK / unicidad).
  - **Entidades SeaORM: no se generaron.** El paso decía «migraciones + entidades»; sin código
    que las use serían archivos muertos. Se generan en el paso 3/4 con la primera consulta.
  - Las PK de `user_roles` y `role_permissions` son compuestas (sin `id`), y `plans`/`roles`
    llevan `code` único. `user_credentials` usa `user_id` como PK (1:1 con `users`).
  - `privacy_events.kind` arranca con un solo valor, `account_deleted`; el resto del enum de
    `db.md` (`export_*`, `deletion_*`) se agrega con migración cuando exista el caso.
  - Simulaciones por plan sembradas desde `negocio.md`: free 1, student 10, standard 12,
    business sin tope.
  - Se agregó `migration` como dependencia de `core-api` (para correr migraciones desde la
    app y las pruebas) y `TEST_DATABASE_URL` al job de pruebas del CI.
- **2026-11-04 — paso 4 (parcial).** `register` y `login` con 18 pruebas en `tests/auth.rs`
  (R1–R8, R10, R11, R16, R17, R18, S3, S4, S6). Se comprobó con 5 mutaciones que fallan: log del
  email, sin bloqueo, email inexistente distinguible, refresh en claro y duplicado mal mapeado.
  La primera versión de la mutación «distinguible» no cambiaba nada (era equivalente) y
  sobrevivió; se rehízo bien. Se probó también el binario real contra una base descartable.
- **`login_attempts` no estaba en el plan.** El límite de intentos (R10/R11) necesita estado;
  se añadió la migración `m20261104_000004_create_login_attempts` y se documentó en `db.md`.
- **S5 (recorrer todas las rutas y exigir `AuthUser`) sigue pendiente:** axum no permite listar
  las rutas del router. Se resolverá con un registro explícito de rutas cuando exista `AuthUser`.
- **`main.rs` ya carga las claves y el secreto JWT** y no arranca sin ellos. El `.env.example`
  trae valores falsos de desarrollo; **un `.env` local viejo con `reemplazar` hará fallar el
  arranque** hasta regenerarlo desde el ejemplo.
- **Docs de Clerk actualizados** (arquitectura, seguridad, API, frontend, desarrollo).
