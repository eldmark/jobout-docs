# Frontend

**Next.js.** Repo: `jobout-web`.

> **Estado: por construir.** Este archivo tiene las decisiones y reglas ya tomadas. El detalle
> de rutas y componentes se llena con las fases correspondientes.

## Responsabilidad

`jobout-web` **no persiste nada**. Es la interfaz: pinta lo que devuelve `core-api` y conduce
la conversación de audio contra `jobout-interview`.

PII pasa por acá en tránsito. No se guarda en `localStorage`, no se loguea en consola en
producción, no se manda a ninguna herramienta de analítica.

## Autenticación

Clerk. El SDK de Clerk maneja el login, y el JWT resultante va en cada llamada a `core-api`.

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
