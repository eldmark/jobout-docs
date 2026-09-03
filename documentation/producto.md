# Producto

## La tesis

**No competimos con LinkedIn o Indeed en su terreno.** Esa guerra se pierde: tienen los dos
lados del mercado, efecto de red y quince años de ventaja.

Entramos por donde ellos no están: **preparación**. El camino completo desde que alguien ve una
oferta hasta que le va bien en la entrevista. Las ofertas y las empresas vienen después, apoyadas
en candidatos que llegan preparados — que es exactamente lo que una bolsa de empleos no puede
ofrecer.

```
Encontrar trabajo
      ↓
Prepararse
      ↓
Practicar
      ↓
Aplicar
      ↓
Mejorar CV
      ↓
Simular entrevista
      ↓
Feedback
```

La referencia mental no es LinkedIn. Es **Duolingo**: rachas, niveles, progreso medible, y una
razón para volver mañana.

## La pantalla que resume el producto

```
Bienvenido Nicolás.

3 entrevistas pendientes
2 ofertas compatibles

Tu score de entrevistas   87/100
Tu confianza              72%
Tu claridad               91%
```

Si un usuario abre la app y ve un número que ayer era peor, vuelve. Ese es el producto.

## Dónde está el valor real

**No es el avatar.** Es el recruiter.

Un avatar realista con preguntas mediocres es un juguete. Un recruiter mediocre no se salva con
el mejor renderizado del mundo. Lo que hace que esto valga la pena es que el recruiter:

- Pregunte bien y **repregunte** cuando la respuesta fue vaga.
- **Recuerde**. «Hace dos semanas me dijiste que trabajabas en Mercado Libre. Hoy dijiste otra
  cosa. ¿Por qué cambió tu historia?» Eso es lo que lo vuelve humano.
- Evalúe con criterios explicables, no con una nota que aparece de la nada.

Las tres cosas que tienen que salir bien en el MVP, en orden:

1. **Calidad del recruiter** — cómo pregunta, repregunta y evalúa.
2. **Velocidad de la conversación** — que se sienta natural, sin esperas incómodas.
3. **Feedback posterior** — puntuación y recomendaciones accionables.

Si esas tres funcionan, el avatar es un plus. Si el recruiter es mediocre, ningún avatar salva
la experiencia.

## Los recruiters

En vez de generar una cara distinta cada vez, hay **un elenco fijo** de recruiters con
identidad propia. El usuario vuelve a practicar con «Martín» como quien vuelve con un
entrenador conocido. Eso le da personalidad al producto y lo hace memorable.

| Recruiter | Rol | Personalidad |
|---|---|---|
| Ana | RRHH | Muy amable. La primera entrevista de todos |
| Martín | CTO | Exigente. Técnico, repregunta hasta el fondo |
| Laura | Recruiter Big Tech | Estructurada, formato entrevista conductual |
| Carlos | CEO de startup | Informal, va al grano, pregunta por ambición y riesgo |
| Sofía | Recruiter internacional | Entrevista en inglés |

El elenco crece hasta ~10. Cada uno tiene prompt, voz, foto y criterios de evaluación propios,
versionados como configuración, no hardcodeados.

**Panel de tres personas** es un modo aparte: varios recruiters en la misma sesión, turnándose.
Es el modo difícil.

## Gamificación

| Nivel | Escenario | Estado |
|---|---|---|
| 1 | Entrevista Junior | Abierto |
| 2 | Entrevista Startup | Se abre al pasar el 1 |
| 3 | Amazon | Bloqueado |
| 4 | Google | Bloqueado |
| 5 | McKinsey | Bloqueado |

Desbloquear un nivel requiere un score mínimo en el anterior. El objetivo no es la dificultad
por la dificultad: es que el usuario tenga una razón concreta para volver.

## Métricas del usuario

| Métrica | Qué mide | De dónde sale |
|---|---|---|
| **Score** | Calidad general de la entrevista, 0–100 | Rúbrica del recruiter sobre la sesión completa |
| **Confianza** | Cuán seguro suena | Señales de voz: pausas, muletillas, ritmo |
| **Claridad** | Cuán entendible es la respuesta | Estructura y concreción del contenido |

Las tres tienen que ser **explicables**. Un número sin un «por qué» no cambia el comportamiento
de nadie. Cada score va acompañado de las dos o tres cosas concretas que lo subirían.

## Objetivos

### De producto

1. Que un usuario complete su primera entrevista simulada en **menos de 5 minutos** desde que
   se registra.
2. Que el feedback sea **accionable**: nada de «mejorá tu comunicación», sí «respondiste tres
   preguntas de experiencia sin dar un solo número; agregá métricas».
3. Que la conversación se sienta **natural**: latencia de respuesta por debajo del segundo.
4. Que el usuario **vuelva**: retorno a la semana como métrica principal.

### De negocio

1. Empezar **barato**. Cada dependencia de una API cara es un techo al margen. El MVP corre sin
   servicio de video generado.
2. Costo por sesión de entrevista conocido y con tope. Un usuario no puede quemar el margen del
   mes.
3. Escalar cambiando piezas, no reescribiendo: avatar V1 → V4 sin tocar el resto del sistema.

### De confianza

La gente sube su CV, su email, su teléfono, su dirección y sus cartas de recomendación. Es
información sensible y el producto se cae si la manejamos mal.

**Política pública, escrita y sostenida: nunca usamos tu información para entrenar modelos.**

El detalle técnico de cómo se sostiene está en [security.md](security.md).

## Historias de usuario

Las historias son el contrato de cada fase. Un `faseN-*.md` en `docs/working/` declara cuáles
cubre.

### Cuenta y perfil

| ID | Historia |
|---|---|
| HU-01 | Como candidato, quiero registrarme con Google o email, para empezar sin fricción |
| HU-02 | Como candidato, quiero subir mi CV, para que el sistema conozca mi experiencia |
| HU-03 | Como candidato, quiero que se extraigan mi experiencia y mis habilidades del CV, para no cargarlas a mano |
| HU-04 | Como candidato, quiero editar lo que se extrajo, para corregir errores |
| HU-05 | Como candidato, quiero borrar mi cuenta y mis datos, para irme cuando quiera |

### Entrevista

| ID | Historia |
|---|---|
| HU-10 | Como candidato, quiero elegir con qué recruiter practicar, para entrenar el escenario que me toca |
| HU-11 | Como candidato, quiero hablar por voz con el recruiter, para que se parezca a una entrevista real |
| HU-12 | Como candidato, quiero que el recruiter repregunte cuando respondo vago, para aprender a ser concreto |
| HU-13 | Como candidato, quiero que el recruiter recuerde mis sesiones anteriores, para que note mis inconsistencias |
| HU-14 | Como candidato, quiero cortar la entrevista a mitad, para retomarla después |
| HU-15 | Como candidato, quiero ver la transcripción de la sesión, para releer qué dije |

### Feedback y progreso

| ID | Historia |
|---|---|
| HU-20 | Como candidato, quiero un score al terminar, para saber cómo me fue |
| HU-21 | Como candidato, quiero saber **por qué** ese score, para poder mejorarlo |
| HU-22 | Como candidato, quiero ver mi progreso en el tiempo, para saber si estoy mejorando |
| HU-23 | Como candidato, quiero desbloquear niveles más difíciles, para tener a dónde ir |
| HU-24 | Como candidato, quiero sugerencias concretas sobre mi CV, para mejorarlo |

### Ofertas y matching

| ID | Historia |
|---|---|
| HU-30 | Como candidato, quiero ver ofertas compatibles con mi perfil, para no buscar a ciegas |
| HU-31 | Como candidato, quiero practicar una entrevista específica para una oferta, para llegar preparado |
| HU-32 | Como candidato, quiero llevar registro de dónde apliqué, para no repetir ni perder el hilo |

### Empresa

| ID | Historia |
|---|---|
| HU-50 | Como empresa, quiero registrar mi organización, para poder publicar ofertas |
| HU-51 | Como reclutador, quiero publicar una oferta, para recibir aplicaciones |
| HU-52 | Como reclutador, quiero ver quién aplicó a mi oferta, para revisar candidatos |
| HU-53 | Como reclutador, quiero mover una aplicación entre estados, para llevar el proceso |
| HU-54 | Como reclutador, quiero marcar candidatos favoritos, para no perderlos de vista |
| HU-55 | Como reclutador, quiero publicar una oferta confidencial, para no exponer que estoy contratando |
| HU-56 | Como empresa, quiero una membresía con vigencia, para acceder según lo que contraté |

### Privacidad

| ID | Historia |
|---|---|
| HU-40 | Como candidato, quiero saber qué datos guardan de mí, para decidir si confío |
| HU-41 | Como candidato, quiero exportar mis datos, para llevármelos |
| HU-42 | Como candidato, quiero la garantía de que mi información no entrena modelos, para subir mi CV tranquilo |

## Los dos lados

JobOut es **two-sided**: candidatos y empresas.

| Lado | Quién | Qué obtiene |
|---|---|---|
| **Candidato** | La persona que busca trabajo | Preparación, entrevistas simuladas, feedback, ofertas compatibles. **Es el lado que define el producto** |
| **Empresa** | Reclutadores de empresas | Publicar ofertas, revisar aplicaciones, marcar candidatos favoritos |

La preparación no se vuelve un extra de una bolsa de empleos: es lo que nos distingue y lo que
le da valor al lado empresa. Un candidato que practicó cinco entrevistas llega mejor que uno
que aplicó a ciegas, y eso es lo que una empresa paga.

**El problema del huevo y la gallina, dicho de frente:** las ofertas las cargan las empresas a
mano. Sin candidatos no vienen empresas; sin ofertas los candidatos no vuelven. La salida es el
orden de construcción: **el lado candidato aporta valor sin una sola oferta publicada** —las
entrevistas simuladas funcionan solas—. Primero eso, después las empresas.

## Qué NO es JobOut

Escrito para poder decir que no:

- **No** es una red social ni tiene feed.
- **No** es un generador de CVs desde cero.
- **No** promete conseguir trabajo. Promete llegar preparado.
- **No** filtra candidatos por edad, género ni estado civil. Es ilegal en la mayoría de los
  mercados a los que apuntamos, y no se implementa aunque una empresa lo pida.
