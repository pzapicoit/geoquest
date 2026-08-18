## Context

`CaminoScreen` (INT-90 + delta-1) se construyó sin acceso al mock definitivo
de Claude Design (`[App] - Camino vertical.dc.html`, proyecto "GeoQuest"),
documentado como no disponible en varios `design.md` archivados. Esta sesión
sí ha podido leerlo vía el MCP de Claude Design (`DesignSync`), incluida su
lógica de referencia (`DCLogic` embebido en el propio `.dc.html`). Ese mock
es la fuente de verdad para los puntos 2 (frontera), 5 (riel), 6 (cabecera) y
7 (animación de scroll) de INT-105; los puntos 1 (orden) y 4 (auto-centrado)
ya están resueltos en el código actual y solo necesitan test de regresión;
el punto 3 (gris de bloqueadas) es una brecha real entre la spec vigente y
el código, no solo un ajuste visual.

Aritmética de referencia del mock (constantes de su `Component`):
`ROW_H = 208`, `GAP = 22`, `PAD_TOP = 132`, `PAD_BOTTOM = 128`, viewport de
diseño `VH = 844`. El camino se construye recorriendo los niveles en orden
**descendente** (`k` de `length-1` a `0`) acumulando `top`, de forma que el
nivel de `orden` más alto queda arriba (`top` pequeño) y el nivel 1 queda
abajo (`top` más grande) — confirma que `ListView(reverse: true)` con
`entradas` en `orden` ascendente (código actual) ya reproduce esto sin
cambios.

## Goals / Non-Goals

**Goals:**
- Eliminar la parada frontera (código y spec) sin romper el resto del
  camino ni el auto-centrado.
- Que una parada bloqueada se perciba íntegramente atenuada (portada, número,
  título, borde, marca del riel), no solo la imagen.
- Añadir un riel de progreso vertical (pista + segmento relleno) fiel al
  mock, alineado con los indicadores de cada parada.
- Que las tarjetas se desvanezcan al entrar/salir bajo la cabecera y el
  botón de jugar, en vez de cortarse en un borde duro.
- Reproducir la animación de aparición ligada al scroll del mock (escala,
  opacidad y traslación suave cerca de los bordes superior e inferior del
  área visible).

**Non-Goals:**
- No se añade botón de atrás: la Home es la pantalla raíz tras el splash;
  el propio mock tampoco lo trae en la cabecera (solo perfil, nombre,
  progreso y puntos).
- No se replica el "kicker" de texto "NIVEL N" que el mock añade sobre el
  título de la temática: es un elemento nuevo no pedido por ninguno de los
  7 puntos de INT-105; se deja como observación de producto, no como tarea.
- No se cambia la unidad mostrada bajo cada indicador del riel (estrellas
  requeridas, ya implementado) por el "puntos" de ejemplo del mock: es una
  diferencia de dominio ya asumida desde INT-90.
- No se toca el backend ni `camino_jugador`.

## Decisions

**D1 — Frontera: eliminación completa, no solo visual.**
Se retira `_FronteraTile` de `camino_screen.dart` y, en el gateway,
`ParadaFrontera`, `intercalarFronteras` y `_fronteraHacia`. Como
`ParadaFrontera` era el único motivo para que `CaminoEntrada` fuera una
`sealed class` con dos subtipos, `CaminoJugador.entradas` pasa a ser
`List<ParadaCamino>` directamente — elimina un nivel de indirección que ya
no representa nada. `SupabaseCaminoGateway.fetchCamino` deja de llamar a
`intercalarFronteras` y usa `paradas` tal cual.
Alternativa descartada: mantener `ParadaFrontera` sin usarla (dead code) —
no aporta nada y confunde a quien lea el gateway después.

**D2 — Atenuado completo de parada bloqueada: extender `_ParadaTile`, no
introducir un widget nuevo.**
Hoy solo la portada aplica `ColorFilter.matrix(_grayscale)`. Replicando los
valores del mock (`locked` en su `renderVals()`), se añade atenuación por
`opacity`/color a: el círculo y el texto del indicador del riel (ya usa
`Colors.white24`, se mantiene), el `_NumeroBadge` (fondo y borde grises en
vez del acento de la temática), el borde de la tarjeta (`Colors.white12` ya
usado, se mantiene) y el título (`tematicaNombre`) — pasa de blanco puro a
`Colors.white.withValues(alpha: 0.62)` cuando `bloqueado`, igual que
`titleColor` del mock. No se introduce un widget "atenuado" genérico:
son los mismos widgets existentes leyendo `bloqueado` donde antes no lo
hacían.

**D3 — Riel de progreso: dos `Positioned` fijos dentro del `Stack` interior
del `ListView`, calculados con la misma aritmética que ya usa `_autoScroll`
para offsets.**
El mock dibuja el riel como dos capas absolutas dentro del contenido
scrolleable (no del viewport): una pista de fondo de extremo a extremo
(`rgba(255,255,255,.08)`, 6px, `left: 38px`) y un segmento relleno con
degradado teal (`rgba(43,192,168,.25)` → `#2BC0A8`) que va desde la marca de
la parada actual hasta el final (nivel 1, abajo del todo) — representa lo ya
recorrido. Se implementa como dos `Container` de ancho fijo (6px) y altura
`contenidoAltura` (pista) / `contenidoAltura - offsetHastaActual` (relleno),
posicionados dentro del `Stack` que ya envuelve las filas del `ListView`
(mismo espacio de coordenadas que usa `_autoScroll`, reutilizando el cálculo
de `acumulado` hasta el índice de la parada actual). Si no hay parada actual
(camino completo), el relleno cubre el 100% del riel.
Alternativa descartada: `CustomPainter` sobre todo el `ListView` — más
control pero innecesario para dos rectángulos con degradado fijo; los
`Container` con `BoxDecoration.gradient` bastan y son más simples de testear.

**D4 — Desvanecido de contenido: `ShaderMask` sobre el `ListView`, no un
degradado más fuerte en la cabecera.**
El mock no resuelve el "no bloque sólido" oscureciendo más la cabecera:
aplica una máscara (`mask-image`) al contenedor scrolleable que funde a
transparente las tarjetas en los primeros/últimos píxeles (bajo la cabecera
y bajo el botón de jugar). En Flutter el equivalente es un `ShaderMask` con
`BlendMode.dstIn` y un `LinearGradient` de franjas
`transparent → opaque → transparent` en las proporciones del mock
(aprox. 0–120px y 800–844px sobre un alto de diseño de 844px, escalado al
alto real del viewport), envolviendo el `ListView`. La cabecera
(`_BarraSuperior`) conserva su propio fondo (ya con degradado), pero deja de
ser la única responsable del efecto: ahora son las tarjetas las que se
disuelven al pasar por debajo, en vez de quedar cortadas por el borde de la
cabecera.
Alternativa descartada: aumentar la opacidad/alto del degradado de la
cabecera — no evita el corte duro de las tarjetas, solo lo oculta parcialmente
detrás de más cabecera opaca.

**D5 — Animación de aparición ligada al scroll: cálculo por posición
conocida (misma técnica que `_autoScroll`), sin `RenderBox`/`GlobalKey`.**
Como las alturas de cada fila ya son fijas y conocidas de antemano (D4 del
`design.md` de INT-90), la posición absoluta de cada parada dentro del
contenido (`top` acumulado) se calcula igual que en `_autoScroll`, y su
posición relativa al viewport es `top - scrollOffset` (ajustada al sentido
de `reverse: true`). Se reproduce la curva del mock:
`out = max(0, TOP_EDGE - vt, vb - BOTTOM_EDGE)`,
`p = clamp(1 - out/RAMP, 0, 1)`, `ease = p² (3 - 2p)` (smoothstep), aplicada
a `opacity`, `scale` (0.93 + 0.07·ease) y `translateY` (hasta 34px con signo
según el borde del que se aleje). Se recalcula en cada notificación de
`_onScroll` (ya existente) guardando el offset en el `State` y usando ese
valor para transformar cada `_ParadaTile` con `Transform` + `Opacity` en el
`build`. Con el tamaño típico del camino (decenas de niveles, no miles),
recalcular todas las filas visibles en cada scroll es barato; no se
introduce virtualización nueva.
Alternativa descartada: `IntersectionObserver`-like con `VisibilityDetector`
(paquete externo) o medir con `GlobalKey`/`RenderBox` — añade una
dependencia o una capa de indirección que la aritmética ya conocida hace
innecesaria.

## Risks / Trade-offs

- **[Riesgo] Recalcular transform en cada scroll con `setState`** podría
  generar jank en caminos muy largos → Mitigación: el nº de niveles es
  acotado (decenas, no miles); si se detecta jank en pruebas manuales, la
  vía de escape es limitar el recálculo a las filas dentro de un rango
  ampliado del viewport en vez de todas.
- **[Riesgo] `ShaderMask` sobre un `ListView` grande puede tener coste de
  composición** en dispositivos de gama baja → Mitigación: la máscara cubre
  solo bandas finas (~120px) en los extremos; se acepta el coste estándar de
  `ShaderMask`, ya usado en patrones equivalentes de Flutter (fade edges).
- **[Riesgo] Quitar `ParadaFrontera` es un cambio de tipo público** en
  `camino_gateway.dart` (`CaminoEntrada` deja de tener sentido como sealed
  class) → Mitigación: no hay consumidores fuera de `camino_screen.dart` y
  los tests del propio módulo; se actualizan en el mismo cambio.

## Migration Plan

Sin migración de datos: cambio puramente de app.
1. Simplificar el gateway (`CaminoJugador.entradas: List<ParadaCamino>`,
   eliminar frontera) y sus tests/fake.
2. Reforzar el atenuado de bloqueadas en `_ParadaTile`/`_NumeroBadge`.
3. Añadir el riel de progreso.
4. Sustituir el degradado de cabecera por `ShaderMask` sobre el `ListView`.
5. Añadir la animación ligada al scroll sobre `_ParadaTile`.
Rollback: revertir el commit restaura el comportamiento actual (con
frontera, sin riel ni animación).

## Open Questions

Ninguna bloqueante: los puntos 5 y 7, antes ambiguos por falta de mock, ya
quedan resueltos con la lectura del `.dc.html` de referencia.
