# Cómo se contribuye a JobOut

Aplica a los cuatro repos: `jobout-docs`, `jobout-core-api`, `jobout-interview` y `jobout-web`.

Las reglas de trabajo para agentes de IA están en [`AGENTS.md`](AGENTS.md). Este archivo es lo
que necesita una persona: ramas, PRs, revisión y cómo se escriben las pruebas.

---

## Ramas

```
jb-##-implementation
```

- `jb-` — prefijo fijo del proyecto
- `##` — número de la tarea o issue
- `implementation` — o el slug que describa el trabajo

```
jb-07-implementation
jb-12-auth-clerk
jb-19-fix-zone-fk
```

**Nunca se commitea directo a `main`.** Rama, PR, revisión, merge.

Una rama = una tarea. Si a mitad de camino descubrís algo que no era parte de la tarea,
anotalo en [`docs/bugs.md`](docs/bugs.md) y abrí otra rama. Un PR que hace tres cosas no lo
revisa nadie bien.

---

## Antes de escribir código: los casos de verdad

**Cada tarea define sus casos de verdad en su archivo de fase, antes de implementar.**

Un «caso de verdad» es una afirmación verificable sobre el comportamiento correcto: dada esta
entrada y este estado, tiene que pasar exactamente esto. No es «probar que el login funciona»
— es «con contraseña vencida devuelve 401 y no crea sesión».

El flujo:

1. Quien toma la tarea escribe los casos de verdad en `docs/working/faseN-*.md`.
2. **El equipo los revisa antes de que se escriba una línea de implementación.** Acá es donde
   se discute qué es correcto; discutirlo después, sobre código ya escrito, sale mucho más caro.
3. Recién con los casos acordados se abre la rama y se implementa.

Escribí los casos como afirmaciones que se pueden convertir en un test uno a uno:

```
✅  Un candidato no puede leer el `personal_data` de otro candidato: devuelve 404
✅  Aplicar dos veces a la misma oferta falla con conflicto, no crea una segunda fila
✅  Al borrar la cuenta, `personal_data` y `cvs` desaparecen y queda un `privacy_event`
❌  Verificar que el perfil funciona bien
❌  Probar los casos borde
```

Los dos últimos no son casos de verdad: no se puede escribir un test a partir de ellos.

**Casos que van sí o sí en toda tarea que toque datos de usuario** (ver
[`documentation/test.md`](documentation/test.md)):

- Acceso horizontal: el usuario A pide un recurso de B y no lo obtiene
- Sin token: la ruta responde 401
- El error provocado con datos sensibles no filtra PII en la respuesta ni en el log

---

## Desarrollo guiado por pruebas

El orden no es negociable:

```
1. Escribí el test del caso de verdad     →  falla (rojo)
2. Escribí el mínimo código que lo pasa   →  pasa (verde)
3. Limpiá sin cambiar el comportamiento   →  sigue verde
```

Que el test **falle primero** no es ceremonia: un test que nunca falló no prueba nada. Es
igual de fácil escribir un test que pasa siempre.

En el PR se nota: el primer commit trae los tests en rojo, los siguientes los ponen en verde.
El CI corre en cada push, así que el rojo inicial queda registrado.

**Cada función nueva nace con su prueba unitaria. Cada endpoint o flujo entre servicios nace
con su prueba de integración.** No existe «las pruebas después».

---

## El pull request

El título repite la rama y agrega qué hace:

```
jb-07-implementation — perfil del candidato y carga de CV
```

El cuerpo sale de [`.github/pull_request_template.md`](.github/pull_request_template.md), que
se carga solo. Cuatro secciones, todas obligatorias:

### 1. Qué se hizo

En prosa, para alguien que no siguió la tarea. El **qué** y el **para qué**, no el cómo.

### 2. Cómo se resolvió

Las decisiones que tomaste y por qué. Lo que descartaste y por qué. Si hay un rodeo feo,
decilo acá: el reviewer lo va a encontrar igual, y es mejor que lo encuentre explicado.

### 3. Archivos tocados

Tabla con cada archivo y qué le pasó. `git diff --name-status main` te da la lista; la columna
de explicación la escribís vos. Sirve para que el reviewer sepa dónde mirar primero.

### 4. Migraciones

**Si hay cambio de esquema, esta sección no puede estar vacía.** El nombre de la migración,
qué tablas y columnas cambia, si es reversible y si necesita algo especial al desplegar.

Y `documentation/db.md` **actualizado en este mismo PR**. Un PR con migración y sin ese cambio
no se aprueba.

Si no hay migraciones, se escribe «Ninguna». No se borra la sección.

---

## Revisión

- **Una aprobación** y **CI en verde** para mergear.
- No te apruebes tu propio PR.
- Un push nuevo invalida las aprobaciones anteriores: el reviewer aprobó un código, no una
  intención.
- El reviewer mira **los tests primero**. Si los casos de verdad no están cubiertos, el resto
  del código no importa todavía.

**Qué bloquea un merge:**

| Bloquea | Por qué |
|---|---|
| Un secreto en el diff | Se para todo, se rota la credencial, después se sigue |
| Migración sin `documentation/db.md` actualizado | El siguiente le cree al doc desactualizado |
| Comportamiento nuevo sin prueba | No se va a poder refactorizar en tres meses |
| PII en un log o en un mensaje de error | Es la filtración por el canal más descuidado |
| Ruta nueva sin autenticar y sin justificación | Es un bug, no una decisión |
| PR que hace tres cosas distintas | No se revisa bien, y el revert arrastra lo que sí servía |

**Qué NO bloquea:** preferencias de estilo que el formateador no marca. Se comentan como
sugerencia y se mergea igual.

---

## Merge

**Squash merge.** Un commit por PR en `main`, con el título del PR.

El mensaje del commit va **en inglés**, siempre, sin importar el idioma de la conversación o de
la documentación. Sin atribución de IA de ningún tipo.

Después del merge:

1. Actualizá [`docs/continue.md`](docs/continue.md): qué se hizo, qué quedó a medias, qué sigue.
2. Si la fase cerró, movela de `docs/working/` a `docs/archived/`.
3. Borrá la rama.

---

## Equipo

| Nombre | Carné |
|---|---|
| Arturo Lima | 24683 |
| Lazaro Diaz | 24713 |
| Jorge Villeda | 24932 |
| Oscar Rompich | 24880 |
| Marco Diaz | 24229 |
