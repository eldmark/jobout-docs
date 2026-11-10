# Frontend

**Next.js.** Repo: `jobout-web`.

> **Estado: Fases 1 y 2 hechas (cuenta, perfil y CV) y la entrevista en modo texto de la Fase 3
> en `develop`; la voz y el lado empresa, por construir.** Este archivo tiene las decisiones y reglas ya tomadas. El detalle
> de rutas y componentes se llena con las fases correspondientes.

## Responsabilidad

`jobout-web` **no persiste nada**. Es la interfaz: pinta lo que devuelve `core-api` y conduce
la conversación de audio contra `jobout-interview`.

PII pasa por acá en tránsito. No se guarda en `localStorage`, no se loguea en consola en
producción, no se manda a ninguna herramienta de analítica.

## Autenticación

**MVP: sin Clerk.** El frontend llama a `POST /api/v1/auth/login` y `/register` de `core-api`. Los
tokens van en cookies `HttpOnly`, `Secure`, `SameSite=Lax` (nunca en `localStorage`) y el JWT de
acceso viaja como `Authorization: Bearer` en cada llamada. Clerk queda como camino de escala.

El token efímero de entrevista es distinto y de vida corta: se pide al abrir una sesión y se
usa solo para el WebSocket. No se guarda.

## La sala de entrevista

La pantalla que define el producto. Dos cosas tienen que salir bien:

**Latencia percibida.** Por debajo del segundo entre que el usuario deja de hablar y el
recruiter empieza. Si hay espera, la ilusión se cae. Esto exige streaming de audio en los dos
sentidos, sin esperar respuestas completas.

**El avatar.** En el MVP es una foto con animación mínima: parpadeo, leve movimiento, e
indicador claro de cuándo está hablando y cuándo escucha. La interfaz entre el audio y lo que
se pinta tiene que aguantar el cambio a LivePortrait y MuseTalk sin reescribir la pantalla. Ver
[arquitectura.md](arquitectura.md).

## Capa de audio

- Captura por `getUserMedia`, streaming por WebSocket.
- Detección de fin de turno: el usuario no debería tener que apretar un botón para «terminé de
  hablar».
- Estado visible siempre: escuchando · pensando · hablando. El silencio sin explicación se lee
  como que se rompió.
- Manejo explícito de permiso de micrófono denegado y de corte de conexión a mitad de sesión.

## El dashboard

La pantalla de retorno. Muestra score, confianza y claridad, entrevistas pendientes, ofertas
compatibles y el progreso de niveles. La referencia visual es Duolingo, no LinkedIn: progreso
legible de un vistazo. Ver [producto.md](producto.md).

## Reglas

1. Ningún dato sensible en `localStorage` ni en `sessionStorage`.
2. Ningún `console.log` con datos de usuario en producción.
3. Toda pantalla maneja sus tres estados: cargando, vacío y error. Un estado vacío sin diseñar
   es una pantalla rota.
4. Componente nuevo nace con su prueba. Ver [test.md](test.md).
5. Accesibilidad en la sala de entrevista: la transcripción en vivo no es un extra, es lo que
   la vuelve usable sin audio.

## Por definir

- Librería de componentes y sistema de diseño.
- Manejo de estado del servidor.
- Estrategia de internacionalización — Sofía entrevista en inglés, así que el producto va a ser
  multi-idioma antes de lo que parece.

## Sesión y capa servidor (Fase 1)

El navegador **nunca** ve los tokens. La sesión pasa por *route handlers* de Next que hablan con
`core-api` y guardan los tokens en cookies `HttpOnly; Secure; SameSite=Lax` (`jo_session`,
`jo_refresh`):

| Ruta web | Qué hace |
|---|---|
| `POST /api/auth/register` · `/login` | llama a `core-api` y fija las cookies |
| `POST /api/auth/logout` | llama a `/auth/logout` y borra las cookies |
| `GET /api/auth/refresh` | renueva y vuelve a la página (las páginas del servidor no escriben cookies) |
| `DELETE /api/account` | `DELETE /me` con la contraseña; borra las cookies |

Páginas: `/sign-up`, `/sign-in`, `/dashboard` (protegida), `/adios`. El middleware deja pasar con
`jo_session` **o** `jo_refresh` (el access dura 15 min). Los textos están en
`lib/messages/es.ts`, nunca dentro de los componentes. El borrado de cuenta abre un diálogo
accesible, exige la contraseña y llama a la API una sola vez.

## Perfil y CV (Fase 2)

Páginas protegidas: `/profile/cv` (subir el CV y **revisar lo propuesto**) y `/profile` (ver y editar
el perfil, y descargar, marcar como primario o borrar un CV). El dashboard muestra «Completa tu
perfil» mientras no haya CV ni skills.

- La capa servidor (`app/api/cvs*`, `app/api/profile`, `app/api/catalogs/[nombre]`) reenvía a
  `core-api` con el token de las cookies `HttpOnly`; el navegador nunca ve tokens ni rutas del
  almacén. La descarga pasa por el servidor.
- El selector acepta solo PDF y DOCX y rechaza más de 5 MB **antes** de enviar.
- **Nada se guarda hasta pulsar «Confirmar»**, que llama una sola vez. Las skills se eligen del
  catálogo con búsqueda; no se pueden inventar.
- Si la extracción falla (`sin_texto`, `ilegible`, `tiempo_agotado`), se explica en español y se
  ofrece llenar el perfil a mano.
- `route-guard.ts` deja pasar sin sesión `/api/cvs`, `/api/profile` y `/api/catalogs` hacia sus
  handlers, que responden 401 en JSON; así un `fetch` sin sesión no recibe el HTML de `/sign-in`.

## Entrevista en modo texto (Fase 3)

Páginas protegidas, todas con los textos en `lib/messages/es.ts` (tuteo):

| Página | Qué hace |
|---|---|
| `/interviews` | Elegir recruiter (rol y personalidad) y nivel. Un nivel bloqueado o no disponible sale deshabilitado con el motivo. Si ya hay una sesión activa, ofrece retomarla |
| `/interviews/[id]` | La conversación: turnos en orden, el último mensaje del recruiter anunciado con `aria-live`, enviar con el botón o Ctrl+Enter, pausar, retomar, abandonar y terminar. Al cerrar muestra el resultado |
| `/interviews/[id]/transcript` | La transcripción de solo lectura de una sesión (HU-15) |
| `/interviews/sessions` | Mis entrevistas, con «Cargar más» por cursor |
| `/interviews/progress` | Los cinco niveles, cuáles están desbloqueados, el mejor score y la evolución (HU-22, HU-23) |

El dashboard muestra «Practica una entrevista» y, si hay una sesión `in_progress` o `paused`,
«Retoma tu entrevista».

- La capa servidor (`app/api/recruiters`, `levels`, `progress`, `interviews/**`) reenvía a `core-api`
  con el token de las cookies, igual que el perfil. `lib/interviews/server.ts` solo deja pasar los
  códigos de error del contrato y dos campos de eco validados por formato (`session_id` UUID y
  `renews_at` ISO 8601); cualquier otro campo del backend se descarta. `Retry-After` se reenvía solo
  si son segundos enteros.
- El texto del turno se recorta y se cuenta en caracteres Unicode (4000 como máximo). El textarea no
  lleva `maxlength`, porque cuenta unidades UTF-16 y rechazaría texto válido.
- `done: true` en un turno significa sesión ya `completed`: la interfaz pide `GET .../score` y muestra
  score, claridad y el desglose criterio por criterio con «x / max», su «por qué» y las mejoras.
  `confidence` no se muestra cuando es `null` (siempre, en modo texto).
- La fecha de renovación de `limite_del_plan` se formatea en UTC: la cuota cuenta por mes UTC y en
  Guatemala el día local sería el anterior.
- Pausar, abandonar y borrar piden confirmación antes de llamar a la API. Los 403, 409, 422, 429 y 503
  se explican en español, sin texto técnico; un 503 o un 429 dejan reintentar sin perder lo escrito.
- `route-guard.ts` suma `/api/recruiters`, `/api/levels`, `/api/progress` y `/api/interviews` a las
  carpetas que responden 401 en JSON por sí mismas.
- Todavía no hay audio: la sala de voz, el WebSocket y el avatar son de la Fase 4.
