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
| BUG-001 | Alta | jobout-web | Si se envía el registro o el ingreso antes de que la página termine de cargar el JavaScript, la URL queda como `/sign-up?...&email=...&password=...`: la contraseña y el correo quedan en el historial del navegador y en el log del servidor de Next | Primera carga de `/sign-up` en `next dev` (compila varios segundos), llenar el formulario y pulsar «Crear cuenta» enseguida. Visto el 2026-11-10 en el recorrido de la Fase 3, con una cuenta de prueba local | `AuthForm.tsx` usa `<form onSubmit>` sin `method`: antes de hidratar, el navegador hace el envío nativo por GET. Arreglo propuesto: `method="post"` y el botón deshabilitado hasta hidratar, con una prueba que lo fije. Sería Crítica con usuarios reales; todavía no hay producción |
| BUG-002 | Baja | jobout-web | `/interviews/sessions` dice «Mostrando 1 entrevistas.» | Terminar una entrevista y abrir «Ver mis entrevistas» con una sola sesión. Visto el 2026-11-10 | El texto no distingue singular de plural |
| BUG-003 | Baja | jobout-core-api | `cargo clippy --all-targets --all-features -- -D warnings` falla dentro del contenedor de desarrollo (`clippy::search_is_some` en `tests/cvs.rs:347`), mientras el mismo comando pasa en el CI | `docker compose exec core-api cargo clippy --all-targets --all-features -- -D warnings` en `develop` (2026-11-10) | El contenedor usa Rust 1.90 (`Dockerfile`, `rust-version = "1.88"`) y el CI `dtolnay/rust-toolchain@stable` (1.99.1 ese día): lo que valida uno no lo valida el otro. Arreglo propuesto: fijar una versión en los dos (`rust-toolchain.toml`) y usar `!…contains(…)` en esa línea |

## Cómo se anota uno

- **ID**: `BUG-001` correlativo, no se reutiliza aunque el bug se cierre.
- **Síntoma**: qué ve el usuario, no qué creés que lo causa.
- **Repro**: los pasos mínimos. Si no lo pudiste reproducir, decilo — es información.
- **Notas**: qué se descartó ya. Le ahorra media hora al siguiente.

Un bug de seguridad con datos expuestos no espera turno en esta tabla: se arregla, se rota lo
que haya que rotar, y después se documenta.
