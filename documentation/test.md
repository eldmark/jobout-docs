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

| Repo | Unitarias | Integración |
|---|---|---|
| `jobout-core-api` | `cargo test` | `cargo test --test integration` contra una BD de prueba |
| `jobout-interview` | `pytest` | `pytest -m integration` con el proveedor simulado |
| `jobout-web` | `vitest` | Playwright para los flujos completos |

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
- Base de datos de prueba: contenedor efímero por corrida contra una compartida.
