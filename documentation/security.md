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
