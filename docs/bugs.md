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
| BUG-005 | Baja | jobout-web | En `/interviews/sessions` los enlaces «Ver resultado» y «Ver transcripción» salen pegados («Ver resultadoVer transcripción»), sin separación, y se parten en dos líneas | Terminar una entrevista y abrir «Ver mis entrevistas» en un ancho de 1560 px. Visto el 2026-11-10 | Falta espacio o un contenedor flex entre los dos enlaces de la columna Acciones |

## Cómo se anota uno

- **ID**: `BUG-001` correlativo, no se reutiliza aunque el bug se cierre.
- **Síntoma**: qué ve el usuario, no qué creés que lo causa.
- **Repro**: los pasos mínimos. Si no lo pudiste reproducir, decilo — es información.
- **Notas**: qué se descartó ya. Le ahorra media hora al siguiente.

Un bug de seguridad con datos expuestos no espera turno en esta tabla: se arregla, se rota lo
que haya que rotar, y después se documenta.
