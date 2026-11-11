# `docs/` — proceso

Trabajo por fases, bugs abiertos y traspaso de sesión. Esto **sí está versionado**: un plan de
fase vale historial y vale revisión en PR.

La referencia estable —cómo es el sistema hoy— está en
[`documentation/`](../documentation/README.md). No copies archivos entre las dos carpetas: acá
va la investigación, allá la conclusión.

## Qué hay acá

| Archivo | Qué contiene |
|---|---|
| [`continue.md`](continue.md) | **Léelo primero.** Traspaso de sesión: qué se hizo, qué quedó a medias, qué sigue |
| [`bugs.md`](bugs.md) | Bugs abiertos. Solo los abiertos |
| [`presentacion-mvp.md`](presentacion-mvp.md) | Casos de prueba para presentar el MVP: pasos, resultado esperado, pruebas que los cubren, estado, guion de demo y plan B |
| [`working/`](working/) | Fases en curso, un archivo por fase |
| [`archived/`](archived/) | Fases cerradas. **Nunca se borran** |

## Ciclo de vida de una fase

```
se planea  →  docs/working/faseN-nombre.md
             se acuerdan los CASOS DE VERDAD antes de codear
se ejecuta →  rama jb-##-slug, tests en rojo, después implementación
              se marcan pasos, se anotan desvíos en el mismo archivo
cierra     →  git mv docs/working/faseN-nombre.md docs/archived/
              y se anota el cierre en continue.md
```

Una fase se archiva cuando **todos** sus criterios de cierre están cumplidos, no cuando se
acabó el tiempo. Si quedó algo suelto, o se queda en `working/` o el resto sale como fase
nueva.

`archived/` es el único rastro de *cómo* se llegó a cada decisión. No se borra nada de ahí.

## Nombres

`faseN-nombre-corto.md` — número correlativo, guiones, sin mayúsculas ni acentos en el nombre
del archivo.

```
fase1-login.md
fase2-perfil-cv.md
fase3-entrevista-realtime.md
```

## Plantilla de fase

Copiá esto al abrir una fase nueva en `working/`:

```markdown
# Fase N — Nombre

**Estado:** en curso | bloqueada | cerrada
**Repos que toca:** jobout-core-api, jobout-web
**Abierta:** YYYY-MM-DD

## Objetivo

Una o dos frases. Qué queda funcionando cuando esto cierre.

## Historias de usuario que cubre

- HU-XX — Como <rol>, quiero <acción>, para <beneficio>

## Alcance

**Dentro:**
- ...

**Fuera:** (y por qué)
- ...

## Cambios de esquema

Ninguno | Tabla `x` nueva, columnas `y` y `z`.
Migración: `<nombre_de_la_migración_seaorm>`
> Si hay cambios acá, `documentation/db.md` se actualiza en el mismo PR.

## Pasos

- [ ] 1. ...
- [ ] 2. ...

## Casos de verdad

> **Se acuerdan ANTES de implementar.** El equipo los revisa acá; discutir qué es correcto
> sobre código ya escrito sale mucho más caro. Cada caso tiene que poder convertirse en un
> test uno a uno.

| # | Caso | Tipo |
|---|---|---|
| 1 | Dada <entrada y estado>, pasa exactamente <esto> | unitaria / integración |

Obligatorios en toda tarea que toque datos de usuario:

| # | Caso | Tipo |
|---|---|---|
| S1 | El usuario A pide por id un recurso de B → 404, nunca el dato | integración |
| S2 | Sin token → 401 | integración |
| S3 | Un error provocado con datos sensibles no filtra PII en la respuesta ni en el log | integración |

No son casos de verdad: «verificar que el perfil funciona bien», «probar los casos borde». No
se puede escribir un test a partir de ellos.

## Criterios de cierre

- [ ] Todos los casos de verdad tienen su test, y fallaron antes de pasar
- [ ] Todas las pruebas verdes
- [ ] Pantalla abierta en navegador y verificada
- [ ] `documentation/` actualizado si cambió una regla permanente
- [ ] `continue.md` actualizado

## Desvíos y hallazgos

Lo que se descubrió sobre la marcha y no estaba en el plan. Esto es lo que le sirve al
siguiente agente.
```
