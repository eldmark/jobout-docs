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
| — | — | — | Ninguno abierto | — | — |

## Cómo se anota uno

- **ID**: `BUG-001` correlativo, no se reutiliza aunque el bug se cierre.
- **Síntoma**: qué ve el usuario, no qué creés que lo causa.
- **Repro**: los pasos mínimos. Si no lo pudiste reproducir, decilo — es información.
- **Notas**: qué se descartó ya. Le ahorra media hora al siguiente.

Un bug de seguridad con datos expuestos no espera turno en esta tabla: se arregla, se rota lo
que haya que rotar, y después se documenta.
