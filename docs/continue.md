# continue.md — traspaso de sesión

**Esto se lee al empezar y se actualiza al terminar.** Es la razón de ser de este repo: que
cualquiera —agente o persona— sepa qué se hizo, cómo y qué sigue, sin preguntar.

Entrada más reciente arriba. No borres entradas viejas: se van quedando como historia.

---

## 2026-09-03 — Esquema de base de datos

**Qué se hizo**

- Se revisó el diagrama previo `Smart-Talent-db-v1.drawio` (bolsa de empleos, 24 tablas más 17
  catálogos): **7 bugs encontrados**, entre ellos una FK a sí misma en `Zone`, `Job_Offer` sin
  `company_id`, FK circular entre `Applicant` y `Personal Data`, y tres booleanos en
  `Job_Applicant` que permitían estados imposibles.
- Se fusionó con lo que JobOut necesita y quedó el esquema completo en
  [`documentation/db.md`](../documentation/db.md).
- La revisión completa —qué estaba mal y qué se cambió— quedó archivada en
  [`archived/revision-esquema-smart-talent.md`](archived/revision-esquema-smart-talent.md).

**Decisiones tomadas**

| Decisión | Elección | Consecuencia |
|---|---|---|
| Alcance del producto | **Two-sided**: candidatos y empresas | Se conservó todo el lado empresa. Obligó a corregir `producto.md`, que decía «no es un ATS» |
| Origen de las ofertas | Carga manual por empresas | Sin ingesta externa. Se asume el huevo y la gallina |
| Catálogos | 17 tablas, no una genérica | SeaORM genera entidades tipadas y PostgreSQL valida cada FK |
| PK | UUID v7 en todas | `/applicants/1234` dejaba enumerar candidatos |
| Contraseñas | Columna eliminada | Con Clerk no guardamos ninguna |
| `is_deleted` | → `deleted_at`, y borrado real para candidatos | HU-05 pide borrado, no una bandera |
| Columnas `json` de skills e idiomas | Descompuestas en tablas puente | Sin esto no hay matching indexable (HU-30) |
| `Recruiter` | Renombrada a `company_recruiter` | «Recruiter» en JobOut es Ana, Martín, Laura: los de IA |

**Eliminado por riesgo legal:** `Job_Offer.age_range_from`, `age_range_to`,
`gender_preference_id` y `marital_status_id`, más el catálogo `gender_preferences`. Filtrar
candidatos por edad, género o estado civil es ilegal en EEUU, la UE y buena parte de LatAm.
`gender_id` y `marital_status_id` se conservan en `personal_data` como dato demográfico
opcional del perfil — la diferencia es que ninguna oferta puede filtrar por ellos.

**Documentos actualizados**

- `documentation/db.md` — esquema completo, reemplaza el placeholder
- `documentation/producto.md` — sección «Los dos lados», 7 historias de empresa (HU-50…HU-56)
- `documentation/glossary.md` — `company_recruiter` contra `ai_recruiter`, rúbrica versionada, match
- `docs/archived/revision-esquema-smart-talent.md` — nuevo

**Qué quedó a medias**

Nada. El esquema está completo a nivel de diseño. Falta escribirlo como migraciones.

**Qué sigue**

1. Crear `jobout-core-api` y escribir las migraciones SeaORM del esquema, por bloques:
   identidad → catálogos → perfil del candidato → empresa y ofertas → entrevista.
2. Definir el orden de fases en `docs/working/`. El lado candidato y las entrevistas primero:
   aportan valor sin una sola oferta publicada.
3. Fase 1 — auth con Clerk y perfil de usuario.

**Decisiones abiertas**

- Clave maestra con rotación propia contra un KMS gestionado, para el cifrado de PII.
- Rotación de la clave del HMAC de `email_hash`.
- Si `skills` se cura a mano o crece desde las extracciones de CV.
- Particionado de `interview_turns` y `access_audit`: son las dos que más crecen.
- Proveedor de LLM y costo por sesión de entrevista, con su tope por usuario.
- Hosting.

---

## 2026-09-02 — Scaffolding de documentación

**Qué se hizo**

- Se definió la arquitectura del proyecto y se tomaron las decisiones de stack (ver tabla
  abajo).
- Este repo (`jobout-docs`) se armó completo: `AGENTS.md` como punto de entrada, `docs/` para
  proceso y `documentation/` para referencia estable.
- Se escribió el documento maestro de producto
  ([`documentation/producto.md`](../documentation/producto.md)) con visión, objetivos,
  historias de usuario, los recruiters y la gamificación.

**Decisiones tomadas**

| Decisión | Elección | Razón |
|---|---|---|
| Core backend | Rust · Axum · SeaORM | Tipos exhaustivos, migraciones en Rust, sin sorpresas en runtime |
| Servicio de IA | Python · FastAPI | LivePortrait y MuseTalk son PyTorch; no hay equivalente en Rust |
| Frontend | Next.js | — |
| Auth | Clerk | MFA y social listos, menos superficie propia manejando credenciales |
| BD | PostgreSQL | — |
| Repos | Multi-repo | Aislamiento real entre el servicio con PII y el que no la tiene |
| Docs | Repo central (`jobout-docs`) | Una sola fuente de verdad |
| Avatar MVP | Foto estática + animación mínima | ~95% menos costo. LivePortrait y MuseTalk vienen después |

**Qué quedó a medias**

Nada. El scaffolding está completo. `documentation/db.md`, `api.md` y `frontend.md` son
esqueletos con las reglas escritas pero **sin contenido técnico todavía** — eso llega con las
fases correspondientes.

**Qué sigue**

1. **Diseño de la base de datos** — el siguiente paso acordado. Entidades base: usuarios,
   perfiles, CVs, recruiters, sesiones de entrevista, turnos, scores, ofertas, aplicaciones.
   Salida: esquema completo en [`documentation/db.md`](../documentation/db.md).
2. Crear los repos `jobout-core-api`, `jobout-interview` y `jobout-web`, cada uno con su
   `AGENTS.md` corto apuntando acá.
3. Fase 1 — auth con Clerk y perfil de usuario.

**Decisiones abiertas**

- Proveedor de LLM y de voz para el MVP: OpenAI Realtime es la apuesta, falta estimar costo
  por sesión de entrevista y definir el tope por usuario.
- Estrategia de cifrado de PII: cifrado a nivel de aplicación está decidido; falta elegir
  entre una clave maestra con rotación o un KMS gestionado.
- Hosting: sin definir.
