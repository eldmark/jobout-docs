# continue.md — traspaso de sesión

**Esto se lee al empezar y se actualiza al terminar.** Es la razón de ser de este repo: que
cualquiera —agente o persona— sepa qué se hizo, cómo y qué sigue, sin preguntar.

Entrada más reciente arriba. No borres entradas viejas: se van quedando como historia.

---

## 2026-09-02 — Scaffolding de documentación

**Qué se hizo**

- Se definió la arquitectura del proyecto y se tomaron las decisiones de stack (ver tabla
  abajo).
- Este repo (`jobout-docs`) se armó completo: `AGENTS.md` como punto de entrada, `docs/` para
  proceso y `documentation/` para referencia estable.
- Se escribió el documento maestro de producto
  ([`documentation/producto.md`](../documentation/producto.md)) con visión, objetivos,
  historias de usuario, los recruiters y la gamificación.

**Decisiones tomadas**

| Decisión | Elección | Razón |
|---|---|---|
| Core backend | Rust · Axum · SeaORM | Tipos exhaustivos, migraciones en Rust, sin sorpresas en runtime |
| Servicio de IA | Python · FastAPI | LivePortrait y MuseTalk son PyTorch; no hay equivalente en Rust |
| Frontend | Next.js | — |
| Auth | Clerk | MFA y social listos, menos superficie propia manejando credenciales |
| BD | PostgreSQL | — |
| Repos | Multi-repo | Aislamiento real entre el servicio con PII y el que no la tiene |
| Docs | Repo central (`jobout-docs`) | Una sola fuente de verdad |
| Avatar MVP | Foto estática + animación mínima | ~95% menos costo. LivePortrait y MuseTalk vienen después |

**Qué quedó a medias**

Nada. El scaffolding está completo. `documentation/db.md`, `api.md` y `frontend.md` son
esqueletos con las reglas escritas pero **sin contenido técnico todavía** — eso llega con las
fases correspondientes.

**Qué sigue**

1. **Diseño de la base de datos** — el siguiente paso acordado. Entidades base: usuarios,
   perfiles, CVs, recruiters, sesiones de entrevista, turnos, scores, ofertas, aplicaciones.
   Salida: esquema completo en [`documentation/db.md`](../documentation/db.md).
2. Crear los repos `jobout-core-api`, `jobout-interview` y `jobout-web`, cada uno con su
   `AGENTS.md` corto apuntando acá.
3. Fase 1 — auth con Clerk y perfil de usuario.

**Decisiones abiertas**

- Proveedor de LLM y de voz para el MVP: OpenAI Realtime es la apuesta, falta estimar costo
  por sesión de entrevista y definir el tope por usuario.
- Estrategia de cifrado de PII: cifrado a nivel de aplicación está decidido; falta elegir
  entre una clave maestra con rotación o un KMS gestionado.
- Hosting: sin definir.
