# API

> **Estado: contratos por definir.** Este archivo tiene las reglas y la frontera entre
> servicios, que aplican desde el primer endpoint. Los contratos concretos se llenan con cada
> fase.

## Las superficies

| Superficie | Servicio | Consumidor | Auth |
|---|---|---|---|
| `REST /api/v1` | `jobout-core-api` | `jobout-web` | JWT propio de `core-api` (MVP) |
| `WS /interview` | `jobout-interview` | `jobout-web` | **Token efímero de sesión** |
| Interna | `core-api` ↔ `interview` | Entre servicios | mTLS o secreto compartido |

## La frontera: qué NUNCA cruza a `jobout-interview`

Esta es la regla más importante del sistema.

**Nunca cruza:**

- Email, teléfono, dirección del usuario
- Nombre real
- El archivo del CV
- Credenciales de base de datos o de S3
- El JWT de acceso del usuario
- Cualquier id permanente de usuario

**Sí cruza:**

- Un **token efímero de sesión**
- El id del recruiter que va a conducir la entrevista
- El contexto de entrevista que `core-api` arma: puesto, seniority, temas a cubrir, y un
  resumen de sesiones anteriores **ya despersonalizado**
- Audio, en tiempo real

Si te encontrás necesitando pasar un dato de la primera lista, la solución no es cifrarlo: es
resolverlo del lado de `core-api`.

## Token efímero de entrevista

```
1. jobout-web            →  POST /api/v1/interviews          (JWT de acceso)
2. jobout-core-api       →  crea la sesión, arma el contexto
                            emite un token efímero de sesión
3. jobout-web            ←  { session_token, ws_url, recruiter }
4. jobout-web            →  WS /interview  (session_token)
5. jobout-interview      →  valida el token contra core-api
6. ... la entrevista ...
7. jobout-interview      →  POST interno: transcripción + señales de voz
8. jobout-core-api       →  persiste, calcula el score, invalida el token
```

Propiedades del token:

- Vigencia de **minutos**, no de horas.
- Alcance de **una sola sesión**. No sirve para otra.
- **No contiene identidad del usuario.** Solo el id de sesión.
- Se invalida al cerrar la sesión. Un token de una sesión terminada no abre nada.

## Reglas para todo endpoint

1. **Nace autenticado.** Si es público, va un comentario que lo justifique. Una ruta pública sin
   justificación es un bug.
2. **Consulta por id filtra por dueño**, igual que el listado. Es la falla de autorización más
   común y la más fácil de cometer.
3. **Nace con su prueba de integración**, escrita al implementarlo. Ver [test.md](test.md).
4. Errores sin PII: ni en el mensaje, ni en el detalle, ni en la traza.
5. Versionado en el path (`/api/v1`). Un cambio incompatible sube la versión, no rompe clientes.
6. Rate limiting por usuario en todo lo que consuma la API del proveedor de LLM: contiene abuso
   y contiene costo.

## Formato

- JSON. `snake_case` en los campos.
- Errores con forma estable: `{ "error": { "code": "...", "message": "..." } }`. El `code` es
  para la máquina, el `message` para la persona, y ninguno lleva PII.
- Paginación por cursor en todo listado que pueda crecer. Nada de devolver todo.
- Fechas en ISO 8601 con zona horaria.

## Endpoints

_Por definir, fase por fase._ Áreas previstas:

| Área | Qué cubre |
|---|---|
| `/auth` | Sesión, perfil actual |
| `/profile` | Perfil, experiencia, habilidades |
| `/cvs` | Subida, extracción, URLs firmadas |
| `/recruiters` | El elenco disponible |
| `/interviews` | Crear sesión, listar, retomar, transcripción |
| `/scores` | Score y su desglose, progreso en el tiempo |
| `/offers` | Ofertas compatibles |
| `/applications` | Registro de aplicaciones |
| `/privacy` | Exportar datos, borrar cuenta |
