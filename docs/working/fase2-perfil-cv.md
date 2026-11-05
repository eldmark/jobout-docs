# Fase 2 — Perfil y CV

**Estado:** en curso (pasos 1 a 11 implementados; falta el cierre con CVs reales y una persona en el navegador)
**Repos que toca:** jobout-core-api, jobout-web, jobout (documentación)
**Abierta:** 2026-11-04

## Objetivo

Una persona sube su CV, el sistema le **propone** su experiencia, habilidades e idiomas, ella los
revisa y corrige, y lo que confirma queda como su perfil. Todo con el archivo guardado en un
lugar privado, sin que ningún dato personal salga a un tercero, y borrable por completo (HU-05).

Es el primer lugar donde el producto guarda **archivos** y **datos sobre la carrera** de una
persona. Lo que se construya acá es lo que después alimenta el matching (HU-30) y la memoria de
los recruiters, así que los errores se pagan en las fases siguientes.

## Historias de usuario que cubre

- HU-02 — Como candidato, quiero subir mi CV, para que el sistema conozca mi experiencia
- HU-03 — Como candidato, quiero que se extraigan mi experiencia y mis habilidades del CV, para
  no cargarlas a mano
- HU-04 — Como candidato, quiero editar lo que se extrajo, para corregir errores
- HU-05 *(ampliación)* — borrar la cuenta ahora también borra los archivos y el perfil

## Lo que esta fase descubrió que el diseño no decía

Se anota antes de escribir casos, porque cambia el alcance:

1. **No hay dónde guardar la «experiencia».** HU-03 la pide, pero `professional_data` solo tiene
   una descripción. Hace falta una tabla `applicant_experiences` (ver «Cambios de esquema»).
2. **Los catálogos no existen todavía.** `skills`, `languages`, `academic_levels`, `professions`
   y `job_hierarchies` están diseñados en `db.md` pero ninguna migración los creó. Sin ellos no
   hay a qué asociar lo extraído.
3. **No hay proveedor de LLM decidido** y la política es «nunca entrenar con tus datos» (HU-42).
   Ver la decisión 2.
4. **Borrar la cuenta ya no cabe en una transacción.** Los archivos viven fuera de PostgreSQL;
   si la base se borra y el borrado del archivo falla, queda un CV huérfano que la persona creyó
   eliminado. Ver B-casos y la tabla `pending_storage_deletions`.
5. **`cv_extractions.extracted (jsonb)` puede filtrar PII sin cifrar** si el extractor guarda lo
   que encuentra. Se resuelve por diseño: el extractor **no extrae datos de contacto**.

## Alcance

**Dentro:**

- Catálogos mínimos con datos semilla: `languages`, `skills`, `academic_levels`, `professions`,
  `job_hierarchies`.
- Perfil: `professional_data`, `applicant_languages`, `applicant_skills`,
  `applicant_extra_knowledge`, `applicant_experiences`, y de `personal_data` **solo el teléfono**
  (cifrado).
- CV: `cvs` (con versiones y uno primario), `cv_extractions`, y una interfaz `BlobStore` con una
  implementación sobre disco privado para desarrollo y pruebas.
- Subida con validación de tipo **por contenido** (PDF y DOCX), tamaño y límites contra archivos
  maliciosos.
- Extracción de texto y un extractor **determinista** (sin red) detrás de una interfaz
  `CvExtractor`.
- Endpoints de CV, de extracción propuesta, de confirmación, de perfil y de catálogos.
- Borrado de la cuenta ampliado: archivos incluidos, con reintento si fallan.
- Frontend: subir CV, revisar y editar lo propuesto, ver y editar el perfil, borrar un CV.

**Fuera (y por qué):**

- **Sugerencias para mejorar el CV (HU-24)** y **ofertas compatibles (HU-30)**: dependen de este
  perfil, pero son su propia fase.
- **Extracción con un LLM**: sin proveedor decidido ni costo estimado. La interfaz queda lista.
- **S3 real**: no hay hosting definido. La interfaz `BlobStore` permite añadirlo sin tocar las
  rutas; hay que hacerlo **antes de salir a usuarios reales** (decisión 1).
- **URLs firmadas de S3**: mientras el almacén sea local, la descarga es un endpoint autenticado
  que entrega el archivo; con S3 pasa a URL firmada de vida corta, como pide `security.md`.
- **Proceso en segundo plano**: la extracción corre en la misma petición (decisión 3).
- **Otros datos personales** de `personal_data` (documento, nacimiento, dirección, género, estado
  civil): nada de esta fase los necesita. Cuanto menos se guarde, menos hay que proteger.
- **Antivirus sobre los archivos subidos**: se anota como riesgo, no se resuelve acá.
- **Cartas de recomendación** y cualquier archivo que no sea el CV.

## Cambios de esquema

Tablas nuevas: `languages`, `skills`, `academic_levels`, `professions`, `job_hierarchies`
(catálogos, forma estándar de `db.md`), `professional_data`, `applicant_languages`,
`applicant_skills`, `applicant_extra_knowledge`, **`applicant_experiences`**, `personal_data`,
`cvs`, `cv_extractions`, **`pending_storage_deletions`**.

Enums de PostgreSQL: `proficiency` (`native` · `advanced` · `intermediate` · `basic`),
`skill_level`, `cv_extraction_status` (`ready` · `failed`).

Migraciones (cada una con `up` y `down`, `db.md` en el mismo PR):

- `m20261105_000001_create_catalogs` (catálogos y semillas)
- `m20261105_000002_create_profile` (perfil, experiencias, `personal_data`)
- `m20261105_000003_create_cvs` (`cvs`, `cv_extractions`, `pending_storage_deletions`)

Decisiones de diseño que `db.md` todavía no dice:

- **`applicant_experiences`**: `applicant_id` FK · `company` · `title` · `start_date` ·
  `end_date` (null = actual) · `description (text, null)` · `position (int)` para conservar el
  orden. **Pregunta abierta:** si `company` y `description` se cifran (decisión 5).
- **`pending_storage_deletions`**: `id` · `storage_key (bytea, cifrado)` · `created_at` ·
  `attempts (int)` · `last_attempt_at`. Es una bandeja de salida: la llena el borrado dentro de
  la misma transacción y se vacía cuando el archivo ya no existe. **Sin FK a `users`** por la
  misma razón que `privacy_events`.
- **`cvs`**: un solo `is_primary = true` por candidato (índice único parcial) y `version`
  correlativa por candidato. `storage_key` es un UUID aleatorio, **nunca** el nombre del archivo
  ni un id del candidato.
- **`cv_extractions.extracted`** solo contiene `{skills[], languages[], experiences[],
  description}`; **jamás** teléfono, email ni dirección.
- Los catálogos usan `code` único para referirse a un valor sin depender de un id (`db.md`).

## Pasos

Cada paso es una rama `jb-##-slug` y un PR. Los marcados ⇉ no dependen entre sí y se pueden
trabajar en paralelo.

- [ ] 0. **Este documento**: el equipo revisa los casos de verdad y resuelve las decisiones abiertas.
- [x] 1. Migración de catálogos y semillas (⇉ con 3 y 4). *(rama `jb-19-profile-schema`)*
- [x] 2. Migración de perfil (`professional_data`, idiomas, skills, experiencias, `personal_data`). *(rama `jb-19-profile-schema`)*
- [x] 3. `BlobStore`: interfaz, almacén en disco privado y almacén en memoria para pruebas (⇉). *(rama `jb-20-blob-store`)*
- [x] 4. Extracción: texto de PDF y DOCX con límites, y `CvExtractor` determinista (⇉, sin base de *(rama `jb-21-cv-extractor`)*
      datos).
- [x] 5. Migración de `cvs`, `cv_extractions` y `pending_storage_deletions`. *(rama `jb-19-profile-schema`)*
- [x] 6. `POST /cvs`: subida, validación y extracción. *(rama `jb-25-cv-routes`)*
- [x] 7. Lectura, descarga, primario y borrado de CVs. *(rama `jb-25-cv-routes`)*
- [x] 8. Confirmación de lo extraído y `GET/PUT /profile`, catálogos. *(rama `jb-26-profile-routes`)*
- [x] 9. Borrado de cuenta ampliado y reintento de `pending_storage_deletions`. *(rama `jb-27-account-deletion-files`)*
- [x] 10. Frontend: subir CV y revisar lo propuesto (⇉ con 11). *(rama `jb-22-cv-pages`)*
- [x] 11. Frontend: perfil y borrado de CV. *(rama `jb-22-cv-pages`)*
- [ ] 12. Recorrido en navegador y cierre. *Recorrido hecho en Chrome contra el backend real, **pero por un agente y con un CV sintético**; faltan la pasada de una persona y la medición con CVs reales (ver «Desvíos»).*

## Casos de verdad

> **Se acuerdan ANTES de implementar.** Cada caso tiene que poder convertirse en un test, uno a
> uno. Los números son los que van a llevar los tests.

### Catálogos (paso 1)

| # | Caso | Tipo |
|---|---|---|
| K1 | Correr las migraciones crea los cinco catálogos con la forma estándar (`id`, `code` único, `name`, `active`, `sort_order`) | integración |
| K2 | `down` seguido de `up` deja el mismo esquema | integración |
| K3 | `code` repetido dentro de un catálogo falla | integración |
| K4 | Se siembran al menos 80 skills de software, y `javascript`, `rust`, `sql`, `docker` y `react` existen | integración |
| K5 | Se siembran `es`, `en` y `pt` en `languages` (códigos ISO 639-1) | integración |
| K6 | Ningún `code` de skill contiene mayúsculas, espacios ni tildes | unitaria |
| K7 | `GET /api/v1/catalogs/skills` sin token → 401 | integración |
| K8 | `GET /api/v1/catalogs/skills` con token devuelve solo las activas, ordenadas por `sort_order` y luego `name`, con `id`, `code` y `name` | integración |
| K9 | Un catálogo desconocido (`/catalogs/otra-cosa`) → 404 | integración |

### Perfil, esquema (paso 2)

| # | Caso | Tipo |
|---|---|---|
| E1 | Crear las tablas de perfil sobre una base migrada; `down` y `up` son reversibles | integración |
| E2 | `applicant_skills` con un `skill_id` inexistente falla (FK) | integración |
| E3 | La misma skill dos veces para el mismo candidato falla (único) | integración |
| E4 | `applicant_languages.proficiency` fuera del enum falla | integración |
| E5 | `personal_data.phone` guardado **no contiene** el teléfono en claro | integración |
| E6 | Borrar un `users` borra en cascada perfil, skills, idiomas, experiencias y `personal_data` | integración |
| E7 | `applicant_experiences` con `end_date` anterior a `start_date` falla (CHECK) | integración |

### Almacén de archivos (paso 3)

| # | Caso | Tipo |
|---|---|---|
| A1 | Guardar bytes con una clave y leerlos con la misma clave devuelve los mismos bytes | unitaria |
| A2 | Leer una clave que no existe devuelve «no encontrado», no un error genérico | unitaria |
| A3 | Borrar una clave existente la elimina; borrar una que no existe **no falla** (idempotente) | unitaria |
| A4 | Una clave con `..`, `/`, `\` o un byte nulo se **rechaza** (sin salirse del directorio base) | unitaria |
| A5 | Dos claves distintas no se pisan; guardar sobre una clave existente falla (no sobrescribe) | unitaria |
| A6 | El directorio base del disco se crea con permisos solo del dueño (`0700`) y los archivos `0600` | unitaria |
| A7 | La interfaz es la misma para el almacén en disco y para el de memoria: la misma batería de pruebas corre contra ambos | unitaria |

### Texto del CV (paso 4)

| # | Caso | Tipo |
|---|---|---|
| X1 | Un PDF de prueba con texto devuelve ese texto | unitaria |
| X2 | Un DOCX de prueba con texto devuelve ese texto | unitaria |
| X3 | Un PDF sin texto (escaneado) devuelve «sin texto», no un error ni un texto vacío engañoso | unitaria |
| X4 | Un archivo corrupto o truncado devuelve un error de dominio, **sin `panic`** | unitaria |
| X5 | Un DOCX cuyo contenido descomprimido supera 20 MB se rechaza **antes** de descomprimirlo todo (zip bomb) | unitaria |
| X6 | Un PDF de más de 15 páginas se procesa solo hasta la 15 y lo dice | unitaria |
| X7 | La extracción tiene un tope de 10 segundos y devuelve «tiempo agotado» | unitaria |
| X8 | El tipo se decide por los **primeros bytes** (`%PDF-`, `PK\x03\x04` con `word/document.xml`), nunca por la extensión ni por el `Content-Type` | unitaria |
| X9 | Un ejecutable renombrado `cv.pdf` se rechaza | unitaria |

### Extractor determinista (paso 4)

| # | Caso | Tipo |
|---|---|---|
| D1 | Un texto que menciona «Rust», «PostgreSQL» y «Docker» propone esas tres skills del catálogo, con su `id` | unitaria |
| D2 | La búsqueda ignora mayúsculas y tildes («POSTGRESQL», «Programacion») | unitaria |
| D3 | No inventa: «Trabajé con rustico y javascripty» **no** propone `rust` ni `javascript` (coincide por palabra completa) | unitaria |
| D4 | Una skill con alias (`js` → `javascript`, `postgres` → `postgresql`) se reconoce por su alias | unitaria |
| D5 | Reconoce idiomas por nombre («Inglés avanzado», «English – intermediate») y propone su nivel; sin nivel indicado propone `intermediate` y lo marca como «a confirmar» | unitaria |
| D6 | Detecta bloques de experiencia con empresa, cargo y fechas en formatos `2021 – 2023`, `ene 2021 – actual` y `01/2021 – 03/2023`; «actual», «presente» y «hoy» dejan `end_date` en null | unitaria |
| D7 | Un texto sin nada reconocible devuelve listas vacías, no un error | unitaria |
| D8 | **No** devuelve teléfonos, emails ni direcciones aunque el texto los contenga (se prueba con un CV que los trae) | unitaria |
| D9 | Cada propuesta lleva una `confianza` (`alta` · `media` · `baja`); lo que viene de un alias o de una fecha ambigua nunca es `alta` | unitaria |
| D10 | La salida es **determinista**: el mismo texto da exactamente el mismo resultado, en el mismo orden | unitaria |
| D11 | Un texto de 2 MB se procesa en menos de 2 segundos (no hay búsquedas cuadráticas) | unitaria |

### Esquema de CV (paso 5)

| # | Caso | Tipo |
|---|---|---|
| C1 | Se crean `cvs`, `cv_extractions` y `pending_storage_deletions`; `down` y `up` son reversibles | integración |
| C2 | Dos `cvs` primarios para el mismo candidato fallan (índice parcial) | integración |
| C3 | `cvs.storage_key` guardado **no contiene** la clave en claro | integración |
| C4 | `pending_storage_deletions` no tiene FK a `users` y sobrevive al borrado del usuario | integración |
| C5 | Borrar un `cvs` borra su `cv_extractions` en cascada | integración |

### Subida (paso 6)

| # | Caso | Tipo |
|---|---|---|
| U1 | `POST /api/v1/cvs` con un PDF válido → 201 con `id`, `version = 1`, `is_primary = true`, y la extracción propuesta | integración |
| U2 | El archivo queda en el almacén bajo una clave aleatoria; `cvs.storage_key` está cifrado y el nombre original **no** forma parte de la clave | integración |
| U3 | El segundo CV del mismo candidato → `version = 2` y `is_primary` pasa al nuevo; el anterior sigue guardado | integración |
| U4 | Sin token → 401 | integración |
| U5 | Un archivo de más de 5 MB → 413, sin guardar nada | integración |
| U6 | Un archivo que no es PDF ni DOCX (por contenido) → 415, sin guardar nada, aunque se llame `cv.pdf` y diga `application/pdf` | integración |
| U7 | Un cuerpo sin campo `file`, o con dos, → 422 | integración |
| U8 | Un nombre de archivo con `../../etc/passwd`, saltos de línea o 500 caracteres se guarda **sanitizado** para mostrarse y no afecta dónde se guarda | integración |
| U9 | Más de 5 CVs guardados → 409 con mensaje claro; hay que borrar uno | integración |
| U10 | Si el almacén falla al guardar, no queda fila en `cvs` (todo o nada) y responde 500 genérico | integración |
| U11 | Si la **base** falla después de guardar el archivo, el archivo se borra (sin huérfanos) | integración |
| U12 | Un CV sin texto extraíble (escaneado) → 201 con extracción `failed` y el motivo «sin texto»; el CV queda guardado y la persona puede llenar el perfil a mano | integración |
| U13 | Dos subidas simultáneas del mismo candidato dejan versiones distintas y **un solo** primario | integración |
| U14 | La extracción nunca bloquea más de 10 segundos la petición | integración |

### Leer, descargar y borrar CVs (paso 7)

| # | Caso | Tipo |
|---|---|---|
| L1 | `GET /api/v1/cvs` lista solo **mis** CVs (versión, nombre, tamaño, fecha, primario), sin `storage_key` | integración |
| L2 | `GET /api/v1/cvs/{id}/file` devuelve los mismos bytes, con `Content-Disposition: attachment` y `X-Content-Type-Options: nosniff` | integración |
| L3 | El CV de otro usuario por id → **404**, nunca 403 ni el archivo (S1) | integración |
| L4 | Un id con formato inválido → 404 | integración |
| L5 | `PUT /api/v1/cvs/{id}/primary` cambia el primario; el de otro usuario → 404 | integración |
| L6 | `DELETE /api/v1/cvs/{id}` → 204: borra la fila, la extracción **y el archivo** | integración |
| L7 | Borrar el CV primario promueve al más reciente restante; si era el único, no queda ninguno | integración |
| L8 | Si el almacén falla al borrar el archivo, el CV desaparece para la persona y la clave queda en `pending_storage_deletions` | integración |
| L9 | El mismo `DELETE` dos veces → el segundo 404 | integración |
| L10 | El nombre del archivo y su contenido **no aparecen en el log** de ninguna de estas rutas | integración |

### Confirmar y editar (paso 8)

| # | Caso | Tipo |
|---|---|---|
| V1 | `GET /api/v1/cvs/{id}/extraction` devuelve lo propuesto con su confianza; el de otro usuario → 404 | integración |
| V2 | `POST /api/v1/cvs/{id}/extraction/confirm` con lo editado por la persona guarda **eso** y no lo propuesto | integración |
| V3 | La confirmación reemplaza skills, idiomas y experiencias previos del perfil en **una transacción**; si algo falla no queda nada a medias | integración |
| V4 | Una `skill_id` que no existe → 422 y no se guarda nada | integración |
| V5 | Dos veces la misma skill → 422 | integración |
| V6 | Un nivel de idioma fuera del enum → 422 | integración |
| V7 | Una experiencia con fin anterior al inicio → 422 | integración |
| V8 | Textos de más de 2000 caracteres en una descripción → 422; HTML o `<script>` se guarda como texto, nunca interpretado | integración |
| V9 | Más de 60 skills, 10 idiomas o 30 experiencias → 422 (tope contra abuso) | integración |
| V10 | Tras confirmar, `cv_extractions.reviewed_by_applicant = true` | integración |
| V11 | Confirmar sin haber editado nada guarda lo propuesto (la persona acepta tal cual) | integración |
| V12 | Confirmar una extracción `failed` con datos escritos a mano funciona igual (HU-04 sin CV legible) | integración |

### Perfil (paso 8)

| # | Caso | Tipo |
|---|---|---|
| P1 | `GET /api/v1/profile` de una cuenta nueva devuelve un perfil vacío con la estructura completa, no 404 | integración |
| P2 | `PUT /api/v1/profile` guarda descripción, nivel académico, profesión, jerarquía, skills, idiomas, conocimientos extra y teléfono | integración |
| P3 | El teléfono se guarda cifrado y se devuelve descifrado; en la base no está en claro | integración |
| P4 | Un teléfono con letras o de más de 20 caracteres → 422 | integración |
| P5 | Un id de catálogo inexistente → 422 | integración |
| P6 | `PUT` es completo: lo que no se envía se vacía; una llamada dos veces da el mismo resultado (idempotente) | integración |
| P7 | `GET /me` sigue devolviendo **exactamente** los mismos campos que en la Fase 1 (no se cuela el perfil) | integración |
| P8 | El perfil de otro usuario no se puede leer ni modificar: no existe ruta por id | integración |
| P9 | Sin token → 401 | integración |

### Borrado de cuenta ampliado (paso 9)

| # | Caso | Tipo |
|---|---|---|
| B1 | `DELETE /me` borra además del perfil todos los **archivos** del candidato en el almacén | integración |
| B2 | Las filas de `cvs`, `cv_extractions`, perfil y experiencias dejan de existir | integración |
| B3 | Si el almacén falla, la cuenta **sí** se borra y las claves quedan en `pending_storage_deletions` (cifradas) | integración |
| B4 | El reintento procesa la bandeja, borra los archivos y la vacía; un archivo que ya no existe cuenta como éxito | integración |
| B5 | Tras reintentar, ninguna fila de la bandeja conserva datos que identifiquen a la persona | integración |
| B6 | `privacy_events` sigue con **una** constancia y sin datos personales, y el borrado de la cuenta con CVs sigue siendo atómico en la base | integración |
| B7 | Los archivos de **otro** usuario no se tocan | integración |
| B8 | Una clave que falla 10 veces se marca para revisión humana y deja un log **sin** la clave | integración |

### Seguridad transversal (obligatorios de la plantilla)

| # | Caso | Tipo |
|---|---|---|
| S1 | El usuario A pide por id un CV, extracción o archivo de B → 404, nunca el dato | integración |
| S2 | Toda ruta nueva sin token → 401; la tabla de rutas las declara `Authenticated` (ninguna es pública) | integración |
| S3 | Un error provocado con datos sensibles (nombre de archivo, teléfono, texto del CV) no los filtra en la respuesta ni en el log | integración |
| S4 | Ni el contenido del CV, ni su texto extraído, ni el teléfono aparecen en el log de peticiones correctas | integración |
| S5 | `tests/route_table.rs` incluye las rutas nuevas en la lista esperada (añadirlas obliga a editar ese test) | integración |
| S6 | Una subida con `Content-Length` mentiroso o cuerpo infinito se corta en el tope, sin agotar memoria | integración |
| S7 | Ninguna ruta de CV devuelve la `storage_key` ni la ruta del archivo en disco | integración |
| S8 | El texto extraído **no se guarda en ningún lado**: se descarta al terminar la petición | integración |

### Frontend (pasos 10 y 11)

| # | Caso | Tipo |
|---|---|---|
| F1 | `/profile/cv` sin sesión redirige a `/sign-in` | unitaria (middleware) |
| F2 | El selector de archivo solo acepta PDF y DOCX y rechaza más de 5 MB **antes** de enviar, con un mensaje claro | componente |
| F3 | Mientras sube se ve el progreso y el botón queda deshabilitado (no se sube dos veces) | componente |
| F4 | Tras subir, se muestra lo propuesto agrupado (experiencia, skills, idiomas) con la confianza de cada cosa; lo de confianza baja se destaca | componente |
| F5 | Cada propuesta se puede editar, quitar y se pueden añadir otras; no se guarda nada hasta pulsar «Confirmar» | componente |
| F6 | Las skills se eligen **del catálogo** (búsqueda con sugerencias); no se puede inventar una | componente |
| F7 | Si la extracción falló («sin texto»), se explica en español y se ofrece llenar el perfil a mano | componente |
| F8 | Confirmar llama a la API una sola vez (doble clic no duplica) y lleva al perfil | componente |
| F9 | Los errores 409, 413, 415 y 422 de la API se muestran en español, sin texto técnico ni nombres de campo internos | componente |
| F10 | Borrar un CV pide confirmación, dice qué se pierde y no llama a la API al primer clic | componente |
| F11 | La descarga pasa por la capa servidor: el navegador **no** ve el token ni la ruta del almacén | unitaria |
| F12 | El dashboard muestra «Completa tu perfil» si no hay CV ni skills, y desaparece cuando hay | componente |
| F13 | Todos los textos salen de `lib/messages/es.ts` y siguen en tuteo | unitaria |
| F14 | Todo es operable con teclado y los errores se anuncian (`aria-live`); el foco va al primer error | componente |
| F15 | Los colores de marca siguen declarados una sola vez y el texto sobre coral usa tinta | unitaria |

## Criterios de cierre

- [ ] Todos los casos de verdad tienen su test, y fallaron antes de pasar
- [ ] Mutaciones: al menos 4 por paso que toque seguridad (validación por contenido, aislamiento
      entre usuarios, borrado, límites), cada una detectada por un test
- [ ] Todas las pruebas verdes en los tres repos y en CI; `clippy -D warnings`, `cargo fmt --check`,
      `tsc` y `eslint` limpios
- [ ] **Con CVs reales** (al menos 5 PDF y 2 DOCX de personas del equipo, con su permiso): se mide
      qué porcentaje de skills y experiencias propone bien el extractor y se anota el número en
      «Desvíos». Si es bajo, es la evidencia para decidir el LLM
- [ ] Recorrido en un navegador real **por una persona**: registrarse → subir CV → revisar y
      editar → confirmar → ver el perfil → borrar un CV → borrar la cuenta → comprobar que no
      quedan archivos en el directorio del almacén
- [ ] `documentation/db.md`, `api.md`, `frontend.md`, `security.md` y `test.md` actualizados
- [ ] `docs/continue.md` actualizado y esta fase movida a `docs/archived/`

## Decisiones abiertas (el equipo las resuelve al revisar este archivo)

1. **Dónde se guardan los archivos.** *Recomendado:* interfaz `BlobStore` + disco privado ahora
   (testable, sin dependencias externas), y la implementación S3 en una fase corta **antes de
   salir a usuarios reales**. *Alternativa:* S3 compatible (MinIO) ya en el compose y el CI; es lo
   más parecido a producción pero añade un servicio y una dependencia grande a esta fase. El
   hosting sigue sin definirse, y S3 depende de él.
2. **Cómo se extrae.** *Recomendado:* extractor determinista, sin red, por tres razones: no hay
   proveedor ni costo decidido, **ningún dato del CV sale del servicio** (HU-42, y es lo más fácil
   de defender ante Luis), y es probable que alcance para skills e idiomas contra un catálogo
   cerrado. *Riesgo honesto:* para experiencia laboral en texto libre puede quedarse corto; por eso
   el criterio de cierre mide la calidad con CVs reales. Si un LLM entra después, tiene que ser con
   retención cero y sin entrenamiento, y detrás de la misma interfaz.
3. **Síncrono o asíncrono.** *Recomendado:* sincrónico con tope de 10 s: más simple, el resultado
   se ve al instante y con un extractor determinista tarda milisegundos. Cambia si algún día se
   usa un LLM, y por eso la interfaz devuelve un resultado y no asume ni una cosa ni la otra.
4. **Tope de CVs por persona.** Se propone 5 (versiones). Es un número, no un principio: se puede
   cambiar.
5. **¿Se cifran `company` y `description` de las experiencias?** `db.md` cifra los datos de
   contacto e identificación, no los datos de carrera. Una descripción libre puede contener casi
   cualquier cosa. *Recomendado:* cifrar `description` y dejar `company` y `title` en claro, porque
   el matching futuro los necesita para filtrar. Esto limita qué se puede buscar por texto en
   descripciones.
6. **Skills: catálogo cerrado o abierto.** *Recomendado:* cerrado y curado a mano (semilla de unas
   100 skills de software) y un canal para sugerir nuevas, no que crezca solo desde los CVs. Ya
   figura como pendiente en `db.md`.
7. **Formatos.** PDF y DOCX. Quedan fuera `.doc` antiguo, `.odt`, `.pages` e imágenes. Un CV como
   foto no se puede leer sin OCR; se trata como «sin texto».

## Riesgos que se aceptan sabiendo que existen

- Un PDF malicioso puede explotar un fallo del lector. Mitigado con límites de tamaño, páginas,
  tiempo y validación por contenido, pero **no eliminado**; por eso la extracción no debería
  correr con más permisos de los necesarios. Un antivirus queda fuera de esta fase.
- El disco local no tiene redundancia ni cifrado en reposo propio. Es válido para desarrollo; **no
  es aceptable en producción** (decisión 1).
- Con extractor determinista, un CV muy creativo (columnas, tablas, plantillas gráficas) puede dar
  texto desordenado y propuestas pobres. La persona siempre puede corregir (HU-04).

## Desvíos y hallazgos

- **2026-11-05 — arranque sin revisión del equipo.** Se pidió empezar sin haber resuelto las siete
  decisiones abiertas, así que se adoptaron **las recomendaciones del plan**: almacén en disco detrás
  de una interfaz, extractor determinista, extracción síncrona, tope de 5 CVs, `description` de las
  experiencias cifrada (`company` y `title` en claro) y catálogo de skills cerrado. **El equipo puede
  revertirlas**; las dos más caras de cambiar son el cifrado de `description` y el extractor.
- **Qué quedó hecho** (cinco ramas apiladas más cuatro independientes, ver los PRs): catálogos con 114
  skills; esquema de perfil y CVs; `BlobStore`; texto de PDF/DOCX y extractor; rutas de CV, perfil y
  confirmación; borrado de cuenta con archivos; y las pantallas. Suite del backend integrado: 325
  pruebas; frontend: 230.
- **Hallazgo de seguridad (corregido en `jb-29`): los valores de las consultas salían en claro en los
  logs con `RUST_LOG=trace`.** `sea-orm` abre un *span* `trace` por consulta con la sentencia y sus
  valores como campos, y cualquier evento dentro los imprime como contexto: nombres, descripción del
  perfil, empresa, cargo y nombre del archivo. Con el filtro por defecto no pasaba, pero un
  `RUST_LOG=trace` «solo un momento» en producción lo habría llevado a los logs. Desactivar
  `sqlx_logging` **no** lo evita (se probó). Se fijó por código que `sea_orm` y `sqlx` no pasen de
  `warn`. Lo vio primero el agente de perfil; lo confirmó una prueba que empezó a fallar al integrar.
- **Tope de cuerpo por ruta.** El tope global de 8 KB impedía subir CVs. Se añadió
  `RouteSpec.body_limit` (sustituye al global solo en esa ruta; un test impide declarar más de 6 MB).
  Consecuencia: el tope global corta con 413 un `PUT /profile` con muchas experiencias de 2000
  caracteres. Si hace falta, se declara un tope propio.
- **Recorrido en Chrome contra el backend real** (el frontend se había probado solo con simulaciones):
  registro → «Completa tu perfil» → subir un DOCX → revisar lo propuesto → editar un nivel →
  confirmar → «Tu perfil» → borrar el CV (diálogo) → subir otro → borrar la **cuenta**. Se comprobó
  además por `curl` y `psql`: la descarga es idéntica byte a byte; el archivo en disco tiene nombre
  UUID aleatorio y permisos `0600` (directorio `0700`); `storage_key` y `description` van cifradas; la
  propuesta guardada no contiene correo ni teléfono; un ejecutable renombrado `.pdf` da 415 y no deja
  archivo; con la contraseña mala el borrado de cuenta da 403 y no toca el archivo; con la buena el
  almacén queda en 0 archivos, la base sin datos, la bandeja vacía y **una** constancia. El log real
  del backend no contiene ningún dato personal.
- **Límites de ese recorrido, para no sobrevalorarlo:** lo hizo un agente, no una persona; el CV lo
  escribió el mismo equipo con un formato limpio, así que **demuestra que el flujo funciona, no que el
  extractor sea bueno con CVs reales** (acertó 10 de 10 skills, 2 experiencias y 2 idiomas, pero con
  texto hecho a su medida); el archivo se inyectó con un `File` creado en la página porque la
  herramienta solo sube archivos que el usuario comparte; la herramienta bloquea leer cookies, así que
  `HttpOnly` no se comprobó en el navegador; solo se vio en oscuro y a ancho de escritorio.
- **Observaciones visuales sin arreglar:** la etiqueta «Primario» se estira como una barra a todo el
  ancho de la tarjeta, y el selector de archivo conserva el texto del navegador («Choose File»).
- **Sin probar:** U14 a nivel de ruta (tiempo agotado: no hay forma de inyectarlo sin tocar
  `AppState`); el bucle de 60 s de `storage_cleanup` en `main` (la lógica sí está probada llamando a la
  función); PDFs reales y CVs con columnas o tablas, que el extractor lee desordenados.
- **Incidentes del entorno que afectaron el trabajo:** el cupo de `/tmp` se llenó con el directorio de
  compilación compartido y bloqueó a tres agentes (se movió a `/home`); `/tmp` se limpió al cambiar de
  día y se perdieron worktrees y scripts (las ramas estaban subidas, no se perdió código); PostgreSQL
  quedó detenido tras un reinicio; y `gh` cambió de cuenta a la de trabajo mientras se trabajaba.
