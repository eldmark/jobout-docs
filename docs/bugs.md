# bugs.md — bugs abiertos

**Solo bugs abiertos.** Cuando uno se cierra, se borra la fila de acá y el cierre se anota en
[`continue.md`](continue.md). Este archivo tiene que poder leerse de un vistazo; si crece a
treinta filas, el problema no es el archivo.

## Severidad

| Nivel | Qué significa |
|---|---|
| **Crítica** | Datos en riesgo, secreto expuesto, o el producto no funciona |
| **Alta** | Un flujo principal roto o degradado para todos los usuarios |
| **Media** | Falla en un caso concreto, con rodeo posible |
| **Baja** | Molestia, cosmético, deuda técnica |

## Abiertos

| ID | Sev | Repo | Síntoma | Repro | Notas |
|---|---|---|---|---|---|
| BUG-004 | Media | jobout-core-api | El score de una entrevista con respuestas buenas sale injusto: «Relevancia 7/20: las respuestas se alejan de las preguntas», «Especificidad: faltan cifras» (había 12, 0 y 300) y «Estructura: no aparecen las tres partes» (había situación, acción y resultado). Score 61 para respuestas concretas | Terminar una entrevista con Martín/Junior: una respuesta vaga («Hice una app web con mi equipo.»), dos concretas con herramientas, cifras y decisiones. Visto el 2026-11-10 | Promedia todas las respuestas, incluida la vaga que provocó la repregunta, y la relevancia compara raíces de 5 letras con la pregunta. Es el límite del evaluador determinista (ya anotado en la Fase 3), pero el «por qué» se lee como un error. Material para Luis y para el motor de la Fase 4 |
| BUG-006 | Media | jobout-web | Con la suite completa, `interview-room`, `interview-sessions` e `interview-transcript` fallan a veces (2 de 8 corridas en `develop`) | `npm test` varias veces en `develop`; con las pruebas de la Fase 5a encima, 5 de 8 | Carrera de la prueba, no del componente: el foco se mueve en un `useEffect` y la prueba lo mira antes. **Arreglo en web #16** (0 de 8 después), sin mergear |
| BUG-007 | Baja | jobout-web | Otras dos pruebas inestables: `sign-forms` «/sign-up (F7) 422 y fallo de red…» e `interview-start` «F13 403 limite_del_plan…» | Aparecieron en las corridas de medición de BUG-006 | Causa: el `role="alert"` de los formularios existe siempre (vacío) y la prueba miraba su texto en cuanto lo encontraba. La misma carrera estaba en `cv-flow`, `profile-view` y `delete-account`. **Arreglo en web #18**, sin mergear |
| BUG-008 | Baja | jobout-web | En el detalle del panel del reclutador, «Habilidades» y «Experiencia» salen como títulos vacíos cuando la persona no tiene ninguna, sin un texto que lo diga | Recorrido del 2026-11-11: una candidata sin perfil aplica y el reclutador abre el detalle | Falta un estado vacío, como el que el diálogo de consentimiento ya muestra del lado de la persona. **Arreglo en web #19** (apilado sobre #17), sin mergear |
| BUG-009 | Baja | jobout-web | Una persona sin empresa que abre `/company/offers/{id}/applications` ve «Tu rol en la empresa no permite hacer esto.» | Recorrido del 2026-11-11, con la cuenta de la candidata | La API responde bien (403 `sin_permiso`); el texto supone que la persona tiene empresa. **Arreglo en web #20** (apilado sobre #17), sin mergear |
| BUG-010 | Baja | jobout-web | En el detalle del panel, una habilidad con un año de experiencia diría «1 años» | Visto leyendo el código al arreglar BUG-008: `panel.skill.years` es «{n} años» sin singular | Mismo caso que BUG-002 (web #11). **Arreglo en web #21** (apilado sobre #19), sin mergear |
| BUG-005 | Baja | jobout-web | En `/interviews/sessions` los enlaces «Ver resultado» y «Ver transcripción» salen pegados («Ver resultadoVer transcripción»), sin separación, y se parten en dos líneas | Terminar una entrevista y abrir «Ver mis entrevistas» en un ancho de 1560 px. Visto el 2026-11-10 | Falta espacio o un contenedor flex entre los dos enlaces de la columna Acciones. **Arreglo en web #14**, sin mergear |
| BUG-011 | Media | jobout (compose) / core-api | `docker compose up --build -d` falla al construir `core-api` con «can't stat …/jobout-core-api/data» (permission denied) | Con el stack ya levantado, correr `docker compose up --build -d` en `jobout/`. Visto el 2026-11-11 | `data/` (el `BLOB_DIR`) lo crea Docker como `root` con modo 0700 y `.dockerignore` no lo excluye, así que el contexto de build no puede leerlo. Rodeo usado: `docker compose build web` y `up -d --no-deps` (el servicio `web` no necesita construir `core-api`). Arreglo: agregar `data/` al `.dockerignore` del core-api |
| BUG-012 | Media | jobout (compose) / web | Tras traer un PR que agrega una dependencia (`three`, JB-77) la sala de entrevista corre sin avatar: no hay ni el círculo con la inicial (0 `canvas`, 0 `.avatar` en el DOM) | Con el contenedor `web` ya levantado, `git pull` de web `develop` y abrir una entrevista. Visto el 2026-11-11 | `node_modules` es un volumen anónimo (`- /app/node_modules`): sobrevive a `git pull` y no trae `three` (`ls node_modules/three` → no existe). Se arregló con `docker compose build web && docker compose up -d --no-deps --force-recreate -V web`. Falta documentarlo en el README/`make dev`, o que el comando de arranque haga `npm ci` si cambia `package-lock.json`. No se pudo explicar por qué tampoco aparece el fallback del avatar |
| BUG-013 | Media | jobout-web | En `/offers` a 1560 px los selectores de «Filtrar ofertas» se solapan: «Profesión», «Tipo de contrato» y «Sector» quedan tapados por la columna de al lado y «Ordenar» se sale de la tarjeta. A 390 px (una columna) se ve bien | Entrar como candidato y abrir `/offers` en una ventana ancha. Captura: `scratch/walk/evidence/screenshot-1794412229204-14.jpg` | Es un problema de la rejilla (los `select` no respetan el ancho de su celda), no de datos. Visto el 2026-11-11 |
| BUG-014 | Media | jobout-web (+ decisión de producto) | Borrar la cuenta siendo el único administrador de una empresa muestra «No pudimos borrar tu cuenta. Sigue activa; inténtalo de nuevo.», aunque la API responde 409 `ultimo_administrador` con «Eres el único administrador de tu empresa. Nombra a otro antes de borrar la cuenta.» | Registrar empresa, ir a `/dashboard` → «Borrar mi cuenta» con la contraseña. Visto el 2026-11-11 (también con un administrador y un reclutador en el equipo) | El texto no le dice a la persona qué hacer. Además, quien es único miembro de su empresa **no puede borrar la cuenta nunca**: no hay ruta para cerrar la empresa (ya documentado en `api.md`) y quitarse a sí mismo da el mismo 409. Para limpiar las cuentas de prueba hubo que borrar la empresa con SQL. Conviene decidir si la 5b cierra la empresa o permite borrar la cuenta con la empresa |
| BUG-015 | Baja | jobout-web | El diálogo «¿Borrar tu cuenta?» solo dice «Tu perfil y tus datos personales» y «Tu historial de prácticas». No menciona que las aplicaciones enviadas siguen en la empresa sin tu nombre (y, para un reclutador, qué pasa con sus ofertas y decisiones) | Abrir el diálogo con una cuenta que tenga aplicaciones | Comprobado en la base: las aplicaciones quedan con `applicant_id` nulo y `shared_fields` vacío, las ofertas con `created_by` nulo y las notas internas de los eventos se conservan cifradas. El texto debería decirlo |
| BUG-016 | Baja | jobout-web | Al abrir la sala de entrevista el `textarea` toma el foco y la página baja sola: el avatar y el encabezado quedan fuera de la pantalla (1560×723 y 390 px) | Iniciar una entrevista y mirar la primera pantalla | El avatar se ve solo si la persona sube. Probar `preventScroll` en el `focus()` o enfocar tras mostrar el avatar |
| BUG-017 | Baja | jobout-web | El orden «Mejor afinidad» y los filtros de `/offers` no quedan en la URL (`location.search` vacío): no se pueden compartir ni sobreviven a «atrás» | Elegir «Mejor afinidad» → Filtrar | Funciona bien en pantalla (100 %, 47 %, 0 %); solo falta el estado en la URL |
| BUG-018 | Baja | jobout-web | El `/dashboard` de una persona con empresa o de la admin sigue mostrando bloques de candidato («Completa tu perfil», «Practica una entrevista», «Aquí aparecerá tu progreso»); la admin ve además «Registrar mi empresa» | Entrar con la cuenta de reclutador y con la de plataforma | Cosmético; no rompe nada |

## Cómo se anota uno

- **ID**: `BUG-001` correlativo, no se reutiliza aunque el bug se cierre.
- **Síntoma**: qué ve el usuario, no qué creés que lo causa.
- **Repro**: los pasos mínimos. Si no lo pudiste reproducir, decilo — es información.
- **Notas**: qué se descartó ya. Le ahorra media hora al siguiente.

Un bug de seguridad con datos expuestos no espera turno en esta tabla: se arregla, se rota lo
que haya que rotar, y después se documenta.
