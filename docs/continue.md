# continue.md — traspaso de sesión

**Esto se lee al empezar y se actualiza al terminar.** Es la razón de ser de este repo: que
cualquiera —agente o persona— sepa qué se hizo, cómo y qué sigue, sin preguntar.

Entrada más reciente arriba. No borres entradas viejas: se van quedando como historia.

---

## 2026-11-11 — Recorrido en el navegador del MVP (JB-84)

Recorrido de punta a punta con Chrome sobre `http://127.0.0.1:3100`, con `develop` de los tres repos
(docs `348868d`, core-api `c2ad75f`, web `8bd671c`) y cuentas `*.example.test` de prueba. No se arregló
nada: es solo recorrido y bugs.

**Qué se hizo**

- **Candidata**: registro, perfil (nivel, profesión, jerarquía), subir CV por el selector (PDF) y por
  arrastrar y soltar (DOCX), revisar la propuesta, confirmar, descargar (el archivo bajado es idéntico al
  subido) y borrar. Entrevista con Martín/Junior: el avatar 3D pasa por reposo → pensando → hablando →
  reposo, repregunta ante la respuesta vaga, resultado (60/100) y progreso.
- **Ofertas**: el chip de afinidad sale en el listado (100 %, 47 %, 0 %), «Mejor afinidad» ordena bien, el
  detalle trae «Afinidad con tu perfil» con el desglose por componente, «Practicar esta entrevista» abre la
  sala con «Practicando: Desarrollador Backend Junior Rust» y las preguntas mencionan Docker, el diálogo de
  consentimiento marca lo obligatorio y lo opcional, «Mis aplicaciones» y retirar.
- **Empresa**: registro, empresa «en verificación» (publicar bloqueado), verificación y membresía por la
  admin de plataforma, oferta creada y publicada (el botón explica «falta el municipio»), oferta
  confidencial, panel con la aplicante, favorito, En revisión → Preseleccionada → Contratada, rechazo,
  invitación y alta de una segunda persona, quitar al único administrador (409 con texto claro).
- **Privacidad**: el reclutador solo ve lo consentido (sin teléfono, descripción, nivel académico ni «lo que
  hiciste»; el correo y la afinidad solo si se marcaron); otra empresa recibe 404 al leer, mover o marcar
  favorita; la oferta confidencial dice «Empresa confidencial» hasta la preselección; tras retirar, el panel
  muestra `applicant: null` y sin favorito; quitar a una persona del equipo le corta el acceso al instante.
- **Borrado de cuentas**: con la base **completamente migrada** `DELETE /me` responde 204 para candidata y
  reclutador. El 500 `leer_empresa` de la vez anterior era la base sin las tablas de empresa (faltaban 7
  migraciones). Quedan aplicaciones anonimizadas (`applicant_id` nulo, `shared_fields` `[]`), ofertas con
  `created_by` nulo y las notas internas cifradas; `users`, `applicants`, `personal_data`, `cvs`,
  `cv_extractions` y `interview_*` de las cuentas de prueba quedaron en 0. En los registros del core-api no
  aparece ningún correo, nombre, empresa ni texto de respuestas.
- Teclado: los diálogos de borrar CV, terminar entrevista, aplicar, mover aplicación, retirar y borrar cuenta
  tienen `role="dialog"` `aria-modal`, foco dentro, Tab/Shift+Tab sin salir y Escape devuelve el foco al botón.
- Responsive a 390 px (iframe, porque `resize_window` no cambió el viewport): listado, detalle y sala sin
  desborde horizontal.

**Bugs nuevos**: BUG-011 a BUG-018 (ver `bugs.md`). Lo más serio: BUG-011/012 (el stack no se reconstruye con
`--build` y el contenedor web no recibe dependencias nuevas), BUG-013 (filtros de `/offers` solapados en
escritorio) y BUG-014 (el único administrador no puede borrar su cuenta y la pantalla dice solo «inténtalo
de nuevo»). BUG-004 se reconfirmó (60/100, «Relevancia 7/20» con respuestas concretas).

**Cómo se resolvió**

- Base local: `cargo run -p migration -- up` dentro del contenedor `core-api` (las 7 migraciones de empresas,
  ofertas, aplicaciones, favoritos y autoría).
- Web: `docker compose build web` y `up -d --no-deps --force-recreate -V web` para que entrara `three`.
- SQL en la base local de desarrollo, y solo eso: (1) `insert into user_roles` con el rol `admin` para
  la usuaria «Ana Admin» (la admin de plataforma de prueba); (2) `update user_subscriptions` de la candidata
  al plan `student` (el plan gratis solo da 1 práctica al mes y ya la había usado); (3) al final, un
  `delete` en orden (aplicaciones, requisitos de ofertas, ofertas, membresías, favoritos, invitaciones,
  reclutadores, empresas) de las dos empresas de prueba, porque sus únicos administradores no podían
  borrar su cuenta (BUG-014).
- El archivo subido por el selector y el de arrastrar se pasaron por `DataTransfer`, porque la herramienta
  del navegador no sube archivos fuera de sus carpetas permitidas.

**No se pudo verificar**: el arrastre con el ratón real desde el explorador de archivos (el evento `drop` se
simuló), la descarga como flujo nativo del navegador más allá del archivo guardado, el borrado del blob en
S3/`data/` (la carpeta es de `root`), `resize_window` real a 390 px y el comportamiento con un lector de
pantalla. Las GIF de la sección B y B2 (empresa y panel) se grabaron pero no llegaron a `~/Downloads`.

**Archivos tocados**

- `docs/bugs.md` (BUG-011 a BUG-018)
- `docs/continue.md` (esta entrada)

**Migraciones**: ninguna en el código. Solo se aplicaron en la base local las 7 que ya estaban en core-api
`develop`.

GIF y capturas: `~/Downloads/A-candidato-registro-cv-entrevista.gif`,
`A2-candidato-ofertas-afinidad-practicar-aplicar.gif`, `C-privacidad-aplicar-retirar.gif`,
`D-borrado-de-cuentas.gif`; capturas en `~/.cache/jobout-work/scratch/walk/evidence/`.

---

## 2026-11-11 — Fase 5a: pasos 7, 10, 11 y 12 con código; recorrido con las dos caras

**Qué se hizo** (nada está mergeado: todo son PRs abiertos hacia `develop`)

| Repo | PR | Qué |
|---|---|---|
| core-api | #36 | Paso 7: panel del reclutador (lista, detalle, estados con nota cifrada, favoritos, `access_audit` en la misma transacción, 120 detalles por hora) |
| core-api | #37 | Paso 10: borrado del reclutador; cinco columnas `*_by` sin FK pasan a `ON DELETE SET NULL`. **Apilado sobre #36** |
| web | #14 | BUG-005: los enlaces de «Ver mis entrevistas» separados |
| web | #15 | Paso 11: frontend del candidato (`/offers`, consentimiento, «Mis aplicaciones» con externas) |
| web | #16 | BUG-006: las pruebas de entrevista que fallaban a veces |
| web | #17 | Paso 12: frontend del reclutador y `/admin/companies`. **Apilado sobre #15** |
| web | #18 | BUG-007: las pruebas esperan el texto de la alerta (la misma carrera en cinco archivos) |
| web | #19 · #20 | BUG-008 (estados vacíos en el panel) y BUG-009 (texto del 403). **Apilados sobre #17** |
| web | #21 | BUG-010: «1 año» en singular. **Apilado sobre #19** |
| docs | #32 → #33 → #34 → este | Estado de la 5a, `db.md` del panel, `db.md` de autoría, y este cierre del día. Cada uno apilado sobre el anterior |

- Pruebas: core-api **851 en verde** dentro del contenedor (Rust 1.90), `clippy -D warnings` y `fmt --check`
  limpios; web #17 **1048** con `tsc`, `eslint` y `next build` limpios. Todo con TDD: el primer commit de cada
  PR trae las pruebas en rojo.
- Una prueba de humo por la API real y un **recorrido en el navegador con las dos caras**, hecho por un agente
  (detalle en `working/fase5-ofertas-empresas.md`, paso 13). Hallazgos: BUG-008 y BUG-009 (bajos).
- Ninguna mención de IA en commits ni PRs (regla de `AGENTS.md`).

**Orden de merge**

1. docs #32 → #33 → #34 → este (`jb-72-fase5a-recorrido`).
2. core-api #36 → #37.
3. web #14, #16 y #18 cuando quieran; #15 → #17 → #19 → #21, y #20 después de #17.

GitHub reapunta un PR apilado a `develop` cuando se mergea el de abajo, pero el CI de «PR completo» no siempre
corre con el reapunte ni al editar el cuerpo: si queda sin check, **cerrar y reabrir el PR** (pasó en
core-api #36). El check de migraciones busca el texto literal `documentation/db.md` en el cuerpo.

**Qué quedó a medias**

- Falta **una aprobación por PR** (nadie se aprueba a sí mismo) y, después, `develop → main`.
- `develop` sigue **sin protección** y con «borrar la rama al mergear» en docs, core-api y web.
- Los criterios de cierre de la 5a que piden personas: una empresa real que publique, una persona real que
  aplique, la revisión del tratamiento de datos y el recorrido de una persona.
- BUG-005 a BUG-010 tienen su arreglo en un PR de web (#14, #16, #18, #19, #20, #21): se cierran al mergear.
- La base de desarrollo local quedó con las cuentas, empresas y ofertas de prueba del recorrido (dominio
  `jobout-prueba.test`). Para dejarla vacía: `cargo run -p migration -- fresh` dentro del contenedor (borra
  todo).

**Qué sigue**

1. Revisar y mergear en el orden de arriba; después `develop → main` en los tres repos y sincronizar `develop`.
2. Que un admin proteja `develop`.
3. Fase 5b: matching (paso 8), con ofertas reales cargadas, y HU-31 (paso 9) según la decisión 12.
4. Los cierres con personas de las Fases 2, 3 y 5a. La Fase 4 solo con proveedor, política y presupuesto.

## 2026-11-10 (cierre del día) — Fase 5a: pasos 1 a 6 en `develop`; docs al día

**Qué se hizo**

- La Fase 5 se partió en **5a** (empresas, ofertas, aplicaciones, panel y las dos caras del frontend) y
  **5b** (matching y HU-31), según la decisión 13. Contrato HTTP de la 5a en `api.md`, `frontend.md` y
  `security.md` (`jb-60`, docs #25). Las 14 decisiones se adoptaron con la opción recomendada, **sin
  revisión del equipo**.
- **Pasos 1 a 6 de la 5a en `develop`** de core-api (#30 a #35), cada uno con su `db.md` (docs #26 a #31):
  catálogos de ofertas con semillas de Guatemala; `Access::Permission` en la tabla de rutas, roles
  `company_admin` y `recruiter`, y roles y permisos en `GET /me`; empresas, invitaciones y verificación por
  la plataforma (`/admin/companies`, con `access_audit`); CRUD de ofertas del reclutador con su máquina de
  estados y cierre automático; ofertas públicas para candidatos; aplicaciones con consentimiento, retiro,
  revelación de las confidenciales y registro privado de aplicaciones externas. BO1 y BO2 (borrar la
  cuenta deja la aplicación anónima en el panel) ya entraron en el paso 6.
- `jb-65-fase5a-estado`: pasos marcados en `fase5-ofertas-empresas.md`, estado de las fases en
  `working/README.md`, y `bugs.md` sin BUG-001 a 003 (cerrados en la tarde; `jb-57` los había vuelto a
  listar al mergear).

**Qué quedó a medias**

- De la 5a faltan el **paso 7** (panel del reclutador: aplicaciones de una oferta, detalle, cambio de
  estado y favoritos), el **paso 10** en lo del reclutador (BO3, BO4), los **pasos 11 y 12** (jobout-web
  no tiene ninguna página de la 5a) y el **13** (recorrido con las dos caras y cierre).
- `develop` sigue **sin protección** y con «borrar la rama al mergear» activado en docs, core-api y web:
  el próximo PR `develop → main` la vuelve a borrar. Solo un admin de los repos lo puede cambiar.

**Qué sigue**

1. Paso 7 en core-api y, en paralelo, el frontend del candidato (paso 11): sus endpoints ya están en
   `develop`.
2. Paso 10, paso 12 y el recorrido con las dos caras (paso 13); después `develop → main`.
3. Siguen pendientes los cierres de personas de las Fases 2 y 3 (CVs reales, la entrevista con Luis).

## 2026-11-10 (noche) — Recorrido en el navegador, hecho por un agente

Contra el entorno local recién levantado desde `main` (`docker compose up --build`, migraciones aplicadas).
**No reemplaza la pasada de una persona del equipo.** Cuenta de prueba local, borrada al final.

- Portada → registro → dashboard («Tu plan: Gratis») ✅
- Elegir recruiter y nivel: Startup bloqueado con el motivo; Amazon, Google y McKinsey «aún no disponible» ✅
- Entrevista con Martín: respuesta vaga → repregunta; dos respuestas concretas → siguiente pregunta ✅
- Pausar (con confirmación) → «Retoma tu entrevista» en el dashboard → Retomar sigue en la misma pregunta ✅
- Terminar (con confirmación): score 61, claridad 96, el desglose suma 61, tres mejoras, sin confianza ✅
- Progreso: Junior mejor score 61; Startup desbloqueado (61 ≥ 60) ✅
- Lista («Mostrando 1 entrevista.») y transcripción ✅
- Segunda entrevista en plan Gratis: «Ya usaste las entrevistas que incluye tu plan este mes. Se renueva el 1 de diciembre de 2026.» ✅
- CV sintético DOCX: propuesta con 2 experiencias, 5 habilidades y 2 idiomas con su nivel → confirmar → perfil ✅; borrar el CV (con aviso) conserva el perfil ✅
- Borrar la cuenta (pide la contraseña): `users`, `applicants`, `cvs`, sesiones, turnos, scores y progreso en 0; 1 fila en `privacy_events`; `usage_ledger` conserva 1 fila **sin** `user_id`; 0 archivos en el almacén; ninguna frase de las respuestas en los logs; `/interviews`, `/interviews/progress` y `/profile` sin sesión redirigen a `/sign-in` ✅
- **Hallazgos nuevos:** BUG-004 (el «por qué» del score parece injusto con respuestas buenas) y BUG-005
  (enlaces pegados en la lista).
- **No cubierto:** descargar el CV (abre un archivo en el navegador), una persona real mirando la pantalla,
  móvil y lector de pantalla.

## 2026-11-10 (tarde) — Fase 3 en `main` y bugs cerrados

- `develop → main` mergeado en los tres repos (core-api #29, web #13, docs #22) con bypass de admin,
  autorizado por el usuario, con el CI verde en los PR.
- **Bugs cerrados**, verificados en el código de `main`: BUG-001 (formularios por POST,
  `AuthForm.tsx`; web #10), BUG-002 (singular «Mostrando 1 entrevista.»; web #11) y BUG-003 (el CI usa
  la versión de Rust de la imagen, 1.90; core-api #28).
- **Cuidado:** los repos tienen «borrar la rama al mergear» activado y el PR `develop → main` **borró
  `develop`**. Se recreó desde `main`. Hay que desactivar esa opción o proteger `develop`.

## 2026-11-10 — Fase 3 en `develop` y recorrida; el cierre depende de personas

**Qué se hizo**

- La Fase 3 (entrevista en modo texto) tiene los **pasos 1 a 11 mergeados en `develop`**: core-api #19
  a #27, web #7 a #9 y docs #15 a #18. Esta entrada lo registra recién ahora: las anteriores decían que
  no había código.
- `jb-50-fase3-cierre` (docs): pasos marcados con sus ramas, tabla de las decisiones que quedaron en el
  código, `frontend.md` (páginas de entrevista), `test.md` (cómo se prueba la entrevista), `api.md`
  (`speaker` es `recruiter` | `applicant`) y `desarrollo.md` (migrar la primera vez, cómo hacerlo sin
  `make`, PostgreSQL nativo en el 5432).
- Pruebas con `--no-fail-fast`: **533 en verde** en core-api (39 binarios, dentro del contenedor) y
  **505** en web, con `tsc` y `eslint` limpios.
- **Recorrido de punta a punta** por un agente contra el backend real: registro, elegir recruiter y
  nivel, repregunta, pausa y reanudación, una sola sesión activa, score con desglose, desbloqueo de
  Startup, transcripción y la cuota del plan Gratis. Todo según el contrato; detalle en
  `working/fase3-entrevista.md`.

**Qué quedó a medias**

- **Lo que no puede hacer un agente:** la pasada de una persona en el navegador (este recorrido no
  tuvo capturas) y **la entrevista con Luis**, que decide si hace falta el motor de IA.
- Las nueve decisiones de la fase se adoptaron con la opción recomendada **sin revisión del equipo**.
- `develop` no está en `main` en docs, core-api ni web: falta el PR `develop → main` en cada uno, con
  una aprobación.
- Tres bugs nuevos en `bugs.md`. **BUG-001 es de seguridad** (contraseña en la URL si se envía el
  registro antes de que cargue el JavaScript).
- Sigue abierta la Fase 2: CVs reales y la pasada de una persona.

**Qué sigue**

1. Arreglar BUG-001 en su propia rama, antes que cualquier otra cosa.
2. Que el equipo confirme las decisiones de la Fase 3 y haga las dos pasadas de personas (Fases 2 y 3).
3. PR `develop → main` en los tres repos y, después, sincronizar `develop` con `main`.
4. Revisión de casos de verdad de la siguiente fase. La 5 no depende de nada externo; la 4 necesita
   antes proveedor, política de no entrenamiento y costo medido, y hay que releerla (sus ⚠ suponían una
   Fase 3 que todavía no existía).

**Pendiente heredado:** ramas sobrantes en `jobout-core-api` (`jb-05-pii-crypto`, `jb-07-password-jwt`,
`jb-29-no-sql-values-in-logs`) y en `Job-out-interview` (`jb-01-service-docs`, `jb-36-develop-flow`);
OAuth aplazado; S3 antes de producción; costo real de la voz.

## 2026-11-09 — Fase 2 mergeada y repo de entrevista documentado

- Las pilas de la Fase 2 (docs, web y core-api #9 a #15) están en `main`; core-api #17 (calidad del
  extractor) en cola de CI al escribir esto. Fases 3, 4 y 5 en `docs/working/` como borradores.
- Se documentó el repo [`Job-out-interview`](https://github.com/eldmark/Job-out-interview) (PR #1 allá):
  servicio, protocolo WebSocket, API interna, proveedores, seguridad, pruebas y desarrollo. **Sin código.**
- Para pasar a la siguiente fase solo falta que el equipo revise los casos de verdad de la Fase 3 y
  resuelva sus decisiones abiertas.

## 2026-11-08 — Fase 3 redactada

- Se redactó [`working/fase3-entrevista.md`](working/fase3-entrevista.md) con ~130 casos de verdad
  (catálogo, motor, evaluación, sesiones, turnos, score, cuota por plan, seguridad, frontend) y 9
  decisiones abiertas. **No hay código de la Fase 3.**
- Mientras tanto se mergea la pila de la Fase 2 en core-api (#12 a #15, luego #17).
- Se dejaron en borrador las Fases 4 (voz, motor de IA y memoria) y 5 (ofertas y empresas). Ninguna tiene
  código. HU-24 (sugerencias de CV) y HU-40/41 (ver y exportar mis datos) quedan sin fase asignada.
- Siguiente: que el equipo revise los casos y resuelva las decisiones (sobre todo motor y cuota por plan).

## 2026-11-05 — Fase 2 implementada, pendiente de revisión y de CVs reales

**Qué se hizo**

- Pasos 1 a 11 de la Fase 2 con TDD y mutaciones: catálogos, esquema de perfil y CVs, almacén de
  archivos, lectura de PDF/DOCX y extractor determinista, rutas de CV, perfil y confirmación, borrado
  de cuenta con archivos, y las pantallas. Todo en PRs apilados; el orden de merge está en cada PR.
- Se corrigió una **fuga de datos en logs** (`RUST_LOG=trace` imprimía valores de consultas): ver
  `documentation/security.md`.
- Recorrido completo en Chrome contra el backend real (detalle y límites en el archivo de la fase).
- **2026-11-06:** la pila de core-api se reordenó para que todos sus PRs pasen el CI (el filtro de logs
  pasó a #12 y se corrigió `l10`); #16 se cerró por redundante. Se midió el extractor con un corpus
  sintético (core-api #17) y se pulió el frontend (web #5, sin ver aún en navegador).

**Qué quedó a medias**

- **Medir el extractor con CVs reales del equipo** (5 PDF y 2 DOCX con su permiso). Es el criterio que
  decide si basta el extractor determinista o hace falta un LLM.
- Que una persona repita el recorrido en un navegador.
- Las siete decisiones abiertas del plan se adoptaron por defecto sin revisión del equipo.
- **S3 antes de producción**: el almacén en disco no tiene redundancia.

**Pendiente heredado:** ramas `jb-05-pii-crypto` y `jb-07-password-jwt` sobrantes en `jobout-core-api`;
OAuth aplazado; costo real de la voz frente al supuesto de texto.

---

## 2026-11-04 — Fase 1 mergeada y Fase 2 redactada

**Qué se hizo**

- La pila de la Fase 1 (13 PRs en los tres repos) quedó mergeada en `main` y la fase está en
  `archived/fase1-identidad.md`.
- Deuda de cierre: [`jb-16`](https://github.com/eldmark/jobout-core-api/pull/8) hace que el CI pruebe
  todos los crates del workspace (la prueba de UUID v7 nunca corría) y `jb-17` arregla `make test`,
  `make migrate` y `test.md`. **Siguen abiertos hasta que alguien los revise.**
- Se redactó [`working/fase2-perfil-cv.md`](working/fase2-perfil-cv.md) con 124 casos de
  verdad. **No hay código de la Fase 2.**

**Lo que la Fase 2 descubrió que el diseño no decía**

HU-03 pide extraer «experiencia» pero no existe dónde guardarla; los catálogos están diseñados y
no migrados; borrar la cuenta ya no cabe en una transacción porque los archivos viven fuera de la
base; y un `jsonb` de extracción puede filtrar PII sin cifrar. Detalle y propuestas en el archivo
de la fase.

**Qué sigue**

1. Que el equipo revise los casos de verdad y resuelva las 7 decisiones abiertas (las más
   importantes: dónde se guardan los archivos, extractor determinista o LLM, y si se cifran las
   experiencias).
2. Paso 1 de la Fase 2: migración de catálogos con sus semillas.
3. Antes de salir a usuarios reales: implementación S3, y que una persona repita el recorrido de
   la Fase 1 en un navegador.

**Pendiente heredado:** ramas `jb-05-pii-crypto` y `jb-07-password-jwt` sobrantes en
`jobout-core-api`; OAuth aplazado; costo real de la voz frente al supuesto de texto.

---

## 2026-11-04 — Documentación de marca y negocio, Fase 1 y módulo de cifrado

**Qué se hizo**

- Se leyeron los documentos del emprendimiento (identidad de marca, sostenibilidad social,
  indicadores financieros y la plantilla de costos) y quedaron en
  [`../documentation/identidad-visual.md`](../documentation/identidad-visual.md) y
  [`../documentation/negocio.md`](../documentation/negocio.md).
- Se redactó [`archived/fase1-identidad.md`](archived/fase1-identidad.md) con sus casos de
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

**Actualización posterior (misma fecha)**

- Tres agentes en paralelo, cada uno en su worktree y rama: migraciones de identidad y planes
  (`jb-06-identity-migrations`), contraseñas y JWT (`jb-07-password-jwt`) y marca y sesión del
  frontend (`jb-08-brand-session`). Verificado por separado: todo en verde.
- Rama de integración `jb-09-register-login` en core-api (junta `jb-06` y `jb-07`) con `register`
  y `login` terminados y probados contra PostgreSQL real y contra el binario.
- Logos vectorizados desde el PDF de identidad, en `brand-assets/` (fuera de los repos).
- Falta: `refresh` y `logout`, `GET /me`, `DELETE /me`, páginas de ingreso y registro, y el
  recorrido en navegador. OAuth sigue aplazado.

**Actualización final de la sesión**

- Terminaron los pasos 4 a 7 de la Fase 1: `refresh`/`logout` (`jb-10`), `AuthUser` y `/me` con
  borrado real (`jb-11`) y las páginas de ingreso, registro, dashboard y borrado (`jb-12`).
- Recorrido de punta a punta contra el backend real: todo correcto (detalle en
  `docs/archived/fase1-identidad.md`).
- Deuda saldada en `jb-14`: contador de intentos compartido y tabla de rutas que protege por
  construcción (sustituye al escaneo del código fuente).
- PRs apilados abiertos en los tres repos; el orden de merge está al inicio de cada uno.
- **Fase 1 cerrada** y movida a `archived/`. El recorrido en Chrome se hizo contra el backend real
  (automatizado; hallazgos y límites en el archivo de la fase). Antes de salir a usuarios reales
  conviene que una persona lo repita a mano. OAuth sigue aplazado.
- Siguiente: fase de perfil y CV (HU-02 a HU-04), y estimar el costo real de la voz antes de
  fijar precios.

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
