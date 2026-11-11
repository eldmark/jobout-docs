# Fase 5 — Ofertas, matching y el lado empresa

**Estado:** en curso. Partida en **5a** (pasos 1–7 y 10–13) y **5b** (pasos 8 y 9), decisión 13. De la 5a,
los pasos 1 a 6 están en `develop` (2026-11-10); faltan 7, 10, 11, 12 y 13. La 5b no tiene código. Las
decisiones 1–14 se adoptaron con la opción recomendada **sin revisión del equipo** (`jb-60`)
**Repos que toca:** jobout-core-api, jobout-web, jobout (documentación)
**Depende de:** Fase 2 (perfil y catálogos). Es **independiente de la Fase 4**: puede ir antes, después
o en paralelo si tocan repos y tablas distintas. La excepción es HU-31, que usa el motor de entrevista
de la Fase 3.
**Abierta:** 2026-11-08

> Borrador escrito antes de que existieran las Fases 3 y 4. El 2026-11-10 se releyó contra `develop`
> (Fase 3 implementada): lo que el borrador daba por hecho y no existe está en «Lo que la revisión
> contra el código encontró», y lo que dependía de la Fase 3 quedó en la decisión 12.

## Objetivo

Que **una empresa** publique ofertas y revise a quienes aplican, y que **una persona** vea ofertas
compatibles con su perfil, practique la entrevista de esa oferta y lleve registro de dónde aplicó.

`producto.md` fija el orden: primero el lado candidato, que aporta valor sin una sola oferta; después
las empresas. Esta fase es ese «después», y cierra el problema del huevo y la gallina: **no se lanza
con ofertas falsas ni inventadas**. Las primeras se cargan a mano con empresas reales.

## Historias de usuario que cubre

- HU-30 — ver ofertas compatibles con mi perfil
- HU-31 — practicar una entrevista específica para una oferta *(usa el motor de la Fase 3; ver la decisión 12)*
- HU-32 — llevar registro de dónde apliqué
- HU-50 — registrar mi organización
- HU-51 — publicar una oferta
- HU-52 — ver quién aplicó
- HU-53 — mover una aplicación entre estados
- HU-54 — marcar candidatos favoritos
- HU-55 — publicar una oferta confidencial
- HU-56 — una membresía con vigencia

## Lo que esta fase descubrió que el diseño no decía

1. **Es la primera vez que los datos de una persona los ve otra persona.** Hasta ahora todo era
   «solo yo veo lo mío». Aplicar a una oferta muestra algo del candidato a un reclutador. Hay que
   decidir **qué** y exigir **consentimiento explícito en cada aplicación**. Es el riesgo central
   de la fase.
2. **Las ofertas confidenciales (HU-55) chocan con las aplicaciones:** el candidato aplica sin saber
   a qué empresa. Hay que decidir qué se revela y cuándo (decisión 3).
3. **La no discriminación tiene que ser verificable, no una promesa.** `db.md` eliminó edad, género y
   estado civil de las ofertas. Falta que el **matching** y los **filtros del reclutador** tampoco los
   usen ni los puedan usar. Se prueba con tests que fallan si aparece uno.
4. **No existe la gestión de empresas.** `companies`, `company_recruiters` y `memberships` están en
   `db.md`, pero nada las crea. Hay que decidir quién da de alta una empresa y **cómo se sabe que es
   real** (un reclutador falso con acceso a datos de candidatos es la mayor amenaza de la fase).
5. **Los roles y permisos nunca se usaron.** Las tablas `roles`/`permissions` existen y hoy solo hay
   rutas «autenticadas». Aquí aparece el primer control por rol.
6. **El plan del usuario no existe como concepto** (`negocio.md`): `memberships` es de empresa. Aquí
   entra el plan Empresarial; los planes de candidato quedan para la cuota de la Fase 3.
7. **Las ofertas caducan.** Una oferta cerrada o de una empresa con la membresía vencida no debe
   aparecer ni recibir aplicaciones.
8. **El matching puede ser injusto sin que nadie lo note.** Si se basa en habilidades escritas, premia
   a quien sabe escribir el CV. Se acepta como limitación y se hace **explicable** (HU-21 en espíritu).

## Lo que la revisión contra el código encontró (2026-11-10)

El borrador suponía piezas que no existen. Cada una cambia el alcance o agrega un paso:

1. **Faltan casi todos los catálogos de una oferta.** Están migrados `academic_levels`,
   `job_hierarchies`, `languages`, `professions` y `skills`. **No** existen `countries`, `states`,
   `cities`, `zones`, `salary_ranges`, `working_shifts`, `contract_types`, `employment_sectors`,
   `driver_licenses` ni `membership_types`, y `job_offers` y `companies` tienen FK a casi todos. El
   caso OF12 decía «los catálogos de la Fase 2»: no alcanzan. Hace falta un paso propio (paso 1) y
   decidir cuánta geografía se siembra (decisión 9).
2. **No hay control por rol.** Las tablas `roles`, `permissions`, `role_permissions` y `user_roles`
   están migradas, pero solo se siembran los roles `applicant` y `admin`, `permissions` está vacía y
   nada las lee. La tabla de rutas (`src/routes/table.rs`) solo conoce `Access::Public` y
   `Access::Authenticated`; `AuthUser` trae solo el id, y `GET /me` no dice qué roles tiene la
   persona, así que el frontend no puede elegir menús (FC6). Hace falta un paso propio (paso 2):
   `Access::Permission(...)` en la tabla de rutas, el rol de reclutador con sus permisos sembrados y
   los roles en `/me`. *A favor:* el middleware ya consulta la cuenta en cada petición (para detectar
   suspendidas), así que RO4 —quitar el rol corta el acceso en la siguiente petición— sale con esa
   misma consulta.
3. **Todo registro crea un `applicants` y el rol `applicant`** (`src/routes/auth.rs`). Un reclutador
   que se registra es, además, candidato. EM8 lo da por bueno, pero nadie lo decidió (decisión 10).
4. **Las invitaciones no tienen tabla.** EM4 y EM5 hablan de invitar reclutadores con un token de un
   solo uso; `db.md` no tiene dónde guardarlo. Se propone `company_invitations`.
5. **`access_audit` no está migrada** y PA8 la necesita: entra en el paso del panel.
6. **`job_preferences` no está migrada** y MA1 usa «preferencias». O se migra aquí, o el matching no
   las usa en esta fase (decisión 14).
7. **Verificar una empresa no tiene quién ni cómo.** La decisión 1 recomienda verificación manual, y
   el rol `admin` existe pero no tiene ninguna ruta. Hay que elegir entre una ruta de administración
   con permiso propio o un comando de consola; nunca un `UPDATE` a mano en la base (decisión 11).
8. **HU-31 con el motor determinista no da para mucho.** El motor de la Fase 3 tiene un banco fijo
   por recruiter × nivel; PR1 pide «armar las preguntas con el puesto y los requisitos», y eso es
   comprensión de lenguaje (Fase 4). `interview_sessions.job_offer_id` ya existe (nulo y sin FK, a la
   espera de `job_offers`). Practicar una oferta además gasta la cuota del plan (Fase 3). Ver la
   decisión 12.
9. **La fase es grande**: trece pasos con los dos nuevos. Ver la decisión 13.

## Alcance

**Dentro:**

- Alta de empresa, reclutadores, rol de reclutador y membresía con vigencia.
- Ofertas: crear, editar, publicar, pausar, cerrar; confidenciales; sus requisitos como tablas
  (habilidades, idiomas, licencias), no JSON.
- Aplicaciones con estados e historial (`job_application_events`); favoritos.
- Ofertas visibles para candidatos y aplicación con consentimiento.
- Matching: puntaje y desglose por oferta (`job_matches`), recalculado cuando cambia el perfil o la oferta.
- Registro de aplicaciones del candidato (las de la plataforma y, si se aprueba, las externas a mano).
- Práctica de una oferta (HU-31) pasando `job_offer_id` a la sesión, según la decisión 12.
- Frontend del candidato (ofertas, aplicaciones) y del reclutador (panel).

**Fuera (y por qué):**

- **Cobro y facturación** de la membresía: se modela la vigencia, no el pago.
- **Notificaciones por correo** a candidatos y reclutadores: fase propia, con su proveedor.
- **Verificación `.edu`, mentores y programa social** (`negocio.md`): tienen su propio modelo de amenazas.
- **Importar ofertas de LinkedIn u otros sitios**: legalmente delicado y no pedido.
- **Chat entre reclutador y candidato.** No es una red social.
- **Búsqueda de candidatos por parte de la empresa** (sin que apliquen): cambia el consentimiento de
  raíz. Solo ven a quien aplicó.

## Cambios de esquema

Tablas ya diseñadas en `db.md`: `companies`, `memberships`, `company_recruiters`,
`company_favorite_applicants`, `job_offers`, `job_offer_skills`, `job_offer_languages`,
`job_offer_driver_licenses`, `job_applications`, `job_application_events`, `job_matches`.

Decisiones que `db.md` todavía no dice:

- **`companies.verified_at`** (null hasta que alguien del equipo la verifique). Sin verificar, una
  empresa no puede publicar.
- **`job_applications.shared_fields`** (jsonb de **nombres de campo**, no valores): qué aceptó mostrar
  el candidato en esa aplicación, para poder auditarlo.
- **`job_applications.consented_at`**, no nulo.
- **`job_offers.company_visible`** derivado de `is_confidential`, para no repetir la lógica en cada consulta.
- **`external_applications`** (si se aprueba la decisión 6): empresa, puesto, fecha, estado y notas,
  con la nota cifrada.

Agregado en la revisión del 2026-11-10:

- **Catálogos de ofertas** (paso 1): `countries` → `states` → `cities` → `zones`, `salary_ranges`,
  `working_shifts`, `contract_types`, `employment_sectors`, `driver_licenses` y `membership_types`,
  ya diseñados en `db.md` («Catálogos»), con sus semillas.
- **Roles** (paso 2): sin tablas nuevas. Una migración siembra el rol de reclutador (y el de admin de
  empresa, si la decisión 7 lo pide) y sus permisos en `permissions` y `role_permissions`.
- **`company_invitations`** (nueva): `company_id` · `email_hash` (HMAC, como `users.email_hash`) ·
  `role` · `token_hash` · `expires_at` · `used_at` · `created_by`. El token nunca se guarda en claro.
- **`access_audit`**: ya diseñada en `db.md`, sin migrar.
- **`job_preferences`**: ya diseñada en `db.md`, sin migrar; solo si la decisión 14 la incluye.
- **FK de `interview_sessions.job_offer_id` → `job_offers`**, con `ON DELETE SET NULL`, en la
  migración de ofertas (así lo anota `db.md`).

Migraciones: `…_create_offer_catalogs`, `…_seed_recruiter_roles`, `…_create_companies`,
`…_create_job_offers`, `…_create_applications`, `…_create_access_audit`, `…_create_matches` (cada una
con `up` y `down`; `db.md` en el mismo PR).

## Pasos

Renumerados el 2026-11-10: los pasos 1 y 2 son nuevos y el antiguo paso 3 («control por rol») se
repartió entre el paso 2 y los demás.

- [ ] 0. **Este documento**: revisión del equipo y decisiones abiertas resueltas. *(Decisiones adoptadas
      con la opción recomendada en `jb-60-fase5a-contract`, docs #25; falta que el equipo las revise.)*
- [x] 1. Catálogos que usan las ofertas, con sus semillas (⇉ con 2). *(core-api `jb-58-offer-catalogs` #31;
      docs `jb-58-db-offer-catalogs` #26)*
- [x] 2. Roles y permisos: `Access::Permission` en la tabla de rutas, rol de reclutador con permisos
      sembrados y roles en `GET /me` (⇉ con 1). *(core-api `jb-59-route-permissions` #30; docs `jb-59-db-roles` #27)*
- [x] 3. Empresas, reclutadores, invitaciones y membresía (migración + endpoints) (⇉ con 4). *(core-api
      `jb-61-companies` #32; docs `jb-61-db-companies` #28)*
- [x] 4. Ofertas y sus requisitos (migración + CRUD del reclutador) (⇉ con 3). *(core-api `jb-62-offers`
      #33; docs `jb-62-db-offers` #29)*
- [x] 5. Listado y detalle de ofertas para candidatos (incluye las confidenciales). *(core-api
      `jb-63-candidate-offers` #34; docs `jb-63-docs-offers-candidato` #30)*
- [x] 6. Aplicar con consentimiento; ver mis aplicaciones; retirar. *(core-api `jb-64-applications` #35;
      docs `jb-64-db-applications` #31. Incluye el registro de aplicaciones externas y BO1/BO2 del paso 10)*
- [x] 7. Panel del reclutador: ver aplicaciones, mover estados, favoritos y `access_audit`. *(core-api
      `jb-67-recruiter-panel`; docs `jb-67-db-panel`)*
- [ ] 8. Matching: cálculo, desglose y recálculo *(5b)*
- [ ] 9. Práctica de una oferta (HU-31), según la decisión 12 *(5b)*
- [x] 10. Borrado de cuenta ampliado (candidato y reclutador). *(Candidato en el paso 6; reclutador en core-api
      `jb-68-recruiter-deletion`, docs `jb-68-db-authorship`)*
- [x] 11. Frontend del candidato. *(web `jb-69-candidate-offers-ui` #15)*
- [x] 12. Frontend del reclutador. *(web `jb-71-recruiter-ui` #17; incluye `/admin/companies`)*
- [ ] 13. Recorrido en navegador con las dos caras y cierre. *(Recorrido de un agente hecho el 2026-11-11; faltan
      el de una persona y los criterios de cierre)*

## Casos de verdad

> Borrador. Cada caso tiene que poder convertirse en un test.

### Catálogos de ofertas (paso 1, nuevo)

| # | Caso | Tipo |
|---|---|---|
| CT1 | Correr las migraciones crea los catálogos de ofertas (`countries`, `states`, `cities`, `zones`, `salary_ranges`, `working_shifts`, `contract_types`, `employment_sectors`, `driver_licenses`, `membership_types`); `down` y `up` son reversibles | integración |
| CT2 | `countries → states → cities → zones` forma una cadena con FK; una ciudad de un estado de otro país no se puede crear | integración |
| CT3 | Las semillas cubren lo que decida la decisión 9, con `code` único por catálogo | integración |
| CT4 | `GET /api/v1/catalogs/{nombre}` sirve los nuevos con el mismo formato y la misma protección que los de la Fase 2; un nombre fuera de la lista → 404 | integración |
| CT5 | `salary_ranges` está en quetzales, ordenado, y los rangos no se solapan | unitaria |

### Roles y permisos (paso 2, nuevo; antes «Roles y aislamiento», paso 3)

| # | Caso | Tipo |
|---|---|---|
| RB1 | La tabla de rutas admite `Access::Permission("...")`; una ruta así exige token **y** el permiso, y sin el permiso responde 403 aunque el handler no lo compruebe | integración |
| RB2 | Una migración siembra el rol de reclutador y sus permisos (`offer.manage`, `application.review`, …) y es reversible | integración |
| RB3 | `GET /me` devuelve los roles de la persona (códigos, nunca ids de `role_permissions`) | integración |
| RO1 | Un candidato que llama a una ruta de reclutador → 403 | integración |
| RO2 | Un reclutador que llama a una ruta de candidato (mis CV, mi perfil) → 403. **Depende de la decisión 10**: si es la misma cuenta, el caso cambia | integración |
| RO3 | Todas las rutas nuevas declaran su permiso en la tabla de rutas y un test falla si una no lo hace | integración |
| RO4 | Quitar el rol de reclutador invalida su acceso en la siguiente petición, sin esperar al vencimiento del token | integración |
| RO5 | Los permisos salen de `role_permissions`, no de comparar cadenas en los handlers | unitaria |
| RO6 | Escalada: un reclutador no puede darse a sí mismo el rol admin | integración |

El aislamiento entre empresas (OF8, PA1, PA7, SX2, SX6) se prueba en el paso de cada recurso, no en uno
aparte.

### Empresas y membresías (paso 3)

| # | Caso | Tipo |
|---|---|---|
| EM1 | `POST /api/v1/companies` crea la empresa sin verificar y vuelve a quien la crea su reclutador administrador | integración |
| EM2 | Una empresa no verificada no puede publicar ofertas → 403 `empresa_no_verificada` | integración |
| EM3 | Un NIT/identificador repetido → 409; el mismo reclutador no puede crear dos empresas iguales | integración |
| EM4 | Solo un admin de la empresa invita reclutadores; uno normal → 403 | integración |
| EM5 | La invitación (`company_invitations`) es de un solo uso, vence y nunca expone el token en claro tras guardarse (solo hash) | integración |
| EM6 | Una membresía tiene `start_date` y `expiration_date` (los nombres de `db.md`); vencida, la empresa no publica pero **conserva** lo ya publicado en borrador | integración |
| EM7 | Las ofertas publicadas de una empresa con membresía vencida dejan de ser visibles y de aceptar aplicaciones | integración |
| EM8 | Una persona puede ser candidato y reclutador a la vez; los dos perfiles no se mezclan en las respuestas | integración |
| EM9 | `DELETE` de un reclutador no borra a la empresa ni sus ofertas; si era el único admin → 409 | integración |
| EM10 | `companies` y `memberships` migran, son reversibles y el campo `verified_at` es nulo por defecto | integración |

### Ofertas (paso 4)

| # | Caso | Tipo |
|---|---|---|
| OF1 | Crear una oferta en `draft` con título, descripción y requisitos → 201; no es visible para candidatos | integración |
| OF2 | `description` existe **una sola vez** (el diseño original la duplicaba) | integración |
| OF3 | Los requisitos van en `job_offer_skills`, `job_offer_languages` y `job_offer_driver_licenses`; no hay columnas JSON | integración |
| OF4 | **No existe ningún campo** de edad, género ni estado civil: enviarlos → 422 y no se guardan | integración |
| OF5 | Publicar valida lo mínimo (título, descripción, ≥1 requisito, vacantes ≥ 1) → 422 con el motivo | integración |
| OF6 | Transiciones válidas: `draft→published→paused→published→closed`; `closed→published` → 409 | integración |
| OF7 | Editar una oferta publicada que ya tiene aplicaciones no cambia los requisitos con los que se aplicó (se versiona o se avisa) | integración |
| OF8 | Un reclutador de la empresa A no ve, edita ni cierra ofertas de la empresa B → 404 | integración |
| OF9 | Una oferta con `hiring_date` pasada se cierra sola | integración |
| OF10 | El texto de la oferta se trata como no confiable: se escapa al mostrar y no se interpreta como HTML | unitaria |
| OF11 | Un salario o rango fuera del catálogo → 422 | integración |
| OF12 | El `salary_range_id` y los demás ids salen de los catálogos (los de la Fase 2 y los del paso 1); un id inactivo → 422, como en el perfil | integración |

### Ofertas para candidatos (paso 5)

| # | Caso | Tipo |
|---|---|---|
| CA1 | `GET /api/v1/offers` lista solo `published` de empresas con membresía vigente, paginadas | integración |
| CA2 | Los filtros (profesión, ciudad, contrato, salario) funcionan y un filtro desconocido → 422 | integración |
| CA3 | Una oferta confidencial **no** muestra empresa, logo ni nada que la identifique, ni en el listado ni en el detalle ni en errores | integración |
| CA4 | La respuesta nunca incluye datos de reclutadores (nombre, correo) | integración |
| CA5 | `GET /offers/{id}` de un `draft`, `closed` o inexistente → 404, igual en los tres casos | integración |
| CA6 | Paginación con límite máximo (50); `limit=1000` → 422 o se recorta | integración |
| CA7 | El listado no hace N+1 consultas (se mide con el número de queries) | integración |

### Aplicaciones (paso 6)

| # | Caso | Tipo |
|---|---|---|
| AP1 | `POST /offers/{id}/applications` con `consent = true` y la lista de campos a compartir → 201 | integración |
| AP2 | Sin consentimiento explícito → 422; el consentimiento no se asume nunca | integración |
| AP3 | Aplicar dos veces → 409, no una segunda fila | integración |
| AP4 | Dos aplicaciones simultáneas dejan una sola | integración |
| AP5 | Aplicar a una oferta cerrada, pausada, borrador o de empresa vencida → 409/404 | integración |
| AP6 | `shared_fields` registra **qué campos** aceptó compartir (nunca los valores) | integración |
| AP7 | `GET /me/applications` lista las mías con estado y fecha; el motivo de rechazo de la empresa **no** aparece si no se decidió mostrarlo | integración |
| AP8 | Retirar la aplicación → `withdrawn`, queda el historial, el reclutador ya no ve los datos compartidos | integración |
| AP9 | Aplicar a una oferta confidencial no revela la empresa hasta que el reclutador lo decida (decisión 3) | integración |
| AP10 | Cada cambio de estado deja una fila en `job_application_events` con quién y cuándo | integración |

### Panel del reclutador (paso 7)

| # | Caso | Tipo |
|---|---|---|
| PA1 | `GET /company/offers/{id}/applications` lista solo las de **mi** oferta | integración |
| PA2 | El reclutador ve **únicamente** los campos que el candidato aceptó compartir; el resto no viaja en la respuesta | integración |
| PA3 | Nunca ve el CV original ni datos de contacto salvo que se compartan explícitamente | integración |
| PA4 | Mover de estado respeta la máquina: `applied→under_review→shortlisted/rejected→hired`; saltos inválidos → 409 | integración |
| PA5 | `hired` y `rejected` son finales (no se reabren) | integración |
| PA6 | Marcar favorito crea una fila única por `(empresa, candidato)`; repetir es idempotente | integración |
| PA7 | Los favoritos de la empresa A no los ve la empresa B | integración |
| PA8 | Todo acceso a datos de un candidato deja una fila en `access_audit` **sin el dato** | integración |
| PA9 | El reclutador no puede filtrar ni ordenar por edad, género, estado civil, nombre ni foto (parámetros → 422) | integración |
| PA10 | Un candidato que borró su cuenta desaparece del panel y queda un registro anónimo del evento | integración |

### Matching (paso 8)

| # | Caso | Tipo |
|---|---|---|
| MA1 | El puntaje (0–100) sale de habilidades, idiomas, experiencia, nivel académico y preferencias; mismo perfil y oferta, mismo puntaje | unitaria |
| MA2 | `breakdown` explica cada componente: qué coincide, qué falta y cuánto pesa | unitaria |
| MA3 | Una habilidad obligatoria ausente baja el puntaje más que una opcional | unitaria |
| MA4 | **El matching no puede leer edad, género, estado civil, nombre, foto ni dirección**; un test construye el perfil con esos campos y comprueba que el puntaje no cambia | unitaria |
| MA5 | Cambiar solo la edad o el género del perfil de prueba no altera el puntaje (prueba de equidad) | unitaria |
| MA6 | `GET /offers?sort=match` ordena por mi puntaje; sin perfil completo, ordena por fecha y lo dice | integración |
| MA7 | Si cambio mi perfil, el puntaje se recalcula; si cambia la oferta, se recalcula para todos | integración |
| MA8 | El recálculo no bloquea la petición y es idempotente | integración |
| MA9 | El puntaje del candidato es visible para él; para el reclutador solo si el candidato lo comparte (decisión 4) | integración |
| MA10 | Un perfil vacío da puntaje bajo con explicación, no error ni NaN | unitaria |

### Práctica de una oferta (paso 9, decisión 12)

| # | Caso | Tipo |
|---|---|---|
| PR1 | `POST /api/v1/interviews` acepta un `job_offer_id` opcional junto a `recruiter_id` y `level_id` y lo guarda en la sesión; **qué preguntas** arma depende de la decisión 12 | integración |
| PR2 | El contexto de la sesión usa solo datos **públicos** de la oferta; una confidencial no revela la empresa | integración |
| PR3 | Practicar una oferta no cuenta como aplicar ni la comparte con nadie | integración |
| PR4 | Una oferta cerrada, en borrador, inexistente o con id mal formado → 404, con el orden de validación del contrato de la Fase 3 (`api.md`) | integración |
| PR5 | Practicar una oferta **gasta la cuota del plan** igual que cualquier sesión (Q1 de la Fase 3) y respeta «una sesión activa» | integración |
| PR6 | El motor recibe del puesto solo título y requisitos, nunca datos de la empresa confidencial ni de la persona (X7 de la Fase 3) | unitaria |

### Borrado (paso 10)

| # | Caso | Tipo |
|---|---|---|
| BO1 | `DELETE /me` de un candidato borra sus aplicaciones, matches y registros externos; las ofertas y empresas quedan | integración |
| BO2 | Las aplicaciones borradas quedan en el panel como «candidato eliminado», sin datos, y el historial de estados se conserva sin identidad | integración |
| BO3 | Borrar a un reclutador conserva su historial de decisiones como anónimo | integración |
| BO4 | `privacy_events` guarda una constancia sin datos personales | integración |

### Seguridad transversal

| # | Caso | Tipo |
|---|---|---|
| SX1 | Acceso horizontal: un candidato no lee la aplicación de otro (404) | integración |
| SX2 | Un reclutador de otra empresa no lee aplicaciones ni favoritos ajenos (404) | integración |
| SX3 | Sin token → 401 en todas las rutas nuevas; la tabla de rutas las declara | integración |
| SX4 | Ningún dato del candidato aparece en logs ni en errores del panel | integración |
| SX5 | Límite de aplicaciones por persona y día (anti-spam) y de ofertas creadas por empresa y hora | integración |
| SX6 | La respuesta de un recurso de otra empresa es idéntica a la de uno inexistente (no revela existencia) | integración |
| SX7 | Una oferta o descripción con script o HTML nunca se ejecuta en el frontend | componente |

### Frontend (pasos 11 y 12)

| # | Caso | Tipo |
|---|---|---|
| FC1 | `/offers` muestra las ofertas con su puntaje y el porqué; las confidenciales sin empresa | componente |
| FC2 | Aplicar muestra **exactamente** qué se va a compartir con casillas, y sin marcar el consentimiento el botón está deshabilitado | componente |
| FC3 | «Mis aplicaciones» muestra el estado y el historial; retirar pide confirmación | componente |
| FC4 | Desde una oferta se puede «practicar esta entrevista» (si la decisión 12 la deja en esta fase) | componente |
| FC5 | El panel del reclutador lista aplicaciones, cambia de estado con confirmación y marca favoritos | componente |
| FC6 | Un candidato nunca ve rutas del panel y viceversa; los menús cambian según el rol | componente |
| FC7 | Todo es operable con teclado, los errores se anuncian y los textos salen de `lib/messages/es.ts` | componente |
| FC8 | Empresa sin verificar o membresía vencida: el panel lo explica y qué hacer | componente |

## Criterios de cierre

- [ ] Todos los casos tienen su test y fallaron antes de pasar; mutaciones en aislamiento entre
      empresas, consentimiento, no discriminación y máquina de estados
- [ ] **La prueba de equidad del matching** (MA4/MA5) corre en CI
- [ ] Una **empresa real** (aunque sea una sola, aliada) publica una oferta y recibe una aplicación
- [ ] Una persona del perfil real aplica a una oferta, entiende qué compartió y ve su estado
- [ ] Revisión de un asesor legal o de una persona con criterio sobre el tratamiento de datos de
      candidatos ante empresas (consentimiento, retención)
- [ ] Recorrido en navegador con las dos caras, sin ofertas ni empresas inventadas en producción
- [ ] `db.md`, `api.md`, `security.md`, `frontend.md`, `producto.md` y `test.md` al día; `docs/continue.md`

## Decisiones abiertas

1. **Cómo se verifica una empresa.** *Recomendado:* manual al inicio (alguien del equipo revisa
   dominio de correo y documento) y a mano también las primeras ofertas. Automatizar es otra fase.
2. **Qué ve el reclutador de un candidato.** *Recomendado:* solo lo que el candidato marca en cada
   aplicación, con un mínimo (nombre visible, habilidades, experiencia). Contacto, solo si lo marca.
3. **Ofertas confidenciales.** *Recomendado:* el candidato aplica sin ver la empresa; la empresa se
   revela solo cuando el reclutador mueve la aplicación a `shortlisted`. Hay que validar que sea justo
   para el candidato.
4. **¿El reclutador ve el puntaje de matching o de entrevista del candidato?** *Recomendado:* solo si
   el candidato lo comparte. Es el diferencial que `negocio.md` vende («perfiles con puntaje validado»)
   y también el punto más delicado.
5. **Retención.** Cuánto tiempo conserva una empresa los datos de quienes aplicaron. *Recomendado:*
   hasta cerrar la oferta más un plazo fijo, y borrado si el candidato retira.
6. **Registro de aplicaciones externas (HU-32).** *Recomendado:* sí, manual y privado, sin que la
   empresa lo sepa. *Alternativa:* solo las de la plataforma.
7. **Roles de la empresa.** *Recomendado:* `admin` y `reclutador`, nada más al inicio.
8. **Recalcular matching** al vuelo o en una tarea. *Recomendado:* en una tarea, con límite.

Agregadas en la revisión contra el código del 2026-11-10:

9. **Cuánta geografía se siembra.** *Recomendado:* solo Guatemala, con sus 22 departamentos y sus
   municipios; `zones` vacía al inicio. Es donde están Luis y las primeras empresas. *Alternativa:*
   texto libre para la ciudad, que deja el filtro por ciudad (CA2) sin índice.
10. **¿Un reclutador es la misma cuenta que un candidato?** Hoy todo registro crea un `applicants`.
    *Recomendado:* sí, la misma cuenta con dos roles. Es lo que supone EM8, y separar cuentas obliga a
    tocar el registro y el login de la Fase 1. *Consecuencia:* RO2 cambia: un reclutador **sí** ve sus
    propios CV y perfil, y lo que se prueba es que el panel nunca devuelve sus datos de candidato.
11. **Quién verifica una empresa y cómo** (complementa la 1). *Recomendado:* una ruta de administración
    con permiso propio (`company.verify`) para el rol `admin`, que deja rastro en `access_audit`.
    *Alternativa:* un comando de consola en core-api, sin interfaz. Lo que **no**: un `UPDATE` a mano.
12. **HU-31 (practicar una oferta) con el motor determinista.** *Recomendado:* aplazarla a la Fase 4,
    donde el motor entiende el puesto, y dejar en esta fase solo la FK de `interview_sessions.job_offer_id`.
    *Alternativa mínima:* guardar `job_offer_id` y agregar una pregunta por requisito obligatorio con una
    plantilla («Cuéntame de una vez que usaste {skill}»); se nota mecánica, igual que el resto del motor.
13. **¿Partir la fase?** *Recomendado:* sí. **5a** = pasos 1 a 7, 10 a 13 (empresas, ofertas,
    aplicaciones, panel y las dos caras del frontend): ya cubre HU-32 y HU-50 a 56 y entrega algo usable.
    **5b** = matching (paso 8) y HU-31 (paso 9). Así el matching se diseña con ofertas reales cargadas,
    no con datos inventados.
14. **¿El matching usa preferencias (`job_preferences`)?** *Recomendado:* no en esta fase; alcanza con
    habilidades, idiomas, experiencia y nivel académico, que ya están en el perfil de la Fase 2. MA1
    pierde «preferencias» hasta que exista una pantalla para cargarlas.

## Riesgos que se aceptan sabiendo que existen

- **Un reclutador falso es la peor amenaza:** obtendría datos de candidatos. La verificación manual
  lo mitiga y no lo elimina.
- **El huevo y la gallina sigue vivo.** Sin empresas aliadas, esta fase entrega un panel vacío.
- **El matching por habilidades premia el CV bien escrito**, no al mejor candidato.
- **Aplicar a una confidencial es una apuesta** para el candidato.
- **No hay notificaciones:** el candidato tiene que volver a mirar su estado.

## Desvíos y hallazgos

- **2026-11-10, revisión contra `develop`** (`jb-54-fase5-revision`): se agregaron los pasos 1 y 2, los
  casos CT1–CT5, RB1–RB3 y PR5–PR6, las tablas que faltaban en «Cambios de esquema» y las decisiones 9 a
  14; se corrigieron EM6 (nombres de columna de `db.md`) y OF12 (los catálogos de la Fase 2 no
  alcanzan). Ningún caso se borró. No hay código.
- **2026-11-10, contrato de la 5a** (`jb-60-fase5a-contract`; solo documentación, en `api.md`, `frontend.md` y
  `security.md`). Se adoptó la opción recomendada de las decisiones 1–14 (5a = pasos 1–7 y 10–13; matching y
  HU-31 a la 5b; sin `job_preferences`; HU-32 incluye las externas). Lo que hubo que decidir o que va más
  allá del plan:
  - **Máquina de estados:** PA4 decía «`shortlisted/rejected→hired`» y PA5 que `rejected` es final. Se
    resolvió: `hired` solo desde `shortlisted`; `rejected` desde `under_review` y `shortlisted`; `applied`
    solo pasa a `under_review` (no se rechaza sin abrirla). Repetir el estado actual es 409, no idempotente.
  - **Retirar:** idempotente (204 sobre `withdrawn`), a diferencia de las demás transiciones. Retirar o ser
    rechazado es definitivo para esa oferta: **no se puede reaplicar** (`ya_aplicaste`).
  - **Códigos nuevos:** `sin_permiso`, `empresa_no_verificada`, `membresia_vencida`, `ya_tiene_empresa`,
    `empresa_duplicada`, `nit_inmutable`, `ultimo_administrador`, `invitacion_invalida`,
    `oferta_con_aplicaciones`, `confidencial_inmutable`, `oferta_propia`, `oferta_incompleta` (con `fields`),
    `consentimiento_requerido`, `campo_no_permitido`, `parametro_no_permitido`, `limite_de_registros`.
    AP5 («409/404») se resolvió con 404 para toda oferta no visible.
  - **Roles:** `recruiter` recibe los 7 permisos de oferta/aplicación/favoritos; `company_admin` suma
    `company.update` y `company.invite`; `admin` solo `company.verify` y **no** lee aplicaciones. Las lecturas
    de ofertas del reclutador piden `offer.update`. RB2 hablaba de `offer.manage`: no existe, son los
    permisos granulares.
  - **Una persona, una empresa** (índice único parcial); EM1 vuelve admin a quien crea la empresa con el rol
    `company_admin`. Rutas `/company/...` en singular: la empresa sale de la membresía.
  - **Consentimiento:** conjunto cerrado de 9 nombres; obligatorios `display_name`, `skills`, `experience`
    (el plan decía «un mínimo» sin fijarlo); contacto = `email` y `phone`; `married_last_name` y segundo
    apellido nunca. Lo compartido se ve **en vivo** (no hay copia) y la lista es inmutable.
  - **Confidenciales:** la revelación es **por aplicación** (`company_revealed_at`) y permanente; no hay
    filtro, búsqueda ni `q` de texto en `/offers` (la descripción puede nombrar a la empresa);
    `is_confidential` queda congelado desde la primera publicación.
  - **OF7:** no se versiona: desde la primera aplicación solo se editan `description`, `schedule`,
    `vacancies` y `hiring_date`; el resto exige cerrar y crear otra.
  - **Verificación y membresía:** además de `verify`, se agregan `unverify`, `GET /admin/companies` y
    `PUT /admin/companies/{id}/membership` (sin ellos no hay forma de probar EM6/EM7 ni de cortar a un
    reclutador falso); cada uno deja fila en `access_audit`. Membresía vencida o empresa sin verificar
    **también bloquea el panel** (no solo publicar), para no dar datos de candidatos a una empresa no
    vigente.
  - **Invitaciones:** el token se devuelve **una vez** en la respuesta (no hay correo); atada al correo;
    7 días; 404 igual en cinco casos de fallo; los límites son 20 por día y 50 pendientes.
  - **Panel:** la lista solo trae `display_name`; el contacto y el resto, solo en el detalle. Auditoría:
    una fila por lista y una por detalle/cambio. Los favoritos se marcan por aplicación y no hay listado
    propio (`favorite=true`); se borran al retirar. La `note` de un cambio es interna, cifrada, y la
    persona nunca la ve (AP7).
  - **BO1/BO2:** las aplicaciones de quien borra su cuenta **no** se borran (BO2 las quiere en el panel):
    pierden `applicant_id` y `shared_fields`. Exige `applicant_id` y `job_offers.created_by` nulables y
    `changed_by` nulable en `db.md`. BO4 no necesita un `kind` nuevo.
  - **Retención (decisión 5):** 90 días desde `closed_at` (la columna no existía), calculado al leer.
  - **Límites (SX5), cifras elegidas:** 20 aplicaciones/persona/24 h, 20 ofertas/empresa/hora, 5 empresas
    por persona y día, 10 aceptaciones de invitación por hora, 120 detalles por reclutador y hora. Topes de
    cuerpo 16 KB (empresa) y 64 KB (oferta).
  - **Cambios de esquema no previstos:** `tax_id` cifrado con hash (puede ser el DPI de una persona),
    `external_applications`, `company_invitations.revoked_at`, nulabilidades arriba.
  - **Catálogos:** `cities` admite `?state_id`; `zones` y `membership-types` no se sirven; la geografía es
    solo Guatemala (decisión 9). El campo de oferta se llama `title` en la API y `name` en la tabla.
  - **Fuera de la 5a pese a estar en el plan de 5a:** ninguna ruta para cerrar una empresa ni borrar al
    único admin (queda 409 `ultimo_administrador`); sin notificaciones.
  - **Huecos de `security.md` encontrados** (ver su sección de la Fase 5a): `married_last_name`, sesgo por el
    nombre visible, `tax_id` en claro, texto de confidenciales, notas libres sin cifrar, roles globales
    contra pertenencia por empresa, falta de canal de denuncia.
- **2026-11-10, paso 4: ofertas del reclutador** (`jb-62-offers` en `jobout-core-api`, `jb-62-db-offers` aquí).
  Lo que el contrato dejaba abierto y se resolvió al implementar; ningún caso OF1–OF12 se cambió:
  - **`applications_count` transitorio:** `job_applications` no existe hasta el paso 6, así que OF7 (congelar
    tras la primera aplicación) y «borrar solo un borrador sin aplicaciones» leen una columna entera
    `job_offers.applications_count` (por defecto 0). El paso 6 la reemplaza por la cuenta real de
    `job_applications` y borra la columna; la API no cambia.
  - **Dos 409 a la vez en `PUT`:** `estado_invalido` (cerrada) gana a todo; entre `confidencial_inmutable` y
    `oferta_con_aplicaciones` gana el primero (es el más específico y el que protege la identidad de la empresa).
  - **`hiring_date` en `PUT`:** el rango «hoy a 2 años» solo se exige si el valor **cambia**: reenviar el mismo
    (aunque ya haya vencido) sigue siendo idempotente. Se valida después de los 409 (depende del recurso).
  - **`is_required` de una skill** se puede omitir y vale `true`; `min_level` puede ir `null`.
  - **413** responde `{"error": "cuerpo_demasiado_grande"}` (el contrato fija el estado, no el código). Las
    acciones (`publish`, `pause`, `close`) y las lecturas también leen el cuerpo para aplicar el tope de 8 KB.
  - **Cupo de 20 ofertas por empresa y hora:** se cuenta sobre `job_offers.created_at` (filas existentes, sin
    tabla de intentos), con un candado por empresa para que 30 creaciones simultáneas dejen exactamente 20.
    Consecuencia conocida: borrar un borrador libera cupo.
  - **Texto:** se quitan los caracteres de control y los invisibles o de dirección (`U+200B–200F`,
    `U+202A–202E`, `U+2066–2069`, `U+FEFF`…); en una línea (título, horario) también los saltos de línea. El
    HTML nunca se toca.
  - **Cierre automático (OF9):** `offers::close_expired(db, now_micros)`; el proceso la corre al arrancar y
    cada hora desde el bucle de limpieza. Pasadas las 00:00 UTC de `hiring_date + 1` la oferta se cierra.
- **2026-11-10, paso 7: panel del reclutador** (`jb-67-recruiter-panel` en `jobout-core-api`, `jb-67-db-panel`
  aquí). Casos PA1–PA10, SX2–SX6 y BO1 (favoritos) en `tests/panel.rs`, escritos antes, en rojo. Lo que se
  decidió al implementar está en `api.md` («Precisiones del paso 7»); lo que más pesa:
  - Una aplicación sin datos visibles (candidato eliminado, retención vencida) **no se mueve** ni se marca
    favorita: 409 `estado_invalido`.
  - `move_status` ahora acepta una transacción abierta: el panel la llama dentro de la suya, así el cambio
    de estado y su fila de `access_audit` se confirman juntos.
  - Al retirar, el favorito se borra si no queda otra aplicación «viva» (`applied`, `under_review`,
    `shortlisted`) en la empresa. Una contratada (`hired`) no lo sostiene.
- **2026-11-10, paso 10: borrado del reclutador** (`jb-68-recruiter-deletion`). BO1 y BO2 ya habían entrado en el
  paso 6, y lo central de BO3 (eventos y ofertas sin autor) ya lo daban las FK `ON DELETE SET NULL` de los pasos
  4 y 6: esas pruebas pasaron en verde desde el principio y quedan como regresión. Lo que sí falló en rojo:
  cinco columnas de autoría sin FK (`companies.updated_by`, `memberships.created_by`/`updated_by`,
  `company_recruiters.created_by`/`updated_by`) conservaban el id de un administrador borrado. Una migración
  les pone FK `ON DELETE SET NULL`, y una prueba recorre todas las columnas `*_by` de la base.
- **2026-11-11, paso 13: recorrido en el navegador con las dos caras, hecho por un agente** contra `core-api`
  real (`jb-68-recruiter-deletion`, que incluye el panel) y `jobout-web` en `next start` (`jb-71-recruiter-ui`,
  que incluye el paso 11). Cuentas de prueba locales. **No reemplaza la pasada de una persona.**
  - Registro → «Registrar mi empresa» → empresa creada «En verificación»; la descripción con `<b>` sale como texto ✅
  - Admin de plataforma (rol dado por SQL: a propósito no hay ruta que lo dé): «Empresas por verificar» →
    verificar → membresía; cada acción con su fila en `access_audit` ✅
  - Oferta nueva: municipio habilitado al elegir departamento; «Publicar» deshabilitado con «Para publicar
    falta: las vacantes.»; guardar → publicar; «confidencial» queda fija ✅
  - Candidata: ve la oferta en `/offers`; el `<script>` de la descripción sale como texto y no hay ningún
    elemento `script` inyectado (SX7); diálogo de consentimiento con los tres obligatorios bloqueados, el
    contacto desmarcado y «Enviar» deshabilitado hasta aceptar (FC2) → aplicó; «Mis aplicaciones»: «Enviada» ✅
  - Panel: la lista solo trae «Ana P.»; el detalle solo lo compartido (el correo, que marcó); solo la
    transición que permite la máquina; mover a «En revisión» con nota → la nota en el historial; favorita
    (`aria-pressed`); `localStorage` y `sessionStorage` vacíos; la nota guardada cifrada; ni el correo ni la
    nota en los logs de `core-api`; auditoría `application.list`, `application.view`, `application.review` ✅
  - La candidata ve «En revisión» con su historial y lo que compartió, **sin** la nota ni el favorito ✅
  - Hallazgos nuevos: BUG-008 y BUG-009 (bajos). Antes, una prueba de humo por la API real (no versionada)
    había recorrido lo mismo sin la interfaz.
  - **No cubierto:** invitar y aceptar a un reclutador en el navegador (cubierto por pruebas de componente),
    retirar desde la interfaz, móvil, modo oscuro y lector de pantalla en estas páginas.
