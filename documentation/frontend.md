# Frontend

**Next.js.** Repo: `jobout-web`.

> **Estado: Fase 1 hecha (ingreso, registro, dashboard y borrado de cuenta);
> el resto por construir.** Este archivo tiene las decisiones y reglas ya tomadas. El detalle
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
