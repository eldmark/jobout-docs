# AGENTS.md — JobOut

Índice y contrato de trabajo. Si vas a tocar algo de JobOut, este archivo se lee primero.

---

## Qué es JobOut

Una plataforma de **preparación y matching para conseguir empleo**. No es una bolsa de trabajo:
competir con LinkedIn o Indeed es una guerra perdida. Lo que vendemos es el camino completo —
encontrar, prepararse, practicar, aplicar, mejorar el CV, simular la entrevista, recibir
feedback — con recruiters de IA que tienen personalidad propia y memoria de sesiones anteriores.

Más parecido a Duolingo que a LinkedIn.

El detalle está en **[documentation/producto.md](documentation/producto.md)**. Léelo antes de
opinar sobre alcance.

---

## Mapa de repos

Multi-repo. Este repo (`jobout-docs`) es la **única fuente de verdad** de reglas, arquitectura
y estado. Cada repo de servicio lleva un `AGENTS.md` corto que apunta acá.

| Repo | Stack | Qué hace | ¿PII? |
|---|---|---|---|
| [`jobout-docs`](https://github.com/eldmark/jobout-docs) | Markdown | Este. Reglas, arquitectura, fases, bugs, traspaso | No |
| [`jobout-core-api`](https://github.com/eldmark/jobout-core-api) | Rust · Axum · SeaORM · PostgreSQL | Auth, usuarios, CVs, ofertas, scores, historial, pagos | **Sí, cifrada** |
| `jobout-interview` | Python · FastAPI | Relay de OpenAI Realtime, animación facial del avatar. **Pendiente** | **Cero** |
| [`jobout-web`](https://github.com/eldmark/jobout-web) | Next.js | Interfaz, dashboard, sala de entrevista | No persiste |

**La frontera de seguridad más importante del proyecto:** `jobout-interview` no tiene
credenciales de base de datos y no almacena nada. Recibe un token efímero de sesión y audio.
Si lo comprometen, no hay datos que robar. Ver
[documentation/security.md](documentation/security.md).

---

## Levantar el entorno

```bash
make dev     # backend + frontend + PostgreSQL, un comando
make test    # pruebas de los dos repos
make down
```

Los tres repos van clonados como hermanos. Ver
[documentation/desarrollo.md](documentation/desarrollo.md).

**Nunca commitees `docker-compose.yml` ni un `.env`.** Lo versionado son los `.example`. Si
agregás una variable que el proyecto necesita, va al `.example` en el mismo PR con un valor
falso — si no, el siguiente que clone levanta un entorno roto y no sabe por qué.

## Antes de tocar nada

En este orden, siempre:

1. **[`docs/continue.md`](docs/continue.md)** — qué se hizo en la última sesión, qué quedó a
   medias, qué sigue.
2. **[`docs/bugs.md`](docs/bugs.md)** — bugs abiertos. Puede que lo que vas a "arreglar" ya
   esté anotado, o que lo que vas a construir esté encima de uno.
3. **[`docs/working/`](docs/working/)** — la fase en curso. Si hay un `faseN-*.md` abierto, tu
   trabajo probablemente pertenece ahí y no a una fase nueva.

Y en el repo de código que vayas a tocar:

```bash
git status --short    # ¿hay cambios que no son tuyos?
```

Si aparecen archivos que no reconoces, otra sesión está a mitad de algo. No los reviertas, no
los limpies, no los commitees sin entender qué son.

---

## Las dos carpetas de documentación

| | [`docs/`](docs/) | [`documentation/`](documentation/) |
|---|---|---|
| Qué es | **Proceso.** Trabajo por fases, bugs abiertos, traspaso de sesión | **Referencia estable.** Cómo es el sistema hoy |
| Vigencia | Refleja el momento en que se escribió | Se actualiza junto con el código |
| Se divide en | `working/` (en curso) y `archived/` (cerradas) | Un archivo por área |
| Sirve para | Entender el *porqué* y el *qué sigue* | Entender el *qué es* |

**No copies archivos de una a otra.** Son formatos distintos: acá una investigación, allá una
conclusión. Cuando un hallazgo de fase se vuelve regla permanente, su forma resumida va a
`documentation/`.

Ambas están versionadas. Un plan de fase vale historial y vale revisión en PR.

---

## Reglas no negociables

### 1. Secretos

**Nunca** commitees `.env`, `.env.local`, claves, certificados, tokens ni credenciales. Si un
secreto aparece en un diff, **se para todo**: no se commitea, se rota la credencial, y recién
después se sigue. Un secreto en el historial de git sigue ahí aunque borres el archivo después.

Lo que sí se versiona es `.env.example`, con los nombres de las variables y valores falsos.

### 2. Cambio de esquema ⇒ migración + documentación, en el mismo PR

Si tocás la base de datos:

- La migración se escribe con **SeaORM**. Nada de `ALTER TABLE` a mano en un servidor.
- **[`documentation/db.md`](documentation/db.md) se actualiza en el mismo PR.** Sin excepción.

Un esquema documentado a medias es peor que no documentado: el siguiente agente le cree.

### 3. Los casos de verdad se acuerdan antes de codear

En `docs/working/faseN-*.md`, y el equipo los revisa ahí — discutir qué es correcto sobre
código ya escrito sale mucho más caro. Después el test en rojo, después el código que lo pone
en verde. **Un test que nunca falló no prueba nada.**

### 4. Cada función nueva nace con su prueba unitaria

No existe "las pruebas después". Una función sin prueba es una función que nadie va a poder
refactorizar con confianza en tres meses.

### 5. Cada endpoint o flujo entre servicios nace con su prueba de integración

Escrita **al momento de implementarlo**, no en una fase de "agregar tests". Ver
[documentation/test.md](documentation/test.md) y [documentation/ci.md](documentation/ci.md).

### 6. PII

Email, teléfono y dirección se cifran a nivel de aplicación antes de tocar la base de datos.
**Nunca aparecen en logs**, ni en mensajes de error, ni en trazas. Los CVs van a S3 privado,
nunca a un bucket público.

### 7. `jobout-interview` no recibe PII ni credenciales de BD

Si te encontrás pasándole el email del usuario a ese servicio, la solución no es "pasarlo
cifrado": es no pasarlo. Ese servicio trabaja con un id de sesión efímero y nada más.

### 8. Toda ruta nueva nace autenticada

Si una ruta tiene que ser pública, va acompañada de un comentario que justifique por qué. Una
ruta pública sin justificación se trata como bug.

### 9. Seguí el patrón que ya existe

Antes de inventar una forma nueva de resolver algo, buscá cómo se resolvió lo mismo dos
carpetas más allá. Un repo con tres formas de hacer lo mismo es un repo que nadie mantiene.

---

## Ramas y pull requests

Guía completa para personas: [`CONTRIBUTING.md`](CONTRIBUTING.md). Lo mínimo:

- **Rama `jb-##-slug`.** El CI rechaza cualquier otro formato. Ej: `jb-07-implementation`
- **Nunca se commitea directo a `main`.** Rama, PR, una aprobación, CI verde, squash merge
- **Los casos de verdad se acuerdan en el archivo de fase ANTES de implementar.** Después se
  escriben los tests (rojo), después el código (verde)
- El cuerpo del PR lleva las cuatro secciones obligatorias: **qué se hizo · cómo se resolvió ·
  archivos tocados · migraciones**. El CI verifica que estén
- Si hay migración, `documentation/db.md` va actualizado en ese mismo PR. El CI lo verifica
- Una rama = una tarea. Lo que descubras de paso va a [`docs/bugs.md`](docs/bugs.md) y a otra
  rama

## Commits

- Mensajes **en inglés**, siempre, sin importar el idioma de la conversación o de la
  documentación.
- **Nunca** agregues atribución de IA: ni trailers `Co-Authored-By`, ni "Generated with", ni
  menciones en cuerpos de PR, comentarios de código o documentación.
- Un commit por implementación, no por archivo ni por sesión.
- Si estás en la rama por defecto, creá una rama antes.

---

## Al terminar

1. Corré las pruebas de lo que tocaste.
2. **Abrí la pantalla en un navegador.** Las pruebas verdes no dicen que la vista sirva.
3. Actualizá **[`docs/continue.md`](docs/continue.md)**: qué se hizo, qué quedó a medias, qué
   sigue. Este paso no es opcional — es la razón de ser de este repo.
4. Si aparecieron bugs que no vas a arreglar ahora, anotalos en
   [`docs/bugs.md`](docs/bugs.md).
5. Si la fase cerró, movela de `docs/working/` a `docs/archived/`.
6. Si cambiaste una regla permanente o el esquema, actualizá `documentation/`.

---

## Verificá antes de afirmar

Si vas a decir "esto funciona así", leelo en el código primero. Si una prueba falla, mostrá la
salida real. Si te saltaste un paso, decilo. La documentación desactualizada es el peor bug de
todos porque el siguiente agente actúa sobre ella sin dudar.

---

## Índice completo

### Referencia estable — [`documentation/`](documentation/README.md)

| Documento | Qué responde |
|---|---|
| [producto.md](documentation/producto.md) | Qué vendemos, a quién, objetivos, historias de usuario, gamificación, los recruiters |
| [arquitectura.md](documentation/arquitectura.md) | Los cuatro repos, sus fronteras, el flujo de entrevista en tiempo real, evolución del avatar |
| [db.md](documentation/db.md) | Esquema, migraciones SeaORM, qué columnas se cifran |
| [api.md](documentation/api.md) | Contratos entre servicios, token efímero de entrevista, qué nunca cruza la frontera |
| [frontend.md](documentation/frontend.md) | Next.js, rutas, estado, Clerk, capa de audio |
| [security.md](documentation/security.md) | Modelo de amenazas, cifrado de PII, secretos, política de privacidad |
| [test.md](documentation/test.md) | Cómo correr y escribir pruebas en cada repo |
| [identidad-visual.md](documentation/identidad-visual.md) | Paleta, tipografías, logo y tono de voz |
| [negocio.md](documentation/negocio.md) | Planes, números del emprendimiento, sostenibilidad social |
| [glossary.md](documentation/glossary.md) | Score, confianza, claridad, sesión, nivel, panel |
| [investigacion.md](documentation/investigacion.md) | El usuario (Luis), alternativas evaluadas, benchmark de LinkedIn. **De acá salen las decisiones** |
| [ci.md](documentation/ci.md) | Qué corre el CI y qué bloquea el merge |

### Proceso — [`docs/`](docs/README.md)

| Documento | Qué contiene |
|---|---|
| [continue.md](docs/continue.md) | Traspaso de sesión. **Se lee primero** |
| [bugs.md](docs/bugs.md) | Bugs abiertos |
| [working/](docs/working/) | Fases en curso |
| [archived/](docs/archived/) | Fases cerradas |
