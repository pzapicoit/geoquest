## 1. Gateway: eliminar la frontera

- [x] 1.1 Quitar `ParadaFrontera`, `intercalarFronteras` y `_fronteraHacia`
      de `app/lib/services/camino_gateway.dart`.
- [x] 1.2 Convertir `CaminoJugador.entradas` a `List<ParadaCamino>` y
      eliminar la `sealed class CaminoEntrada` (ya sin más de un subtipo).
- [x] 1.3 `SupabaseCaminoGateway.fetchCamino` usa `paradas` directamente en
      vez de `intercalarFronteras(paradas)`.
- [x] 1.4 Actualizar `app/test/camino_gateway_test.dart`: eliminar el grupo
      `intercalarFronteras` y ajustar los tipos donde se referencie
      `CaminoEntrada`/`ParadaFrontera`.
- [x] 1.5 Actualizar `app/test/fakes/fake_camino_gateway.dart` y
      `app/test/camino_screen_test.dart` si referencian `ParadaFrontera` o
      `CaminoEntrada` (tipar `camino` con `List<ParadaCamino>`), quitando el
      test `'la frontera bloqueada muestra cuántas estrellas faltan'`.

## 2. Pantalla: quitar `_FronteraTile` y reforzar el gris de bloqueadas

- [x] 2.1 Eliminar `_FronteraTile` y `_fronteraAltura` de
      `camino_screen.dart`; simplificar el `for` del `ListView` (ya no
      distingue `ParadaFrontera` de `ParadaCamino`).
- [x] 2.2 En `_ParadaTile`, atenuar el título (`tematicaNombre`) a
      `Colors.white.withValues(alpha: 0.62)` cuando `bloqueado`.
- [x] 2.3 En `_NumeroBadge`, añadir un estado "bloqueado" (fondo y borde
      grises en vez del acento de temática) y pasarlo desde `_ParadaTile`.
      También se añadió un borde a toda tarjeta (antes inexistente, como en
      el mock), atenuado a `Colors.white12` cuando está bloqueada.
- [x] 2.4 Test de regresión: una parada bloqueada no debe mostrar ningún
      elemento con el color de acento de su temática (número, borde).

## 3. Riel de progreso vertical

- [x] 3.1 Calcular, junto a `alturas`/`contenidoAltura` (ya existentes en
      `build`), el offset acumulado hasta la parada `es_actual` (o hasta el
      final si no hay actual), reutilizando la misma lógica que
      `_autoScroll`.
- [x] 3.2 Añadir dentro del `Stack` que envuelve las filas del `ListView`
      dos `Positioned`/`Container` de 6px de ancho: la pista de fondo
      (`Colors.white.withValues(alpha: 0.08)`) de extremo a extremo, y el
      segmento relleno con `LinearGradient` teal desde la marca actual hasta
      el nivel 1.
- [x] 3.3 Verificar alineación horizontal del riel con el círculo indicador
      de cada parada (columna de 52px a la izquierda de la tarjeta).
- [x] 3.4 Test de widget: con progreso parcial, el segmento relleno cubre
      desde la parada actual hasta el final; con camino completo, cubre
      todo.

## 4. Desvanecido de contenido bajo cabecera y botón de jugar

- [x] 4.1 Envolver el `ListView` en un `ShaderMask` (`BlendMode.dstIn`) con
      un `LinearGradient` que funda a transparente los primeros ~120px
      (bajo la cabecera) y los últimos ~140px (bajo el botón de jugar) del
      área visible, dejando opaco el resto.
      Nota de implementación: el `ListView(reverse:true)` original se
      sustituyó por `SingleChildScrollView` + `Stack` de posición absoluta
      (mismo enfoque que el mock), necesario también para el riel (#3) y la
      animación (#5); el `ShaderMask` envuelve ese nuevo árbol igual.
- [x] 4.2 Ajustar los porcentajes del gradiente a `_topBarAltura`/
      `_ctaAltura` reales en vez de los píxeles fijos del mock (390×844),
      para que la franja de desvanecido coincida con el tamaño real de
      cabecera y botón.
- [ ] 4.3 Comprobar manualmente que una tarjeta que se desplaza bajo la
      cabecera o el botón se disuelve gradualmente, sin verse cortada en un
      borde duro. — Pendiente de testing local (requiere ejecutar la app).

## 5. Animación de aparición ligada al scroll

- [x] 5.1 Calcular, en `_onScroll` (o en `build` a partir del offset ya
      guardado), la posición `top` acumulada de cada parada (mismo cálculo
      que `_autoScroll`) y su posición relativa al viewport.
      Nota: implementado con `AnimatedBuilder(animation: _controller)`
      alrededor del `Stack` de paradas, en vez de `setState` en `_onScroll`,
      para no reconstruir toda la pantalla (cabecera, `FutureBuilder`) en
      cada frame de scroll — mismo resultado, más barato.
- [x] 5.2 Implementar la curva smoothstep del mock
      (`out = max(0, TOP_EDGE - vt, vb - BOTTOM_EDGE)`,
      `p = clamp(1 - out/RAMP, 0, 1)`, `ease = p²(3-2p)`) para derivar
      `opacity`, `scale` (0.93 + 0.07·ease) y `translateY` por parada.
- [x] 5.3 Aplicar `Opacity` + `Transform` (escala y traslación) a cada
      `_ParadaTile` con esos valores, actualizándolos en cada notificación
      de scroll.
- [ ] 5.4 Prueba manual de rendimiento: hacer scroll rápido por un camino
      con varias decenas de niveles y confirmar que no hay jank apreciable.
      — Pendiente de testing local (requiere ejecutar la app).

## 6. Verificación de comportamiento ya correcto (sin cambio esperado)

- [x] 6.1 Test de regresión: el nivel 1 se sigue mostrando al final
      (abajo) del `ListView` y el de `orden` más alto arriba, tras quitar
      la frontera.
- [x] 6.2 Test de regresión: el auto-centrado en la parada `es_actual` al
      montar sigue funcionando igual sin las alturas de frontera mezcladas
      en el cálculo. — Cubierto por el test ya existente
      `'el auto-scroll deja la parada actual visible y centrada en la
      pantalla'`, que sigue en verde tras el cambio.

## 7. Documentación y cierre

- [x] 7.1 Ejecutar `flutter test` completo del módulo `app`. — 229/229 OK.
- [x] 7.2 Ejecutar `flutter analyze` sobre `app/lib` y `app/test`. — sin
      incidencias.
- [x] 7.3 Actualizar `.devplugin/architecture.md` si documenta la parada
      frontera o el camino vertical. — No la documenta a ese nivel de
      detalle; sin cambios necesarios.
