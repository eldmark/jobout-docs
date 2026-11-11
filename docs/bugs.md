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

## Cómo se anota uno

- **ID**: `BUG-001` correlativo, no se reutiliza aunque el bug se cierre.
- **Síntoma**: qué ve el usuario, no qué creés que lo causa.
- **Repro**: los pasos mínimos. Si no lo pudiste reproducir, decilo — es información.
- **Notas**: qué se descartó ya. Le ahorra media hora al siguiente.

Un bug de seguridad con datos expuestos no espera turno en esta tabla: se arregla, se rota lo
que haya que rotar, y después se documenta.
