## 1. Botón fijo de jugar

- [x] 1.1 Añadir constante `_ctaAltura` en `camino_screen.dart` (espacio
      reservado para el botón).
- [x] 1.2 Crear `_BotonJugar` (estilo consistente con `_StartButton` de
      `username_screen.dart`: degradado teal→azul, sombra sólida, texto
      "Jugar nivel N · Tema" en Baloo 2).
- [x] 1.3 Mostrarlo con `Positioned` sobre el `Stack` de `CaminoScreen`
      solo cuando exista una parada `esActual`; al tocarlo, reusar
      `_onTapParada` con esa parada.

## 2. Centrado de caminos cortos

- [x] 2.1 En `build()`, calcular `contenidoAltura` (suma de alturas de
      `camino.entradas`), `disponible` (alto de pantalla menos
      `_topBarAltura` y `_ctaAltura`) y `extra` (mitad del sobrante,
      con mínimo 0).
- [x] 2.2 Usar `_topBarAltura + extra` y `_ctaAltura + extra` como
      padding superior/inferior del `ListView`, en vez de las
      constantes fijas de antes.
- [x] 2.3 Pasar el mismo `paddingBottom` calculado a `_autoScroll` para
      que su cálculo de offset siga centrando la parada actual con el
      padding real, no con una constante desincronizada.

## 3. Tests

- [x] 3.1 Test de widget: con una sola parada, el botón "Jugar nivel"
      aparece y navega a esa parada.
- [x] 3.2 Test de widget: con un camino completo (ninguna parada
      `esActual`), el botón no aparece.
- [x] 3.3 Test de widget: con un camino corto (una parada, viewport
      real), la parada no queda pegada al borde inferior — su centro
      cae dentro de una banda central razonable de la pantalla.
- [x] 3.4 Reconfirmar que el test de auto-scroll con camino largo
      (7 niveles) sigue centrando igual que antes (regresión).
