# Glosario

Los términos del producto, para que signifiquen lo mismo en el código, en la documentación y en
la conversación.

| Término | Qué es |
|---|---|
| **Candidato** | El usuario. La persona que busca trabajo. Es nuestro cliente, no el reclutador |
| **Recruiter** | Un entrevistador de IA del elenco fijo, con prompt, voz, foto y rúbrica propios. Ana, Martín, Laura, Carlos, Sofía… |
| **Elenco** | El conjunto de recruiters disponibles. Fijo y con identidad, no generado al azar |
| **Sesión** | Una entrevista simulada completa, de principio a fin. Se puede pausar y retomar |
| **Turno** | Un intercambio dentro de una sesión: lo que dice el recruiter y lo que responde el candidato |
| **Score** | Calidad general de la entrevista, 0–100. Sale de la rúbrica del recruiter sobre la sesión completa |
| **Confianza** | Cuán seguro suena el candidato. Sale de señales de voz: pausas, muletillas, ritmo |
| **Claridad** | Cuán entendible y concreta es la respuesta. Sale del contenido, no de la voz |
| **Rúbrica** | Los criterios con los que un recruiter evalúa. Versionada: un score viejo se explica con la rúbrica con la que se calculó |
| **Desglose** | El «por qué» de un score. Las dos o tres cosas concretas que lo subirían |
| **Nivel** | Escalón de gamificación: Junior, Startup, Amazon, Google, McKinsey. Se desbloquea con un score mínimo del anterior |
| **Panel** | Modo con varios recruiters en la misma sesión, turnándose. El modo difícil |
| **Memoria del recruiter** | Lo que el recruiter recuerda de sesiones anteriores del mismo candidato. Es lo que le permite detectar inconsistencias |
| **Token efímero de sesión** | Credencial de vida corta, alcance de una sola entrevista, sin identidad del usuario adentro. Lo único con lo que `jobout-interview` trabaja |
| **PII** | Información personal identificable: email, teléfono, dirección, nombre real |
| **Fase** | Una unidad de trabajo planificada. Vive en `docs/working/` y se archiva al cerrar |

## Nombres de servicios

| Nombre | Qué es |
|---|---|
| `jobout-docs` | Este repo. Reglas y documentación |
| `jobout-core-api` | Rust. Datos, auth, scoring. Toda la PII |
| `jobout-interview` | Python. Entrevista en tiempo real y avatar. Sin PII |
| `jobout-web` | Next.js. Interfaz |
