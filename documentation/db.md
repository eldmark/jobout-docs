# Base de datos

**PostgreSQL. ORM: SeaORM. Migraciones en Rust, dentro de `jobout-core-api`.**

El esquema nace de un diagrama previo de bolsa de empleos (`Smart-Talent-db-v1`) fusionado con
lo que JobOut necesita: entrevistas simuladas, scoring, memoria del recruiter y gamificación.
La revisión de ese diagrama —bugs encontrados y qué se cambió— está en
[`docs/archived/revision-esquema-smart-talent.md`](../docs/archived/revision-esquema-smart-talent.md).

## La regla que no se negocia

**Cambio de esquema ⇒ migración SeaORM + este archivo actualizado, en el mismo PR.**

Sin excepción, sin «lo documento después». Un esquema documentado a medias es peor que uno no
documentado: el siguiente agente le cree y construye encima.

Corolarios:

- Ningún `ALTER TABLE` a mano contra un servidor. Si no está en una migración, no pasó.
- Toda migración implementa `up` y `down`.
- Una migración no se edita después de haber corrido en cualquier entorno compartido. Se
  escribe otra.
- Todo modelo declara explícitamente su tabla.

## Convenciones

| | |
|---|---|
| Nombres | Tablas en **plural, snake_case**: `interview_sessions` |
| PK | **UUID v7**, nunca `int autoincrement` |
| Timestamps | `timestamptz`, siempre con zona |
| Auditoría | Toda tabla lleva `created_at`, `created_by`, `updated_at`, `updated_by`. Las de autoría que una ruta llena con el id de una persona son FK → `users` **`ON DELETE SET NULL`**: borrar la cuenta deja la acción sin autor (BO3; ver «Columnas de autoría del lado empresa») |
| Borrado | `deleted_at timestamptz null`, no `is_deleted boolean` |
| Estados | Enum de PostgreSQL, nunca `varchar` libre |
| FK | Declaradas en la base, no solo en el código |

**Por qué UUID v7 y no autoincremental:** `/applicants/1234` deja contar cuántos candidatos hay
y enumerarlos uno por uno. V7 además ordena por tiempo, así que no pierde localidad de índice
como v4.

**Excepción al borrado lógico:** un candidato que pide borrar su cuenta se borra **de verdad**
(HU-05). `deleted_at` es para empresas y ofertas, donde hace falta rastro.

## Cifrado de columnas

Estas se cifran **a nivel de aplicación**, antes de llegar a PostgreSQL:

| Tabla | Columnas |
|---|---|
| `users` | `email` |
| `personal_data` | `document_id`, `date_of_birth`, `address`, `phone`, `mobile` |
| `admins` | `phone`, `phone2` |
| `cvs` | `storage_key` |

El cifrado en reposo del disco no reemplaza esto: protege contra el robo del disco, no contra
un dump ni contra una inyección. Ver [security.md](security.md).

**Una columna cifrada no se puede indexar ni buscar por contenido.** Por eso `users` lleva
además `email_hash (bytea, unique)`: un HMAC determinístico con clave separada. Se busca por el
hash, se lee del cifrado. La clave del HMAC no es la clave de cifrado — si se filtra una, la
otra sigue protegiendo.

## Acceso

Solo **`jobout-core-api`** habla con PostgreSQL.

`jobout-interview` **no tiene credenciales de base de datos**. No es una omisión de
configuración: es la frontera de seguridad del sistema. Si aparece un `DATABASE_URL` en ese
repo, es un bug crítico.

---

# Esquema

## Mapa

```
IDENTIDAD              PERFIL CANDIDATO           EMPRESA
users                  applicants                 companies
 ├ user_credentials     ├ personal_data            ├ company_recruiters
 ├ refresh_tokens       ├ professional_data        ├ memberships
 ├ user_roles           ├ job_preferences          ├ company_invitations
 ├ user_subscriptions   ├ applicant_languages      └ company_favorite_applicants
 ├ admins               ├ applicant_skills         OFERTAS
 ├ applicants           ├ cvs                      job_offers
 └ company_recruiters   │  ├ cv_extractions         ├ job_offer_skills
roles                   │  └ cv_suggestions        ├ job_offer_languages
permissions             └ applicant_level_progress ├ job_offer_driver_licenses
role_permissions                                   ├ job_applications
plans                                              │   └ job_application_events
                                                   └ job_matches

ENTREVISTA
ai_recruiters ── rubrics ── rubric_versions
interview_levels
interview_sessions
 ├ interview_turns          TRANSVERSAL
 ├ interview_scores         access_audit
 ├ interview_session_tokens privacy_events
 └ recruiter_memories       usage_ledger · rate_events

CATÁLOGOS  countries → states → cities → zones
           document_types · genders · marital_statuses · driver_licenses
           academic_levels · professions · job_hierarchies · employment_statuses
           employment_sectors · salary_ranges · working_shifts · contract_types
           membership_types · languages · skills
```

---

## Identidad y acceso

### `users`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `clerk_user_id` | varchar | **null**, unique. En el MVP no hay Clerk (auth propia); queda para el camino de escala |
| `email` | bytea | **cifrado** |
| `email_hash` | bytea | unique. HMAC determinístico, para buscar |
| `first_name` | varchar | not null |
| `middle_name` | varchar | null |
| `last_name` | varchar | not null |
| `last_name2` | varchar | null |
| `married_last_name` | varchar | null |
| `status` | enum `user_status` | `active` · `suspended` · `pending_verification` (default) |
| `deleted_at` | timestamptz | null. Ver nota de borrado real abajo |

**No hay columna `password` en `users`.** Las credenciales viven en `user_credentials`, tabla
aparte, para que un `SELECT * FROM users` nunca arrastre un hash.

`deleted_at` acá es solo marca transitoria mientras corre el borrado. HU-05 exige borrado real:
se borra la fila y sus dependientes (las FK hijas son `ON DELETE CASCADE`) y se deja constancia
en `privacy_events`.

### `user_credentials`

| Columna | Tipo | Notas |
|---|---|---|
| `user_id` | uuid | PK y FK → `users`, `ON DELETE CASCADE` |
| `password_hash` | varchar | **Argon2id** (formato PHC, con sal propia). Nunca la contraseña |

### `refresh_tokens`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `user_id` | uuid | FK → `users`, `ON DELETE CASCADE`. Índice |
| `token_hash` | bytea | unique. **Solo el hash** del token; el valor entregado no se guarda |
| `expires_at` | timestamptz | not null |
| `revoked_at` | timestamptz | null. Lleno = revocado (logout o rotación) |


### `login_attempts`

| Columna | Tipo | Notas |
|---|---|---|
| `email_hash` | bytea | PK. El HMAC del email, nunca el email |
| `failures` | integer | Fallos seguidos dentro de la ventana |
| `window_started_at` | timestamptz | Inicio de la ventana de 15 minutos |

Sin FK a `users` a propósito: también cuenta emails que no existen, para que el bloqueo (429
tras 5 fallos) no revele cuáles tienen cuenta. Un ingreso correcto borra la fila. Las filas
vencidas se pisan solas al próximo fallo; limpiarlas en lote queda pendiente.

### `roles` · `permissions` · `role_permissions` · `user_roles`

`roles` y `permissions`: `id` (uuid v7) · `code` (unique) · `name` · `description` ·
`deleted_at`. `role_permissions` (`role_id`, `permission_id`) y `user_roles` (`user_id`,
`role_id`) tienen **PK compuesta**, FK con `ON DELETE CASCADE` y `assigned_date timestamptz`
(el `date (string)` original pasa a `timestamptz`).

La migración de identidad siembra los roles `applicant` (Candidato) y `admin` (Administrador). La
migración `m20261108_000004_seed_recruiter_roles` (Fase 5, paso 2) agrega los roles `company_admin` y
`recruiter` y los diez permisos, **buscando todo por `code`** (los ids son UUID v7 generados al
sembrar, no se escriben a mano en ningún lado). Los permisos se agrupan **por rol**, no por área ni
feature:

| Rol | Permisos sembrados |
|---|---|
| `applicant` | ninguno |
| `recruiter` | `offer.create` · `offer.update` · `offer.publish` · `offer.close` · `application.read` · `application.review` · `favorite.manage` |
| `company_admin` | los de `recruiter` + `company.update` · `company.invite` |
| `admin` | `company.verify` (solo la plataforma; ningún rol de empresa lo recibe) |

`down` borra esos dos roles y esos diez permisos (sus filas de `role_permissions` y `user_roles` caen
en cascada) y no toca `applicant` ni `admin`. Un rol o permiso con `deleted_at` no concede nada.

Los permisos se comprueban **por su literal**, nunca por nombre de ruta. Ver
[security.md](security.md).

### `admins`

`user_id` FK · `position` · `phone` (cifrado) · `ext` · `phone2` (cifrado) · `ext2`

### `applicants`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `user_id` | uuid | FK unique → `users`, `ON DELETE CASCADE` |

**Se quitaron `personal_data_id` y `professional_data_id`.** Eran FK circulares: las tablas
hijas ya apuntan acá con `applicant_id`. Una relación 1:1 se declara en un solo lado.

### `plans`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `code` | varchar | unique: `free` · `student` · `standard` · `business` |
| `name` | varchar | |
| `monthly_price_gtq` | numeric(10,2) | not null |
| `monthly_simulations` | integer | null = sin tope |

Sembrados por la migración (ver [negocio.md](negocio.md)): `free` Q0 (1 simulación),
`student` Q60 (10), `standard` Q75 (12), `business` Q487.50 (sin tope).

### `user_subscriptions`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `user_id` | uuid | FK → `users`, `ON DELETE CASCADE`. Índice |
| `plan_id` | uuid | FK → `plans` |
| `status` | enum `subscription_status` | `active` · `expired` · `cancelled` |
| `source` | enum `subscription_source` | `free` · `paid` · `student_trial` · `mentor` |
| `started_at` | timestamptz | default `now()` |
| `expires_at` | timestamptz | null |

**Un solo registro `active` por usuario**, garantizado por un índice único **parcial**
(`UNIQUE (user_id) WHERE status = 'active'`). El historial (`expired`, `cancelled`) no tiene
tope. Es el plan de las personas: `memberships` **sigue siendo solo de empresas** (plan
Empresarial) y no se toca.

### `company_recruiters`

Migración `m20261110_000002_create_companies` (Fase 5a, paso 3).

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK. Es el `id` que ve el administrador en `GET /company/recruiters` |
| `user_id` | uuid | FK → `users`, **`ON DELETE CASCADE`**: borrar la cuenta borra su fila |
| `company_id` | uuid | FK → `companies` |
| `role` | varchar | `company_admin` o `recruiter` (`CHECK`). Es la verdad de «mi rol en la empresa»; el rol de la cuenta (`user_roles`) lo da la misma transacción |
| `position` | varchar | null (cargo; la 5a no lo pide) |
| `deleted_at` | timestamptz | null. Quitar a alguien lo marca, no borra la fila |
| `created_by` · `updated_by` | uuid | null. FK → `users`, `ON DELETE SET NULL` (paso 10): quién lo dio de alta y quién lo quitó |

**Una persona, una empresa**, garantizado por el índice único **parcial**
`company_recruiters_one_company_per_user` (`UNIQUE (user_id) WHERE deleted_at IS NULL`): quien salió
(`deleted_at`) puede entrar a otra. Los roles de empresa solo se dan al crear la empresa
(`company_admin`) y al aceptar una invitación; ninguna otra ruta los asigna.

> **Renombrada.** En el diagrama original era `Recruiter`. En JobOut, «recruiter» es Ana,
> Martín o Laura — los entrevistadores de IA. Dos cosas distintas no pueden llamarse igual: el
> humano de una empresa es `company_recruiter`, el de IA es `ai_recruiter`. Ver
> [glossary.md](glossary.md).

---

## Perfil del candidato

### `personal_data` — 1:1 con `applicants`

| Columna | Tipo | Notas |
|---|---|---|
| `applicant_id` | uuid | FK unique |
| `document_id` | bytea | **cifrado** |
| `date_of_birth` | bytea | **cifrado** |
| `address` | bytea | **cifrado** |
| `phone` | bytea | **cifrado** |
| `mobile` | bytea | **cifrado** |
| `availability_to_travel` | boolean | |
| `document_type_id` · `gender_id` · `marital_status_id` · `country_of_residency_id` · `driver_license_id` | uuid | FK a catálogos, todos nullable |

> **Estado (Fase 2):** la tabla existe **solo con `applicant_id` y `phone` (cifrado)**. Las demás
> columnas se añaden cuando una fase las necesite: cuanto menos dato personal se guarde, menos hay
> que proteger. Esta tabla no la devuelve `GET /me`.

Los catálogos demográficos son **opcionales**: `gender_id` y `marital_status_id` pasan a
nullable. Un candidato tiene que poder no responderlos. Como dato de perfil son legítimos;
como criterio de filtro de una oferta, no (ver `job_offers`).

### `professional_data` — 1:1 con `applicants`

`applicant_id` FK unique (cascade) · `description (text)` · `last_academic_level_id` FK ·
`profession_id` FK · `last_job_hierarchy_id` FK. Las tres FK son nullable. *(Migrada en la Fase 2.)*

`resume_url` se elimina: los CVs ahora viven en la tabla `cvs`, con versiones y sin URL suelta.

### `applicant_languages` y `applicant_skills`

> Reemplazan a la tabla `Academic Data` del diagrama original, que no contenía datos académicos
> —tenía idiomas y software— y guardaba todo en columnas `json`.

`applicant_languages` — `applicant_id` · `language_id` FK · `proficiency` enum
(`native` · `advanced` · `intermediate` · `basic`)

`applicant_skills` — `applicant_id` · `skill_id` FK · `level` enum `skill_level` (`beginner` ·
`intermediate` · `advanced` · `expert`, nullable) · `years_of_experience (int, null, ≥ 0)`.
**Única por `(applicant_id, skill_id)`.**

`applicant_languages` — única por `(applicant_id, language_id)`; `proficiency` es el enum
`proficiency` (`native` · `advanced` · `intermediate` · `basic`), **no nulo**.

`applicant_extra_knowledge` — `applicant_id` **único** · `description (text)`, para lo que no entra
en `skills`.

*(Todas migradas en la Fase 2, con FK `ON DELETE CASCADE` desde `applicants` y las columnas de
auditoría habituales.)*

### `applicant_experiences`

> **Tabla nueva en la Fase 2.** HU-03 pide extraer la «experiencia» del CV y el diseño original no
> tenía dónde guardarla.

| Columna | Tipo | Notas |
|---|---|---|
| `applicant_id` | uuid | FK, cascade |
| `company` | varchar | not null. En claro: el matching futuro la necesita |
| `title` | varchar | not null. En claro |
| `start_date` | date | not null |
| `end_date` | date | null = trabajo actual. CHECK `end_date IS NULL OR end_date >= start_date` |
| `description` | bytea | null. **Cifrado**: es texto libre y puede contener casi cualquier cosa |
| `position` | int | orden en el que la persona las presenta |

Tradeoff de cifrar `description`: no se puede buscar por texto dentro de las descripciones.

**Por qué no `json`:** HU-30 es «ver ofertas compatibles con mi perfil». Con JSON, el matching
es un escaneo de tabla completa parseando documentos. Con tablas puente, es un JOIN indexado.
El matching es núcleo del producto, no un extra.

`native_spanish` y `native_english` desaparecen como booleanos: son dos filas en
`applicant_languages` con `proficiency = native`. Así el producto no queda cableado a dos
idiomas — Sofía entrevista en inglés hoy, y mañana hay un recruiter en portugués.

### `job_preferences` — 1:1 con `applicants`

`applicant_id` FK unique · `current_employment_status_id` · `desired_job_hierarchy_id` ·
`previous_employment_sector_id` · `expected_salary_range_id` · `working_shift_id` ·
`contract_type_id` · `zone_id` — todos FK a catálogos.

### `cvs`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `applicant_id` | uuid | FK |
| `storage_key` | bytea | **cifrado.** Clave del objeto en S3 privado |
| `original_filename` | varchar | |
| `mime_type` | varchar | validado en la subida |
| `size_bytes` | bigint | validado en la subida |
| `version` | int | correlativo por candidato |
| `is_primary` | boolean | uno solo en true por candidato |

Nunca una URL permanente: `core-api` emite URLs firmadas de vida corta tras verificar el dueño.

`cv_extractions` — `cv_id` FK **único** (cascade) · `extracted (jsonb, not null)` · `status` enum
`cv_extraction_status` (`ready` · `failed`) · `reason (varchar, null)` (por qué falló:
`sin_texto`, `ilegible`, `tiempo_agotado`) · `model` · `extracted_at` ·
`reviewed_by_applicant (boolean, default false)`. Acá **sí** va `jsonb`: es la propuesta del
extractor, y lo que el candidato confirma se copia a las tablas del perfil (HU-03, HU-04).
**`extracted` solo contiene** `{description, skills[], languages[], experiences[]}`: **nunca
teléfono, email ni dirección** (el extractor no los extrae), porque esa columna no se cifra.
El texto completo del CV no se guarda en ningún lado.

`cvs`: `UNIQUE (applicant_id, version)` y un índice único parcial
`cvs_one_primary_per_applicant_idx` (un solo `is_primary = true` por candidato). `storage_key` es un
UUID aleatorio, nunca el nombre del archivo ni un id de la persona. *(Migradas en la Fase 2.)*

### `pending_storage_deletions`

> **Tabla nueva en la Fase 2.** Borrar la cuenta ya no cabe en una sola transacción: los archivos
> viven fuera de PostgreSQL. Si la base se borra y el borrado del archivo falla, la persona
> creería que su CV desapareció cuando sigue ahí.

`id` · `storage_key (bytea, cifrado)` · `attempts (int, default 0)` · `last_attempt_at (null)` ·
auditoría. Es una bandeja de salida: el borrado inserta aquí las claves de archivo **en la misma
transacción** que borra los datos, y un proceso de reintento la vacía cuando el archivo ya no
existe. **Sin FK a `users`**, por la misma razón que `privacy_events`: tiene que sobrevivir al
borrado de la persona.

`cv_suggestions` — `cv_id` FK · `kind` enum · `content (text)` · `applied (boolean)` ·
`created_at` (HU-24).

---

## Empresa

### `companies`

Migración `m20261110_000002_create_companies` (Fase 5a, paso 3).

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `name` | varchar | |
| `tax_id` | bytea | **cifrado** (AES-256-GCM, como el resto de la PII). El NIT como lo escribió la persona |
| `tax_id_hash` | bytea | HMAC-SHA256 del NIT **normalizado** (mayúsculas, sin guiones ni espacios) con la clave de hash y un prefijo de dominio. **Único** (`companies_tax_id_hash_key`): dos empresas no pueden tener el mismo NIT sin poder leerlo desde la base |
| `website` · `phone` · `description` | varchar · varchar · text | null |
| `active` · `deleted_at` | boolean · timestamptz | |
| `verified_at` | timestamptz | **null por defecto**: la empresa nace sin verificar. Solo lo mueven las rutas `company.verify`, nunca un `UPDATE` a mano |
| `country_id` | uuid | FK → `countries` |
| `employment_sector_id` | uuid | FK → `employment_sectors` |
| `created_by` | uuid | FK → `users`, **`ON DELETE SET NULL`**: de ahí sale el dominio del correo que ve el admin de plataforma; si la cuenta se borra, queda `null` |

### Columnas de autoría del lado empresa

Migración `m20261111_000002_anonymize_company_authorship` (Fase 5a, paso 10, BO3). `companies.updated_by`,
`memberships.created_by`/`updated_by` y `company_recruiters.created_by`/`updated_by` se crearon sin FK y
conservaban el id de una cuenta ya borrada (quien editó o verificó la empresa, quien fijó la membresía,
quien dio de alta o quitó a un reclutador). Pasan a FK → `users` `ON DELETE SET NULL`, con un índice
parcial `WHERE … IS NOT NULL` cada una, como ya eran `companies.created_by`, `job_offers.created_by` y
`job_application_events.changed_by`. `up` primero pone en `null` los ids que ya no existen; `down` quita
las FK y los índices.

Así, al borrar la cuenta de un reclutador o un administrador, sus decisiones quedan **sin autor** en la
misma transacción del borrado, y una prueba (`tests/recruiter_deletion.rs`) recorre **todas** las columnas
`uuid` `*_by` de la base y falla si alguna conserva el id.

### `memberships`

**Solo de empresas** (plan Empresarial). Los planes de personas viven en `user_subscriptions`.

| Columna | Notas |
|---|---|
| `company_id` | **FK nueva.** En el diagrama original la membresía era huérfana: no se sabía de quién era |
| `membership_type_id` | FK a catálogo (`membership_types`; hoy solo `business`) |
| `start_date` · `expiration_date` | `date`; `CHECK (expiration_date >= start_date)` |
| `status` | enum `membership_status` `active` · `expired` · `cancelled` |

`created_by` · `updated_by`: FK → `users`, `ON DELETE SET NULL` (paso 10). Los llena el admin de la
plataforma que fija la membresía.

**Una sola `active` por empresa** (índice único parcial `memberships_one_active_per_company`); el
historial (`cancelled`, `expired`) no tiene tope. `PUT /admin/companies/{id}/membership` cancela la
vigente y crea la nueva en una transacción. «Vigente» se calcula por fechas (`start_date <= hoy <=
expiration_date`, UTC) **y** `status = 'active'`; la columna no cambia sola al vencer.

### `company_invitations`

Migración `m20261110_000002_create_companies`. Invitación de un reclutador a **una** empresa.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `company_id` | uuid | FK → `companies`, `ON DELETE CASCADE` |
| `email_hash` | bytea | HMAC del correo del invitado (el mismo de `users.email_hash`). **No hay correo en claro**: la invitación solo sirve para la cuenta con ese correo |
| `role` | varchar | `recruiter` o `company_admin` (`CHECK`) |
| `token_hash` | bytea | **SHA-256** del token (256 bits aleatorios, base64url). Único. El token solo se devuelve una vez; aquí nunca está en claro |
| `expires_at` | timestamptz | creación + 7 días |
| `used_at` | timestamptz | null. Se marca con `UPDATE ... WHERE used_at IS NULL AND expires_at > now()`: un solo uso, aun con dos aceptaciones simultáneas |
| `revoked_at` | timestamptz | null. Revocar la deja inservible y la saca del listado |
| `created_by` | uuid | FK → `users`, `ON DELETE SET NULL` |
| `created_at` | timestamptz | |

Los topes (20 por empresa y día, 50 pendientes) se cuentan sobre estas filas.

### `company_favorite_applicants`

Migración `m20261111_000001_create_company_favorites` (Fase 5a, paso 7). Contrato en
[api.md](api.md), «Panel del reclutador».

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `company_id` | uuid | NOT NULL, FK → `companies`, `ON DELETE CASCADE`: el favorito es de la empresa |
| `applicant_id` | uuid | NOT NULL, FK → `applicants`, **`ON DELETE CASCADE`**: borrar la cuenta borra los favoritos que las empresas tenían sobre ella (BO1). Índice propio |
| `created_at` | timestamptz | |

**Una fila por (empresa, persona)** (`company_favorite_applicants_company_applicant_key`), no por
aplicación: se marca sobre una aplicación pero vale para la persona en toda la empresa, y el `PUT`
es idempotente (`ON CONFLICT DO NOTHING`). No guarda quién lo marcó: el panel no lo necesita y sería
un dato más que anonimizar (BO3). Al **retirar** una aplicación, la misma transacción borra el
favorito si a la persona no le queda otra aplicación viva (`applied`, `under_review` o
`shortlisted`) en esa empresa.

---

## Ofertas

### `job_offers`

Migración `m20261110_000003_create_job_offers` (Fase 5a, paso 4). Contrato en
[api.md](api.md), «Ofertas del reclutador».

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK. Reemplaza al par `id int` + `uuid` del original |
| `company_id` | uuid | NOT NULL, FK → `companies`. Faltaba en el diagrama original. Toda consulta por id filtra también por ella |
| `created_by` | uuid | **null**, FK → `company_recruiters`, `ON DELETE SET NULL`: borrar al reclutador no borra la oferta de la empresa (BO2) |
| `name` | varchar(120) | NOT NULL. En la API se llama `title` |
| `description` | text | null (un borrador puede estar casi vacío). **Una sola vez.** Estaba duplicada |
| `status` | enum `job_offer_status` | `draft` · `published` · `paused` · `closed`. Por defecto `draft`. Solo cambia por las rutas de transición |
| `is_experience_required` | boolean | NOT NULL, por defecto `false` |
| `required_experience` | int | null, 0–50 (años). La API exige que vaya si `is_experience_required` y que no vaya si no |
| `main_language_id` | uuid | null, FK → `languages` |
| `is_confidential` | boolean | NOT NULL, por defecto `false`. Congelado por la API desde la primera publicación |
| `company_visible` | boolean | **Columna generada** (`GENERATED ALWAYS AS (NOT is_confidential) STORED`): no se escribe y no sale de la API |
| `featured` | boolean | NOT NULL, por defecto `false`. Es de plataforma: la API no lo acepta |
| `schedule` | varchar(120) | null |
| `required_availability_to_travel` | boolean | NOT NULL, por defecto `false` |
| `required_driver_license` | boolean | NOT NULL, por defecto `false`. **Derivado**: lo fija el servidor (verdadero si hay filas en `job_offer_driver_licenses`) |
| `vacancies` | int | null, 1–999 (la API lo exige para publicar) |
| `hiring_date` | date | null. Pasada = la oferta abierta se cierra sola |
| `publication_date` | date | null. La pone el servidor en la **primera** publicación y no cambia |
| `closed_at` | timestamptz | null. Se fija al cerrar (a mano o por la tarea de `hiring_date`) y es la base de la retención de 90 días. `CHECK ((status = 'closed') = (closed_at IS NOT NULL))` |
| `profession_id` · `employment_sector_id` · `job_hierarchy_id` · `minimum_academic_level_id` · `state_id` · `city_id` · `salary_range_id` · `working_shift_id` · `contract_type_id` | uuid | null, FK a catálogos. La API exige que estén activos y que `city_id` sea de `state_id` |
| `created_at` · `updated_at` | timestamptz | NOT NULL, por defecto `now()` |

Índices: `(company_id, created_at DESC, id DESC)` y `(company_id, status, created_at DESC, id DESC)`
para el listado de la empresa (más nuevas primero, filtro por estado) y el límite de 20 ofertas por
empresa y hora (se cuenta sobre estas filas); parcial `(hiring_date) WHERE status IN ('published',
'paused')` para el cierre automático; parcial `(created_by) WHERE created_by IS NOT NULL` para la FK.

**Columnas eliminadas del diagrama original, a propósito:**

| Columna | Por qué se va |
|---|---|
| `age_range_from`, `age_range_to` | Filtrar candidatos por edad es discriminación por edad |
| `gender_preference_id` | Filtrar por género es discriminación por sexo |
| `marital_status_id` | Filtrar por estado civil es discriminación por estado familiar |

Las tres son ilegales como criterio de selección en EEUU, la UE y buena parte de LatAm. El
catálogo `gender_preferences` se elimina entero: no tiene otro uso.

Si un puesto tiene un requisito de edad legítimo y verificable —turno nocturno con mínimo
legal, por ejemplo— se modela como un requisito explícito y justificado, no como un rango de
filtrado.

**Columnas `json` y `array` descompuestas:**

- `software_knowledge (json)` → `job_offer_skills` (`job_offer_id` · `skill_id` · `is_required` · `min_level`)
- `extra_languages (json)` → `job_offer_languages` (`job_offer_id` · `language_id` · `min_proficiency`)
- `expected_driver_license (array)` → `job_offer_driver_licenses` (`job_offer_id` · `driver_license_id`)

Las tres tienen PK compuesta (`job_offer_id` + el id del catálogo: sin repetidos), FK `ON DELETE
CASCADE` desde `job_offers` y un índice por el id del catálogo (para el matching de la 5b).
`job_offer_skills.is_required` es NOT NULL (por defecto `true`) y `min_level` (enum `skill_level`)
admite null. `job_offer_languages.min_proficiency` (enum `proficiency`) es NOT NULL.

Misma razón que en el perfil: sin esto no hay matching indexable.

### `job_applications`

Migración `m20261110_000004_create_applications` (Fase 5a, paso 6). Contrato en
[api.md](api.md), «Aplicar, ver y retirar (candidato)».

> Era `Job_Applicant`. El original tenía `selected`, `reviewed` y `rejected` como tres
> booleanos con su timestamp cada uno, lo que permite estados imposibles: `selected = true` y
> `rejected = true` a la vez. Un solo estado y un historial.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `applicant_id` | uuid | **null**, FK → `applicants`, **`ON DELETE SET NULL`**: borrar la cuenta no borra la aplicación; queda como «candidato eliminado» (BO1, PA10) |
| `job_offer_id` | uuid | NOT NULL, FK → `job_offers` (sin cascada: una oferta con aplicaciones no se borra) |
| `status` | enum `job_application_status` | `applied` · `under_review` · `shortlisted` · `rejected` · `withdrawn` · `hired`. Por defecto `applied` |
| `shared_fields` | jsonb | NOT NULL, por defecto `[]`. Lista de **nombres** de campo que la persona aceptó compartir (conjunto cerrado de nueve, ver el contrato), nunca valores: el panel lee el perfil vivo filtrado por ellos. `CHECK` de que es un arreglo |
| `consented_at` | timestamptz | NOT NULL, por defecto `now()`: lo fija el servidor |
| `company_revealed_at` | timestamptz | null. Se fija al pasar a `shortlisted` una oferta confidencial; no se borra después (revelación por aplicación, HU-55) |
| `applied_at` · `status_changed_at` | timestamptz | NOT NULL, por defecto `now()` |

- `UNIQUE (applicant_id, job_offer_id)`: una sola aplicación por oferta, para siempre (retirar o ser
  rechazada no la libera). Las filas anónimas (`applicant_id` nulo) no chocan entre sí.
- `CHECK (applicant_id IS NOT NULL OR shared_fields = '[]')` y el trigger `BEFORE UPDATE OF
  applicant_id` (`job_applications_anonymize_trg`): al perder a la persona, `shared_fields` pasa a `[]`
  en el mismo `UPDATE` de la FK. No queda ningún dato de ella.
- Índices: `(applicant_id, applied_at DESC, id DESC)` parcial donde no es nulo («mis aplicaciones» y el
  límite de 20 en 24 h, que se cuenta sobre estas filas) y `(job_offer_id, applied_at DESC, id DESC)`
  (panel y la cuenta de la oferta).
- La columna transitoria `job_offers.applications_count` **se elimina**: la cuenta sale de esta tabla.
  `down` la devuelve con la cuenta real.

`job_application_events` — rastro de cada transición.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `job_application_id` | uuid | NOT NULL, FK, `ON DELETE CASCADE` |
| `from_status` | enum | null en el primer evento (`null → applied`) |
| `to_status` | enum | NOT NULL |
| `changed_by` | uuid | **null**, FK → `users`, `ON DELETE SET NULL`: borrar la cuenta (de la persona o de quien decidió) deja el evento sin su id (BO2, BO3) |
| `note` | bytea | null. **Cifrada** (el reclutador puede escribir cualquier cosa); solo la ven los reclutadores de la empresa |
| `created_at` | timestamptz | NOT NULL |

Índice `(job_application_id, created_at, id)`. Acá vive el rastro completo de quién revisó, quién
seleccionó y quién rechazó — los `reviewed_by`, `selected_by` y `rejected_by` del diagrama original,
ahora con historial y no solo el último. La persona solo ve `{status, at}`.

### `external_applications`

Aplicaciones hechas fuera de la plataforma (HU-32). **Privada de la persona**: no se comparte con
ninguna empresa ni pasa por la máquina de estados.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `applicant_id` | uuid | NOT NULL, FK → `applicants`, **`ON DELETE CASCADE`**: borrar la cuenta borra el registro |
| `company_name` · `position` | varchar(120) | NOT NULL |
| `applied_on` | date | NOT NULL |
| `status` | varchar | NOT NULL, `CHECK` en `applied` · `interviewing` · `offer` · `rejected` · `withdrawn` · `accepted` |
| `notes` | bytea | null. **Cifrada** |
| `created_at` · `updated_at` | timestamptz | NOT NULL |

Índice `(applicant_id, applied_on DESC, id DESC)`. El tope de 200 por persona lo aplica la API.

### `job_matches`

`applicant_id` · `job_offer_id` · `score (smallint)` · `breakdown (jsonb)` · `computed_at` ·
unique compuesto. Precalculado: HU-30 tiene que responder rápido, no calcular al vuelo.

---

## Entrevista — lo propio de JobOut

### `ai_recruiters`

El elenco: Ana, Martín, Laura, Carlos, Sofía. Ver [producto.md](producto.md). Se siembra en la
migración `m20261108_000001_create_interview_catalog`; en el código se nombran por `code`
(`RecruiterCode`), nunca por id, porque los ids cambian entre entornos.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `code` | varchar unique | `ana`, `martin`, `laura`, `carlos`, `sofia`. Estable, se usa en el código |
| `display_name` | varchar | |
| `role_title` | varchar | «CTO», «Recruiter Big Tech» |
| `personality` | text | Descripción visible para el usuario |
| `system_prompt` | text | Configuración, versionada en git y sincronizada acá. Se siembra vacío (`''`): es del motor de IA |
| `voice_id` | varchar null | Voz del proveedor |
| `avatar_asset_key` | varchar null | Imagen base para la animación |
| `language_id` | uuid | FK a `languages`, buscado por `code`. Sofía entrevista en inglés (`en`); los otros cuatro en español (`es`) |
| `rubric_id` | uuid | FK. Una rúbrica propia por recruiter |
| `active` | boolean | |
| `sort_order` | int | Orden de presentación |

Semillas: `ana` (RRHH), `martin` (CTO), `laura` (Recruiter Big Tech), `carlos` (CEO de startup) y
`sofia` (Recruiter internacional).

### `rubrics` y `rubric_versions`

Un score de hace tres meses tiene que seguir explicándose con la rúbrica con la que se calculó.
Por eso la rúbrica se versiona y el score guarda **qué versión** lo produjo.

`rubrics` — `id` · `name` (único) · `description`

`rubric_versions` — `id` · `rubric_id` FK · `version (int)` · `criteria (jsonb)` · `published_at` ·
`is_current (boolean)`. `(rubric_id, version)` es único.

- **Una sola vigente por rúbrica**: índice único parcial sobre `rubric_id` donde `is_current`.
- **Una versión publicada nunca se edita ni se borra**: se publica otra. Lo garantiza un trigger
  (`rubric_versions_immutable_trg`): si `published_at` no es null, cualquier `UPDATE` que cambie
  `rubric_id`, `version`, `criteria` o `published_at`, y cualquier `DELETE`, falla. Lo único que se
  puede cambiar es `is_current` (pasa a `false` cuando entra la nueva). Un borrador
  (`published_at` null) sí se edita.
- **`criteria`** es un arreglo de objetos `{code, name, max_points, description}` cuyos
  `max_points` suman **exactamente 100**. Los `code` son `especificidad`, `estructura`,
  `relevancia`, `claridad` y `profundidad`; cada recruiter les da un peso distinto (Martín pesa más
  la especificidad y la profundidad; Laura, la estructura). Esa suma la vigila una prueba, no la base.

Semillas: una rúbrica (`rubrica-<code>`) con su versión 1 publicada y vigente por recruiter.

### `interview_levels`

| Columna | Notas |
|---|---|
| `code` | `junior` · `startup` · `amazon` · `google` · `mckinsey` |
| `display_name` · `description` | |
| `sort_order` | int. 0 a 4, de menor a mayor |
| `previous_level_id` | uuid null. El nivel que hay que pasar antes. Junior es null; el resto forma una cadena sin ciclos (un nivel no puede preceder a sí mismo) |
| `min_score_to_unlock` | smallint null, entre 1 y 100. Score mínimo en el anterior. Null solo si no hay nivel previo |
| `available` | boolean, por defecto `false`. Solo los niveles con banco de preguntas se pueden empezar |
| `active` | boolean |

Semillas: Junior (sin mínimo), Startup (60), Amazon (70), Google (75) y McKinsey (80). Solo Junior
y Startup están `available`; los otros tres existen pero no se pueden empezar.

### `interview_sessions`

Migración `m20261108_000002_create_interviews`.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `applicant_id` | uuid | FK, `ON DELETE CASCADE`: borrar la cuenta borra sus sesiones |
| `ai_recruiter_id` | uuid | FK |
| `interview_level_id` | uuid | FK |
| `job_offer_id` | uuid | **null**, FK → `job_offers` **`ON DELETE SET NULL`** (la sesión sobrevive a la oferta); índice parcial donde no es null. Antes de la FK no había contra qué validar, así que la migración de ofertas anula cualquier valor previo — practicar para una oferta concreta (HU-31) |
| `rubric_version_id` | uuid | FK, NOT NULL. Se fija al empezar, no al terminar |
| `status` | enum `interview_status` | `created` · `in_progress` · `paused` · `completed` · `abandoned`. Por defecto `created` |
| `started_at` · `paused_at` · `completed_at` | timestamptz | null hasta que ocurre cada hecho |
| `last_activity_at` | timestamptz | NOT NULL, por defecto `now()` |
| `created_at` · `updated_at` | timestamptz | |

Una persona tiene **a lo sumo una sesión abierta**: índice único parcial
`interview_sessions_one_open_per_applicant_idx` sobre `applicant_id` donde `status` es
`in_progress` o `paused`. Las `created`, `completed` y `abandoned` no tienen tope.

`paused` existe por HU-14: cortar a mitad y retomar después. (El diseño original traía
`ended_at` y `duration_seconds`; se reemplazan por `paused_at`/`completed_at` y la duración se
calcula.)

### `interview_turns`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `interview_session_id` | uuid | FK, `ON DELETE CASCADE` |
| `seq` | int | ≥ 1. `UNIQUE (interview_session_id, seq)` |
| `speaker` | enum `interview_speaker` | `recruiter` · `applicant` |
| `kind` | varchar | CHECK: `question` · `follow_up` · `answer` · `closing` |
| `transcript` | **bytea** | **Cifrado a nivel de aplicación** (AES-256-GCM, `nonce ‖ cifrado ‖ etiqueta`) con las `PiiKeys`, vía `interview::store_crypto`. Nunca texto en claro |
| `audio_ms` | int | null (en modo texto no hay audio), ≥ 0 |
| `created_at` | timestamptz | |

**El audio no se persiste** salvo que el usuario lo pida. La transcripción sí, cifrada: es lo que
le da valor al feedback (HU-15) y a la memoria entre sesiones (HU-13), y es dato sensible. Ver
[security.md](security.md).

### `interview_scores` — 1:1 con la sesión

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `interview_session_id` | uuid | FK unique, `ON DELETE CASCADE` |
| `score` | smallint | NOT NULL, CHECK 0–100 |
| `confidence` | smallint | **null**, CHECK 0–100. Señales de voz: en modo texto no existe |
| `clarity` | smallint | NOT NULL, CHECK 0–100. Contenido |
| `breakdown` | jsonb | NOT NULL. **El «por qué».** Los 2–3 puntos concretos que subirían el score |
| `rubric_version_id` | uuid | FK. Con cuál se calculó |
| `computed_at` | timestamptz | |

`breakdown` no es opcional. Un número sin explicación no cambia el comportamiento de nadie
(HU-21).

### `recruiter_memories`

Lo que hace que Martín se sienta humano: **«hace dos semanas me dijiste que trabajabas en
Mercado Libre; hoy dijiste otra cosa»** (HU-13).

| Columna | Tipo | Notas |
|---|---|---|
| `applicant_id` · `ai_recruiter_id` | uuid | FK |
| `interview_session_id` | uuid | FK. De qué sesión salió |
| `source_turn_id` | uuid | FK null. El turno exacto. Sin esto no se puede citar |
| `kind` | enum | `fact` · `goal` · `weakness` · `inconsistency` |
| `content` | text | Despersonalizado: es lo único que cruza a `jobout-interview` |
| `valid_from` | timestamptz | |
| `superseded_by` | uuid | FK null → otra memoria. **Así se detecta la inconsistencia**: un `fact` nuevo que contradice a uno viejo lo supersede, y el par queda disponible para repreguntar |

### `interview_session_tokens`

| Columna | Notas |
|---|---|
| `interview_session_id` | FK |
| `token_hash` | bytea. **Solo el hash.** El token en claro se entrega una vez y no se guarda |
| `issued_at` · `expires_at` | Vigencia de minutos |
| `consumed_at` · `revoked_at` | null |

Una tabla y no solo un JWT firmado, porque hace falta poder **revocar**: al cerrar la sesión, el
token muere. Ver el contrato en [api.md](api.md).

### `applicant_level_progress`

`id` · `applicant_id` FK (`ON DELETE CASCADE`) · `interview_level_id` FK · `unlocked_at`
(por defecto `now()`) · `best_score` (smallint null, 0–100) · `sessions_completed` (int, por
defecto 0, ≥ 0) · `UNIQUE (applicant_id, interview_level_id)` (HU-23).

---

## Transversal

### `access_audit`

Migración `m20261110_000002_create_companies` (Fase 5a, paso 3).

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `actor_user_id` | uuid | FK → `users`, **`ON DELETE SET NULL`**: el rastro sobrevive a la cuenta, sin su id |
| `action` | varchar | `company.list`, `company.verify`, `company.unverify`, `company.membership_set`; desde el paso 7, `application.list`, `application.view` y `application.review` |
| `resource_type` · `resource_id` | varchar · uuid | `company` y la empresa (nulo en la lista); `job_offer` y la oferta (`application.list`); `job_application` y la aplicación (`application.view`, `application.review`) |
| `ip_hash` | bytea | HMAC de la IP con prefijo de dominio; null si no se conoce. Nunca la IP |
| `created_at` | timestamptz | |

El índice `(actor_user_id, created_at)` sostiene también el tope de 120 detalles del panel por
reclutador y hora (SX5), que se cuenta sobre las filas `application.view`.

**Sin el contenido del dato.** El registro de auditoría no puede convertirse en la nueva
filtración. Por eso la IP va hasheada: ni NIT, ni nombre, ni correo. La fila se escribe en la
**misma transacción** que la acción: si el insert falla, la acción falla.

### `rate_events`

Migración `m20261110_000002_create_companies`. Contador de intentos que sobrevive al proceso, como
`login_attempts` pero con una fila por intento: `id` · `kind` (`company_create`,
`invitation_accept`) · `subject_id` (FK → `users`, `ON DELETE CASCADE`) · `created_at`. Índice
`(kind, subject_id, created_at)`. Sostiene «5 empresas por persona y día» y «10 intentos de aceptar
una invitación por persona y hora».

### `privacy_events`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `subject_hash` | bytea | HMAC del email (el mismo de `users.email_hash`). Índice |
| `kind` | enum `privacy_event_kind` | hoy solo `account_deleted`; se amplía con migraciones |
| `notes` | varchar | null |

**Sin FK a `users`, a propósito:** si la tuviera, borrar al usuario borraría su propia
constancia de borrado. Por eso guarda `subject_hash` y nunca el id ni el email. Sobrevive al
borrado de la cuenta: es la constancia de que ocurrió (HU-05, HU-41).

### `usage_ledger`

Migración `m20261108_000003_create_usage_ledger`.

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `user_id` | uuid | FK → `users`, **`ON DELETE SET NULL`**, null. Borrar la cuenta deja la fila sin el id de la persona: el costo agregado sobrevive y nadie queda detrás |
| `interview_session_id` | uuid | FK → `interview_sessions`, **`ON DELETE SET NULL`**, null. Borrar una sesión no borra su gasto, y por eso tampoco devuelve la cuota |
| `provider` | varchar | not null. `deterministic` mientras el motor no cueste; el motor de IA traerá el suyo |
| `operation` | varchar | not null. Hoy `interview_session` |
| `units` | integer | not null, ≥ 0 |
| `cost_micros` | bigint | not null, por defecto 0, ≥ 0 (millonésimas de la moneda de cobro) |
| `occurred_at` | timestamptz | por defecto `now()` |

Índices: `(user_id, operation, occurred_at)` (la cuenta mensual) e `(interview_session_id)`.

Objetivo de negocio: costo por sesión conocido y con tope. Un usuario no puede quemar el margen
del mes. Sin esta tabla no hay forma de saberlo hasta que llega la factura.

**Cuota mensual por plan (Fase 3).** Cada sesión de entrevista iniciada escribe una fila
(`operation = 'interview_session'`, `provider = 'deterministic'`, `units = 1`, `cost_micros = 0`),
**en la misma transacción** que crea la sesión. La cuota del mes se cuenta sobre esas filas, en mes
calendario UTC, contra `plans.monthly_simulations` (null = sin tope; Gratis 1, Estudiantil 10,
Estándar 12). Sin suscripción activa (ninguna, vencida o cancelada) se aplica el tope de Gratis:
nunca «sin tope». Cambiar de plan a mitad de mes aplica el tope nuevo a lo ya usado. Abandonar o
borrar una sesión no devuelve la cuota. Superar el tope es `403 limite_del_plan` con `renews_at`
(primer instante del mes siguiente, UTC). La variable `ENFORCE_PLAN_LIMITS=false` salta solo la
comprobación; el uso se sigue registrando.

---

## Catálogos

Se mantienen como **tablas** —no como una `catalog_items` genérica ni como enums— para que
SeaORM genere entidades tipadas y PostgreSQL valide cada FK. Con una tabla genérica nada
impediría que `gender_id` apuntara a una profesión.

Todos con la misma forma: `id (uuid v7)` · `code (varchar unique)` · `name` · `description` ·
`active` · `sort_order`.

`code` es la novedad respecto del diagrama original: permite referirse a un valor desde el
código (`profession.code = 'software_engineer'`) sin depender de un id que cambia entre
entornos.

**Geografía, encadenada:**

```
countries → states (country_id) → cities (state_id) → zones (city_id)
```

> `zones.zone_id` en el diagrama original era una FK **a sí misma**. Es `city_id`.

**Del diagrama original:** `document_types` · `genders` · `marital_statuses` ·
`driver_licenses` · `academic_levels` · `professions` · `job_hierarchies` ·
`employment_statuses` · `employment_sectors` · `salary_ranges` · `working_shifts` ·
`contract_types`

**Nuevos:** `membership_types` · `languages` (ISO 639-1) · `skills`

**Migrados en la Fase 2:** `languages` (`es`, `en`, `pt`), `skills` (**114** de software, curadas a
mano), `academic_levels` (6), `professions` (12) y `job_hierarchies` (6). Las semillas viven en
`migration/src/seeds.rs`. `skills` lleva además `aliases text[] NOT NULL DEFAULT '{}'`
(`js` → `javascript`, `postgres` → `postgresql`…), que el extractor usa para reconocerlas; los
`code` son `[a-z0-9-]` sin mayúsculas ni tildes (`csharp`, `nodejs`). El catálogo es **cerrado**:
la persona elige de la lista y no puede inventar una skill.

**Migrados en la Fase 5 (paso 1, `m20261110_000001_create_offer_catalogs`):** `countries`, `states`,
`cities`, `zones`, `salary_ranges`, `working_shifts`, `contract_types`, `employment_sectors`,
`driver_licenses` y `membership_types`, con la forma estándar y sus semillas en
`migration/src/offer_seeds.rs`. Lo que `db.md` no decía y se decidió:

- **Geografía.** Cada eslabón lleva la FK a su padre (`states.country_id`, `cities.state_id`,
  `zones.city_id`), sin repetir el país en la ciudad: una ciudad no puede quedar en un país
  distinto al de su estado porque no tiene dónde decirlo. El `name` es único **dentro del
  padre** (`UNIQUE (padre_id, name)`, sin duplicados de texto libre), y el `code` es único en
  toda la tabla. Hay varios «San José» o «Concepción», así que el `code` de un municipio lleva
  el del departamento: `sacatepequez-antigua-guatemala`, `guatemala-guatemala`. Borrar un padre
  con hijos falla (sin `ON DELETE CASCADE`).
- **Solo se siembra Guatemala** (decisión 9 de la Fase 5): `gt`, sus **22 departamentos** y sus
  **340 municipios**; `zones` queda **vacía**. El municipio de Guatemala (la capital) cuelga del
  departamento de Guatemala.
- **`salary_ranges`** agrega `currency char(3) NOT NULL DEFAULT 'GTQ'`, `min_amount` y
  `max_amount` (`numeric(12,2)`, el máximo nulo en el último rango). Son montos **mensuales** en
  quetzales, mínimo y máximo **inclusivos**, sin huecos ni solapes (una prueba lo verifica); un
  `CHECK` impide un mínimo negativo o un máximo menor que el mínimo. Se siembran siete rangos,
  de «Menos de Q3,000» a «Q35,000 o más».
- **Semillas simples:** `working_shifts` (diurna, mixta, nocturna, rotativa, flexible, tiempo
  parcial), `contract_types` (indefinido, plazo fijo, por servicios (freelance), pasantía, por
  obra determinada), `employment_sectors` (18, de tecnología a «otro»), `driver_licenses`
  (tipos A, B, C y M) y `membership_types`, con una sola fila: `business`, «Empresarial», con
  el mismo `code` que el plan de `plans`. El precio y los beneficios de la membresía no viven en
  el catálogo.

Los demás catálogos (`document_types`, `genders`, `marital_statuses`, `employment_statuses`)
siguen sin migrar.

**Eliminado:** `gender_preferences` — su único uso era filtrar ofertas por género.

---

## Pendiente de decidir

- Clave maestra con rotación propia contra un KMS gestionado, para el cifrado de PII.
- Proceso de rotación de la clave del HMAC de `email_hash`.
- Si `skills` se cura a mano o crece desde las extracciones de CV.
- Estrategia de particionado de `interview_turns` y `access_audit`: son las dos que más crecen.
