# Pruebas

## Las dos reglas

**1. Cada función nueva nace con su prueba unitaria.**
No existe «las pruebas después». Una función sin prueba es una función que nadie va a poder
refactorizar con confianza dentro de tres meses.

**2. Cada endpoint o flujo entre servicios nace con su prueba de integración**, escrita al
momento de implementarlo. No en una fase posterior de «agregar tests»: esa fase nunca llega, y
cuando llega ya nadie recuerda cuál era el comportamiento correcto.

Un PR que agrega comportamiento sin pruebas no se mergea. No es rigor por rigor: es que el
producto maneja PII y cobra dinero.

## Por repo

| Repo | Cómo se corre | Qué hay hoy |
|---|---|---|
| `jobout-core-api` | `make test-api` (desde `jobout-docs`) o `cargo test --workspace` con `TEST_DATABASE_URL` | Unitarias por módulo e integración contra **PostgreSQL real** en `tests/` |
| `jobout-interview` | `pytest` / `pytest -m integration` con el proveedor simulado | Repo creado con solo documentación; el código llega en la Fase 4 (ver `docs/pruebas.md` allá) |
| `jobout-web` | `npm test` (vitest + Testing Library) o `make test-web` | Lógica pura, componentes y *route handlers* con `fetch` simulado. Playwright para flujos completos: **no está instalado todavía** |

### Backend: PostgreSQL real, nunca SQLite

Los enums de PostgreSQL, los índices parciales y las FK se comportan distinto en otros motores, así
que las pruebas de esquema y de endpoints corren contra PostgreSQL.

- `make test-api` levanta solo el servicio `postgres` y le pasa a las pruebas el puerto de tu `.env`
  (`DB_PORT`).
- Sin `make`: `TEST_DATABASE_URL=postgres://jobout:jobout@localhost:<puerto>/postgres cargo test --workspace`.
  Si no se define, las pruebas usan el puerto `5532`.
- **Cada prueba crea su propia base** (`test_<uuid>`), la migra y la borra al terminar
  (`tests/common/mod.rs`). Nunca tocan la base `jobout` de desarrollo.
- En CI hay un servicio `postgres` y `TEST_DATABASE_URL` apunta a él; el CI corre
  `cargo test --workspace` para no dejar crates sin probar (el de `migration` también).

### Cómo se sabe que un test sirve

Un test que nunca falló no prueba nada. Al terminar una tarea se **rompe el código a propósito**
(quitar una comprobación, invertir una condición) y se verifica que un test cae; después se
restaura. Si la mutación sobrevive, o el test no sirve o la mutación era equivalente (y se
descarta con una nota). Así se encontraron huecos en la Fase 1.

## Qué se prueba en cada nivel

**Unitarias** — lógica pura: cálculo de score, extracción de datos del CV, validaciones,
cifrado y descifrado de PII. Rápidas, sin red, sin base de datos.

**Integración** — el endpoint completo con su base de datos: que el JWT se valide, que la
autorización filtre, que la migración corresponda al modelo, que el error no filtre PII.

**End-to-end** — los flujos que definen el producto: registro → subir CV → primera entrevista →
score. Pocos, pero estos no pueden romperse.

## Probar la entrevista sin quemar la API

Una prueba de integración que llame a OpenAI Realtime de verdad es lenta, cara y da distinto
cada vez. No se hace.

- **El proveedor se simula.** El servicio habla contra una interfaz; en pruebas se inyecta una
  implementación que devuelve turnos grabados.
- **Los turnos grabados son datos de prueba versionados**: transcripciones reales de sesiones de
  desarrollo, sin PII, guardadas como fixtures. Cubren el caso bueno, la respuesta vaga que
  debe disparar repregunta, y el silencio.
- **Contra el proveedor real se corre a mano**, cuando se cambia el prompt de un recruiter o el
  modelo. No en CI, no en cada PR.
- El cálculo de score se prueba **siempre** contra transcripciones fijas: dada esta
  conversación, este score. Si el número cambia sin que se haya tocado la rúbrica, hay un bug.

### La entrevista de texto hoy (Fase 3)

- **El motor es puro y determinista** (`src/interview/`): banco de preguntas, repreguntas y evaluación
  se prueban sin base ni red en `tests/interview_engine.rs`. El mismo historial da siempre la misma
  respuesta y el mismo score.
- **Las rutas reciben el motor por `AppState.engine`**, igual que el almacén de archivos. Las pruebas
  enchufan `ScriptedEngine` (devuelve lo que se le indica) o un motor que falla, para probar el 503 y
  el «todo o nada» del turno.
- **La concurrencia se prueba de verdad**, sin `sleep`: varias peticiones simultáneas contra
  PostgreSQL real, y una compuerta en el motor que retiene al ganador hasta que los perdedores ya
  recibieron su 409.
- **Las pruebas de tiempo miden CPU, no reloj de pared** (`tests/timing/mod.rs`): el mínimo de varias
  repeticiones del tiempo de CPU del hilo. En Linux (CI y Docker) usa `CLOCK_THREAD_CPUTIME_ID`; en
  otros sistemas cae al reloj de pared y puede ser menos estable.
- **La cuota**: las pruebas que crean muchas sesiones con la misma persona la apagan con
  `ENFORCE_PLAN_LIMITS=false`; la cuota se prueba en `tests/interview_quota.rs`, y el interruptor en
  `tests/interview_quota_off.rs`, en su propio binario porque cambia el entorno del proceso. El mes se
  calcula con un reloj inyectado, así que la frontera de mes no espera ni duerme.
- **Que el texto no llegue a los logs** se comprueba con una marca única en la respuesta y una captura
  de logs, más una prueba de que la captura funciona (si no capturara nada, el test pasaría siempre).

## Pruebas obligatorias de seguridad

Estas no son opcionales en ningún endpoint que toque datos de usuario:

- **Acceso horizontal**: el usuario A pide por id un recurso de B y recibe 404 o 403, nunca el
  dato.
- **Sin token**: la ruta responde 401. Vale para toda ruta que no tenga el comentario que
  justifica ser pública.
- **PII fuera de logs y errores**: se provoca un error con datos sensibles en la entrada y se
  verifica que no aparecen en la respuesta ni en el log.
- **Frontera de servicios**: se verifica que la carga que `core-api` manda a `interview` no
  contiene ningún campo de PII.

## Antes de decir «funciona»

1. Pruebas del módulo que tocaste, verdes.
2. **La pantalla abierta en un navegador.** Las pruebas verdes no dicen que la vista sirva: un
   dashboard puede pasar toda su suite y mostrar `NaN` en el score.
3. Si una prueba falla, se muestra la salida real. Si se saltó un paso, se dice.

## Por definir

- Configuración de CI y qué corre en cada PR.
- Umbral de cobertura, si es que se pone uno.
- Playwright para los flujos completos del frontend (hoy el recorrido de punta a punta se hace
  a mano con el backend real y queda anotado en el archivo de la fase).
