# Revisión del esquema Smart-Talent-db-v1

**Estado:** cerrada
**Fecha:** 2026-09-03
**Entrada:** `Smart-Talent-db-v1.drawio` — diagrama previo de bolsa de empleos, 24 tablas más 17 catálogos
**Salida:** [`documentation/db.md`](../../documentation/db.md)

## Objetivo

Revisar el diagrama existente, corregir sus defectos y fusionarlo con lo que JobOut necesita:
entrevistas simuladas, scoring, memoria del recruiter y gamificación.

## Bugs encontrados

| # | Tabla | Problema | Resolución |
|---|---|---|---|
| 1 | `Zone` | `zone_id` FK **a sí misma**. Rompía la cadena Country→State→City→Zone | `city_id` |
| 2 | `Job_Offer` | `description (text)` declarada **dos veces** | Una sola |
| 3 | `Job_Offer` | **Sin `company_id`.** Faltaba la FK más importante del esquema | Agregada, más `created_by` |
| 4 | `Membership` | Sin FK a `Company` ni a `User`: membresía huérfana | `company_id` |
| 5 | `Applicant` ↔ `Personal Data` | FK **circular**: `Applicant.personal_data_id` y `Personal_Data.applicant_id`. Igual con `professional_data_id` | Solo `applicant_id` en las hijas. Una 1:1 se declara de un lado |
| 6 | `Academic Data` | No contenía datos académicos —tenía idiomas y software— y el nivel académico estaba en `Professional Data` | Descompuesta en `applicant_languages`, `applicant_skills` y `applicant_extra_knowledge` |
| 7 | `Job_Applicant` | `selected`, `reviewed` y `rejected` como tres booleanos independientes permitían estados imposibles: `selected = true` **y** `rejected = true` | `status` enum + `job_application_events` con historial |

## Cambios estructurales

**Colisión de nombre — `Recruiter`.** En el diagrama era una persona de una empresa. En JobOut
un «recruiter» es Ana, Martín o Laura: los entrevistadores de IA, ya definidos así en
`producto.md` y `glossary.md`. Dos cosas distintas no pueden llamarse igual.

```
Recruiter  →  company_recruiter   (la persona de la empresa)
(nueva)    →  ai_recruiter        (Ana, Martín, Laura, Carlos, Sofía)
```

**`User.password` eliminada.** La nota del diagrama decía «no recomiendo guardar las contraseñas
en la BD, de ser necesario guardarlas cifradas». Con Clerk la respuesta no es cifrarlas: es no
tenerlas. Queda `clerk_user_id` y nada más.

**PK `int autoincrement` → UUID v7.** `/applicants/1234` deja contar candidatos y enumerarlos.
El diagrama ya intuía esto con `Job_Offer.uuid`; se generaliza y se elimina el par id/uuid.

**PII sin cifrar.** `Personal_Data.address`, `phone`, `mobile`, `document_id`, `date_of_birth`,
`User.email` y `Admin.phone` estaban en claro. Ahora se cifran a nivel de aplicación, con
`email_hash` (HMAC determinístico) para poder buscar.

**`is_deleted boolean` → `deleted_at timestamptz`**, y borrado real para candidatos: HU-05 dice
«borrar mi cuenta y mis datos», y eso no es una bandera.

**Columnas `json` descompuestas en tablas puente.** `software_knowledge`, `other_languages`,
`extra_languages` y `expected_driver_license (array)` impedían el matching: HU-30 exige
comparar perfil contra oferta, y con JSON eso es un escaneo completo parseando documentos. Ahora
son `applicant_skills`, `applicant_languages`, `job_offer_skills`, `job_offer_languages` y
`job_offer_driver_licenses`.

`native_spanish` y `native_english` como booleanos desaparecen: son filas en
`applicant_languages` con `proficiency = native`. El producto no queda cableado a dos idiomas.

**Catálogos con `code`.** Se mantienen como 17 tablas —SeaORM genera entidades tipadas y
PostgreSQL valida cada FK— pero ganan `code varchar unique` para poder referirse a un valor
desde el código sin depender de un id que cambia entre entornos.

## Columnas eliminadas por riesgo legal

`Job_Offer` filtraba candidatos por `age_range_from`, `age_range_to`, `gender_preference_id` y
`marital_status_id`.

Los tres criterios son ilegales como filtro de selección en EEUU, la UE y buena parte de LatAm
—discriminación por edad, por sexo y por estado familiar—. JobOut apunta a mercado
internacional: Sofía entrevista en inglés desde el MVP. Las columnas se eliminaron y con ellas
el catálogo `gender_preferences`, que no tenía otro uso.

`gender_id` y `marital_status_id` **sí se conservan** en `personal_data`, como dato demográfico
opcional y nullable del perfil. La diferencia es que un candidato puede no responderlos y que
ninguna oferta puede filtrar por ellos.

Un requisito de edad legítimo y verificable —un mínimo legal para turno nocturno— se modela como
requisito explícito y justificado, no como un rango de filtrado.

## Decisiones tomadas

| Pregunta | Decisión |
|---|---|
| ¿Producto de un lado o de dos? | **Two-sided desde el inicio.** Se conserva todo el lado empresa. Obligó a corregir `producto.md`, que decía «no es un ATS» |
| ¿De dónde salen las ofertas? | **Carga manual por empresas.** Sin ingesta externa |
| ¿Cómo se modelan los catálogos? | **Tablas**, no una `catalog_items` genérica ni enums |

**Riesgo asumido y anotado:** carga manual por empresas es el problema del huevo y la gallina.
Sin candidatos no vienen empresas; sin ofertas los candidatos no vuelven. La mitigación es el
orden de construcción: candidato y entrevistas simuladas primero, que aportan valor sin
necesitar una sola oferta publicada; el lado empresa después.

## Tablas nuevas de JobOut

Ninguna existía en el diagrama original. Son el producto:

`ai_recruiters` · `rubrics` · `rubric_versions` · `interview_levels` · `interview_sessions` ·
`interview_turns` · `interview_scores` · `recruiter_memories` · `interview_session_tokens` ·
`applicant_level_progress` · `cvs` · `cv_extractions` · `cv_suggestions` · `job_matches` ·
`access_audit` · `privacy_events` · `usage_ledger`

Las dos que más pensamiento requirieron:

**`rubric_versions`** — un score de hace tres meses tiene que seguir explicándose con la rúbrica
con la que se calculó. Una versión publicada nunca se edita; se publica otra. El score guarda
qué versión lo produjo.

**`recruiter_memories`** — con `superseded_by` apuntando a otra memoria. Un `fact` nuevo que
contradice a uno viejo lo supersede, y el par queda disponible para que Martín repregunte
(HU-13). `source_turn_id` guarda el turno exacto: sin eso no se puede citar lo que el candidato
dijo.
