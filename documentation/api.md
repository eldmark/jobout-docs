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

### Identidad (Fase 1)

Todas bajo `/api/v1`. Errores siempre `{"error": "<código>", "message": "<texto en español>"}`.
Cuerpo máximo 8 KB (413 si se excede). Nada de lo que entra o sale se escribe en logs.

| Ruta | Auth | Cuerpo → respuesta |
|---|---|---|
| `POST /auth/register` | pública (es la puerta de entrada) | `{email, password, first_name, last_name}` → 201 `{access_token, refresh_token, token_type: "Bearer", expires_in: 900}` · 409 `registro_no_disponible` · 422 `datos_invalidos` |
| `POST /auth/login` | pública | `{email, password}` → 200 mismos tokens · 401 `credenciales_invalidas` (igual para «no existe» y «clave incorrecta») · 403 `cuenta_no_disponible` (suspendido) · 429 `demasiados_intentos` (5 fallos en 15 min por email) |
| `POST /auth/refresh` | pública (el access puede haber expirado) | `{refresh_token}` → 200 tokens nuevos; el anterior queda revocado · 401 `sesion_invalida` para token desconocido, expirado, vacío o **reutilizado**; reusar uno rotado revoca todas las sesiones del usuario · 403 suspendido |
| `POST /auth/logout` | pública | `{refresh_token}` → 204, idempotente; solo revoca esa sesión |
| `GET /me` | Bearer | → 200 `{id, first_name, last_name, status, email, plan: {code, name} \| null}`. Nunca devuelve `email_hash`, hash de contraseña ni `clerk_user_id` |
| `DELETE /me` | Bearer | `{password}` → 204 · 403 `contrasena_incorrecta` (suma al contador de intentos; con bloqueo activo, 429) · 401 si la cuenta ya no existe · 422 sin contraseña |

`DELETE /me` es **borrado real** (HU-05): en una transacción deja una fila en `privacy_events`
(`account_deleted`, fecha y `subject_hash`, sin email, nombre ni id) y borra `users`; las FK en
cascada eliminan candidato, roles, credenciales, refresh tokens y suscripciones. El token de
acceso anterior pasa a 401 y el mismo email puede registrarse de nuevo como cuenta nueva.

**Las rutas se montan solo desde la tabla `src/routes/table.rs`.** Cada entrada declara su acceso:
`Access::Public("por qué")` exige una justificación real, y `Access::Authenticated` aplica la
autenticación **al montar la ruta**, aunque el handler se olvide de pedir `AuthUser`. Los módulos
de rutas no construyen `Router`s: devuelven `Vec<RouteSpec>`. `tests/route_table.rs` ejercita la
aplicación real (protegidas dan 401 con cualquier credencial inválida, los métodos declarados son
los reales, la lista de rutas esperadas está fija y obliga a que una ruta nueva se revise).
El límite de cuerpo (8 KB) es global.


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
