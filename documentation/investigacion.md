# Investigación

De dónde salieron las decisiones de producto. Tres piezas: el usuario, las alternativas que se
evaluaron y el benchmark contra LinkedIn.

Lo que este documento fija, [`producto.md`](producto.md) lo ejecuta.

---

## El usuario: Luis Estrada

La persona del proyecto. No es un promedio: es un caso concreto que sirve para decir que no.

| | |
|---|---|
| Edad | 24 años |
| País | Guatemala |
| Educación | Universidad — Ingeniería en Sistemas |
| Estado | Recién graduado, buscando su primer trabajo estable en tecnología |

**Quién es.** Luis es una persona cerrada. No conecta bien con desconocidos y le cuesta hacer
conversación incluso sobre temas que le interesan. En el eje extrovertido–introvertido está del
lado introvertido; es más metódico que creativo y más pensativo que sentimental.

**Su experiencia.** Solo prácticas, **y las consiguió por conocer al contacto**. Nunca estuvo en
una entrevista real.

Ese dato es el producto entero. Luis no necesita otro portal donde aplicar: necesita no
congelarse la primera vez que alguien le pregunte «contame de vos».

**Qué lo mueve**

- Conseguir una plaza en una empresa de tecnología ya establecida
- Un sueldo mayor al base de un ingeniero en sistemas
- Contactos que le abran puertas después

**Qué quiere lograr**

- Desenvolverse en una entrevista y en interacciones sociales con futuros compañeros
- **Hacer destacar sus habilidades de programación de forma clara y precisa** — sabe programar;
  lo que no sabe es contarlo

**Qué opina del producto: 8/10.**

> «Le parece interesante la idea, siente que practicar antes de las entrevistas puede aumentar
> las posibilidades de obtener el puesto.
>
> **La parte que no le convence mucho es la inclusión de la IA**, pero si se incorpora de forma
> correcta la idea tendría potencial.»

**Cómo lo ayudamos.** Ofreciendo un espacio de asesoramiento donde pueda practicar y ganar
confianza antes de ese momento de su carrera.

### Lo que Luis nos obliga a hacer

| Lo que dice Luis | Lo que se decide |
|---|---|
| No convence la IA | **La IA es el medio, nunca el pitch.** Ver la restricción abajo |
| Nunca estuvo en una entrevista real | La primera entrevista tiene que ser con Ana, la amable. No se arranca con Martín |
| Le cuesta hablar con desconocidos | Practicar solo, sin nadie mirando, es una ventaja del producto — no una limitación |
| Sabe programar pero no contarlo | El feedback ataca **claridad**, no conocimiento técnico |
| Consiguió las prácticas por un contacto | Sabe que el acceso importa. Por eso la preparación se vende como lo que empareja la cancha |
| Quiere sueldo mayor al base | Las expectativas salariales son parte del perfil, y practicar la negociación es producto futuro |

---

## La restricción que atraviesa todo el producto

Dos fuentes independientes dijeron lo mismo:

- **Luis:** «la parte que no me convence mucho es la inclusión de la IA»
- **Benchmark de LinkedIn, columna «qué hace mal»:** «impulsar la inclusión innecesaria de
  inteligencia artificial generativa»

El usuario objetivo desconfía de la IA, y el equipo señaló el uso de IA como el defecto
principal del competidor. JobOut es un producto de IA.

Eso no invalida el producto — Luis igual le puso 8/10 — pero define cómo se presenta:

> **La IA es el medio, nunca el pitch.**

En concreto:

| Se hace | No se hace |
|---|---|
| «Practicá con Martín, CTO exigente» | «Entrevistas con inteligencia artificial» |
| Un score explicado con dos cosas concretas que lo suben | Un número mágico que sale de un modelo |
| Recruiters con nombre, cara y personalidad | Un chatbot genérico |
| Feedback que se puede discutir y verificar | «La IA determinó que…» |
| Decir con claridad qué hace la IA cuando el usuario pregunta | Esconderlo, u ocuparlo de adorno |

Un score sin explicación es exactamente el tipo de IA que a Luis no le convence. Por eso
`interview_scores.breakdown` no es opcional en el esquema: es la respuesta técnica a una
objeción de producto. Ver [db.md](db.md).

---

## Cuadro de alternativas

Las cuatro formas que se evaluaron para entregar el producto.

| Alternativa | Descripción | Ventajas | Desventajas | Impacto |
|---|---|---|---|---|
| **App móvil** | Aplicación funcional en Android e iOS | Se usa en cualquier lugar | Los espacios de trabajo son distintos y las pantallas no siempre se adaptan a video; adaptar a todos los tamaños es mucho más costoso | **Alta** |
| **Sitio web** | Sitio accesible desde la web | Compatible con más dispositivos | No siempre hay una computadora a mano, y la portabilidad es difícil en celular | **Alta** |
| **Face to face** | Contratar personas especializadas para dar el servicio | Interactuar con otra persona hace el aprendizaje más significativo | Las preguntas pueden estar sesgadas, y contratar profesionales es más costoso | Medio |
| **Kit completo** | Las tres opciones juntas, a mayor precio | Experiencia más completa | No es viable por la cantidad de recursos y tiempo que hay que invertir en cada apartado | Bajo |

### Qué se eligió y por qué

**Sitio web.** Mismo potencial de impacto que la app móvil, con dos ventajas que decidieron:

1. **Un solo desarrollo.** La app móvil obliga a dos plataformas, y el propio análisis marca que
   adaptar video a todos los tamaños de pantalla es lo más caro.
2. **La entrevista es una sesión larga, sentado.** El caso de uso real de Luis es practicar 20
   minutos con calma, no revisar algo en la fila del bus. La debilidad anotada de la web —«no
   siempre hay una computadora a mano»— pesa poco cuando la actividad ya pide estar sentado.

**Face to face** aporta lo que el análisis dice: interacción humana real. Pero su desventaja
—«las preguntas pueden estar sesgadas»— es justamente lo que un recruiter con rúbrica versionada
resuelve: todos los candidatos se evalúan con el mismo criterio, y ese criterio se puede leer.
Es lo que hace que un simulacro con IA sea **más justo**, no menos, que uno con una persona
distinta cada vez. Ese es el argumento con el que se le responde a la objeción de Luis.

**Kit completo** queda descartado por lo que dice el cuadro: no es viable con los recursos que
hay. La app móvil no está descartada para siempre — es la extensión natural cuando el producto
web funcione.

---

## Benchmark: LinkedIn

### Qué hace bien

- Lo que más lo representa es la **marca personal** que uno construye
- Los **contactos** que se hacen a través de las publicaciones, y la cantidad de gente a la que
  se llega por medio de ellas

### Qué hace mal

- **Pocos o nulos filtros** para evitar publicaciones basura
- **Impulsar la inclusión innecesaria de IA generativa**, tanto como herramienta de la página
  como en las ofertas de trabajo generadas con IA
- **Dejó de estar enfocado en trabajos**: hoy es más una red social

### Qué se copia

- Un **perfil completo que sirva como currículum**
- Que las **habilidades se puedan validar comunitariamente** dentro de la plataforma

### Qué se hace diferente

- Ayudar a las personas a mantener un **perfil de preparación** para las entrevistas y sobre los
  conocimientos de su disciplina
- Ayudar al cliente **un paso más allá**: dar simulacros de entrevista, no limitarse a encontrar
  la entrevista

### Lo que el benchmark decide

| Hallazgo | Decisión |
|---|---|
| LinkedIn dejó de enfocarse en trabajos | **JobOut no tiene feed ni red social.** Está en «Qué NO es JobOut» |
| IA generativa innecesaria como defecto | La restricción de arriba: la IA es el medio, no el pitch |
| Publicaciones basura sin filtro | Las ofertas las carga una empresa registrada, con `tax_id` y membresía. La barrera de entrada es la defensa |
| Perfil como currículum | Ya está: `personal_data`, `professional_data`, `applicant_skills`, `cvs` |
| Validación comunitaria de skills | **No está en el esquema.** Ver abajo |
| Preparación como diferenciador | Es el producto entero |

### Validación comunitaria de skills — pendiente

Es lo único del benchmark que no se implementó. Necesita masa crítica de usuarios para
funcionar: con cien candidatos, nadie valida a nadie.

Hay una versión que sí escala desde el primer día y que LinkedIn no tiene: **una skill validada
por el desempeño en las entrevistas**. Si Martín preguntó tres veces sobre concurrencia y las
respuestas puntuaron alto, esa skill queda respaldada por evidencia, no por un clic de un
conocido — que es exactamente la crítica que se le hace al endorsement de LinkedIn.

Queda anotado como candidato a fase futura, no en el esquema todavía.

---

## Equipo

| Nombre | Carné |
|---|---|
| Arturo Lima | 24683 |
| Lazaro Diaz | 24713 |
| Jorge Villeda | 24932 |
| Oscar Rompich | 24880 |
| Marco Diaz | 24229 |
