## 1. Indicador izquierdo: puntos totales en vez de estrellas requeridas

- [x] 1.1 En `app/lib/screens/camino_screen.dart`, añadir `required this.puntosTotales` (tipo `int`) a `_ParadaTile` y pasarlo desde donde se instancia (`_buildParadaAnimada`/`build` de `_CaminoScreenState`, usando `camino.puntosTotales`).
- [x] 1.2 Sustituir `Text('${parada.estrellasRequeridas} ★', ...)` (columna izquierda, ~línea 675) por el valor formateado de `puntosTotales` usando `_formatMiles`, sin el símbolo ★.
- [x] 1.3 Revisar que `parada.estrellasRequeridas` se sigue usando donde corresponde (cálculo de `_meta`, gating de `bloqueado`) — no debe desaparecer del modelo ni de esos usos, solo dejar de imprimirse en el indicador izquierdo.

## 2. Tests

- [x] 2.1 En `app/test/camino_screen_test.dart`, añadir un test que compruebe que el indicador izquierdo de cada parada muestra `puntosTotales` formateado con separador de miles, y que el valor es idéntico en todas las paradas del camino renderizado.
- [x] 2.2 Añadir un test para el caso `puntosTotales = 0` (jugador sin respuestas todavía).
- [x] 2.3 Añadir un test que compruebe que una parada con `desbloqueado = false` renderiza el icono de candado (`Icons.lock_rounded` / `_CandadoBadge`).
- [x] 2.4 Añadir un test que compruebe que una parada con `desbloqueado = false` aplica el filtro de escala de grises a su portada (`ColorFiltered` con la matriz `_grayscale`), y que una parada desbloqueada no lo aplica.
- [x] 2.5 Ejecutar `flutter test app/test/camino_screen_test.dart` (o el runner del proyecto) y confirmar que toda la suite pasa.

## 3. Verificación manual

- [ ] 3.1 Levantar la app localmente y confirmar visualmente que el indicador izquierdo de cada parada muestra los puntos totales del jugador, coherente con la píldora de la cabecera. — Pendiente de testing local (requiere ejecutar la app).
- [ ] 3.2 Confirmar visualmente que las paradas bloqueadas siguen mostrando candado y portada en gris (sin regresión). — Pendiente de testing local (requiere ejecutar la app).
