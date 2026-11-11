# Seguridad

La gente sube su CV, su email, su teléfono, su dirección, su historia laboral y sus cartas de
recomendación. Es de lo más sensible que alguien entrega a un producto, y lo entrega justo
cuando está en una posición vulnerable: buscando trabajo.

Si manejamos eso mal, no hay producto. Y bien manejado es una **ventaja competitiva**, no un
costo.

## Modelo de amenazas

| Amenaza | Consecuencia | Mitigación |
|---|---|---|
| Filtración de la base de datos | PII de todos los usuarios expuesta | Cifrado de columnas a nivel de aplicación: el dump sin la clave no sirve |
| Compromiso del servicio de entrevista | — | Ese servicio **no tiene credenciales de BD ni PII**. No hay nada que robar |
| Secreto commiteado | Acceso total, permanente en el historial | `.gitignore` estricto, revisión de diff, rotación inmediata si pasa |
| PII en logs | Filtración por el canal más descuidado | Ningún campo de PII se loguea. Nunca |
| CV accesible por URL | Documento personal público | S3 privado, solo URLs firmadas de vida corta |
| Acceso horizontal (usuario A lee datos de B) | Filtración dirigida | Toda consulta por id filtra por dueño, igual que el listado |
| Token de entrevista reutilizado | Sesión ajena | Token efímero, alcance de una sola sesión, vigencia de minutos |
| Uso de datos para entrenar | Ruptura de confianza, problema legal | Política explícita y `store: false` en las llamadas al proveedor |

## Frontera de servicios

**`jobout-interview` no recibe PII ni credenciales de base de datos.**

Si te encontrás pasándole el email del usuario a ese servicio, la solución no es cifrarlo antes
de pasarlo: es **no pasarlo**. Trabaja con un id de sesión efímero y con el contexto mínimo de
entrevista que `core-api` le arma. El contrato exacto está en [api.md](api.md).

Esta regla es la que hace que un compromiso de ese servicio sea un incidente de disponibilidad
y no una filtración de datos.

## PII

Se cifran **a nivel de aplicación**, antes de tocar la base de datos:

- email
- teléfono
- dirección
- contenido extraído del CV que incluya datos de contacto

Cifrado en reposo del disco **no alcanza**: protege contra el robo del disco, no contra un dump
de la base ni contra una inyección SQL. Lo que protege contra eso es que la columna llegue
cifrada.

Reglas:

- Ningún campo de PII aparece en logs, mensajes de error, trazas ni métricas.
- Ningún campo de PII cruza a `jobout-interview`.
- Borrar la cuenta borra los datos, no marca una bandera (HU-05).
- Exportación de datos disponible para el usuario (HU-41).

## Transporte y sesión

- **HTTPS obligatorio**, sin excepción, ni siquiera en desarrollo compartido. HSTS en
  producción.
- **JWT cortos** más refresh tokens. Un token robado tiene vida útil corta.
- **MVP: auth propia.** Guardamos credenciales, así que: hash **Argon2id** (m=19 MiB, t=2, p=1),
  contraseña de 10 a 128 caracteres, mensajes que no distinguen «no existe» de «contraseña
  incorrecta», trabajo de Argon2 aunque el email no exista, y bloqueo tras 5 fallos en 15
  minutos por email (`login_attempts`).
- Nada de bcrypt heredado ni SHA para **contraseñas**. SHA-256 sí se usa para el refresh token
  guardado: es un valor aleatorio de 256 bits, no una contraseña elegida por una persona.
- Clerk queda como camino de escala (MFA, Google, recuperación de contraseña).

## Autorización

- **Toda ruta nueva nace autenticada.** Si tiene que ser pública, va un comentario que
  justifique por qué. Una ruta pública sin justificación es un bug.
- Los permisos se comprueban por su literal, nunca por nombre de ruta.
- **Una ruta que exige un permiso lo declara en la tabla** (`Access::Permission("offer.create")`),
  no en el handler. El permiso sale de `user_roles` → `role_permissions` en la **misma consulta de la
  cuenta** que ya hace cada petición, sin caché: quitar un rol corta el acceso en la siguiente
  petición, sin esperar a que venza el JWT. Sin token, 401; cuenta suspendida, 403
  `cuenta_no_disponible`; sin el permiso, 403 `sin_permiso`. El cuerpo es el mismo para todo permiso
  faltante y **no dice cuál** (ni si existe). Un test falla si una ruta que exige permiso se declara
  solo `Authenticated`.
- **Escalada (RO6): ningún endpoint que dé roles puede ser solo `Authenticated`.** Hoy no existe
  ninguno. Los que lleguen exigen `company.invite` (roles de empresa) o `company.verify`
  (verificación de empresas) y nunca dan `admin`.
- **Si un listado filtra filas por dueño, cada acción por id filtra igual.** La falla clásica
  es el listado correcto y el `GET /recurso/{id}` que devuelve el de cualquiera.
- Nada de parámetros de ruta interpolados en SQL.

## Almacenamiento de archivos

- S3 **privado**. Ningún bucket público, ninguna URL permanente.
- Acceso solo por URL firmada de vida corta, emitida por `core-api` tras verificar el dueño.
- Los CVs se validan por tipo y tamaño antes de guardarse.

## Secretos

- `.env`, `.env.*`, `*.pem`, `*.key` están en `.gitignore` en los cuatro repos.
- Se versiona `.env.example` con los nombres de las variables y valores falsos.
- **Si un secreto aparece en un diff, se para todo**: no se commitea, se rota la credencial y
  recién después se sigue. Borrar el archivo en un commit posterior no lo saca del historial.
- En producción, los secretos vienen del gestor del proveedor, no de un archivo en el servidor.

## Auditoría de accesos

Se registra quién accedió a qué dato sensible y cuándo. Sin el contenido del dato: el registro
de auditoría no puede ser la nueva filtración.

## Política pública

> **Nunca usamos tu información para entrenar modelos.**

Cómo se sostiene técnicamente:

- Llamadas al proveedor de LLM con retención desactivada (`store: false` o equivalente).
- Contrato con el proveedor que prohíba el entrenamiento sobre nuestros datos.
- El audio de la entrevista no se persiste salvo que el usuario lo pida explícitamente; la
  transcripción sí, porque es lo que le da valor al feedback y al recuerdo entre sesiones.

Esto no es marketing: es una decisión de arquitectura y hay que poder demostrarla.

## Al escribir código

Reglas cortas, para tenerlas en la cabeza:

1. Ruta nueva nace autenticada.
2. Consulta por id filtra por dueño.
3. PII cifrada antes de la BD, nunca en logs.
4. Nada de SQL construido con interpolación.
5. `jobout-interview` no ve PII.
6. Secreto en el diff = se para todo.

## Pendiente

- Elegir entre clave maestra con rotación propia y un KMS gestionado.
- Definir el proceso de rotación de claves de cifrado de PII.
- Rate limiting por usuario en las sesiones de entrevista, que además contiene el costo.
- Revisión de seguridad antes del primer usuario real.

## Sesión: refresh y borrado (Fase 1)

- **Rotación con detección de robo.** Cada `refresh` revoca el token usado y entrega uno nuevo,
  en una operación atómica. Reusar un token ya rotado o revocado revoca **todas** las sesiones
  del usuario: o lo robaron, o se está usando dos veces.
- Respuesta única (`sesion_invalida`) para token desconocido, expirado o reutilizado.
- `DELETE /me` exige la contraseña, cuenta los intentos fallidos con el mismo contador de
  `login_attempts` y deja constancia sin datos personales en `privacy_events`.
- Los errores de base de datos se registran por categoría, nunca con su texto: puede traer
  valores de la fila.

## Archivos de CV y logs (Fase 2)

- **Validación por contenido**, nunca por extensión ni `Content-Type`; 5 MB como máximo, y la lectura
  se corta al llegar al tope (un cuerpo infinito o un `Content-Length` mentiroso no agotan memoria).
  Contra archivos maliciosos: 15 páginas de PDF, 20 MB descomprimidos de DOCX (se suma el tamaño
  declarado de todas las entradas **antes** de leer, contra zip bombs) y 10 s de tope. Sin `unsafe` ni
  procesos externos. **Riesgos que quedan:** el hilo de parseo no se puede cancelar (si `lopdf` se
  cuelga de verdad, sigue gastando CPU aunque la petición ya respondió), un PDF con streams
  comprimidos enormes no tiene tope de memoria propio, y no hay antivirus.
- **El nombre del archivo nunca forma parte de la clave de almacén** (es un UUID v7 aleatorio) y solo
  se muestra saneado. `cvs.storage_key` y las claves de la bandeja de borrado se guardan cifradas.
- **El texto extraído no se guarda en ningún lado**, y el extractor **no extrae datos de contacto**,
  porque `cv_extractions.extracted` no se cifra.
- **`description` de las experiencias y el teléfono van cifrados.** `company` y `title` en claro (el
  matching futuro los necesita); es una decisión abierta del plan.
- **Almacén en disco = solo desarrollo:** directorio `0700`, archivos `0600`, escritura atómica y sin
  sobrescribir. No tiene redundancia ni cifrado en reposo propio. **Hay que usar S3 antes de
  producción.**

### Los logs nunca llevan valores de consultas

`sea-orm` abre un *span* de nivel `trace` por cada consulta con la sentencia **y sus valores** como
campos, y cualquier evento dentro (incluso un INFO propio) los imprime como contexto. Varios valores
van en claro: nombres, descripción del perfil, empresa, cargo, nombre del archivo. Con
`RUST_LOG=trace` salían en los logs.

`telemetry::env_filter` fija **por código** que `sea_orm`, `sqlx` y `sea_orm_migration` no pasen de
`warn`, venga lo que venga en `RUST_LOG`. Desactivar `sqlx_logging` **no** basta (se probó). Las
pruebas de logs capturan con ese filtro al máximo. Verificado con el binario real y `RUST_LOG=trace`.

### Entrevista (Fase 3)

Contrato en [api.md](api.md#entrevista-fase-3). Lo que la seguridad exige de él:

- **La transcripción es dato sensible** y se guarda **cifrada** (`interview_turns.transcript`). Una
  sesión ajena responde 404, nunca 403.
- **El texto de la persona, el del recruiter y el desglose no se escriben en ningún log** (ni de
  peticiones correctas ni de errores) y los 422 no repiten lo enviado. `POST /interviews/{id}/turns`
  declara su propio tope de cuerpo (32 KB): el global de 8 KB no alcanza para 4000 caracteres.
- **Tope de uso:** 20 turnos por minuto por persona (429), 40 turnos por sesión y una sola sesión
  activa; contienen abuso y, cuando entre el motor de IA, costo.
- **Texto como dato, nunca como instrucción:** lo que la persona escribe no cambia el score ni el
  comportamiento del motor (caso X8, que se repite con el motor de IA).
- **El motor no recibe PII ni ids de persona**, solo el historial y la configuración del recruiter.

### Redacción con IA del recruiter (JB-88)

Apagada por defecto (`AI_REPLIES_ENABLED`). Cuando se enciende, un modelo **gratuito** de OpenRouter
redacta lo que dice el recruiter; la evaluación, la cuota y los desbloqueos siguen siendo deterministas.

- **Lo que se envía**: rol y nivel del recruiter, el título de la oferta (si es una práctica de oferta),
  la pregunta que eligió el motor determinista y los **últimos 4 mensajes** de la conversación. **Las
  respuestas de la persona viajan** (el modelo no puede reaccionar a lo que no ve). **No** se envían
  nombre, correo, ids, contenido del CV ni nombre de empresa; el motor no los recibe (la frontera del
  motor no cambia) y `tests/interview_ai_replies_flow.rs` lo fija con nombres y un correo plantados.
- **Aviso obligatorio antes del uso real**: los modelos gratuitos de OpenRouter **pueden registrar y
  usar los prompts para entrenar**. La pantalla de inicio de la entrevista de `jobout-web` lo dice
  (JB-92) **solo cuando el servidor informa `ai_replies: true`** en `GET /recruiters`, y pide marcar una
  casilla de conocimiento antes de «Empezar entrevista»; con la IA apagada no cambia nada. El aviso pide
  además no escribir datos personales sensibles: la persona escribe sin saber que puede haber otro destino
  que `core-api`. La casilla **no se guarda en el servidor** (es un freno en la pantalla, no un
  consentimiento auditable); si se necesitara probarlo, sería una decisión y una migración aparte.
- **La clave** (`OPENROUTER_API_KEY`) solo se lee del entorno, va en la cabecera `Authorization` y no
  se escribe en logs, errores, pruebas ni documentos. `Debug` de la configuración la oculta.
- **Los logs no llevan contenido**: solo el modelo, la razón del fallo, la latencia y un contador
  (`fallbacks_total`). Nunca el texto de la persona, el del recruiter ni lo que devolvió el modelo.
- **El texto de la persona es dato, no instrucción**: va entre `<candidato>…</candidato>` (se le quitan
  los `<` y `>`), nunca en el prompt de sistema; el modelo no puntúa. Si el resultado parece una fuga del
  prompt, está en otro idioma, tiene markdown o prefijos de rol, se limpia o se descarta.
- **Tope de costo y de espera**: 200 tokens de salida, 600 caracteres, 8 s por intento, hasta 3 modelos.
  Mientras el modelo contesta, el turno sigue dentro de su transacción (la sesión queda bloqueada por
  `turno_en_proceso`); el peor caso por turno es la suma de los intentos.

## Ofertas, empresas y panel (Fase 5a)

Contrato en [api.md](api.md#ofertas-y-empresas-fase-5a). Es la primera vez que los datos de una persona
los ve otra: el modelo de amenazas de arriba no tenía esta fila.

| Amenaza | Consecuencia | Mitigación |
|---|---|---|
| Reclutador falso | Datos de candidatos a un tercero | Empresa sin verificar no publica ni recibe aplicaciones; verificación manual por `company.verify` con fila en `access_audit`; `unverify` corta el acceso; límite de 120 detalles por hora; el admin de plataforma no lee aplicaciones |
| Compartir de más | El reclutador ve lo que la persona no aceptó | Consentimiento explícito por aplicación, conjunto cerrado de campos, lo no marcado no viaja, CV y datos sensibles inexistentes en la API; test de que cada campo ausente no está en la respuesta |
| Confidencial deanonimizada | La empresa se conoce antes de tiempo | `company` nulo en listado, detalle, errores y «mis aplicaciones» hasta `shortlisted`, por aplicación; sin filtro, orden ni búsqueda por empresa ni por texto |
| Discriminación | Filtrar por edad, género, estado civil o nombre | Parámetros y campos cerrados: lo demás es 422 antes de tocar la base; tests que fallan si aparecen |
| Acceso horizontal entre empresas | Una empresa lee aplicaciones o favoritos de otra | La empresa sale de la membresía, no del path; 404 idéntico para ajeno e inexistente |
| Invitación robada | Un tercero entra a una empresa | Token de 256 bits, solo su hash en la base, un uso, 7 días, atada al correo de la invitación, 10 intentos por hora |
| Escalada de rol | Un reclutador se vuelve admin | Los roles de empresa solo se dan al crear la empresa o aceptar una invitación; `admin` no se da por la API |

**Huecos que esta fase encontró** (decididos en el contrato o aceptados y dichos):

- **`married_last_name` y segundo apellido** son datos de estado civil: nunca salen en `display_name` ni
  en ninguna respuesta al reclutador.
- **El nombre ya delata género u origen.** `display_name` es obligatorio al aplicar (decisión 2), así que el
  sesgo por nombre queda **abierto**: lo único que se impide es filtrar u ordenar por él. Evaluar una
  revisión ciega (nombre visible desde `under_review`) antes de abrir al público.
- **`tax_id` de una empresa puede ser el DPI/NIT de una persona** (un negocio individual): se cifra y se
  busca por HMAC, como el correo. En `db.md` estaba en claro.
- **El texto de una oferta confidencial puede nombrar a la empresa** y el servidor no lo puede detectar. Es
  responsabilidad de quien publica; la UI lo avisa. Riesgo aceptado.
- **Las notas del reclutador son texto libre** y pueden traer datos de la persona: se cifran
  (`job_application_events.note`).
- **Roles globales, pertenencia por empresa.** `user_roles` no sabe de empresas: un permiso sin fila en
  `company_recruiters` no sirve (404). Hay que probarlo, no solo asumirlo.
- **Ver en vivo, no copiar.** El panel lee el perfil de la persona filtrado por `shared_fields`; no hay
  copia que purgar, y retirar o borrar cortan el acceso de inmediato. Contra: lo que la empresa vio ya
  no se puede probar después (se prueba con `access_audit`, sin contenido).
- **`access_audit` crece con cada vista** y, si falla el insert, la petición falla: es adrede (sin dato
  sin rastro). Falta su particionado (ya anotado en `db.md`).
- **El nombre de una empresa en un error o log** de una confidencial no debe salir nunca: los errores son
  de texto fijo y el rastro de logs no lleva ids de empresa en rutas de candidato.
- **No hay antiabuso de contenido**: nada impide publicar una oferta falsa o fraudulenta (cobrar por
  aplicar, pedir datos extra). La verificación manual lo mitiga; falta un canal de denuncia.
- **Rate limiting** de esta fase (SX5) sale de filas persistentes, no de memoria del proceso; el
  de la entrevista sigue en «Pendiente».
- **Sin empresa cerrable:** no hay ruta para cerrar una empresa ni para borrar al único `company_admin`;
  hasta que exista, lo hace el equipo y queda a mano.
- **Legal:** consentimiento y retención (90 días tras el cierre) necesitan revisión de un asesor antes del
  primer usuario real, como pide el plan de la fase.
