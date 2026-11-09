# Fase 5 — Ofertas, matching y el lado empresa

**Estado:** borrador (casos de verdad pendientes de revisión del equipo; **no hay código todavía**)
**Repos que toca:** jobout-core-api, jobout-web, jobout (documentación)
**Depende de:** Fase 2 (perfil y catálogos). Es **independiente de la Fase 4**: puede ir antes, después
o en paralelo si tocan repos y tablas distintas. La excepción es HU-31, que usa el motor de entrevista
de la Fase 3.
**Abierta:** 2026-11-08

> Borrador escrito antes de que existan las Fases 3 y 4. Lo que dependa de ellas está marcado ⚠.

## Objetivo

Que **una empresa** publique ofertas y revise a quienes aplican, y que **una persona** vea ofertas
compatibles con su perfil, practique la entrevista de esa oferta y lleve registro de dónde aplicó.

`producto.md` fija el orden: primero el lado candidato, que aporta valor sin una sola oferta; después
las empresas. Esta fase es ese «después», y cierra el problema del huevo y la gallina: **no se lanza
con ofertas falsas ni inventadas**. Las primeras se cargan a mano con empresas reales.

## Historias de usuario que cubre

- HU-30 — ver ofertas compatibles con mi perfil
- HU-31 — practicar una entrevista específica para una oferta *(⚠ usa el motor de la Fase 3)*
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

## Alcance

**Dentro:**

- Alta de empresa, reclutadores, rol de reclutador y membresía con vigencia.
- Ofertas: crear, editar, publicar, pausar, cerrar; confidenciales; sus requisitos como tablas
  (habilidades, idiomas, licencias), no JSON.
- Aplicaciones con estados e historial (`job_application_events`); favoritos.
- Ofertas visibles para candidatos y aplicación con consentimiento.
- Matching: puntaje y desglose por oferta (`job_matches`), recalculado cuando cambia el perfil o la oferta.
- Registro de aplicaciones del candidato (las de la plataforma y, si se aprueba, las externas a mano).
- Práctica de una oferta (HU-31) pasando `job_offer_id` a la sesión. ⚠
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

Migraciones: `…_create_companies`, `…_create_job_offers`, `…_create_applications`,
`…_create_matches` (cada una con `up` y `down`; `db.md` en el mismo PR).

## Pasos

- [ ] 0. **Este documento**: revisión del equipo y decisiones abiertas resueltas.
- [ ] 1. Empresas, reclutadores, rol y membresía (migración + endpoints) (⇉ con 2)
- [ ] 2. Ofertas y sus requisitos (migración + CRUD del reclutador) (⇉ con 1)
- [ ] 3. Control por rol/permiso y aislamiento entre empresas
- [ ] 4. Listado y detalle de ofertas para candidatos (incluye las confidenciales)
- [ ] 5. Aplicar con consentimiento; ver mis aplicaciones; retirar
- [ ] 6. Panel del reclutador: ver aplicaciones, mover estados, favoritos
- [ ] 7. Matching: cálculo, desglose y recálculo
- [ ] 8. Práctica de una oferta (HU-31) ⚠
- [ ] 9. Borrado de cuenta ampliado (candidato y reclutador)
- [ ] 10. Frontend del candidato
- [ ] 11. Frontend del reclutador
- [ ] 12. Recorrido en navegador con las dos caras y cierre

## Casos de verdad

> Borrador. Cada caso tiene que poder convertirse en un test.

### Empresas y membresías (paso 1)

| # | Caso | Tipo |
|---|---|---|
| EM1 | `POST /api/v1/companies` crea la empresa sin verificar y vuelve a quien la crea su reclutador administrador | integración |
| EM2 | Una empresa no verificada no puede publicar ofertas → 403 `empresa_no_verificada` | integración |
| EM3 | Un NIT/identificador repetido → 409; el mismo reclutador no puede crear dos empresas iguales | integración |
| EM4 | Solo un admin de la empresa invita reclutadores; uno normal → 403 | integración |
| EM5 | La invitación es de un solo uso, vence y nunca expone el token en claro tras guardarse (solo hash) | integración |
| EM6 | Una membresía tiene `starts_at` y `expires_at`; vencida, la empresa no publica pero **conserva** lo ya publicado en borrador | integración |
| EM7 | Las ofertas publicadas de una empresa con membresía vencida dejan de ser visibles y de aceptar aplicaciones | integración |
| EM8 | Una persona puede ser candidato y reclutador a la vez; los dos perfiles no se mezclan en las respuestas | integración |
| EM9 | `DELETE` de un reclutador no borra a la empresa ni sus ofertas; si era el único admin → 409 | integración |
| EM10 | `companies` y `memberships` migran, son reversibles y el campo `verified_at` es nulo por defecto | integración |

### Ofertas (paso 2)

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
| OF12 | El `salary_range_id` y los catálogos se leen de los catálogos de la Fase 2 | integración |

### Roles y aislamiento (paso 3)

| # | Caso | Tipo |
|---|---|---|
| RO1 | Un candidato que llama a una ruta de reclutador → 403 | integración |
| RO2 | Un reclutador que llama a una ruta de candidato (mis CV, mi perfil) → 403 | integración |
| RO3 | Todas las rutas nuevas declaran su permiso en la tabla de rutas y un test falla si una no lo hace | integración |
| RO4 | Quitar el rol de reclutador invalida su acceso en la siguiente petición, sin esperar al vencimiento del token | integración |
| RO5 | Los permisos salen de `role_permissions`, no de comparar cadenas en los handlers | unitaria |
| RO6 | Escalada: un reclutador no puede darse a sí mismo el rol admin | integración |

### Ofertas para candidatos (paso 4)

| # | Caso | Tipo |
|---|---|---|
| CA1 | `GET /api/v1/offers` lista solo `published` de empresas con membresía vigente, paginadas | integración |
| CA2 | Los filtros (profesión, ciudad, contrato, salario) funcionan y un filtro desconocido → 422 | integración |
| CA3 | Una oferta confidencial **no** muestra empresa, logo ni nada que la identifique, ni en el listado ni en el detalle ni en errores | integración |
| CA4 | La respuesta nunca incluye datos de reclutadores (nombre, correo) | integración |
| CA5 | `GET /offers/{id}` de un `draft`, `closed` o inexistente → 404, igual en los tres casos | integración |
| CA6 | Paginación con límite máximo (50); `limit=1000` → 422 o se recorta | integración |
| CA7 | El listado no hace N+1 consultas (se mide con el número de queries) | integración |

### Aplicaciones (paso 5)

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

### Panel del reclutador (paso 6)

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

### Matching (paso 7)

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

### Práctica de una oferta (paso 8, ⚠ Fase 3)

| # | Caso | Tipo |
|---|---|---|
| PR1 | `POST /interviews` con `job_offer_id` guarda la referencia y arma las preguntas con el puesto y los requisitos | integración |
| PR2 | El contexto de la sesión usa solo datos **públicos** de la oferta; una confidencial no revela la empresa | integración |
| PR3 | Practicar una oferta no cuenta como aplicar ni la comparte con nadie | integración |
| PR4 | Una oferta cerrada o borrador → 404 | integración |

### Borrado (paso 9)

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

### Frontend (pasos 10 y 11)

| # | Caso | Tipo |
|---|---|---|
| FC1 | `/offers` muestra las ofertas con su puntaje y el porqué; las confidenciales sin empresa | componente |
| FC2 | Aplicar muestra **exactamente** qué se va a compartir con casillas, y sin marcar el consentimiento el botón está deshabilitado | componente |
| FC3 | «Mis aplicaciones» muestra el estado y el historial; retirar pide confirmación | componente |
| FC4 | Desde una oferta se puede «practicar esta entrevista» (⚠ Fase 3) | componente |
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

## Riesgos que se aceptan sabiendo que existen

- **Un reclutador falso es la peor amenaza:** obtendría datos de candidatos. La verificación manual
  lo mitiga y no lo elimina.
- **El huevo y la gallina sigue vivo.** Sin empresas aliadas, esta fase entrega un panel vacío.
- **El matching por habilidades premia el CV bien escrito**, no al mejor candidato.
- **Aplicar a una confidencial es una apuesta** para el candidato.
- **No hay notificaciones:** el candidato tiene que volver a mirar su estado.

## Desvíos y hallazgos

_Vacío hasta que se empiece a implementar._
