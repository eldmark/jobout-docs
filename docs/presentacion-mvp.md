# Presentación del MVP — catálogo de casos de prueba para la demo

**Qué es esto.** Un catálogo de casos que se pueden **mostrar en vivo** para presentar lo que el MVP de
JobOut hace hoy. Cada caso dice qué probar, con qué datos, paso a paso, qué debe pasar, qué prueba
automática lo cubre y si alguien ya lo vio funcionar en el navegador.

**De dónde sale.** `develop` de los tres repos al 2026-11-11 (docs `9a54f05`, core-api `242812d`, web
`ed910c7`). Los nombres de pruebas se verificaron leyendo `tests/*.rs` de core-api y `tests/*.test.*` de
web; si un caso dice «solo manual», es porque no hay prueba que lo cubra. El estado «probado en navegador»
sale **solo** de lo que dicen [`continue.md`](continue.md) y [`bugs.md`](bugs.md): nada se marcó por
suposición.

## Cómo leer los estados

| Estado | Significa |
|---|---|
| **probado en navegador (2026-11-11)** | Lo recorrió el agente de JB-84 con Chrome el 2026-11-11 (`continue.md`, «Recorrido en el navegador del MVP»). Fue con web `8bd671c`, **antes** de web #27 y #28 (ver «Lo que cambió después del recorrido») |
| **probado en navegador (2026-11-10)** | Solo lo vio el recorrido anterior (`continue.md`, «Recorrido en el navegador, hecho por un agente», 2026-11-10 noche) |
| **probado solo por pruebas automáticas** | Hay pruebas verdes, pero nadie lo vio en un navegador según los docs |
| **no probado** | No hay código ni prueba. Hoy solo el chat de IA |

Los dos recorridos los hizo **un agente**, no una persona del equipo: ninguno reemplaza la pasada de una
persona (lo dicen los dos docs). El drag-and-drop se probó con un evento `drop` simulado, no con el ratón
desde el explorador de archivos.

Cada caso lleva un ID `CP-<ÁREA>-<NN>`. Áreas: `CUE` cuenta y perfil · `CV` · `ENT` entrevista · `OFE`
ofertas · `APL` aplicar con consentimiento · `EMP` lado empresa · `PRI` privacidad y seguridad · `CHAT`
chat de IA.

## Resumen

| Área | Casos | Navegador 2026-11-11 | Navegador 2026-11-10 | Solo pruebas automáticas | No probado | «Solo manual» |
|---|---|---|---|---|---|---|
| Cuenta y perfil (`CUE`) | 12 | 3 | 2 | 7 | 0 | 0 |
| CV (`CV`) | 14 | 6 | 0 | 8 | 0 | 0 |
| Entrevista (`ENT`) | 21 | 8 | 7 | 6 | 0 | 1 |
| Ofertas (`OFE`) | 11 | 7 | 0 | 4 | 0 | 0 |
| Aplicar con consentimiento (`APL`) | 11 | 6 | 0 | 5 | 0 | 0 |
| Lado empresa (`EMP`) | 21 | 16 | 0 | 5 | 0 | 0 |
| Privacidad y seguridad (`PRI`) | 12 | 9 | 0 | 3 | 0 | 0 |
| Chat de IA (`CHAT`) | 3 | 0 | 0 | 0 | 3 | 3 |
| **Total** | **105** | **55** | **9** | **38** | **3** | **4** |

«Solo manual» cuenta los casos sin prueba automática que los cubra: el límite BUG-004 (CP-ENT-11) y los tres
del chat. Los demás 101 casos tienen al menos una prueba con nombre verificado. Ojo: «probado en navegador»
lo hizo **un agente** y, en web, antes de #27 y #28.

## Antes de presentar

### Entorno

- Stack arriba y **migrado**: `make dev` y, en otra terminal, `make migrate` (ver
  [`desarrollo.md`](../documentation/desarrollo.md)). Sin migrar, las rutas de empresa fallan con
  `relation "..." does not exist`.
- Si trajiste web `develop` con dependencias nuevas (`three`, para el avatar 3D), reconstruye el contenedor:
  `docker compose build web && docker compose up -d --no-deps --force-recreate -V web` (BUG-012). Sin
  `three` la sala de entrevista ni siquiera dibuja el avatar.
- Abajo se usa `<WEB>` para la URL del frontend (por defecto `http://localhost:3000`; el recorrido usó
  `http://127.0.0.1:3100` por el `.env`) y `<API>` para la del backend (`http://localhost:8080`, rutas bajo
  `/api/v1`).
- Una ventana ancha (1560 px) para el escritorio; si falla el proyector, 390 px también se vio bien.

### Cuentas de demo

**Todo es inventado.** Usa un dominio de prueba (`jobout-prueba.test`) y una contraseña de al menos 10
caracteres que solo conozcas tú. Se crean por la interfaz en `<WEB>/sign-up`: nombre, apellido, correo y
contraseña.

| Cuenta | Rol | Correo de ejemplo | Cómo se crea |
|---|---|---|---|
| Candidata | candidate | `camila.demo@jobout-prueba.test` | `/sign-up` |
| Candidata sin perfil | candidate | `vacia.demo@jobout-prueba.test` | `/sign-up` y no tocar el perfil |
| Reclutadora (empresa A) | recruiter (`company_admin`) | `reclutadora.demo@jobout-prueba.test` | `/sign-up` → «Registrar mi empresa» |
| Reclutador invitado | recruiter | `reclutador2.demo@jobout-prueba.test` | `/sign-up`, y acepta la invitación de la empresa A |
| Reclutadora (empresa B) | recruiter (`company_admin`) | `otra.demo@jobout-prueba.test` | `/sign-up` → «Registrar mi empresa» con otro NIT |
| Admin de plataforma | admin | `admin.demo@jobout-prueba.test` | `/sign-up` y **un** SQL (abajo) |

**El único SQL.** No hay ruta que dé el rol de admin de plataforma (es a propósito, `fase5` paso 13). En la
base local de desarrollo, con el `user_id` de la cuenta admin (se obtiene con
`SELECT id FROM users WHERE first_name = 'Ana' AND last_name = 'Admin';` si la registras con ese nombre):

```sql
INSERT INTO user_roles (user_id, role_id)
SELECT '<USER_ID_ADMIN>', id FROM roles WHERE code = 'admin';
```

Con eso la admin ve «Empresas por verificar» (`<WEB>/admin/companies`) y **verifica la empresa y le asigna
la membresía desde la interfaz**: no hace falta otro SQL, y verificar con un `UPDATE` a mano está prohibido
(`db.md`). La membresía es «Empresarial», con inicio y fin (máximo 400 días).

**Opcional, para que la candidata practique más de una vez.** El plan Gratis da 1 práctica al mes, y
practicar una oferta también la gasta. Para el ensayo y la demo principal pasa a la candidata al plan
Estudiantil (10 al mes) y deja la candidata sin perfil en Gratis para mostrar el límite (CP-ENT-17):

```sql
UPDATE user_subscriptions
SET plan_id = (SELECT id FROM plans WHERE code = 'student')
WHERE user_id = '<USER_ID_CANDIDATA>' AND status = 'active';
```

### Datos de demo

- **Archivos de CV (inventados).** Un PDF y un DOCX de «Camila Demo» con: perfil de dos líneas, experiencia
  en dos empresas ficticias (con fechas `2022-2024` y `2024-actual`), habilidades Rust, PostgreSQL y Docker,
  e idiomas «Español nativo» e «Inglés intermedio». **Sin teléfono, dirección ni documento reales.** Para los
  errores: un `.txt` (o `.png`), un ejecutable cualquiera renombrado a `cv.pdf`, un PDF cortado a la mitad, un
  archivo de más de 5 MB (`{ printf '%%PDF-1.4\n'; head -c 5300000 /dev/zero; } > grande.pdf`) y un PDF sin
  texto (una imagen exportada a PDF).
- **Ofertas (de la empresa A, publicadas).** «Desarrollador Backend Junior Rust» (obligatorias Rust y Docker,
  deseable PostgreSQL, Inglés intermedio, 2 años); una **confidencial** («Analista de datos»); y una que
  pida habilidades que Camila no tiene (afinidad 0 %). Así el listado muestra afinidades distintas (el
  recorrido vio 100 %, 47 % y 0 %).
- **Respuestas de entrevista, ya escritas** (se pegan): una **vaga**, «Hice una app web con mi equipo.»; y
  dos **concretas**, con situación, acción y resultado y cifras («Construí una API en Rust con Axum y
  PostgreSQL para 300 usuarios; decidí usar Docker para desplegar y bajé la respuesta de 800 ms a 120 ms»).
- **Llamadas de API** (casos de privacidad). Un token se obtiene con
  `curl -s -X POST <API>/api/v1/auth/login -H 'content-type: application/json' -d '{"email":"<CORREO>","password":"<CONTRASEÑA_DEMO>"}'`
  y se manda como `-H 'authorization: Bearer <TOKEN>'`. Nunca pegues tokens ni contraseñas reales en una
  pantalla compartida.

## Lo que cambió después del recorrido

El recorrido del 2026-11-11 se hizo con web `8bd671c`. Después entraron a `develop` web #27 (BUG-012 a
BUG-018: filtros de `/offers` sin solaparse, `sort` y filtros en la URL, `preventScroll` en la sala, diálogo
de borrar cuenta más claro, dashboard sin bloques de candidato para empresas) y web #28 (pulido visual), y
core-api #40 (BUG-011). `bugs.md` todavía los lista como «sin mergear». **Esos arreglos están en `develop`
pero nadie los vio en un navegador:** ensaya la demo con el `develop` actual antes de presentarla.

## Casos de prueba

### Cuenta y perfil

#### CP-CUE-01 — Registro de una candidata
- **Objetivo:** crear una cuenta y llegar al dashboard con el plan Gratis.
- **Precondiciones:** correo nuevo, sin cuenta.
- **Pasos:** `<WEB>` → «Crear cuenta» (`/sign-up`) → nombre, apellido, correo, contraseña de 10 o más
  caracteres → «Crear cuenta».
- **Resultado esperado:** va a `/dashboard`, que muestra el nombre y «Tu plan: Gratis». API:
  `POST /auth/register` → 201.
- **Automatizada:** core-api `tests/auth.rs::r1_registro_valido_crea_cuenta_completa`; web
  `tests/sign-forms.test.tsx` («10 caracteres exactos pasan; envía a /api/auth/register y va a /dashboard»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-CUE-02 — Validación del formulario de registro
- **Objetivo:** mostrar que no se envía nada inválido.
- **Pasos:** `/sign-up` → correo sin `@` y contraseña de 9 caracteres → «Crear cuenta»; luego dejar todo vacío.
- **Resultado esperado:** mensajes en español, el foco va al primer campo inválido, no hay llamada a la API.
- **Automatizada:** web `tests/sign-forms.test.tsx` («valida en el cliente: email inválido y contraseña
  corta, sin llamar a la API», «campos vacíos: pide cada uno y el foco va al primero inválido»); core-api
  `tests/auth.rs::r4_datos_invalidos_dan_422`.
- **Estado:** probado solo por pruebas automáticas.

#### CP-CUE-03 — Correo repetido sin revelar quién tiene cuenta
- **Pasos:** `/sign-up` con el correo de Camila otra vez.
- **Resultado esperado:** un mensaje genérico (409 `registro_no_disponible`), que no nombra el correo.
- **Automatizada:** core-api `tests/auth.rs::r2_email_repetido_da_409_generico`; web
  `tests/sign-forms.test.tsx` («409: muestra solo el mensaje genérico, en un aria-live, sin nombrar el correo»).
- **Estado:** probado solo por pruebas automáticas.

#### CP-CUE-04 — Ingresar y cerrar sesión
- **Pasos:** `/sign-in` con la cuenta → `/dashboard` → «Cerrar sesión».
- **Resultado esperado:** entra al dashboard; al cerrar vuelve a `/sign-in` y `/dashboard` ya no abre.
  Los tokens van en cookies `HttpOnly`; el navegador no los ve.
- **Automatizada:** core-api `tests/auth.rs::r7_login_correcto_entrega_tokens`,
  `tests/refresh.rs::r15_logout_revoca_el_refresh`; web `tests/sign-forms.test.tsx` («éxito: POST a
  /api/auth/login y va a /dashboard»), `tests/dashboard.test.tsx` (««Cerrar sesión» hace POST
  /api/auth/logout y va a /sign-in»).
- **Estado:** probado solo por pruebas automáticas.

#### CP-CUE-05 — Credenciales malas y bloqueo tras 5 fallos
- **Pasos:** `/sign-in` con una contraseña equivocada 5 veces; después con la correcta.
- **Resultado esperado:** el mismo mensaje para «no existe» y «clave mala»; a la quinta, 429
  `demasiados_intentos` durante 15 minutos (también para un correo que no existe).
- **Automatizada:** core-api `tests/auth.rs::r8_fallos_de_login_son_indistinguibles`,
  `r10_cinco_fallos_bloquean_el_login`, `r10_el_bloqueo_no_revela_si_el_email_existe`; web
  `tests/sign-forms.test.tsx` («401 no distingue entre correo inexistente y contraseña mala»).
- **Estado:** probado solo por pruebas automáticas. **No lo hagas con la cuenta de la demo:** la bloquea 15
  minutos.

#### CP-CUE-06 — Sin sesión, las páginas piden ingresar
- **Pasos:** en una ventana sin sesión abrir `<WEB>/dashboard`, `/profile` o `/interviews`.
- **Resultado esperado:** redirige a `/sign-in`. Una llamada `fetch` a `/api/cvs` o `/api/profile` sin sesión
  recibe 401 en JSON, no el HTML de la página.
- **Automatizada:** web `tests/middleware.test.ts`, `tests/route-guard.test.ts`, `tests/interview-guard.test.ts`;
  core-api `tests/route_table.rs::t3_las_rutas_protegidas_exigen_token`.
- **Estado:** probado en navegador (2026-11-10, tras borrar la cuenta: `/interviews`, `/interviews/progress` y
  `/profile` redirigieron a `/sign-in`).

#### CP-CUE-07 — Completar el perfil
- **Objetivo:** guardar nivel académico, profesión, jerarquía, teléfono y descripción.
- **Precondiciones:** sesión de Camila.
- **Pasos:** `<WEB>/profile` → elegir nivel académico, profesión y jerarquía; teléfono ficticio
  (`+502 5555 0000`); descripción corta → «Guardar».
- **Resultado esperado:** aviso de guardado; al recargar, los datos siguen. API: `PUT /profile` → 204
  (reemplazo completo e idempotente).
- **Automatizada:** core-api `tests/profile.rs::p2_put_guarda_el_perfil_completo`,
  `p6_put_es_completo_e_idempotente`; web `tests/profile-view.test.tsx` («guarda el perfil completo con un
  PUT»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-CUE-08 — Teléfono inválido y doble clic
- **Pasos:** en `/profile`, teléfono `abc` → «Guardar»; luego un teléfono válido y doble clic.
- **Resultado esperado:** el teléfono inválido no llama a la API y enfoca el campo; el doble clic envía una
  sola vez.
- **Automatizada:** core-api `tests/profile.rs::p4_telefono_invalido_da_422`; web
  `tests/profile-view.test.tsx` («teléfono inválido: no llama a la API y enfoca el campo», «doble clic en
  guardar envía una sola vez»).
- **Estado:** probado solo por pruebas automáticas.

#### CP-CUE-09 — Teléfono y descripción cifrados en la base
- **Pasos (para quien quiera ver la prueba):** guardar el perfil de CP-CUE-07 y, en la base,
  `SELECT phone FROM personal_data;`.
- **Resultado esperado:** bytes ilegibles (`bytea` cifrado), no el número.
- **Automatizada:** core-api `tests/profile.rs::p3_telefono_y_descripcion_van_cifrados`,
  `tests/profile_schema.rs::e5_telefono_y_descripcion_no_estan_en_claro`.
- **Estado:** probado solo por pruebas automáticas.

#### CP-CUE-10 — Dashboard según lo que ya hiciste
- **Pasos:** `/dashboard` con una cuenta nueva; después con una entrevista pausada.
- **Resultado esperado:** cuenta nueva: «Completa tu perfil» y «Practica una entrevista»; con una entrevista
  en curso o pausada: «Retoma tu entrevista» (gana la en curso).
- **Automatizada:** web `tests/dashboard-profile.test.tsx`, `tests/interview-dashboard.test.tsx` («una
  sesión pausada también se retoma», «si hay una en curso y otra pausada, gana la en curso»).
- **Estado:** probado en navegador (2026-11-10: «Retoma tu entrevista» tras pausar). Los bloques de
  candidato que aparecían a una cuenta de empresa (BUG-018) se arreglaron en web #27, sin verlo en navegador.

#### CP-CUE-11 — El menú depende del rol
- **Pasos:** `/dashboard` con Camila, con la reclutadora y con la admin.
- **Resultado esperado:** Camila: «Ver ofertas», «Mis aplicaciones», «Registrar mi empresa». Reclutadora:
  «Mi empresa» y «Ofertas de mi empresa». Admin: «Empresas por verificar», sin «Registrar mi empresa».
  El menú es solo comodidad: la API sigue decidiendo (CP-PRI-03).
- **Automatizada:** web `tests/offers-nav.test.tsx`; core-api `tests/me.rs::m3_me_trae_roles_y_permisos_de_un_candidato`.
- **Estado:** probado en navegador (2026-11-11), pero el recorrido vio el dashboard **antes** de web #27
  (BUG-018).

#### CP-CUE-12 — La sesión se renueva sola y un refresh reusado cierra todo
- **Pasos:** solo por API: `POST /auth/refresh` con el `refresh_token`; repetir con el mismo.
- **Resultado esperado:** el primero da tokens nuevos; reusar el viejo da 401 `sesion_invalida` y **revoca
  todas las sesiones** de la persona.
- **Automatizada:** core-api `tests/refresh.rs::r12_refresh_valido_rota_el_token`,
  `r13_reuso_revoca_todas_las_sesiones`; web `tests/dashboard.test.tsx` («401: manda al refresco
  transparente», «401 justo después de refrescar: no hay bucle»).
- **Estado:** probado solo por pruebas automáticas.

### CV

#### CP-CV-01 — Subir un PDF con el selector
- **Precondiciones:** sesión de Camila; `camila-demo.pdf` inventado de menos de 5 MB.
- **Pasos:** `<WEB>/profile/cv` → «Elegir archivo» → el PDF → «Subir CV».
- **Resultado esperado:** el botón se deshabilita mientras sube, dice que está analizando el CV y luego
  muestra la **propuesta**. API: `POST /cvs` (multipart, campo `file`) → 201 con `extraction`.
- **Automatizada:** core-api `tests/cvs.rs::u1_subir_un_pdf_valido`; web `tests/cv-flow.test.tsx` («muestra
  el progreso, deshabilita el botón y no sube dos veces», «al terminar de subir anuncia que está analizando
  el CV…»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-CV-02 — Subir un DOCX arrastrando y soltando
- **Pasos:** `/profile/cv` → arrastrar `camila-demo.docx` desde el explorador sobre la zona de subida (se
  resalta al arrastrar) → soltar → «Subir CV».
- **Resultado esperado:** el archivo queda elegido con su nombre y se habilita la subida; el resto, igual que
  CP-CV-01.
- **Automatizada:** core-api `tests/cvs.rs::u1b_subir_un_docx_valido`; web `tests/cv-flow.test.tsx` («soltar
  un PDF lo deja elegido y habilita la subida», «al arrastrar encima se resalta y al salir se quita»,
  «mientras sube no acepta otro archivo soltado»).
- **Estado:** probado en navegador (2026-11-11), con un evento `drop` **simulado**. El arrastre real con el
  ratón no se verificó: pruébalo tú en el ensayo.

#### CP-CV-03 — Revisar la propuesta
- **Pasos:** tras subir, mirar la pantalla de revisión.
- **Resultado esperado:** la propuesta sale **agrupada** en experiencia, habilidades e idiomas; lo de
  confianza baja se destaca y un idioma sin nivel claro dice «a confirmar». **Nada se guardó todavía.** La
  propuesta nunca trae teléfono, correo ni dirección.
- **Automatizada:** core-api `tests/cvs.rs::u12c_la_extraccion_lista_se_guarda_con_su_propuesta`,
  `tests/cv_extractor.rs` (`d5_*`, `d6_*`, `d9_*`), `tests/cv_corpus.rs::d8_el_corpus_jamas_filtra_contacto`;
  web `tests/cv-flow.test.tsx` («agrupa en experiencia, habilidades e idiomas y destaca la confianza baja»,
  «el idioma «a confirmar» se avisa»).
- **Estado:** probado en navegador (2026-11-11). Las experiencias salen con las limitaciones de CP-CV-14.

#### CP-CV-04 — Corregir la propuesta antes de confirmar
- **Pasos:** en la revisión, quitar una habilidad, cambiar el cargo de una experiencia, añadir una
  experiencia nueva y buscar una habilidad en el catálogo.
- **Resultado esperado:** lo editado es lo que se enviará, y no antes; las habilidades se eligen del
  catálogo con búsqueda (no se inventan) y no se ofrecen las ya elegidas; un fin anterior al inicio da error
  de validación.
- **Automatizada:** web `tests/cv-flow.test.tsx` («lo editado es lo que se envía, y no antes», «se puede
  añadir una experiencia nueva», «sugiere desde el catálogo y no permite inventar», «fin anterior al inicio
  es un error de validación»); core-api `tests/profile.rs::v2_v3_v10_confirmar_guarda_lo_editado_y_reemplaza`.
- **Estado:** probado solo por pruebas automáticas.

#### CP-CV-05 — Confirmar y que el perfil se llene
- **Pasos:** «Confirmar» (una vez, o con doble clic).
- **Resultado esperado:** una sola llamada; va al perfil, que ahora muestra las experiencias, habilidades e
  idiomas. API: `POST /cvs/{id}/extraction/confirm` → 204; guarda **lo que la persona envió**, todo o nada.
- **Automatizada:** core-api `tests/profile.rs::v11_confirmar_lo_propuesto_tal_cual`,
  `v3_un_fallo_a_mitad_revierte_todo`; web `tests/cv-flow.test.tsx` («doble clic no duplica y lleva al
  perfil»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-CV-06 — Descargar el CV
- **Pasos:** `/profile` → en la lista de CVs, «Descargar».
- **Resultado esperado:** baja un archivo **idéntico** al subido (mismos bytes). La descarga pasa por el
  servidor; el navegador no ve rutas del almacén.
- **Automatizada:** core-api `tests/cvs.rs::l2_la_descarga_entrega_los_mismos_bytes`; web
  `tests/profile-view.test.tsx` («muestra versión, nombre, primario y descarga por la capa servidor»).
- **Estado:** probado en navegador (2026-11-11): el archivo bajado era idéntico. El flujo nativo de descarga
  del navegador no se verificó más allá del archivo.

#### CP-CV-07 — Un segundo CV y marcar el primario
- **Pasos:** subir un segundo CV → en `/profile`, «Marcar como primario» en el anterior.
- **Resultado esperado:** el segundo pasa a ser primario al subirlo; el cambio manual funciona y siempre hay
  un solo primario.
- **Automatizada:** core-api `tests/cvs.rs::u3_el_segundo_cv_pasa_a_ser_el_primario`, `l5_cambiar_el_primario`;
  web `tests/profile-view.test.tsx` («marcar como primario llama a PUT y recarga la lista»).
- **Estado:** probado solo por pruebas automáticas.

#### CP-CV-08 — Borrar un CV
- **Pasos:** `/profile` → «Borrar» en un CV → leer el aviso → confirmar.
- **Resultado esperado:** el primer clic **no** borra: abre un diálogo (foco dentro, Escape lo cierra). Al
  confirmar se borran el CV, su extracción y el archivo; **el perfil confirmado se conserva**.
- **Automatizada:** core-api `tests/cvs.rs::l6_borrar_se_lleva_fila_extraccion_y_archivo`,
  `l7_borrar_el_primario_promueve_al_mas_reciente`; web `tests/profile-view.test.tsx` («el primer clic abre el
  diálogo y NO llama a la API», «confirmar borra una sola vez (doble clic) y la lista se actualiza»).
- **Estado:** probado en navegador (2026-11-11). Que el archivo desaparezca del almacén **no** se verificó
  (la carpeta `data/` es de `root`); sí en 2026-11-10 («0 archivos en el almacén» tras borrar la cuenta).

#### CP-CV-09 — Error: tipo de archivo inválido
- **Pasos:** `/profile/cv` → elegir un `.txt` o `.png`; después, un ejecutable renombrado a `cv.pdf` y subir.
- **Resultado esperado:** el selector solo ofrece PDF y DOCX y un tipo ajeno da un aviso claro antes de
  enviar. El ejecutable renombrado **sí llega al servidor** y recibe 415 `tipo_no_permitido`: el tipo se
  decide por el **contenido** (`%PDF-` o un ZIP con `word/document.xml`), no por la extensión.
- **Automatizada:** core-api `tests/cvs.rs::u6_el_tipo_se_decide_por_contenido`,
  `tests/cv_text.rs::x9_ejecutable_renombrado_se_rechaza`; web `tests/cv-flow.test.tsx` («rechaza un tipo que
  no es PDF ni DOCX», «un 415 por contenido (archivo dañado o renombrado) explica qué hacer»).
- **Estado:** probado solo por pruebas automáticas.

#### CP-CV-10 — Error: archivo de más de 5 MB
- **Pasos:** elegir `grande.pdf` (5,3 MB).
- **Resultado esperado:** mensaje claro **antes** de enviar, sin subir nada. Por API directa, 413
  `archivo_demasiado_grande`; justo 5 MB pasa.
- **Automatizada:** web `tests/cv-flow.test.tsx` («rechaza más de 5 MB ANTES de enviar, con mensaje claro»);
  core-api `tests/cvs.rs::u5_mas_de_5_mb_es_413_y_justo_5_mb_pasa`, `s6b_un_content_length_mentiroso_no_evita_el_tope`.
- **Estado:** probado solo por pruebas automáticas.

#### CP-CV-11 — Error: archivo dañado
- **Pasos:** subir el PDF cortado a la mitad.
- **Resultado esperado:** el archivo se guarda pero la extracción queda `failed` con motivo `ilegible`; la
  pantalla lo explica en español y ofrece **llenar el perfil a mano**. Nada inventado.
- **Automatizada:** core-api `tests/cvs.rs::u12b_un_pdf_ilegible_se_guarda_con_extraccion_fallida`,
  `tests/cv_text.rs::x4_pdf_truncado_es_corrupt`, `x4_docx_truncado_es_corrupt`; web `tests/cv-flow.test.tsx`
  («explica en español y ofrece llenar a mano», «motivo %s» con `ilegible` y `tiempo_agotado`).
- **Estado:** probado solo por pruebas automáticas.

#### CP-CV-12 — Error: un CV sin texto (escaneado)
- **Pasos:** subir un PDF que es una imagen.
- **Resultado esperado:** motivo `sin_texto`, con la misma salida: llenar a mano. No hay OCR.
- **Automatizada:** core-api `tests/cvs.rs::u12_un_cv_sin_texto_se_guarda_con_extraccion_fallida`,
  `tests/cv_text.rs::x3_pdf_sin_texto_devuelve_no_text`.
- **Estado:** probado solo por pruebas automáticas.

#### CP-CV-13 — Tope de 5 CVs por persona
- **Pasos:** subir un sexto CV (por API es más rápido).
- **Resultado esperado:** 409 `limite_de_cvs`.
- **Automatizada:** core-api `tests/cvs.rs::u9_maximo_cinco_cvs`, `u9b_el_tope_es_por_persona`.
- **Estado:** probado solo por pruebas automáticas.

#### CP-CV-14 — Un CV difícil: la propuesta es limitada (límite conocido)
- **Objetivo:** que nadie se sorprenda en vivo. El extractor es determinista y se midió con 22 CVs
  inventados (habilidades e idiomas 100 %, experiencias 90 %, un **techo optimista**).
- **Pasos:** subir un CV de dos columnas, o uno en prosa sin encabezados, o con «Worked at X 2022-2024».
- **Resultado esperado (honesto):** puede fallar. Una experiencia puede venir mal, hasta con confianza alta
  en el peor caso (dos columnas intercaladas). La revisión antes de «Confirmar» existe para eso. **No usar
  en la demo un CV real ni uno que no hayas ensayado.**
- **Automatizada:** core-api `tests/cv_corpus.rs` (`medicion_del_corpus`, `mejora_*`); lo que sigue fallando
  **no tiene prueba** porque el corpus no lo cubre.
- **Estado:** probado solo por pruebas automáticas, sobre un corpus sintético. Faltan CVs reales
  (`working/fase2-perfil-cv.md`).

### Entrevista

#### CP-ENT-01 — Elegir recruiter y nivel
- **Precondiciones:** sesión de Camila (plan Estudiantil); sin sesión activa.
- **Pasos:** `<WEB>/interviews`.
- **Resultado esperado:** salen los 5 recruiters (Ana, Martín, Laura, Carlos, Sofía) con su rol y
  personalidad, y 5 niveles. **Startup** sale deshabilitado con el motivo (hace falta un score mínimo en
  Junior); **Amazon, Google y McKinsey** dicen «aún no disponible».
- **Automatizada:** core-api `tests/interview_catalog_routes.rs::r2_recruiters_con_campos_publicos`,
  `r3_niveles_con_mi_progreso`, `r5_un_nivel_no_disponible_aparece_bloqueado`; web
  `tests/interview-start.test.tsx` («un nivel bloqueado aparece deshabilitado con el motivo, y uno no
  disponible también»).
- **Estado:** probado en navegador (2026-11-10).

#### CP-ENT-02 — Iniciar una entrevista
- **Pasos:** elegir Martín y «Junior» → «Empezar entrevista».
- **Resultado esperado:** abre la sala con la primera pregunta (la apertura del recruiter, la misma cada
  vez). Un doble clic crea **una** sola sesión. API: `POST /interviews` → 201.
- **Automatizada:** core-api `tests/interview_sessions.rs::s1_crear_devuelve_la_sesion_con_la_primera_pregunta`,
  `s6_creaciones_simultaneas_dejan_una_sola_sesion`; `tests/interview_engine.rs::m3_first_question_is_the_recruiters_opening_and_the_same_every_time`;
  web `tests/interview-start.test.tsx` («doble clic -> un solo POST y navega a la conversación»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-ENT-03 — Cada recruiter se comporta distinto
- **Pasos:** repetir CP-ENT-02 con Ana (RRHH), Martín (CTO) y Sofía.
- **Resultado esperado:** bancos de preguntas distintos (Ana pregunta por motivación y trabajo en equipo,
  Martín por decisiones técnicas y repregunta más); **Sofía entrevista en inglés**, también las
  repreguntas. Es un motor **determinista** por reglas, no un LLM.
- **Automatizada:** core-api `tests/interview_engine.rs::m2_banks_differ_and_ana_asks_motivation_and_teamwork_martin_technical_decisions`,
  `m8_martin_follows_up_where_ana_accepts`, `m10_sofia_speaks_english_everyone_else_spanish_including_follow_ups`;
  `tests/interview_catalog.rs::k3_sofia_entrevista_en_ingles_y_el_resto_en_espanol`.
- **Estado:** probado en navegador (2026-11-11) solo con Martín. Ana en 2026-11-10 (flujo de entrevista).
  Sofía no se vio en navegador.

#### CP-ENT-04 — Una respuesta vaga provoca una repregunta
- **Pasos:** en la sala, responder «Hice una app web con mi equipo.» → enviar con el botón o Ctrl+Enter.
- **Resultado esperado:** el recruiter **repregunta sobre lo mismo** en vez de pasar a la siguiente.
- **Automatizada:** core-api `tests/interview_turns.rs::t3_vaga_da_repregunta_y_buena_da_la_siguiente_pregunta`;
  `tests/interview_engine.rs::m5_short_answer_triggers_a_follow_up_on_the_same_question`.
- **Estado:** probado en navegador (2026-11-11).

#### CP-ENT-05 — Una respuesta concreta avanza (y hay un tope de repreguntas)
- **Pasos:** responder con la respuesta concreta de los datos de demo; después, otras vagas seguidas.
- **Resultado esperado:** la concreta pasa a la siguiente pregunta sin repregunta; como máximo hay 2
  repreguntas por pregunta y luego avanza; las preguntas no se repiten.
- **Automatizada:** core-api `tests/interview_engine.rs::m6_long_answer_with_concrete_example_moves_on_without_follow_up`,
  `m7_at_most_two_follow_ups_per_question_then_it_advances`, `m4_questions_never_repeat_and_follow_a_fixed_order`.
- **Estado:** probado en navegador (2026-11-11).

#### CP-ENT-06 — Enviar y validar el texto
- **Pasos:** enviar una respuesta vacía; una de más de 4000 caracteres; Enter solo; Ctrl+Enter.
- **Resultado esperado:** vacío y >4000 no se envían y se explica; Enter solo **no** envía; Ctrl+Enter (o
  Cmd+Enter) sí; el campo se vacía y se deshabilita mientras espera.
- **Automatizada:** web `tests/interview-room.test.tsx` («con Ctrl+Enter (y Cmd+Enter) envía; Enter solo no
  envía», «un texto de más de 4000 caracteres no se envía y se explica»); core-api
  `tests/interview_turns.rs::t4_validacion_del_texto`.
- **Estado:** probado solo por pruebas automáticas (el recorrido usó el envío normal).

#### CP-ENT-07 — Pausar y retomar
- **Pasos:** en la sala, «Pausar» → confirmar → `/dashboard` → «Retoma tu entrevista» → «Retomar».
- **Resultado esperado:** la pausa pide confirmación; el dashboard ofrece retomar; retomar muestra la
  **misma** pregunta, sin repetir ni saltar. Una pausada más de 7 días pasa sola a abandonada.
- **Automatizada:** core-api `tests/interview_sessions.rs::s9_pausar`, `s10_retomar_devuelve_el_ultimo_turno_del_recruiter`,
  `s11_retomar_no_repite_ni_salta_preguntas`, `s13_la_limpieza_abandona_las_pausadas_de_mas_de_7_dias`; web
  `tests/interview-dashboard.test.tsx`, `tests/interview-sessions.test.tsx`.
- **Estado:** probado en navegador (2026-11-10).

#### CP-ENT-08 — Solo una entrevista activa
- **Pasos:** con una entrevista en curso, volver a `/interviews` y empezar otra.
- **Resultado esperado:** 409 `sesion_en_curso`; la pantalla ofrece «Retoma tu entrevista» hacia esa sesión.
- **Automatizada:** core-api `tests/interview_sessions.rs::s5_con_sesion_activa_no_se_crea_otra`; web
  `tests/interview-start.test.tsx` («409 sesion_en_curso ofrece «Retoma tu entrevista» hacia esa sesión»).
- **Estado:** probado solo por pruebas automáticas (el recorrido del 2026-11-10 lo ejercitó por API).

#### CP-ENT-09 — Terminar la entrevista: resultado y puntaje
- **Precondiciones:** al menos 2 respuestas de la persona.
- **Pasos:** «Terminar y ver mi score» → confirmar.
- **Resultado esperado:** pantalla de resultado con **score** (0–100), **claridad**, el **desglose** por
  criterio con «x / máximo» y su «por qué» (los puntos suman exactamente el score), **2 o 3 mejoras**
  ordenadas por cuánto subirían el score, y **sin «confianza»** (siempre `null` en modo texto). El «por qué»
  nunca copia más de 80 caracteres de lo que escribiste. En el recorrido salió 60/100.
- **Automatizada:** core-api `tests/interview_finish.rs::c1_finish_calcula_el_score_y_completa_la_sesion`,
  `tests/interview_engine.rs::v3_score_is_exactly_the_sum_of_the_breakdown`, `v4_two_or_three_improvements_sorted_by_potential_gain`,
  `v11_why_cites_the_criterion_and_never_quotes_more_than_80_chars_of_the_user`; web
  `tests/interview-result.test.tsx` («el desglose muestra puntos obtenidos sobre el máximo de cada criterio, y
  suman el score», «no se muestra cuando es nula: ni etiqueta ni «—»»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-ENT-10 — Terminar antes de tiempo
- **Pasos:** recién empezada la sesión, «Terminar y ver mi score».
- **Resultado esperado:** 422 `entrevista_muy_corta` (hacen falta 2 respuestas) y la sesión sigue abierta.
  Terminar dos veces no recalcula ni duplica.
- **Automatizada:** core-api `tests/interview_finish.rs::c2_con_menos_de_dos_respuestas_no_se_termina`,
  `c6_terminar_dos_veces_no_recalcula_ni_duplica`.
- **Estado:** probado solo por pruebas automáticas.

#### CP-ENT-11 — El puntaje que parece injusto (BUG-004, límite conocido)
- **Objetivo:** que el presentador lo diga antes de que lo vea el público.
- **Pasos:** terminar una entrevista con una respuesta vaga y dos concretas (Martín/Junior).
- **Resultado esperado (honesto):** el score sale **bajo** (60–61) y el «por qué» dice «Relevancia 7/20: las
  respuestas se alejan de las preguntas», «faltan cifras» o «no aparecen las tres partes», aunque haya cifras
  y situación-acción-resultado. Causa: el evaluador es determinista, promedia **todas** las respuestas
  (incluida la vaga) y compara raíces de 5 letras. Es el límite del evaluador por reglas; el motor de IA
  (Fase 4) es la respuesta de producto. Reconfirmado el 2026-11-11.
- **Automatizada:** solo manual para el problema en sí (es un límite, no un fallo). Las pruebas de `v6` y `v7` en
  `tests/interview_engine.rs` fijan que más cifras y más estructura **suben** el score, no que sea justo.
- **Estado:** probado en navegador (2026-11-11), como bug abierto.

#### CP-ENT-12 — Transcripción de solo lectura
- **Pasos:** desde el resultado, «Ver transcripción».
- **Resultado esperado:** los turnos en orden con quién habló; sin campo de texto ni botones de enviar,
  pausar o terminar; el texto se pinta como texto, nunca como HTML. Una sesión no terminada explica que no
  hay transcripción.
- **Automatizada:** web `tests/interview-transcript.test.tsx` («es de solo lectura…», «el texto se muestra
  como texto, nunca como HTML»); core-api `tests/interview_sessions.rs::s8_leer_una_sesion_con_todos_los_turnos_descifrados`.
- **Estado:** probado en navegador (2026-11-10).

#### CP-ENT-13 — Mis entrevistas
- **Pasos:** `<WEB>/interviews/sessions`.
- **Resultado esperado:** una fila por sesión con fecha, nivel, recruiter, estado y score; «Mostrando 1
  entrevista.» en singular; acciones según el estado (completada: resultado y transcripción; en curso o
  pausada: retomar); «Cargar más» por cursor. Los enlaces «Ver resultado» y «Ver transcripción» deben salir
  separados (BUG-005, arreglado en web #14).
- **Automatizada:** web `tests/interview-sessions.test.tsx`; core-api `tests/interview_sessions.rs::s7_el_listado_es_mio_y_sin_transcripciones`,
  `s7b_paginacion_por_cursor`.
- **Estado:** probado en navegador (2026-11-10). El arreglo de BUG-005 no se volvió a ver en navegador.

#### CP-ENT-14 — Progreso
- **Pasos:** `<WEB>/interviews/progress`.
- **Resultado esperado:** los cinco niveles en orden, cuáles están desbloqueados, el mejor score y las
  sesiones completadas; la evolución cronológica; con una sola sesión no hay comparación; sin sesiones, un
  estado vacío con un llamado a practicar.
- **Automatizada:** web `tests/interview-progress.test.tsx`; core-api `tests/interview_catalog_routes.rs::r6_progreso_cronologico`,
  `r6b_cuenta_nueva_sin_progreso`.
- **Estado:** probado en navegador (2026-11-11).

#### CP-ENT-15 — Desbloqueo de niveles
- **Pasos:** terminar una entrevista Junior con score de **60 o más** → volver a `/interviews`.
- **Resultado esperado:** Startup queda desbloqueado (mínimo 60); un escalón por vez (desbloquear Startup no
  abre Amazon); por debajo del mínimo no desbloquea y `best_score` solo sube. Mínimos: Startup 60, Amazon 70,
  Google 75, McKinsey 80 (los tres últimos aún no disponibles).
- **Automatizada:** core-api `tests/interview_finish.rs::c8_un_score_en_el_minimo_desbloquea_el_siguiente_nivel`,
  `c9_por_debajo_no_desbloquea_y_best_score_solo_sube`, `c11_desbloquear_startup_no_desbloquea_amazon`.
- **Estado:** probado en navegador (2026-11-10: score 61 desbloqueó Startup).

#### CP-ENT-16 — No se puede empezar un nivel bloqueado o no disponible
- **Pasos:** en `/interviews`, intentar elegir Startup antes de desbloquearlo, o Amazon.
- **Resultado esperado:** el nivel está deshabilitado y un clic no lo elige. Por API: 403 `nivel_bloqueado` o
  409 `nivel_no_disponible` (este último gana, para que Amazon, Google y McKinsey digan siempre lo mismo).
- **Automatizada:** core-api `tests/interview_sessions.rs::s3_nivel_bloqueado_y_no_disponible`; web
  `tests/interview-start.test.tsx` («un nivel deshabilitado no cuenta como elegido aunque se haga clic…»).
- **Estado:** probado en navegador (2026-11-10).

#### CP-ENT-17 — Cuota del plan gratuito
- **Precondiciones:** una cuenta en plan **Gratis** que ya usó su práctica del mes (la candidata sin perfil).
- **Pasos:** empezar una segunda entrevista.
- **Resultado esperado:** «Ya usaste las entrevistas que incluye tu plan este mes. Se renueva el 1 de
  diciembre de 2026.» (403 `limite_del_plan`, fecha en UTC). Abandonar o borrar **no** devuelve la cuota.
  Estudiantil da 10 al mes y Estándar 12.
- **Automatizada:** core-api `tests/interview_quota.rs::q1_gratis_permite_una_y_la_segunda_es_403_con_renovacion`,
  `q4_abandonar_o_borrar_no_devuelve_la_cuota`, `q2_los_topes_de_estudiantil_y_estandar`; web
  `tests/interview-start.test.tsx` («403 limite_del_plan muestra la fecha de renovación en es-GT»).
- **Estado:** probado en navegador (2026-11-10). El 2026-11-11 la candidata ya había usado su práctica y se
  pasó a Estudiantil por SQL.

#### CP-ENT-18 — Abandonar y borrar una sesión
- **Pasos:** en la sala, «Abandonar» → confirmar; en un resultado, «Borrar esta sesión» → confirmar.
- **Resultado esperado:** ambos piden confirmación y avisan que el progreso acumulado no cambia; abandonar
  libera la sesión activa; borrar vale en cualquier estado.
- **Automatizada:** core-api `tests/interview_sessions.rs::s12_abandonar_libera_el_cupo`,
  `s14_borrar_en_cascada_sin_tocar_el_progreso`; web `tests/interview-result.test.tsx` («confirmar con doble
  clic -> un solo DELETE y aviso de que el progreso no cambió»).
- **Estado:** probado solo por pruebas automáticas.

#### CP-ENT-19 — Avatar 3D en reposo, pensando y hablando
- **Pasos:** en la sala, mirar el avatar de Martín: al entrar; al enviar una respuesta; cuando llega la
  pregunta.
- **Resultado esperado:** **reposo** al esperar tu respuesta → **pensando** mientras espera al recruiter →
  **hablando** (un tiempo proporcional al texto de la pregunta) → de vuelta a **reposo**. Es decorativo
  (`aria-hidden`); la transcripción y el `aria-live` llevan el mensaje.
- **Automatizada:** web `tests/interviewer-avatar.test.tsx` («el estado se refleja en data-state», «habla
  por un tiempo proporcional al texto y vuelve a reposo», «pensar tiene prioridad…»),
  `tests/interview-room.test.tsx` («piensa mientras se espera al recruiter y habla cuando llega su turno»).
- **Estado:** probado en navegador (2026-11-11). **Riesgo:** en un contenedor sin `three` no hay ni avatar
  (BUG-012, README actualizado en web #27); en la sala, el textarea con foco podía bajar la página y esconder
  al avatar (BUG-016, `preventScroll` en web #27, sin verlo en navegador).

#### CP-ENT-20 — Si el avatar 3D no carga, queda el 2D
- **Pasos:** solo con pruebas (rompe el `import()` de la escena); en la demo, con `prefers-reduced-motion`.
- **Resultado esperado:** queda el avatar 2D con la inicial, sin romper la sala; con movimiento reducido,
  un solo fotograma y ningún bucle.
- **Automatizada:** web `tests/interviewer-avatar-import.test.tsx`, `tests/interviewer-avatar.test.tsx`
  («si la escena falla, queda el avatar 2D sin romper», «movimiento reducido: un solo fotograma y ningún bucle»).
- **Estado:** probado solo por pruebas automáticas.

#### CP-ENT-21 — Si el motor falla, no se pierde la respuesta
- **Pasos:** solo por pruebas: el motor responde 503.
- **Resultado esperado:** «todo o nada»: la respuesta **no** queda guardada, el texto vuelve al campo y se
  puede reenviar. En la demo (plan B): es lo que pasa si el backend se cae a mitad de turno.
- **Automatizada:** core-api `tests/interview_turns.rs::t7_si_el_motor_falla_no_se_guarda_nada`; web
  `tests/interview-room.test.tsx` («si falla (503): mensaje en español anunciado, el texto vuelve al campo y
  se reintenta»).
- **Estado:** probado solo por pruebas automáticas.

### Ofertas

#### CP-OFE-01 — Lista de ofertas
- **Precondiciones:** empresa A verificada con 3 ofertas publicadas (una confidencial); sesión de Camila.
- **Pasos:** `<WEB>/offers` (desde el dashboard, «Ver ofertas»).
- **Resultado esperado:** una tarjeta por oferta: título enlazado al detalle, empresa, lugar, condiciones,
  vacantes y fecha; la confidencial dice «Empresa confidencial», sin nombre ni sitio. Solo salen las
  publicadas, de empresas verificadas con membresía vigente y no vencidas por fecha. Sin ofertas: estado
  vacío.
- **Automatizada:** core-api `tests/offers_public.rs::ca1_solo_publicadas_de_empresas_verificadas_y_vigentes`,
  `ca3_la_confidencial_no_revela_la_empresa`; web `tests/offers-list.test.tsx`.
- **Estado:** probado en navegador (2026-11-11).

#### CP-OFE-02 — Filtros
- **Pasos:** `/offers` → «Filtrar ofertas» → elegir un departamento (el municipio se habilita) y un tipo de
  contrato → «Filtrar» → «Quitar filtros».
- **Resultado esperado:** hay ocho filtros (profesión, departamento, municipio, contrato, salario, turno,
  sector, jerarquía) y el orden; **no** hay buscador de texto ni filtro por empresa (deanonimizaría las
  confidenciales). «Cargar más» conserva los filtros.
- **Automatizada:** core-api `tests/offers_public.rs::ca2_los_filtros_de_catalogo_funcionan`; web
  `tests/offers-list.test.tsx` («los ocho filtros del contrato y el orden…», «el municipio depende del
  departamento…», ««Filtrar» pide la primera página con los filtros elegidos…»).
- **Estado:** probado en navegador (2026-11-11), solo «Mejor afinidad → Filtrar». A 1560 px los selectores se
  **solapaban** (BUG-013) y el orden no quedaba en la URL (BUG-017); web #27 lo arregló, sin verlo en
  navegador. Ensaya esta pantalla.

#### CP-OFE-03 — Orden por afinidad
- **Pasos:** `/offers` → «Ordenar» → «Mejor afinidad» → «Filtrar».
- **Resultado esperado:** cada tarjeta muestra un chip de afinidad (100 %, 47 %, 0 % con los datos de demo)
  y el listado va de mayor a menor. API: `GET /offers?sort=match`.
- **Automatizada:** core-api `tests/matching.rs::ma6_sort_match_ordena_por_mi_puntaje_y_pagina`,
  `el_listado_trae_el_match_de_quien_llama`; web `tests/offers-list.test.tsx`, `tests/match-lib.test.ts`.
- **Estado:** probado en navegador (2026-11-11).

#### CP-OFE-04 — Sin perfil no hay afinidad, y lo dice
- **Precondiciones:** la candidata sin perfil.
- **Pasos:** `/offers` → «Mejor afinidad».
- **Resultado esperado:** ordena por fecha y lo dice (`sorted_by: "recent"`, `match_unavailable:
  "perfil_vacio"`); nunca un error ni un `NaN`.
- **Automatizada:** core-api `tests/matching.rs::ma6_sin_perfil_ordena_por_fecha_y_lo_dice`; web
  `tests/offers-paging.test.tsx` («expone la primera página (sorted_by y match_unavailable) en `head`»).
- **Estado:** probado solo por pruebas automáticas.

#### CP-OFE-05 — Detalle y desglose de la afinidad
- **Pasos:** abrir una oferta → sección «Afinidad con tu perfil».
- **Resultado esperado:** el puntaje y **cuatro componentes** con sus puntos sobre su peso: habilidades 50,
  idiomas 15, experiencia 20, nivel académico 15; cada habilidad dice «cumple», «cumple en parte» o «no
  cumple», si es obligatoria o deseable y los niveles; experiencia compara años pedidos y años tuyos; un
  componente que la oferta no pide no cuenta. No depende del color (todo es texto).
- **Automatizada:** core-api `tests/matching.rs::ma1_ma2_el_detalle_trae_mi_match_con_su_desglose`,
  `el_puntaje_suma_idiomas_experiencia_y_nivel`, `ma4_el_nombre_de_la_persona_no_cambia_el_puntaje`; web
  `tests/match-breakdown.test.tsx`, `tests/offer-detail.test.tsx`.
- **Estado:** probado en navegador (2026-11-11). **Límite:** solo cuentan habilidades, idiomas, experiencia
  y nivel académico (ver «Límites y bugs conocidos»).

#### CP-OFE-06 — Empresa confidencial
- **Pasos:** abrir la oferta confidencial.
- **Resultado esperado:** dice «Empresa confidencial», sin sitio ni nombre, y avisa **cuándo** se revela
  (al ser preseleccionada). Sector, ubicación, salario y requisitos sí se ven.
- **Automatizada:** core-api `tests/offers_public.rs::ca3_la_confidencial_no_revela_la_empresa`,
  `ca3_los_errores_no_nombran_la_empresa`; web `tests/offer-detail.test.tsx` («CA3: una confidencial no
  muestra empresa ni sitio, aunque la API los trajera…»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-OFE-07 — Practicar la entrevista de una oferta
- **Pasos:** en el detalle, «Practicar esta entrevista».
- **Resultado esperado:** abre la sala con «Practicando: Desarrollador Backend Junior Rust»; el recruiter es
  Ana y el nivel el más bajo disponible; después de la apertura hay **una pregunta por habilidad obligatoria**
  (hasta 3) y **una por idioma** (hasta 2) con una plantilla fija, y las preguntas mencionan Docker. Gasta la
  cuota del plan y respeta «una sola sesión activa».
- **Automatizada:** core-api `tests/interview_offer_practice.rs::pr1_crear_con_oferta_guarda_el_vinculo_y_lo_muestra`,
  `pr1_las_preguntas_siguientes_salen_de_los_requisitos_obligatorios`, `pr5_practicar_gasta_la_cuota_y_respeta_la_sesion_activa`;
  `tests/interview_offer_engine.rs`; web `tests/practice-offer.test.tsx`, `tests/interview-room.test.tsx`
  («si la sesión está vinculada a una oferta, dice «Practicando: título»…»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-OFE-08 — Practicar no es aplicar
- **Pasos:** practicar una oferta confidencial; después, como reclutadora, mirar el panel de esa oferta.
- **Resultado esperado:** la empresa **no ve nada**: no se crea ninguna aplicación; la persona puede aplicar
  después como si nada. En una confidencial, ni la sesión ni las preguntas nombran a la empresa. Si la oferta
  se cierra, la sesión se conserva; si se borra, sigue sin vínculo.
- **Automatizada:** core-api `tests/interview_offer_practice.rs::pr3_practicar_no_es_aplicar_ni_la_ve_la_empresa`,
  `pr2_una_oferta_confidencial_no_revela_la_empresa`, `cerrar_la_oferta_conserva_la_sesion_y_su_vinculo`;
  web `tests/practice-offer.test.tsx` («el texto de ayuda menciona que es práctica: no aplica a la oferta»).
- **Estado:** probado solo por pruebas automáticas.

#### CP-OFE-09 — Una oferta que no está visible da 404
- **Pasos:** con la reclutadora, pausar una oferta; con Camila, abrir su enlace del detalle.
- **Resultado esperado:** «la oferta ya no está disponible», sin reintento y con un enlace a otras ofertas.
  Por API es el **mismo 404** para borrador, pausada, cerrada, vencida, de empresa sin verificar, ajena o con
  id mal formado.
- **Automatizada:** core-api `tests/offers_public.rs::ca5_lo_no_visible_da_el_mismo_404`,
  `ca1_quitar_la_verificacion_o_la_vigencia_oculta_de_inmediato`; web `tests/offer-detail.test.tsx` («404: la
  oferta ya no está disponible…»).
- **Estado:** probado solo por pruebas automáticas.

#### CP-OFE-10 — «Cargar más» sin repetir
- **Pasos:** con más de 20 ofertas, «Cargar más».
- **Resultado esperado:** añade las siguientes sin repetir; el foco pasa a la primera tarjeta nueva; si falla,
  conserva lo visto. El cursor solo sirve para el orden con el que se emitió.
- **Automatizada:** core-api `tests/offers_public.rs::paginar_con_cursor_recorre_todo_sin_repetir`,
  `tests/matching.rs::el_cursor_de_match_no_sirve_en_otro_orden_ni_al_reves`; web `tests/offers-paging.test.tsx`.
- **Estado:** probado solo por pruebas automáticas. **Poco útil en la demo** (hay pocas ofertas).

#### CP-OFE-11 — El texto de una oferta es texto, no HTML
- **Pasos:** como reclutadora, crear una oferta con `<b>negrita</b>` y `<script>alert(1)</script>` en la
  descripción; como Camila, abrirla.
- **Resultado esperado:** se ve el texto literal; no se inyecta ningún `script`.
- **Automatizada:** core-api `tests/offers_public.rs::el_texto_de_la_oferta_viaja_tal_cual`; web
  `tests/offer-detail.test.tsx` («SX7: descripción, título, horario y habilidades con HTML se pintan como
  texto»).
- **Estado:** probado en navegador (2026-11-11, recorrido de la Fase 5a: el `<script>` salió como texto).

### Aplicar con consentimiento

#### CP-APL-01 — El diálogo de consentimiento
- **Pasos:** en el detalle de una oferta, «Aplicar».
- **Resultado esperado:** el primer clic **no** aplica: abre un diálogo «Aplicar a esta oferta» que dice
  «Esto es lo que verá la empresa» y lista **cada** campo con su casilla. Marcados y **bloqueados**: nombre
  (con la inicial del apellido), habilidades y experiencia («Siempre se comparte»). Sin marcar: lo que
  hiciste en cada experiencia, idiomas, nivel académico, descripción, **correo**, **teléfono** y «Compartir
  mi afinidad con esta oferta». Lo que no tienes sale como «No tienes teléfono en tu perfil». «Enviar» está
  **deshabilitado** hasta marcar «Acepto compartir esto». Avisa que no se puede ampliar ni reaplicar, que se
  ve en vivo, y que **nunca** ve el CV, dirección, documento, fecha de nacimiento ni prácticas.
- **Automatizada:** web `tests/offer-detail.test.tsx` («el primer clic no aplica…», «lista CADA campo del
  conjunto cerrado con su casilla…», «avisa que no se puede ampliar ni reaplicar…»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-APL-02 — Aplicar con lo mínimo
- **Pasos:** en el diálogo, dejar solo los tres bloqueados → marcar «Acepto compartir esto» → «Enviar mi
  aplicación».
- **Resultado esperado:** la aplicación queda «Enviada» en «Mis aplicaciones». API: `POST
  /offers/{id}/applications` con `{consent: true, shared_fields: [...]}` → 201, con su evento
  `null → applied`. No se envía correo ni se avisa a nadie.
- **Automatizada:** core-api `tests/applications.rs::aplicar_con_consentimiento_crea_aplicacion_y_evento`;
  web `tests/offer-detail.test.tsx`.
- **Estado:** probado en navegador (2026-11-11).

#### CP-APL-03 — Sin consentimiento no hay aplicación
- **Pasos (API):** `POST <API>/api/v1/offers/<OFERTA_ID>/applications` con `{"shared_fields":["display_name","skills","experience"]}`
  (sin `consent`), y otra vez con `"consent":"true"` (texto).
- **Resultado esperado:** 422 `consentimiento_requerido` en ambos y **no se crea nada**. Faltan los
  obligatorios o hay un nombre ajeno al conjunto: 422 `datos_invalidos`.
- **Automatizada:** core-api `tests/applications.rs::sin_consentimiento_422_y_no_crea_nada`,
  `shared_fields_invalidos_422`, `consented_at_no_lo_manda_el_cliente`.
- **Estado:** probado solo por pruebas automáticas.

#### CP-APL-04 — Qué campos se comparten: correo y afinidad opcionales
- **Pasos:** aplicar a una oferta marcando **correo** y «Compartir mi afinidad»; aplicar a otra sin
  marcarlos. Como reclutadora, abrir el detalle de cada una (CP-EMP-14).
- **Resultado esperado:** el correo y la afinidad (calculada **solo con lo que marcaste**) aparecen en el
  panel únicamente si se marcaron; lo no marcado **no existe** en la respuesta (la clave no viene, no es
  `null`). Sin compartirla, ningún dato de matching llega a la empresa.
- **Automatizada:** core-api `tests/applications.rs::cada_campo_opcional_va_solo_si_se_marco`,
  `lo_compartido_es_solo_lo_consentido`; `tests/matching.rs::ma9_el_reclutador_ve_un_puntaje_hecho_solo_con_lo_consentido`,
  `ma9_sin_compartirlo_ningun_dato_de_matching_llega_al_reclutador`; web `tests/recruiter-panel.test.tsx`.
- **Estado:** probado en navegador (2026-11-11).

#### CP-APL-05 — No se puede aplicar dos veces
- **Pasos:** volver a abrir la oferta a la que ya aplicaste; también tras retirar o ser rechazada.
- **Resultado esperado:** no hay «Aplicar»: dice el estado y enlaza a «Mis aplicaciones». Por API, 409
  `ya_aplicaste` (incluso tras retirar o ser rechazada); dos simultáneas dejan **una**. Reaplicar tras retirar
  no existe. Una oferta de tu propia empresa: 409 `oferta_propia`.
- **Automatizada:** core-api `tests/applications.rs::ya_aplicaste_incluso_tras_retirar_o_ser_rechazada`,
  `dos_simultaneas_dejan_una`, `oferta_propia_409_y_ajena_si`; web `tests/offer-detail.test.tsx` («si ya
  apliqué: no hay «Aplicar», dice el estado…»).
- **Estado:** probado solo por pruebas automáticas.

#### CP-APL-06 — Aplicar a una confidencial
- **Pasos:** aplicar a «Analista de datos».
- **Resultado esperado:** el diálogo avisa «no sabrás qué empresa es hasta que te preseleccionen». En «Mis
  aplicaciones» dice «Empresa confidencial» hasta que la reclutadora la pase a «Preseleccionada»
  (CP-EMP-17).
- **Automatizada:** core-api `tests/applications.rs::la_empresa_confidencial_se_revela_solo_al_shortlisted_y_por_aplicacion`;
  web `tests/applications-view.test.tsx` («AP9: una confidencial sin revelar dice «Empresa confidencial»…»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-APL-07 — Mis aplicaciones
- **Pasos:** `<WEB>/applications`; «Ver detalle» en una aplicación.
- **Resultado esperado:** una tarjeta por aplicación con la oferta, la empresa, el lugar, el estado
  (nombres en español) y la fecha; el detalle trae el **historial** y **lo que compartí**. Nunca muestra el
  motivo, la nota interna ni quién decidió. Un enlace de oferta que ya no está publicada no enlaza.
- **Automatizada:** core-api `tests/applications.rs::mis_aplicaciones_solo_las_mias_paginadas`,
  `el_historial_de_la_persona_no_trae_nota_ni_quien_decidio`; web `tests/applications-view.test.tsx`
  («AP7: nunca muestra el motivo, la nota interna ni quién decidió…»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-APL-08 — Retirar una aplicación
- **Pasos:** en «Mis aplicaciones» → «Retirar aplicación» → leer el diálogo → confirmar.
- **Resultado esperado:** el primer clic no retira; el diálogo dice que es **definitivo** y que la empresa
  deja de ver lo compartido. Pasa a «Retirada». Solo se ofrece desde enviada, en revisión o preseleccionada.
  API: `POST /me/applications/{id}/withdraw` → 204, idempotente.
- **Automatizada:** core-api `tests/applications.rs::retirar_idempotente_y_no_desde_finales`,
  `al_retirar_deja_de_verse_lo_compartido`; web `tests/applications-view.test.tsx` («AP8: confirmar retira una
  sola vez…», «solo se ofrece desde applied, under_review o shortlisted»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-APL-09 — Lo compartido se ve en vivo y no se amplía
- **Pasos:** con el teléfono compartido, borrar el teléfono del perfil de Camila; como reclutadora, recargar
  el detalle. Intentar compartir más después de aplicar.
- **Resultado esperado:** el panel lee el perfil **actual** filtrado por los nombres compartidos: deja de
  verse el teléfono. **No hay ruta para ampliar** lo compartido: hay que retirar, y no se puede reaplicar.
- **Automatizada:** core-api `tests/applications.rs::lo_compartido_se_ve_en_vivo`,
  `no_hay_ruta_para_ampliar_lo_compartido`.
- **Estado:** probado solo por pruebas automáticas.

#### CP-APL-10 — Aplicaciones externas (registro privado)
- **Pasos:** `<WEB>/applications` → pestaña «Externas» → crear, editar y borrar un registro (empresa, puesto,
  fecha, estado, notas).
- **Resultado esperado:** dice que es **privado**; ninguna empresa lo ve; las notas se guardan cifradas;
  máximo 200 por persona; borrar pide confirmación.
- **Automatizada:** core-api `tests/external_applications.rs` (`crear_leer_actualizar_y_borrar`,
  `las_notas_se_guardan_cifradas`, `maximo_200_por_persona`); web `tests/external-applications.test.tsx`.
- **Estado:** probado solo por pruebas automáticas.

#### CP-APL-11 — Límite de aplicaciones
- **Pasos (API):** 21 aplicaciones nuevas en 24 horas.
- **Resultado esperado:** la 21 recibe 429 `demasiados_intentos` con `Retry-After`; los 409 no cuentan.
- **Automatizada:** core-api `tests/applications.rs::veinte_por_dia_y_la_21_es_429`,
  `los_409_no_cuentan_y_ganan_al_429`.
- **Estado:** probado solo por pruebas automáticas.

### Lado empresa

#### CP-EMP-01 — Registrar una empresa
- **Precondiciones:** sesión de la reclutadora (cuenta común).
- **Pasos:** `/dashboard` → «Registrar mi empresa» → `/company` → nombre, NIT ficticio, sitio `https://…`,
  país, sector → «Registrar empresa».
- **Resultado esperado:** la empresa queda **«En verificación»** con el aviso de qué hacer; quien la crea
  pasa a ser `company_admin`. El NIT se guarda cifrado con un HMAC para detectar duplicados; un NIT repetido
  (aunque cambie el formato) es 409 `empresa_duplicada`; una persona, una empresa (409 `ya_tiene_empresa`).
- **Automatizada:** core-api `tests/companies.rs::em1_crear_la_empresa_la_deja_sin_verificar_y_hace_admin_a_quien_la_crea`,
  `el_nit_se_guarda_cifrado_y_con_hmac`, `em3_un_nit_repetido_es_409_aunque_cambie_el_formato`; web
  `tests/company-view.test.tsx` («crear: envía una vez solo CompanyInput… y muestra «En verificación»…»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-EMP-02 — Sin verificar no se publica
- **Pasos:** con la empresa «En verificación», `/company/offers` → «Crear oferta» → completar un borrador.
- **Resultado esperado:** los borradores se crean y se editan, pero «Publicar» queda deshabilitado con el
  motivo (empresa sin verificar). Por API, 403 `empresa_no_verificada`. Lo mismo con la membresía vencida
  (403 `membresia_vencida`).
- **Automatizada:** core-api `tests/offers.rs::una_empresa_sin_verificar_no_publica`,
  `una_membresia_vencida_no_publica`; web `tests/offer-editor.test.tsx` (««Publicar» deshabilitado con el
  motivo: empresa sin verificar o membresía vencida (FC8)»), `tests/company-offers.test.tsx`.
- **Estado:** probado en navegador (2026-11-11).

#### CP-EMP-03 — La admin de plataforma verifica la empresa
- **Precondiciones:** la cuenta admin con el rol dado por SQL («Antes de presentar»).
- **Pasos:** sesión de la admin → `/admin/companies` (cola de «no verificadas») → en la empresa A, «Verificar».
- **Resultado esperado:** la lista trae NIT, sitio, **dominio** del correo de quien la creó (para contrastarlo
  con el sitio) y número de reclutadores, nunca el correo completo. «Verificar» sale de la cola y lo anuncia;
  es idempotente. La admin no puede verificar una empresa de la que es miembro (403). «Quitar verificación»
  pide confirmación y oculta las ofertas publicadas.
- **Automatizada:** core-api `tests/company_verification.rs::solo_el_admin_de_plataforma_entra_y_no_lee_nada_mas`,
  `verificar_es_idempotente_audita_una_vez_y_no_mueve_la_fecha`,
  `un_admin_de_plataforma_no_verifica_la_empresa_de_la_que_es_miembro`; web `tests/admin-companies.test.tsx`.
- **Estado:** probado en navegador (2026-11-11).

#### CP-EMP-04 — La admin asigna la membresía
- **Pasos:** en `/admin/companies`, empresa A → «Membresía» → inicio hoy, fin dentro de unos meses →
  «Guardar membresía».
- **Resultado esperado:** «Guardamos la membresía.»; la empresa ya puede publicar. La membresía nueva
  reemplaza a la vigente; el fin no puede ser anterior al inicio ni pasar de 400 días. No hay cobro.
- **Automatizada:** core-api `tests/company_verification.rs::la_membresia_se_crea_se_audita_y_reemplaza_a_la_vigente`,
  `la_membresia_valida_el_cuerpo`; web `tests/admin-companies.test.tsx` («guarda con PUT {membership_type:
  business, start_date, expiration_date}», «fechas fuera de rango no se envían y se explica por qué»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-EMP-05 — Crear una oferta (borrador)
- **Pasos:** reclutadora → `/company/offers/new` → título (obligatorio), descripción, vacantes,
  profesión, departamento y municipio, requisitos (habilidades obligatorias/deseables, idiomas) → guardar.
- **Resultado esperado:** queda en **borrador**; con solo el título basta para guardar. El municipio se
  habilita al elegir el departamento. **No hay** campos de edad, género ni estado civil (la API los rechaza
  con 422 `campo_no_permitido`).
- **Automatizada:** core-api `tests/offers.rs::of1_crear_una_oferta_en_draft`,
  `solo_el_titulo_es_obligatorio_al_crear`, `of4_campos_discriminatorios_y_de_plataforma_dan_422`; web
  `tests/offer-editor.test.tsx` («el formulario se envía por POST y no hay campos de edad, género ni estado
  civil (OF4)»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-EMP-06 — Publicar (y lo que falta)
- **Pasos:** con la empresa verificada y con membresía, abrir un borrador incompleto → «Publicar».
- **Resultado esperado:** el botón explica qué falta («Para publicar falta: el municipio» / las vacantes…).
  Mínimo: título, descripción, vacantes, profesión, departamento, municipio y **al menos un requisito**.
  Completo, publica una vez y queda **publicada** (la primera publicación fija `publication_date`).
- **Automatizada:** core-api `tests/offers.rs::of5_publicar_valida_lo_minimo`,
  `una_fecha_de_contratacion_pasada_no_deja_publicar`; web `tests/offer-editor.test.tsx` (««Publicar»
  deshabilitado con el motivo: faltan datos», «un borrador completo de una empresa vigente se publica una vez
  y queda publicado»).
- **Estado:** probado en navegador (2026-11-11: «falta el municipio» y publicación).

#### CP-EMP-07 — Oferta confidencial
- **Pasos:** crear una oferta con «confidencial» marcado → publicar → intentar desmarcarla.
- **Resultado esperado:** el formulario avisa «No pongas el nombre de tu empresa en el texto»; los
  candidatos la ven sin empresa (CP-OFE-06); tras publicar, «confidencial» **queda fija** (409
  `confidencial_inmutable`). El servidor **no** puede detectar un nombre de empresa escrito en la descripción.
- **Automatizada:** core-api `tests/offers.rs::la_confidencialidad_se_congela_al_publicar`; web
  `tests/offer-editor.test.tsx` («confidencial: aparece el aviso fijo…», ««confidencial» queda fijo desde la
  primera publicación»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-EMP-08 — Pausar y reanudar una oferta
- **Pasos:** oferta publicada → «Pausar» → comprobar que Camila ya no la ve → «Publicar» otra vez.
- **Resultado esperado:** pausada sale del listado y deja de aceptar aplicaciones (las existentes
  siguen). `published ⇄ paused`; repetir la misma transición es 409 `estado_invalido`.
- **Automatizada:** core-api `tests/offers.rs::of6_transiciones_validas`, `of6_transiciones_invalidas_son_409_y_no_cambian_nada`;
  web `tests/offer-editor.test.tsx` («pausar una publicada; cerrar pide confirmación porque es definitivo»).
- **Estado:** probado solo por pruebas automáticas.

#### CP-EMP-09 — Cerrar una oferta
- **Pasos:** oferta publicada o pausada → «Cerrar oferta» → confirmar.
- **Resultado esperado:** pide confirmación porque es **definitivo**; queda cerrada y de solo lectura (no se
  edita, borra ni republica); sus aplicaciones siguen en el panel hasta 90 días después. Una tarea cierra sola
  las ofertas cuya fecha de contratación ya pasó.
- **Automatizada:** core-api `tests/offers.rs::una_pausada_se_puede_cerrar`, `una_cerrada_no_se_edita_ni_se_borra`,
  `of9_el_cierre_automatico_usa_el_reloj_inyectado`; web `tests/offer-editor.test.tsx` («una oferta cerrada no
  se edita: todo de solo lectura y lo dice»).
- **Estado:** probado solo por pruebas automáticas. **Ojo:** cerrar una **oferta** existe; **cerrar la
  empresa** no (ver «Límites y bugs conocidos»).

#### CP-EMP-10 — Editar una oferta que ya recibió aplicaciones
- **Pasos:** oferta publicada con una aplicación → editar el título.
- **Resultado esperado:** solo descripción, horario, vacantes y fecha de contratación siguen editables; lo
  demás sale de solo lectura. Por API, 409 `oferta_con_aplicaciones`. Para cambiar requisitos se cierra y se
  crea otra.
- **Automatizada:** core-api `tests/offers.rs::of7_con_aplicaciones_solo_se_editan_cuatro_campos`; web
  `tests/offer-editor.test.tsx` («OF7: con aplicaciones, solo descripción, horario, vacantes y fecha siguen
  editables…»).
- **Estado:** probado solo por pruebas automáticas.

#### CP-EMP-11 — Invitar a un reclutador
- **Pasos:** reclutadora (`company_admin`) → `/company` → «Invitar a alguien» → correo del invitado y rol →
  «Crear invitación» → «Copiar» el código. Como el invitado (cuenta nueva): `/company` → pegar el código.
- **Resultado esperado:** el código se muestra **una sola vez** (la lista nunca lo muestra); en la base solo
  queda su hash; vale 7 días, un solo uso, y **solo para ese correo**. Al aceptar, la persona entra a la
  empresa con el rol dado. No hay correo electrónico: el código se pasa a mano. 20 invitaciones al día por
  empresa; 10 intentos de aceptar por persona y hora.
- **Automatizada:** core-api `tests/company_invitations.rs::em5_la_invitacion_devuelve_el_token_una_vez_y_en_la_base_solo_queda_su_hash`,
  `aceptar_da_el_rol_de_empresa_y_gasta_la_invitacion`, `una_invitacion_invalida_es_siempre_el_mismo_404`; web
  `tests/company-view.test.tsx` («invitar: el código se muestra UNA vez, con «Copiar»…»).
- **Estado:** probado en navegador (2026-11-11: invitación y alta de una segunda persona).

#### CP-EMP-12 — Quitar a alguien del equipo
- **Pasos:** `company_admin` → `/company` → equipo → quitar al reclutador invitado → confirmar. Con la
  sesión del quitado, recargar `/company/offers`.
- **Resultado esperado:** le corta el acceso **en la petición siguiente**; la empresa, sus ofertas y el
  historial no se tocan; si la persona sigue siendo candidata, su cuenta no cambia.
- **Automatizada:** core-api `tests/companies.rs::em9_quitar_a_un_reclutador_conserva_la_empresa_y_la_cuenta`,
  `tests/route_permissions.rs::ro4_quitar_el_rol_corta_el_acceso_en_la_siguiente_peticion`; web
  `tests/company-view.test.tsx` («equipo: lista nombre y rol; quitar pide confirmación…»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-EMP-13 — El único administrador no puede irse
- **Pasos:** el único `company_admin` se quita a sí mismo, o intenta «Borrar mi cuenta».
- **Resultado esperado:** 409 `ultimo_administrador`; la pantalla de equipo lo explica con texto claro. Al
  borrar la cuenta, el diálogo (desde web #27) explica qué hacer y que **cerrar la empresa aún no es
  posible** (BUG-014, ver «Límites»).
- **Automatizada:** core-api `tests/companies.rs::em9_el_ultimo_administrador_no_se_puede_quitar_ni_salir`,
  `em9_borrar_la_cuenta_respeta_al_ultimo_administrador`; `tests/recruiter_deletion.rs::el_unico_administrador_no_se_borra`;
  web `tests/company-view.test.tsx`, `tests/delete-account.test.tsx` («BUG-014: 409 ultimo_administrador…»).
- **Estado:** probado en navegador (2026-11-11). El texto nuevo del borrado de cuenta (web #27) no.

#### CP-EMP-14 — Panel de aplicantes
- **Pasos:** `/company/offers` → en la oferta, el número de aplicaciones → `/company/offers/{id}/applications`
  → elegir a Camila.
- **Resultado esperado:** la **lista** trae solo nombre visible («Camila D.»), estado, favorito y fecha, con
  filtro por estado y favoritos y orden por fecha (nada más). El **detalle** (región lateral) trae solo lo
  compartido. Si la persona no tiene habilidades o experiencia, dice que no hay datos (BUG-008, arreglado en
  web #19).
- **Automatizada:** core-api `tests/panel.rs::pa1_la_lista_es_solo_de_mi_oferta`,
  `pa2_la_lista_solo_trae_el_nombre_visible`, `pa3_el_detalle_trae_solo_lo_compartido`; web
  `tests/recruiter-panel.test.tsx`.
- **Estado:** probado en navegador (2026-11-11). Los estados vacíos (BUG-008) y «1 año» en singular
  (BUG-010) están arreglados, sin verlos en navegador.

#### CP-EMP-15 — Cambiar el estado de una aplicación
- **Pasos:** en el detalle, mover «Enviada» → «En revisión» (con una nota) → «Preseleccionada» →
  «Contratada». En otra aplicación, «En revisión» → «Rechazada».
- **Resultado esperado:** cada cambio abre un diálogo con una **nota interna** (hasta 500 caracteres) y
  confirmar envía una vez; el historial anota el cambio. Solo se ofrecen las transiciones válidas.
- **Automatizada:** core-api `tests/panel.rs::pa4_cambiar_de_estado_respeta_la_maquina`,
  `la_nota_se_guarda_cifrada_y_solo_la_ve_el_panel`; web `tests/recruiter-panel.test.tsx` («solo ofrece las
  transiciones de la máquina; confirmar envía una vez {to, note}…», «una nota de más de 500 caracteres no se
  envía…»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-EMP-16 — Las reglas de la máquina de estados
- **Pasos (API):** intentar `applied → shortlisted`, `rejected → hired`, repetir el mismo estado, o mover una
  aplicación retirada.
- **Resultado esperado:** 409 `estado_invalido` con el estado vigente y **sin tocar nada**. Camino:
  `applied → under_review → shortlisted → hired`; `rejected` desde `under_review` o `shortlisted`;
  `withdrawn` solo la persona. `hired`, `rejected` y `withdrawn` son **finales**. Contratar no cierra la
  oferta ni descuenta vacantes. Dos movimientos simultáneos dejan uno.
- **Automatizada:** core-api `tests/applications.rs::move_status_respeta_la_maquina_y_el_alcance`,
  `dos_movimientos_simultaneos_dejan_uno`; `tests/panel.rs::pa4_cambiar_de_estado_respeta_la_maquina`; web
  `tests/recruiter-panel.test.tsx` («409 estado_invalido: lo explica y muestra el estado vigente»).
- **Estado:** probado solo por pruebas automáticas (el recorrido hizo el camino feliz y un rechazo).

#### CP-EMP-17 — Preseleccionar revela la empresa confidencial
- **Pasos:** con una aplicación a la confidencial, la reclutadora la pasa a «Preseleccionada»; después Camila
  abre «Mis aplicaciones».
- **Resultado esperado:** el diálogo **avisa antes** que revela la empresa; desde entonces Camila ve el
  nombre de la empresa **solo en su aplicación** (el listado público y los demás siguen sin verlo). No se
  esconde otra vez aunque pase a rechazada.
- **Automatizada:** core-api `tests/panel.rs::preseleccionar_una_confidencial_revela_la_empresa`,
  `tests/applications.rs::la_empresa_confidencial_se_revela_solo_al_shortlisted_y_por_aplicacion`; web
  `tests/recruiter-panel.test.tsx` («mover a preseleccionada en una oferta confidencial avisa ANTES que revela
  la empresa»).
- **Estado:** probado en navegador (2026-11-11: dice «Empresa confidencial» hasta la preselección).

#### CP-EMP-18 — Favoritos
- **Pasos:** en el detalle, «Favorita»; recargar; desmarcar.
- **Resultado esperado:** marcar y desmarcar (`aria-pressed`); el favorito es **por empresa y persona**, lo
  ven todos los reclutadores de esa empresa y desaparece al retirar la aplicación (si no queda otra viva).
  No se puede marcar una aplicación anónima o retirada.
- **Automatizada:** core-api `tests/panel.rs::pa6_pa7_favoritos_por_empresa_y_persona`,
  `retirar_borra_el_favorito_si_no_queda_otra_viva`; web `tests/recruiter-panel.test.tsx` («favorito: PUT al
  marcar, DELETE al desmarcar, con aria-pressed»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-EMP-19 — Auditoría de accesos
- **Pasos:** tras CP-EMP-14 a 15, en la base: `SELECT action, resource_type, created_at FROM access_audit
  ORDER BY created_at DESC LIMIT 10;`.
- **Resultado esperado:** una fila por acceso (`application.list`, `application.view`, `application.review`,
  `company.verify`, `company.membership_set`…), **sin el contenido** y con la IP hasheada. Si falla la
  auditoría, la acción falla: no hay acción sin rastro. Un reclutador lee como máximo 120 detalles por hora.
- **Automatizada:** core-api `tests/panel.rs::pa8_cada_acceso_deja_su_fila_de_auditoria`,
  `sin_auditoria_no_hay_dato`, `ciento_veinte_detalles_por_hora`; `tests/company_verification.rs::si_la_auditoria_falla_la_accion_falla_y_no_queda_cambiada`.
- **Estado:** probado en navegador (2026-11-11, recorrido de la Fase 5a: auditoría `application.list`,
  `application.view`, `application.review`).

#### CP-EMP-20 — La nota interna es interna
- **Pasos:** mover una aplicación con la nota «Buen perfil, falta inglés»; como Camila, abrir el historial de
  su aplicación.
- **Resultado esperado:** la nota aparece en el panel y **no** en la vista de Camila (sin nota, sin quién
  decidió, sin favorito). En la base la nota está cifrada.
- **Automatizada:** core-api `tests/panel.rs::la_nota_se_guarda_cifrada_y_solo_la_ve_el_panel`,
  `tests/applications.rs::el_historial_de_la_persona_no_trae_nota_ni_quien_decidio`; web
  `tests/applications-view.test.tsx` («AP7…»).
- **Estado:** probado en navegador (2026-11-11, recorrido de la Fase 5a).

#### CP-EMP-21 — Editar los datos de la empresa
- **Pasos:** `company_admin` → `/company` → editar descripción y teléfono → guardar; intentar cambiar el NIT
  de una empresa verificada.
- **Resultado esperado:** guarda con un `PUT` completo; el NIT de una verificada es inmutable (409
  `nit_inmutable`, explicado). Un reclutador que no es administrador no ve «editar», ni el equipo, ni las
  invitaciones.
- **Automatizada:** core-api `tests/companies.rs::put_company_reemplaza_es_idempotente_y_exige_el_permiso`,
  `el_nit_de_una_empresa_verificada_es_inmutable_y_el_de_una_no_verificada_no_puede_chocar`; web
  `tests/company-view.test.tsx` («editar: PUT con CompanyInput completo; 409 nit_inmutable se explica», «un
  reclutador (no admin) no ve editar, el equipo ni las invitaciones»).
- **Estado:** probado solo por pruebas automáticas.

### Privacidad y seguridad

#### CP-PRI-01 — La reclutadora solo ve lo que Camila consintió
- **Pasos:** Camila aplica marcando solo los tres obligatorios; la reclutadora abre el detalle.
- **Resultado esperado:** ve nombre con inicial, habilidades y experiencia (sin la descripción de lo que
  hizo). **No ve** teléfono, correo, descripción profesional, nivel académico ni afinidad. Lo no marcado no
  viaja (la clave no existe).
- **Automatizada:** core-api `tests/applications.rs::lo_compartido_es_solo_lo_consentido`,
  `tests/panel.rs::pa3_el_detalle_trae_solo_lo_compartido`; web `tests/recruiter-panel.test.tsx` («solo lo
  compartido: sin contacto si no se compartió…»).
- **Estado:** probado en navegador (2026-11-11).

#### CP-PRI-02 — Lo que jamás se comparte, marque lo que marque
- **Pasos:** Camila aplica con **todas** las casillas marcadas; la reclutadora mira detalle y respuesta de
  la API (`GET /company/applications/{id}`).
- **Resultado esperado:** nunca llegan el archivo del CV (no hay ruta ni URL), dirección, documento, fecha
  de nacimiento o edad, género, estado civil, foto, transcripciones ni resultados de entrevista, el plan ni
  el id permanente de la persona.
- **Automatizada:** core-api `tests/applications.rs::con_todo_marcado_jamas_sale_lo_prohibido`.
- **Estado:** probado en navegador (2026-11-11, «sin teléfono, descripción, nivel académico ni «lo que
  hiciste»» cuando no se marcaron). Con **todo** marcado, solo pruebas automáticas.

#### CP-PRI-03 — Otra empresa recibe 404
- **Pasos:** sesión de la reclutadora de la empresa B; con el `id` de una aplicación u oferta de la
  empresa A, por API: `GET /company/applications/<APLICACION_A>`, `POST /company/applications/<APLICACION_A>/status` y
  `PUT /company/applications/<APLICACION_A>/favorite`, y `GET /company/offers/<OFERTA_A>`.
- **Resultado esperado:** **404 `no_encontrado`**, idéntico a «no existe» y a «id mal formado»: no revela
  que el recurso existe. Una persona con el permiso pero sin empresa también recibe 404.
- **Automatizada:** core-api `tests/panel.rs::la_aplicacion_ajena_es_404_en_todas_las_rutas`,
  `tests/offers.rs::of8_la_oferta_de_otra_empresa_es_404_identico_al_inexistente`,
  `tests/companies.rs::sx6_lo_ajeno_inexistente_y_mal_formado_es_el_mismo_404`; web
  `tests/recruiter-panel.test.tsx` («404: la oferta no es de tu empresa o no existe»).
- **Estado:** probado en navegador (2026-11-11): «otra empresa recibe 404 al leer, mover o marcar favorita».

#### CP-PRI-04 — Lo ajeno de un candidato también es 404
- **Pasos (API):** con el token de la candidata sin perfil, pedir `GET /cvs/<CV_DE_CAMILA>/file`,
  `GET /interviews/<SESION_DE_CAMILA>` y `GET /me/applications/<APLICACION_DE_CAMILA>`.
- **Resultado esperado:** 404 en los tres, nunca 403 ni el dato; sin token, 401.
- **Automatizada:** core-api `tests/cvs.rs::l3_el_cv_ajeno_es_404_siempre`,
  `tests/interview_sessions.rs::x1_la_sesion_ajena_es_404_identico_al_inexistente`,
  `tests/applications.rs::la_aplicacion_ajena_es_404_para_leer_y_retirar`, `tests/profile.rs::p8_el_perfil_de_otro_no_se_lee_ni_se_modifica`.
- **Estado:** probado solo por pruebas automáticas.

#### CP-PRI-05 — Una aplicación retirada desaparece del panel
- **Pasos:** Camila retira su aplicación (CP-APL-08); la reclutadora recarga la lista y el detalle.
- **Resultado esperado:** la fila sigue (estado e historial), pero dice «retirada», sin datos de la persona,
  sin favorito y sin acciones (`applicant: null`). Lo mismo a los 90 días de cerrar la oferta («retención
  vencida») y al borrar la cuenta («candidato eliminado»).
- **Automatizada:** core-api `tests/applications.rs::al_retirar_deja_de_verse_lo_compartido`,
  `retencion_de_90_dias_desde_el_cierre`; `tests/panel.rs::retirada_y_retencion_vencida_no_muestran_datos`;
  web `tests/recruiter-panel.test.tsx` («PA10: «candidato eliminado», «retirada» o «retención vencida», sin
  datos ni acciones»).
- **Estado:** probado en navegador (2026-11-11: tras retirar, `applicant: null` y sin favorito).

#### CP-PRI-06 — Las transcripciones y las notas se guardan cifradas
- **Pasos:** tras una entrevista, en la base: `SELECT transcript FROM interview_turns LIMIT 3;` y
  `SELECT note FROM job_application_events WHERE note IS NOT NULL LIMIT 3;`.
- **Resultado esperado:** bytes ilegibles (`bytea` con AES), no texto. La API sí las devuelve descifradas al
  dueño. Cifrar el mismo texto dos veces da resultados distintos; con otra clave o con un byte alterado,
  falla.
- **Automatizada:** core-api `tests/interview_sessions.rs::s1b_el_texto_del_turno_se_guarda_cifrado`,
  `tests/interview_schema.rs::e7_la_transcripcion_no_queda_en_claro`, `tests/crypto.rs::cifrar_dos_veces_da_resultados_distintos`,
  `tests/panel.rs::la_nota_se_guarda_cifrada_y_solo_la_ve_el_panel`.
- **Estado:** probado en navegador (2026-11-11) solo para la nota («la nota guardada cifrada», recorrido de
  la Fase 5a). La transcripción, solo por pruebas automáticas.

#### CP-PRI-07 — Ningún dato personal en los registros
- **Pasos:** tras la demo, `docker compose logs core-api | grep -i -E 'camila|reclutadora|jobout-prueba|Hice una app'`.
- **Resultado esperado:** **0 coincidencias**: ni correos, ni nombres, ni empresas, ni el texto de las
  respuestas, ni el de una oferta. Los errores tampoco los llevan.
- **Automatizada:** core-api `tests/auth.rs::s4_el_log_no_contiene_datos_sensibles`,
  `tests/cvs.rs::l10_nada_sensible_aparece_en_el_log_ni_en_los_errores`,
  `tests/interview_turns.rs::t11_el_texto_no_sale_en_logs_ni_en_errores`,
  `tests/applications.rs::nada_de_lo_compartido_llega_al_log`, `tests/panel.rs::nada_del_panel_llega_al_log`,
  `tests/companies.rs::el_log_y_los_errores_no_llevan_nit_nombre_ni_correo`, `tests/telemetry.rs`.
- **Estado:** probado en navegador (2026-11-11): «en los registros del core-api no aparece ningún correo,
  nombre, empresa ni texto de respuestas»; y 2026-11-10 con las frases de las respuestas.

#### CP-PRI-08 — Borrar la cuenta de una candidata: qué se va y qué queda anonimizado
- **Pasos:** Camila (con CV, entrevista y una aplicación) → `/dashboard` → «Borrar mi cuenta» → leer el
  diálogo → contraseña → confirmar. Después, en la base:
  `SELECT count(*) FROM users;`, `applicants`, `personal_data`, `cvs`, `interview_sessions`,
  `SELECT applicant_id, shared_fields FROM job_applications;`.
- **Resultado esperado:** 204. **Se borran**: la cuenta, el perfil, los CVs (y sus archivos), las
  entrevistas con transcripciones y scores, los favoritos de las empresas y los registros externos. **Queda
  anonimizado**: la aplicación sigue en el panel como «candidato eliminado» con estado e historial,
  `applicant_id` nulo y `shared_fields` `[]`; el `usage_ledger` conserva el costo **sin** el id; queda **una**
  fila en `privacy_events` (`account_deleted`) sin nombre, correo ni id. El token y el login dejan de servir
  y el mismo correo se puede registrar otra vez.
- **Automatizada:** core-api `tests/me.rs::b1_delete_borra_la_cuenta_y_sus_datos`,
  `tests/applications.rs::borrar_la_cuenta_deja_la_aplicacion_anonima`, `tests/applications_schema.rs::borrar_al_usuario_anonimiza_en_la_base`,
  `tests/account_deletion_files.rs::b1_delete_borra_los_archivos_del_candidato`,
  `tests/account_deletion_interviews.rs::b3_el_ledger_conserva_el_costo_sin_el_id_de_la_persona`; web
  `tests/delete-account.test.tsx`.
- **Estado:** probado en navegador (2026-11-11 y 2026-11-10). El diálogo dice «Tu perfil y tus datos
  personales» y «Tu historial de prácticas» pero **no** que las aplicaciones quedan sin tu nombre (BUG-015);
  web #27 lo agregó, sin verlo en navegador.

#### CP-PRI-09 — Borrar la cuenta de un reclutador
- **Pasos:** la reclutadora invitada (que **no** es el único administrador) → «Borrar mi cuenta».
- **Resultado esperado:** 204; sus decisiones y ofertas **quedan sin autor** (`changed_by` y `created_by`
  nulos), las notas internas siguen cifradas, y su pertenencia y roles se borran. El único `company_admin`
  recibe 409 `ultimo_administrador` y no se borra nada (CP-EMP-13).
- **Automatizada:** core-api `tests/recruiter_deletion.rs::bo3_las_decisiones_del_reclutador_quedan_anonimas`,
  `bo3_un_administrador_que_no_es_el_unico_se_va_sin_dejar_su_id`, `tests/authorship_schema.rs`.
- **Estado:** probado en navegador (2026-11-11: `DELETE /me` 204 para candidata y reclutador con la base
  migrada).

#### CP-PRI-10 — Límites de tasa
- **Pasos (API, uno por uno; ninguno con las cuentas de la demo):**
  | Qué | Límite | Respuesta |
  |---|---|---|
  | Login fallido | 5 en 15 min por correo | 429 `demasiados_intentos` |
  | Turnos de entrevista | 20 por minuto por persona | 429 con `Retry-After` |
  | Aplicaciones | 20 por persona en 24 h | 429 |
  | Empresas creadas | 5 por persona y día | 429 |
  | Ofertas creadas | 20 por empresa y hora | 429 |
  | Invitaciones | 20 por empresa y día (50 pendientes) | 429 / 422 |
  | Aceptar invitaciones | 10 por persona y hora | 429 |
  | Detalles del panel | 120 por reclutador y hora | 429 |
  | Cuerpo de la petición | 8 KB (16 KB y 64 KB en empresas y ofertas; 6 MiB en `POST /cvs`) | 413 |
- **Resultado esperado:** el 429 lleva `Retry-After` en segundos; la UI dice cuánto esperar sin perder lo
  escrito. Los contadores salen de filas de la base, no de la memoria del proceso.
- **Automatizada:** core-api `tests/login_attempts.rs`, `tests/interview_turns.rs::t10_mas_de_20_turnos_por_minuto_dan_429`,
  `tests/applications.rs::veinte_por_dia_y_la_21_es_429`, `tests/companies.rs::crear_empresas_esta_limitado_a_5_por_persona_y_dia`,
  `tests/offers.rs::sx5_veinte_ofertas_por_empresa_y_hora`, `tests/company_invitations.rs::aceptar_esta_limitado_a_10_intentos_por_persona_y_hora_acierte_o_no`,
  `tests/panel.rs::ciento_veinte_detalles_por_hora`, `tests/route_table.rs::t8_el_tope_de_cuerpo_es_global`.
- **Estado:** probado solo por pruebas automáticas.

#### CP-PRI-11 — Sin token, 401; una cuenta suspendida, 403
- **Pasos (API):** cualquier ruta protegida sin `authorization`, con un JWT firmado con otra clave y con un
  JWT con `alg: none`.
- **Resultado esperado:** 401 en todas; una cuenta suspendida recibe 403 `cuenta_no_disponible`. La
  protección sale de la tabla de rutas, no de que el handler se acuerde.
- **Automatizada:** core-api `tests/route_table.rs::t3_las_rutas_protegidas_exigen_token`,
  `t3b_un_jwt_de_otra_clave_no_pasa`, `tests/jwt.rs::alg_none_se_rechaza`, `tests/auth.rs::r17_usuario_suspendido_recibe_403`.
- **Estado:** probado solo por pruebas automáticas.

#### CP-PRI-12 — Sin datos del candidato guardados en el navegador
- **Pasos:** con el panel abierto, en las herramientas del navegador mirar `localStorage`, `sessionStorage`
  y la consola.
- **Resultado esperado:** vacíos. Los tokens viven en cookies `HttpOnly`. Los datos del candidato solo
  existen en el estado de la página.
- **Automatizada:** web `tests/recruiter-panel.test.tsx` («ni localStorage, ni sessionStorage, ni
  console.log al usar el panel»), `tests/cookies.test.ts`.
- **Estado:** probado en navegador (2026-11-11, recorrido de la Fase 5a: `localStorage` y `sessionStorage`
  vacíos).

### Chat de IA

> **Pendiente de PR jb-88.** El chat de IA está en desarrollo y **no hay código en `develop`** de ninguno de
> los tres repos (buscar `openrouter` no da nada; no hay PR abierto con ese nombre). Lo único que se sabe es
> la intención que dio el equipo: reformular con modelos **gratuitos de OpenRouter**, con un **respaldo
> determinista** si el modelo no responde. **No se inventa su comportamiento:** los pasos y resultados de
> estos casos se llenan al mergear el PR, y hasta entonces **no se muestra en la demo**.

#### CP-CHAT-01 — Reformulación con un modelo gratuito de OpenRouter
- **Objetivo:** pendiente de PR jb-88. Por definir al mergear: qué se reformula, dónde está en la interfaz
  y con qué modelos.
- **Precondiciones, pasos y resultado esperado:** pendiente de PR jb-88.
- **Automatizada:** solo manual (no hay código ni pruebas en `develop` hoy).
- **Estado:** no probado (pendiente de PR jb-88).

#### CP-CHAT-02 — Respaldo determinista cuando el modelo no responde
- **Objetivo:** pendiente de PR jb-88. Intención declarada: que siga habiendo una salida si el modelo
  gratuito falla o se limita.
- **Precondiciones, pasos y resultado esperado:** pendiente de PR jb-88 (cómo se simula la caída del modelo
  también está por definir).
- **Automatizada:** solo manual (no hay código ni pruebas en `develop` hoy).
- **Estado:** no probado (pendiente de PR jb-88).

#### CP-CHAT-03 — Qué sale hacia el proveedor externo
- **Objetivo:** pendiente de PR jb-88. Antes de mostrarlo, confirmar **qué texto viaja a OpenRouter** y que
  no incluye datos personales ni de empresas confidenciales: las reglas del resto de la API (nada sensible
  en logs ni errores) no cubren por sí solas un tercero nuevo.
- **Precondiciones, pasos y resultado esperado:** pendiente de PR jb-88.
- **Automatizada:** solo manual (no hay código ni pruebas en `develop` hoy).
- **Estado:** no probado (pendiente de PR jb-88).

## Límites y bugs conocidos que pueden aparecer en la demo

Dilo antes de que lo vea el público. Los de **web** marcados «arreglado en `develop`» están mergeados pero
**no se volvieron a ver en navegador**; `bugs.md` aún los lista como «sin mergear».

| Qué | Dónde se nota | Estado | Qué decir |
|---|---|---|---|
| **BUG-004** El «por qué» del score parece injusto con respuestas buenas (60–61 con cifras y situación-acción-resultado; «Relevancia 7/20») | CP-ENT-09, CP-ENT-11 | Abierto, core-api | Es el evaluador **por reglas**, sin IA. Promedia todas las respuestas (incluida la vaga) y compara raíces de 5 letras. El motor de IA (Fase 4) y la validación con Luis son lo que sigue |
| El evaluador y el recruiter son **deterministas** (banco de preguntas por reglas); sin voz y sin LLM. La Fase 4 es un borrador | Toda la entrevista | Límite de producto | «Modo texto». El avatar 3D anima por estado, no habla con voz |
| Extracción de CV limitada: dos columnas intercaladas, prosa sin encabezados y «Worked at X 2022-2024» fallan; las experiencias se midieron al 90 % **con CVs inventados** | CP-CV-03, CP-CV-14 | Límite conocido, sin CVs reales | Por eso la propuesta se **revisa y se confirma**; nada se guarda antes |
| **No hay cierre de empresa.** Un único administrador no puede borrar su cuenta (409 `ultimo_administrador`) ni quitarse | CP-EMP-13, CP-PRI-09 | **BUG-014**, decisión de producto abierta. Web #27 explica el 409 en el diálogo | No lo demuestres con la cuenta de la reclutadora principal: queda atrapada. Hay que limpiar con SQL |
| **El matching solo cubre** habilidades (50), idiomas (15), experiencia (20) y nivel académico (15). No entran ubicación, salario, turno, contrato ni licencia (no están en el perfil) | CP-OFE-03, CP-OFE-05 | Límite del MVP; los pesos son una primera versión sin ofertas reales | «Es una afinidad explicable, no un ranking final». Se calcula al leer (sin guardar), aceptable con cientos de ofertas |
| Amazon, Google y McKinsey «aún no disponible»; solo Junior y Startup | CP-ENT-01, CP-ENT-15 | Por diseño | Se anuncian como «pronto» |
| El plan Gratis da **1** práctica al mes, y practicar una oferta la gasta | CP-ENT-17, CP-OFE-07 | Por diseño | Usa una candidata en plan Estudiantil para la demo (SQL) |
| No hay correo ni chat: las invitaciones se pasan a mano (código de un solo uso) y el contacto solo llega si la persona lo comparte | CP-EMP-11, CP-APL-01 | Por diseño | «JobOut no tiene chat» está en el diálogo |
| La verificación de empresas es **manual** (la admin revisa dominio y documento fuera de la API) y la membresía no cobra | CP-EMP-03, CP-EMP-04 | Por diseño | No hay pasarela de pago |
| El nombre de una empresa **confidencial** escrito en la descripción no se detecta | CP-EMP-07 | Límite conocido (`security.md`) | Por eso el aviso fijo |
| Filtros solapados a 1560 px (BUG-013), foco que baja la página en la sala (BUG-016), orden no guardado en la URL (BUG-017), dashboard con bloques de candidato en cuentas de empresa (BUG-018) | CP-OFE-02, CP-ENT-19, CP-CUE-10 | Arreglados en web #27, **sin verlos en navegador** | Ensáyalos con `develop` actual |
| El contenedor `web` sin `three` no dibuja ni el avatar (BUG-012); `docker compose up --build` falla en core-api por `data/` (BUG-011) | Arranque | Arreglados (web #27, core-api #40); queda abierta la mejora de `make dev` | Reconstruye `web` con `-V`; no uses `--build` en vivo |
| Pruebas inestables de web (BUG-006, BUG-007) | Solo CI | Arreglados en web #16 y #18 (en `develop`) | No se ven en la demo |
| BUG-005, BUG-008, BUG-009, BUG-010: enlaces pegados, secciones vacías, texto del 403 y «1 años» | CP-ENT-13, CP-EMP-14 | Arreglados en web #14, #19, #20, #21 | Si ves alguno, es un regreso |
| Las dos pasadas del navegador las hizo **un agente**; el drop de archivos fue simulado; no se probó móvil real, modo oscuro ni lector de pantalla en las páginas de empresa | Todo | Pendiente de personas | No afirmes «probado con usuarios» |
| Faltan los cierres con personas: CVs reales, la entrevista con Luis, una empresa real que publique | Fases 2, 3 y 5a | Pendiente | Es un MVP |
| Los CVs viven en disco local (`BLOB_DIR`); hace falta S3 antes de producción | CP-CV-06 | Pendiente | Es un entorno de desarrollo |

## Guion de demo (10 a 12 minutos)

**Antes (no cuenta en el tiempo):** el stack arriba y migrado; las seis cuentas de «Cuentas de demo»
creadas; la admin con su SQL; la **empresa A verificada, con membresía y tres ofertas publicadas** (una
confidencial); la **empresa B recién registrada y sin verificar**; Camila en plan Estudiantil, **sin** perfil
ni CV (así se ve el flujo entero); el CV de demo y las tres respuestas de entrevista en un bloc de notas; una
sesión de navegador por cuenta (ventanas de incógnito o perfiles distintos) y el ensayo completo con el
`develop` actual.

| Min | Qué se muestra | Cuenta | Casos |
|---|---|---|---|
| 0:00 | **Qué es JobOut** en una frase: practicar entrevistas y aplicar a ofertas compartiendo solo lo que tú decides | — | — |
| 0:30 | **Registro** de una candidata nueva (la cuenta que se ve crear) → dashboard con «Tu plan: Gratis» y «Completa tu perfil» | candidata | CP-CUE-01, CP-CUE-10 |
| 1:30 | **Perfil y CV.** Completar nivel y profesión; en `/profile/cv`, arrastrar el DOCX; mostrar la propuesta agrupada y la confianza baja; corregir una cosa; «Confirmar». Mencionar el error de archivo >5 MB sin hacerlo | Camila | CP-CUE-07, CP-CV-02, CP-CV-03, CP-CV-05 |
| 3:30 | **Entrevista con Martín (Junior).** Avatar en reposo → pegar la respuesta **vaga** → pensando → hablando → **repregunta** → pegar una concreta → **Terminar** → resultado con desglose y mejoras. **Decir BUG-004 antes de mostrar el puntaje** | Camila | CP-ENT-02, CP-ENT-04, CP-ENT-09, CP-ENT-19, CP-ENT-11 |
| 6:00 | **Progreso y niveles:** Startup desbloqueado si el score llegó a 60; Amazon, Google y McKinsey «pronto». Mencionar la cuota del plan Gratis | Camila | CP-ENT-14, CP-ENT-15, CP-ENT-17 |
| 6:45 | **Ofertas:** `/offers` → «Mejor afinidad» (100 %, 47 %, 0 %) → detalle con «Afinidad con tu perfil» → la confidencial. Mostrar «Practicar esta entrevista» (no hace falta correrla) | Camila | CP-OFE-03, CP-OFE-05, CP-OFE-06, CP-OFE-07 |
| 8:00 | **Aplicar con consentimiento:** el diálogo; marcar **correo** y **afinidad**, dejar el teléfono sin marcar → «Enviar» → «Mis aplicaciones» | Camila | CP-APL-01, CP-APL-02, CP-APL-04 |
| 9:00 | **Lado empresa.** Con la reclutadora: panel de la oferta → Camila → solo lo consentido (correo y afinidad sí; teléfono, no) → «En revisión» con nota → «Favorita». Mover la aplicación a la confidencial a «Preseleccionada» y mostrar el aviso | reclutadora A | CP-EMP-14, CP-EMP-15, CP-EMP-17, CP-EMP-18, CP-PRI-01 |
| 10:15 | **Verificación:** con la admin, `/admin/companies` → verificar la **empresa B** y darle membresía (30 segundos) | admin | CP-EMP-03, CP-EMP-04 |
| 10:45 | **Privacidad:** Camila **retira** la aplicación → la reclutadora recarga y ya no hay datos; en una terminal, una llamada de la empresa B a una aplicación de la A → **404** | Camila, reclutadora, B | CP-APL-08, CP-PRI-05, CP-PRI-03 |
| 11:30 | **Cierre:** lo que no está (voz, IA en el evaluador, cierre de empresa, chat de IA **pendiente de PR jb-88**) y lo que viene | — | Límites |

Si el tiempo aprieta, recorta en este orden: el progreso (6:00), la verificación (10:15) y la llamada de 404.
**No muestres el chat de IA** mientras el PR jb-88 no esté mergeado y ensayado.

## Plan B si algo falla

| Si falla… | Muestra en su lugar |
|---|---|
| El stack no levanta o la API no responde | Las **capturas y GIF** del recorrido del 2026-11-11 (`~/Downloads/A-candidato-registro-cv-entrevista.gif`, `A2-candidato-ofertas-afinidad-practicar-aplicar.gif`, `C-privacidad-aplicar-retirar.gif`, `D-borrado-de-cuentas.gif`) y el resumen de pruebas verdes (core-api 851, web 1048 al cierre de la 5a) |
| El avatar 3D no aparece (sin `three`, BUG-012) o el navegador no lo soporta | Sigue con la sala sin avatar: la transcripción y el estado («te toca responder») llevan la entrevista. Reconstruye `web` con `-V` después de la demo |
| La entrevista tarda o el motor da 503 | Es «todo o nada»: reenvía el mismo texto, no se perdió. Si no vuelve, abre la transcripción y el resultado de una **sesión ya terminada** (preparada antes) |
| El puntaje sale «injusto» | Ya lo avisaste (BUG-004). Muestra el desglose y las mejoras, y di que es el evaluador por reglas |
| La cuota del plan se acabó (403 `limite_del_plan`) | Es CP-ENT-17: muéstralo como una función. Cambia a una sesión ya hecha |
| El extractor del CV propone cosas raras | Es la razón de la revisión: corrige a mano y confirma. Si no propone nada, «llenar a mano» (CP-CV-11) |
| El arrastre de archivos no funciona | Usa el selector «Elegir archivo» (CP-CV-01) |
| Los filtros de `/offers` se ven solapados | Usa solo «Mejor afinidad» y una ventana más angosta (a 390 px se vio bien) |
| La empresa A no puede publicar (sin verificar o membresía vencida) | Es CP-EMP-02: muéstralo, verifica con la admin y sigue. Ten una oferta ya publicada de reserva |
| La admin no ve «Empresas por verificar» | Falta el SQL del rol `admin`; cierra sesión y vuelve a entrar tras aplicarlo |
| Un diálogo o botón no responde | Recarga la página: la cuenta y los datos están en la base; el consentimiento y las aplicaciones no se duplican (doble clic y reintento seguros) |
| Todo lo demás | Las pruebas automáticas: `docker compose exec core-api cargo test --workspace` o `npm test` en `jobout-web`, y la tabla de casos de este documento |

## Cómo se mantiene

Cuando un caso se vea en un navegador, cambia su **Estado** con la fecha y quién lo hizo. Cuando entre el PR
jb-88, llena los casos `CP-CHAT-*` desde su código y sus pruebas, no desde memoria. Los nombres de prueba se
verifican con `grep` en `tests/`; si renombras una prueba, corrige aquí su referencia.
