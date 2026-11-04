# continue.md — traspaso de sesión

**Esto se lee al empezar y se actualiza al terminar.** Es la razón de ser de este repo: que
cualquiera —agente o persona— sepa qué se hizo, cómo y qué sigue, sin preguntar.

Entrada más reciente arriba. No borres entradas viejas: se van quedando como historia.

---

## 2026-11-04 — Documentación de marca y negocio, Fase 1 y módulo de cifrado

**Qué se hizo**

- Se leyeron los documentos del emprendimiento (identidad de marca, sostenibilidad social,
  indicadores financieros y la plantilla de costos) y quedaron en
  [`../documentation/identidad-visual.md`](../documentation/identidad-visual.md) y
  [`../documentation/negocio.md`](../documentation/negocio.md).
- Se redactó [`working/fase1-identidad.md`](working/fase1-identidad.md) con sus casos de
  verdad. **Decisión de MVP:** autenticación propia con JWT, sin Clerk; Clerk queda como camino
  de escala. Se agregan planes de usuario (`plans`, `user_subscriptions`).
- Paso 1 de la fase, en `jobout-core-api` (rama `jb-05-pii-crypto`): módulo `crypto` con
  AES-256-GCM y HMAC del email, 17 pruebas, escritas primero en rojo.
- El entorno quedó verde: `jobout-web` con dependencias instaladas y pruebas pasando.

**Decisiones tomadas**

| Decisión | Elección |
|---|---|
| Autenticación del MVP | JWT propio, Argon2id, refresh rotativo. Sin Clerk |
| Membresías de usuario | Tablas nuevas `plans` y `user_subscriptions`; `memberships` sigue siendo de empresas |
| «Entrar con Google» | Fuera del MVP; HU-01 queda cubierta solo con email |

**Qué quedó a medias**

- Nada commiteado: los cambios están en las ramas `jb-04-fase1-identidad` (docs) y
  `jb-05-pii-crypto` (core-api), solo en local.
- El push por SSH no funcionó: la clave personal tiene passphrase y la sesión no tenía agente.
- Las ramas `jb-02-fix-dev-stale-binary` (core-api) y `jb-03-ci-migration-glob` (docs) no están
  en `main` local; falta confirmar si se mergearon en GitHub.
- `jobout-web/package-lock.json` quedó sin versionar.

**Qué sigue**

1. Que el equipo revise los casos de verdad de `fase1-identidad.md`.
2. Paso 2: migraciones del bloque identidad y de planes, con `db.md`, contra PostgreSQL real.
3. Pasos 3 a 8 de la fase.

**Alerta de negocio:** el modelo financiero calcula Q0.80 por simulación «de texto», pero el
producto es voz en tiempo real. Hay que estimar el costo real antes de fijar precios
(ver [`../documentation/negocio.md`](../documentation/negocio.md)).

---

## 2026-09-03 — Backend, frontend y entorno dockerizado

**Qué se hizo**

- Se crearon los repos **`jobout-core-api`** (Rust · Axum · SeaORM) y **`jobout-web`**
  (Next.js), ambos dockerizados con tres etapas: `dev` con recarga en caliente, `builder`, y
  `runtime` sin compilador, sin fuente y **sin root**.
- **Un comando levanta todo:** `make dev` desde este repo. Verifica que los repos hermanos
  estén clonados, copia los `.example` a sus versiones locales sin pisar nada, y levanta
  backend, frontend y PostgreSQL.
- Patrón `.example` versionado / local ignorado en los tres repos, para `docker-compose.yml` y
  los `.env`. El CI de cada repo rechaza que se versione un local.
- CI propio en cada repo: formato, lint, tipos, pruebas, **la imagen `runtime` compila**, sin
  secretos, formato de rama y secciones del PR.
- Guía completa en [`../documentation/desarrollo.md`](../documentation/desarrollo.md).

**Casos de verdad ya escritos**

Los dos repos arrancan con `/health` probado, y en ambos hay un caso que fija **qué campos
puede devolver una ruta pública** — es una ruta sin autenticación, así que el test evita que
alguien le agregue un dato de usuario sin darse cuenta.

**Correcciones**

- `documentation/ci.md` decía `cargo sqlx migrate`; con SeaORM es `sea-orm-cli migrate`.
- La imagen de Rust quedó en `1.90-bookworm`: las dependencias transitivas piden rustc ≥ 1.88,
  y `1.85` no compila. Anotado en `Cargo.toml` con `rust-version`.

**Dos checks de CI que vale la pena conocer**

- **`jobout-web`** rechaza cualquier `NEXT_PUBLIC_*SECRET`, `*TOKEN`, `*PASSWORD` o `*_KEY`.
  Ese prefijo compila el valor dentro del bundle: un secreto con ese nombre es un secreto
  público.
- **`jobout-interview`**, cuando exista, rechaza cualquier cliente de PostgreSQL. Ese servicio
  no habla con la base de datos por diseño; el check está especificado en `ci.md`.

**Qué quedó a medias**

Nada. Falta `jobout-interview` (Python · FastAPI), que no era parte de esta tarea.

**Qué sigue**

1. Agregar a Arturo, Lazaro, Jorge y Oscar como colaboradores en los tres repos.
2. Migraciones SeaORM del esquema, por bloques: identidad → catálogos → perfil →
   empresa/ofertas → entrevista.
3. Fase 1 — auth con Clerk y perfil de usuario.
4. Crear `jobout-interview` cuando toque la fase de entrevista.

---

## 2026-09-03 — Repositorio, reglas de PR y contexto de investigación

**Qué se hizo**

- Se creó el repo remoto y se configuró la protección de `main`.
- **Reglas de contribución** en [`../CONTRIBUTING.md`](../CONTRIBUTING.md): ramas `jb-##-slug`,
  casos de verdad antes de codear, TDD, las cuatro secciones obligatorias del PR y qué bloquea
  un merge.
- **Plantilla de PR** en `.github/pull_request_template.md`, con las cuatro secciones y la
  lista de verificación previa a pedir revisión.
- **CI** en `.github/workflows/ci.yml` para este repo, y el contrato para los otros tres en
  [`../documentation/ci.md`](../documentation/ci.md).
- Se parsearon los dos PDFs del proyecto y su contenido quedó en
  [`../documentation/investigacion.md`](../documentation/investigacion.md): la persona (Luis
  Estrada), el cuadro de alternativas y el benchmark contra LinkedIn.

**El hallazgo que más cambió el producto**

Dos fuentes independientes dijeron lo mismo: Luis —«la parte que no me convence mucho es la
inclusión de la IA»— y el benchmark de LinkedIn, que marca «impulsar la inclusión innecesaria
de IA generativa» como su defecto principal.

De ahí sale una restricción que atraviesa todo: **la IA es el medio, nunca el pitch.** Se vende
«practicá con Martín, CTO exigente», no «entrevistas con inteligencia artificial». Y explica por
qué `interview_scores.breakdown` no es opcional en el esquema: un score sin explicación es
exactamente el tipo de IA que a Luis no le convence.

**Decisiones tomadas**

| Decisión | Elección |
|---|---|
| Casos de verdad | Se definen en el **archivo de fase**, antes de implementar. El PR los ejecuta |
| Protección de `main` | PR obligatorio, 1 aprobación, CI verde, sin push directo |
| Merge | Squash. Un commit por PR |
| Formato de rama | `jb-##-slug`. El CI lo rechaza si no cumple |
| Plataforma | **Sitio web**, del cuadro de alternativas. Mismo impacto que la app móvil con un solo desarrollo, y la entrevista es una sesión larga sentado |

**Qué quedó a medias**

Nada. Falta que los otros cuatro del equipo tengan acceso al repo.

**Qué sigue**

1. Agregar a Arturo, Lazaro, Jorge y Oscar como colaboradores.
2. Crear `jobout-core-api` con el mismo `CONTRIBUTING.md` y el CI de Rust de `ci.md`.
3. Migraciones SeaORM del esquema, por bloques.
4. Fase 1 — auth con Clerk y perfil de usuario.

**Anotado para fase futura**

**Skills validadas por desempeño en entrevistas.** Es lo único del benchmark que no se
implementó: la validación comunitaria de LinkedIn necesita masa crítica. La versión que escala
desde el primer día es respaldar una skill con la evidencia de las entrevistas —si Martín
preguntó tres veces sobre concurrencia y las respuestas puntuaron alto, esa skill tiene
evidencia y no un clic de un conocido—. No está en el esquema todavía.

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
