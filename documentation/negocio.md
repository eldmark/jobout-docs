# Modelo de negocio y sostenibilidad

Fuentes del curso Emprendimiento e Innovación (UVG, Sección 10):
`PlantillaEmprendimiento_v2.xlsx`, `Indicadores financieros — Plataforma de preparación para el
primer empleo en software.pdf` y `sostenibilidad social.pdf`.

Esto es **contexto de producto**, no especificación técnica. Nada de acá se implementa hasta
que una fase lo reclame. Las cifras son supuestos del equipo, no datos medidos.

## Planes

| Plan | Q/mes | Para quién | Incluye | Simulaciones IA | Margen |
|---|---|---|---|---|---|
| Gratis | 0 | Cualquier persona (atrae usuarios) | **Con anuncios.** Diagnóstico técnico, 1 simulación al mes, foros y ofertas | 1 | −Q0.80 (los anuncios dejan Q0.65 en español, Q3.06 en inglés) |
| Estudiantil | 60 | Universitarios con carné, 18–24 años | Sin anuncios, 10 simulaciones con feedback, ruta por área (frontend, backend, datos, QA), puntaje de progreso | 10 | Q46.50 (78 %) |
| Estándar | 75 | Recién graduados y autodidactas | Todo lo Estudiantil + 12 simulaciones y revisión de CV y LinkedIn | 12 | Q59.15 (79 %) |
| Empresarial | 487.50 | Empresas de tecnología y universidades | Ofertas destacadas, perfiles con puntaje validado, reportes de preparación | uso empresarial | Q435.63 (89 %) |

Mezcla de pago supuesta: 70 % Estudiantil, 30 % Estándar. Rango de mercado de la encuesta:
US$5–10 (≈ Q39–Q78); 41 % no pagaría nada.

## Supuestos clave

- Inversión inicial **Q127,000**; costos fijos **Q13,723/mes** (+5 % anual).
- 2,500 usuarios activos en español el año 1, +20 % en inglés; crecimiento +80/50/30/20 %.
- Conversión a pago **5 %** (45 % dijo que pagaría; la compra real suele ser menor).
- Publicidad solo al plan Gratis: 30 vistas/mes, **solo banners o native ads**, nunca pop-ups
  durante una simulación.
- Empresas: 2 en el año 1 → 10 en el año 5. **Ninguna ha sido consultada todavía.**
- TMAR 20 % (6 % plazo fijo + 14 % riesgo).

## Resultados (escenario base)

| Indicador | Resultado |
|---|---|
| ROI a 5 años | 338.7 % |
| VPN | Q117,555 |
| TIR | 38.1 % |
| Payback | 3.2 años |
| Punto de equilibrio | 233 suscriptores/mes (el año 1 proyecta 150, el 64 %) |

Rango: VPN −Q473,314 (bajista, se rechaza) a Q959,516 (alcista).

**El resultado depende de tres cosas** que hay que validar primero: que la versión en inglés
atraiga usuarios de países Tier-1 (si pagan CPM de Latinoamérica el VPN baja a Q20,770); que el
5 % de los gratis pague; y que los anuncios no arruinen la experiencia.

## Sostenibilidad social

1. **Acceso educativo.** Primer mes gratis del plan Estudiantil y descuento mientras se siga
   estudiando, verificado con correo institucional `.edu`. Cuesta Q46.50 de margen por
   estudiante, por eso se limitan los cupos al inicio. Indicadores: estudiantes inscritos con
   correo `.edu`, simulaciones completadas, universidades aliadas, estudiantes activos
   trabajando.
2. **Programa de mentores.** Los usuarios enseñan programación a niños de bajos recursos
   (mínimo de horas al mes) y, al graduarse, conservan el descuento si siguen como mentores.
   Indicadores: horas de mentoría, niños atendidos, mentores activos, graduados que conservan
   el descuento, graduados empleados, duración en el empleo. **Para cuidar a los menores:**
   alianza con una ONG o escuela y filtro de seguridad a los mentores.

## Lo que esto implica para el producto

| Hallazgo | Consecuencia técnica |
|---|---|
| El plan Gratis lleva anuncios y la app es bilingüe | Textos fuera de los componentes desde la Fase 1; slots de anuncio y selector de idioma más adelante |
| Hay cuatro planes y tope de simulaciones por mes | `usage_ledger` ya registra uso y costo por usuario (`operation`, `units`, `cost_micros`) y sirve para contar simulaciones por periodo. Lo que **falta** es el concepto de plan de un usuario |
| Verificación `.edu` | Campo o evento de verificación de correo institucional. No existe todavía en `db.md` |
| Programa de mentores con menores | Datos de menores y verificación de mentores: es un área de **seguridad** nueva, no entra sin su propio modelo de amenazas |
| `memberships` existe en el esquema | Hoy pertenece a una **empresa** (`company_id`), no a un usuario: sirve para el plan Empresarial, pero los planes Estudiantil y Estándar necesitan una tabla o campo nuevo |

## Tensión a resolver

**El modelo de costos supone simulaciones de texto** (≈ US$0.10, Q0.80 por simulación). El
producto, en cambio, está diseñado alrededor de **voz en tiempo real** con OpenAI Realtime
([arquitectura.md](arquitectura.md)). La voz en tiempo real es probablemente más cara que una
simulación de texto, y el margen del 78–79 % de los planes de pago, y el VPN, dependen de ese
costo. Hay que estimar el costo real por sesión de voz (ya figura como decisión abierta en
`continue.md`) y recalcular la hoja `COSTOS`/`PLANES` antes de comprometer precios. Este
repo no lo calculó: es una alerta, no una conclusión.

## Cosas que no coinciden entre fuentes

- La plantilla dice **plan Gratis con 1 simulación al mes**; `producto.md` habla de niveles y
  desbloqueos sin tope por plan. Hay que alinearlos.
- Los PDFs hablan de **Guatemala y Latinoamérica** y los ingresos suponen un mercado en inglés;
  la persona del proyecto (Luis, ver `investigacion.md`) es guatemalteco y los documentos de
  producto no mencionan el mercado en inglés.
