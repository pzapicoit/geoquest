---
type: scope
parent: int-90-camino-niveles-home
reason: Al probar en local, faltaba el botón "Jugar nivel N · Tema" del
  diseño de referencia, y con pocos niveles cargados el camino queda
  anclado muy abajo, con un vacío enorme encima que no respeta el diseño.
---

## Why

Al implementar INT-90 se omitió, sin documentarlo como decisión, el
botón fijo inferior "Jugar nivel N · Tema" que sí trae el mock de
referencia (`[App] - Camino vertical.dc.html`). Además, el diseño de
referencia da por hecho un camino largo (13 niveles); con el contenido
real actual (1-2 niveles) el camino queda anclado al fondo del `ListView`
invertido con un vacío enorme encima, lo que en testing local se percibe
como que no respeta el diseño.

## What Changes

- Se añade el botón fijo inferior "Jugar nivel N · Tema" (CTA principal),
  visible siempre sobre el camino, que navega al nivel de la parada
  `es_actual` — igual que el mock de referencia. Si no hay parada actual
  (camino completo), el botón no se muestra.
- Se ajusta el layout del camino para que, cuando el contenido total sea
  más corto que la pantalla visible, quede apoyado justo encima del
  botón (con un margen pequeño) y el hueco sobrante suba hacia la barra
  superior, en vez de quedar pegado al fondo con un vacío por encima.
- Las tarjetas de parada pasan a tener la misma altura que el mock de
  referencia (`ROW_H = 208`), más proporcionadas que antes.

## Capabilities

### New Capabilities
(ninguna)

### Modified Capabilities
- `app-player-path-home`: se añade el requisito del botón "Jugar nivel"
  y se precisa el layout para caminos más cortos que la pantalla.

## Impact

- **Código modificado**: `app/lib/screens/camino_screen.dart` (nuevo
  botón inferior, ajuste de padding/centrado del `ListView`).
- Sin cambios de backend ni de gateway.
