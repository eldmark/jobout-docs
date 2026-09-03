# Arquitectura

## Principio de partición

El sistema se parte **por sensibilidad de datos**, no por capas ni por lenguaje favorito.

Todo lo que toca información personal vive en un servicio en Rust con tipos estrictos y acceso
a la base de datos. Todo lo que necesita el ecosistema de Python —modelos de PyTorch para
animación facial, relay de audio en tiempo real— vive en un servicio **sin credenciales de base
de datos y sin PII**.

Si comprometen el servicio de entrevista, no hay datos que robar. Esa es mejor postura que
«todo en un lenguaje».

## Los repos

| Repo | Stack | Responsabilidad | PII | BD |
|---|---|---|---|---|
| `jobout-docs` | Markdown | Reglas, arquitectura, fases, bugs | No | No |
| `jobout-core-api` | Rust · Axum · SeaORM | Usuarios, CVs, ofertas, sesiones, scores, historial, pagos | **Sí, cifrada** | Sí |
| `jobout-interview` | Python · FastAPI | Relay de OpenAI Realtime, animación facial | **No** | **No** |
| `jobout-web` | Next.js | Interfaz, dashboard, sala de entrevista | En tránsito | No |

Multi-repo. Cada uno lleva un `AGENTS.md` corto que apunta a `jobout-docs`.

## Vista general

```
                       ┌──────────────┐
                       │  jobout-web  │  Next.js
                       │   (browser)  │
                       └──┬────────┬──┘
              REST + JWT  │        │  WebSocket (audio)
                          │        │
             ┌────────────▼──┐  ┌──▼──────────────────┐
             │ jobout-core-  │  │  jobout-interview   │
             │     api       │  │                     │
             │ Rust · Axum   │  │  Python · FastAPI   │
             │   SeaORM      │  │                     │
             └───┬───────┬───┘  └──┬───────────────┬──┘
                 │       │         │               │
        ┌────────▼──┐ ┌──▼────┐ ┌──▼──────────┐ ┌──▼──────────┐
        │ PostgreSQL│ │  S3   │ │   OpenAI    │ │  Motor de   │
        │  cifrada  │ │privado│ │  Realtime   │ │  animación  │
        └───────────┘ └───────┘ └─────────────┘ └─────────────┘

        Clerk ──► valida JWT en core-api (JWKS)
```

`jobout-interview` **no tiene flecha hacia PostgreSQL ni hacia S3**. Es deliberado. Ver
[security.md](security.md).

## El flujo de la entrevista

El error caro sería generar un video completo por cada respuesta del recruiter: latencia de
varios segundos y costo por interacción. No se hace así.

```
Usuario habla
      ↓
jobout-web captura audio  ──WebSocket──►  jobout-interview
                                                ↓
                              OpenAI Realtime API
                              (voz → razonamiento → voz,
                               en una sola conexión)
                                                ↓
                                     Audio del recruiter
                                                ↓
                              Motor local de animación facial
                              (foto animada / LivePortrait / MuseTalk)
                                                ↓
                        ◄──WebSocket──  Avatar animado en el navegador
```

**Por qué OpenAI Realtime y no Whisper + GPT + TTS por separado:** una sola conexión hace voz →
texto → razonamiento → voz. Tres servicios encadenados suman tres latencias y tres puntos de
falla.

**Por qué la animación es local:** depender de un servicio de video por interacción es caro y
lento. Animar una imagen con el audio ya generado corre en nuestra infraestructura y no escala
con el precio de nadie más.

Al terminar la sesión, `jobout-interview` entrega la transcripción y las señales de voz a
`jobout-core-api`, que las persiste y calcula el score. El servicio de entrevista no guarda
nada.

## Evolución del avatar

Una decisión que se puede cambiar sin tocar el resto del sistema. La interfaz entre el audio
generado y lo que se pinta en pantalla es la misma en las cuatro versiones.

| Versión | Cómo | Costo | Cuándo |
|---|---|---|---|
| **V1** | Foto estática con animación mínima (parpadeo, leve movimiento, indicador de habla) | ~95% menos | **MVP** |
| **V2** | LivePortrait — open source, anima una imagen | Cómputo propio | Cuando V1 se sienta pobre |
| **V3** | MuseTalk — mejor sincronía labial, corre local | Cómputo propio | Cuando haya GPU dedicada |
| **V4** | HeyGen u otro servicio gestionado | Alto, por minuto | Solo con clientes pagando |

**Tavus no es una opción de MVP.** Es SaaS, no corre local, y se paga por API desde el primer
minuto.

Se arranca en V1 a propósito: el valor está en el recruiter, no en la cara.

## Autenticación

Clerk. `jobout-web` obtiene el JWT, `jobout-core-api` lo valida contra el JWKS de Clerk. No
guardamos contraseñas: menos superficie de ataque sobre lo más sensible que existe.

`jobout-interview` **no valida JWT de usuario**. Recibe un **token efímero de sesión** que
emite `core-api`, con vigencia de minutos, alcance de una sola sesión de entrevista y sin
identidad del usuario adentro. El contrato está en [api.md](api.md).

## Datos

- **PostgreSQL** — cifrado en reposo a nivel de disco, más cifrado a nivel de aplicación en las
  columnas de PII (email, teléfono, dirección).
- **S3 privado** — CVs y cartas de recomendación. Nunca un bucket público, nunca una URL
  permanente: solo URLs firmadas de vida corta.
- **Migraciones** — SeaORM, versionadas en `jobout-core-api`. Ver [db.md](db.md).

## Qué se decidió no hacer, y por qué

| Decisión | Razón |
|---|---|
| No monorepo | El aislamiento entre el servicio con PII y el que no la tiene tiene que ser real, no una convención de carpetas |
| No generar video por respuesta | Latencia y costo por interacción |
| No Whisper + GPT + TTS encadenados | Tres latencias, tres fallos posibles. Realtime lo hace en una conexión |
| No auth propia en el MVP | Contraseñas mal guardadas es el riesgo más caro y más común |
| No Python en el core | El activo es la base de datos; queremos que un typo en una columna no compile |
| No Rust en el servicio de IA | LivePortrait y MuseTalk son PyTorch. No hay puerto y no vale escribirlo |

## Decisiones abiertas

- Hosting y orquestación.
- Cifrado de PII: clave maestra con rotación propia contra un KMS gestionado.
- Costo por sesión de entrevista y tope por usuario.
