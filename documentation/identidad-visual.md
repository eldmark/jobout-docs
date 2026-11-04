# Identidad visual

Fuente: `JobOut_Identidad_v2.pdf` (equipo, UVG Sección 10). Este archivo guarda lo que el
código necesita; la guía original manda si hay duda.

## Marca

- **Nombre:** *Job* = tu primer empleo en software. *Out* = salir del aula y de la teoría hacia
  la entrevista real. En el logo, «Job» va en tinta (o blanco sobre fondo oscuro) y «Out» en
  coral.
- **Eslogan:** «Llega listo a tu primera entrevista.»
- **Logo:** un marco índigo con `<` (código y formación) unido a un marco coral con una flecha
  (la salida al mercado laboral). Variantes: principal, sobre tinta, sobre índigo monocromo e
  isotipo para redes y app.
- **Misión:** ayudar a jóvenes sin experiencia a saber si están listos para su primera
  entrevista en software, con práctica real, feedback personalizado y acceso a oportunidades.
- **Visión:** ser la plataforma de referencia para dar el salto del aula al primer empleo en
  tecnología en Guatemala y Latinoamérica.
- **Valores:** confianza · práctica real · personalización · accesibilidad · comunidad.

## Color

| Nombre | Hex | RGB | Uso |
|---|---|---|---|
| Índigo JobOut | `#5B4BFF` | 91, 75, 255 | Principal: títulos, botones y fondos de marca |
| Tinta | `#14122B` | 20, 18, 43 | Texto y fondos oscuros |
| Coral | `#FF6B4A` | 255, 107, 74 | Acento: flecha del logo y llamadas a la acción |
| Menta | `#2FD39A` | 47, 211, 154 | Progreso, logros y mensajes de éxito |
| Lavanda | `#ECE9FF` | 236, 233, 255 | Fondos suaves y tarjetas |

**Proporción:** 50 % blancos y lavanda · 30 % índigo · 12 % tinta · 8 % coral.

**Contraste (medido en la guía):** blanco sobre índigo 5.4:1 · tinta sobre blanco 18.2:1 ·
tinta sobre coral 6.5:1 · tinta sobre menta 9.5:1.
**Regla dura: sobre coral el texto va siempre en tinta, nunca en blanco (2.8:1, no cumple).**

## Tipografía

| Fuente | Uso | Licencia |
|---|---|---|
| **Sora Bold** | Títulos, logo y cifras destacadas | Google Fonts (libre) |
| **Manrope** | Texto corrido, formularios y documentos | Google Fonts (libre) |

Escala de la guía: título 28 pt · subtítulo 18 pt · texto de apoyo 14 pt.

En Next.js se cargan con `next/font/google` (se autoalojan, sin pedir nada a Google en
runtime).

## Voz

Cercana pero seria: un mentor que **te tutea**, es claro y directo, y motiva sin prometer
milagros.

| Decimos | Evitamos |
|---|---|
| «Practica hoy, entra con confianza.» | «¡Consigue trabajo garantizado!» |
| «Tu feedback está listo» | Promesas de resultado |

Esto refuerza la restricción de [investigacion.md](investigacion.md): **la IA es el medio, no el
pitch.** Se vende práctica y feedback, no «entrevistas con inteligencia artificial».

> **Nota de idioma.** La documentación técnica de este repo está escrita en voseo; **los textos
> que ve el usuario van en tuteo** (guía de marca) y, más adelante, también en inglés.

## En el código

Los tokens viven en `jobout-web/app/globals.css` como variables CSS, **una sola vez**, y los
componentes los usan; nadie escribe un hex a mano.

```css
:root {
  --color-indigo: #5b4bff;
  --color-ink: #14122b;
  --color-coral: #ff6b4a;
  --color-mint: #2fd39a;
  --color-lavender: #ece9ff;
}
```
