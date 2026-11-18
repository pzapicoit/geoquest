## 1. Cabeceras

- [x] 1.1 Tests: cabecera del camino sin elipsis con apodo de 16 caracteres y 123 456 puntos; formato «Nivel N/M · E/T ★»; trofeo anunciado como «Clasificación»
- [x] 1.2 `camino_screen.dart`: `FittedBox(scaleDown)` en apodo y progreso, formato compacto y `Semantics` del trofeo
- [x] 1.3 Tests y código: «Desafío N de M» y el nombre de la parada en líneas separadas en `_TarjetaDeProgreso`

## 2. Mapa

- [x] 2.1 Test: con un pin real a 20 px del borde izquierdo, el rótulo empieza a ≥ 8 px del borde; con el pin centrado, el rótulo queda centrado
- [x] 2.2 `mapa_mundi.dart`: `_RotuloDentroDelMapa` y ancho del mapa en `_PinDelMapa`

## 3. Hoja de resultado y pista

- [x] 3.1 Tests: primer fotograma de la hoja con «—» y sin desglose; al terminar, valores finales y desglose visibles
- [x] 3.2 `nivel_juego_screen.dart`: «—» hasta que avance cada contador y desglose con la opacidad del avance de los puntos
- [x] 3.3 Tests y código: «IMAGEN · PISTA N», instrucción «Coloca tu pin lo más cerca que puedas.» y la X anunciada como «Cerrar pista»

## 4. Resumen y bienvenida

- [x] 4.1 Tests de `animoNoSuperado` por tramos (38 %, 50 %, 79 %, 80 %, 90 %) y del resumen con 38 %
- [x] 4.2 `resumen_nivel_screen.dart`: título y frase según el tramo
- [x] 4.3 Tests y código: «Siguiente: X» sin repetir cuando la parada no tiene título propio

## 5. «Películas»

- [x] 5.1 Migración de datos `tematicas.nombre` «Peliculas» → «Películas», condicionada al valor viejo, y `seed.sql`
- [ ] 5.2 Revisión `ecc:database-reviewer`, simulación con `db push --dry-run` y aplicación en producción **solo con luz verde explícita**

## 6. Cierre

- [x] 6.1 `flutter analyze`, `dart format` y `flutter test` en verde
- [x] 6.2 Revisión `ecc:a11y-architect` de los dos botones y de la cabecera encogida
- [ ] 6.3 Prueba en web (Chrome DevTools o Playwright): cabeceras, rótulos al borde, hoja de resultado, resumen y bienvenida
