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
| Auditoría | Toda tabla lleva `created_at`, `created_by`, `updated_at`, `updated_by` |
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
 ├ user_roles           ├ job_preferences          └ company_favorite_applicants
 ├ user_subscriptions   ├ applicant_languages
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
 └ recruiter_memories       usage_ledger

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

La migración siembra los roles `applicant` (Candidato) y `admin` (Administrador). Los permisos
se agrupan **por rol**, no por área ni feature.

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

`user_id` FK · `company_id` FK · `position` · `deleted_at`

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

`name` · `tax_id` · `website` · `phone` · `description` · `active` · `deleted_at` ·
`country_id` FK · `employment_sector_id` FK

### `memberships`

**Solo de empresas** (plan Empresarial). Los planes de personas viven en `user_subscriptions`.

| Columna | Notas |
|---|---|
| `company_id` | **FK nueva.** En el diagrama original la membresía era huérfana: no se sabía de quién era |
| `membership_type_id` | FK a catálogo |
| `start_date` · `expiration_date` | |
| `status` | enum `active` · `expired` · `cancelled` |

### `company_favorite_applicants`

`company_id` FK · `applicant_id` FK · unique compuesto.

---

## Ofertas

### `job_offers`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK. Reemplaza al par `id int` + `uuid` del original |
| `company_id` | uuid | **FK nueva.** Faltaba en el diagrama original |
| `created_by` | uuid | FK → `company_recruiters` |
| `name` | varchar | |
| `description` | text | **una sola vez.** Estaba duplicada |
| `status` | enum | `draft` · `published` · `paused` · `closed` |
| `is_experience_required` | boolean | |
| `required_experience` | int | null |
| `main_language_id` | uuid | FK |
| `is_confidential` · `featured` | boolean | |
| `schedule` | varchar | |
| `required_availability_to_travel` | boolean | |
| `required_driver_license` | boolean | |
| `vacancies` | int | |
| `hiring_date` · `publication_date` | date | |
| `profession_id` · `employment_sector_id` · `job_hierarchy_id` · `minimum_academic_level_id` · `state_id` · `city_id` · `salary_range_id` · `working_shift_id` · `contract_type_id` | uuid | FK a catálogos |

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

Misma razón que en el perfil: sin esto no hay matching indexable.

### `job_applications`

> Era `Job_Applicant`. El original tenía `selected`, `reviewed` y `rejected` como tres
> booleanos con su timestamp cada uno, lo que permite estados imposibles: `selected = true` y
> `rejected = true` a la vez. Un solo estado y un historial.

| Columna | Tipo | Notas |
|---|---|---|
| `applicant_id` · `job_offer_id` | uuid | FK. Unique compuesto: no se aplica dos veces |
| `status` | enum | `applied` · `under_review` · `shortlisted` · `rejected` · `withdrawn` · `hired` |
| `applied_at` | timestamptz | |
| `status_changed_at` | timestamptz | |

`job_application_events` — `job_application_id` FK · `from_status` · `to_status` ·
`changed_by` (uuid, null si fue el sistema) · `note (text, null)` · `created_at`.

Acá vive el rastro completo de quién revisó, quién seleccionó y quién rechazó — los
`reviewed_by`, `selected_by` y `rejected_by` del diagrama original, ahora con historial y no
solo el último.

### `job_matches`

`applicant_id` · `job_offer_id` · `score (smallint)` · `breakdown (jsonb)` · `computed_at` ·
unique compuesto. Precalculado: HU-30 tiene que responder rápido, no calcular al vuelo.

---

## Entrevista — lo propio de JobOut

### `ai_recruiters`

El elenco: Ana, Martín, Laura, Carlos, Sofía. Ver [producto.md](producto.md).

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `code` | varchar unique | `ana`, `martin`, `laura`… Estable, se usa en el código |
| `display_name` | varchar | |
| `role_title` | varchar | «CTO», «Recruiter Big Tech» |
| `personality` | text | Descripción visible para el usuario |
| `system_prompt` | text | Configuración, versionada en git y sincronizada acá |
| `voice_id` | varchar | Voz del proveedor |
| `avatar_asset_key` | varchar | Imagen base para la animación |
| `language_id` | uuid | FK. Sofía entrevista en inglés |
| `rubric_id` | uuid | FK |
| `active` | boolean | |

### `rubrics` y `rubric_versions`

Un score de hace tres meses tiene que seguir explicándose con la rúbrica con la que se calculó.
Por eso la rúbrica se versiona y el score guarda **qué versión** lo produjo.

`rubrics` — `id` · `name` · `description`

`rubric_versions` — `rubric_id` FK · `version (int)` · `criteria (jsonb)` · `published_at` ·
`is_current (boolean)`. Una versión publicada **nunca se edita**: se publica otra.

### `interview_levels`

| Columna | Notas |
|---|---|
| `code` | `junior` · `startup` · `amazon` · `google` · `mckinsey` |
| `display_name` · `description` | |
| `sort_order` | int |
| `previous_level_id` | uuid null. El nivel que hay que pasar antes |
| `min_score_to_unlock` | smallint. Score mínimo en el anterior |

### `interview_sessions`

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid v7 | PK |
| `applicant_id` | uuid | FK |
| `ai_recruiter_id` | uuid | FK |
| `interview_level_id` | uuid | FK |
| `job_offer_id` | uuid | FK **null** — practicar para una oferta concreta (HU-31) |
| `rubric_version_id` | uuid | FK. Se fija al empezar, no al terminar |
| `status` | enum | `created` · `in_progress` · `paused` · `completed` · `abandoned` |
| `started_at` · `ended_at` | timestamptz | |
| `duration_seconds` | int | null |

`paused` existe por HU-14: cortar a mitad y retomar después.

### `interview_turns`

`interview_session_id` FK · `seq (int)` · `speaker` enum (`recruiter` · `applicant`) ·
`transcript (text)` · `started_at` · `ended_at` · `audio_ms (int)` · unique (`session_id`, `seq`).

**El audio no se persiste** salvo que el usuario lo pida. La transcripción sí: es lo que le da
valor al feedback (HU-15) y a la memoria entre sesiones (HU-13). Ver [security.md](security.md).

### `interview_scores` — 1:1 con la sesión

| Columna | Tipo | Notas |
|---|---|---|
| `interview_session_id` | uuid | FK unique |
| `score` | smallint | 0–100 |
| `confidence` | smallint | 0–100. Señales de voz |
| `clarity` | smallint | 0–100. Contenido |
| `breakdown` | jsonb | **El «por qué».** Los 2–3 puntos concretos que subirían el score |
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

`applicant_id` · `interview_level_id` · `unlocked_at` · `best_score` · `sessions_completed` ·
unique compuesto (HU-23).

---

## Transversal

### `access_audit`

`actor_user_id` · `action` · `resource_type` · `resource_id` · `ip_hash (bytea)` ·
`created_at`.

**Sin el contenido del dato.** El registro de auditoría no puede convertirse en la nueva
filtración. Por eso la IP va hasheada.

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

`user_id` · `interview_session_id` FK null · `provider` · `operation` · `units` ·
`cost_micros (bigint)` · `occurred_at`.

Objetivo de negocio: costo por sesión conocido y con tope. Un usuario no puede quemar el margen
del mes. Sin esta tabla no hay forma de saberlo hasta que llega la factura.

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
la persona elige de la lista y no puede inventar una skill. Los demás catálogos siguen sin
migrar.

**Eliminado:** `gender_preferences` — su único uso era filtrar ofertas por género.

---

## Pendiente de decidir

- Clave maestra con rotación propia contra un KMS gestionado, para el cifrado de PII.
- Proceso de rotación de la clave del HMAC de `email_hash`.
- Si `skills` se cura a mano o crece desde las extracciones de CV.
- Estrategia de particionado de `interview_turns` y `access_audit`: son las dos que más crecen.
