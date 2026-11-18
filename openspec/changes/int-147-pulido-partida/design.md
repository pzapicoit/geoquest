## Context

Son ocho arreglos pequeños e independientes en cinco ficheros de la app y un
dato de la base. Se agrupan en un cambio porque comparten objetivo (pulido, sin
lógica de juego nueva) y forma de verificarse: tests de widget y una pasada
visual en 390×844.

## Goals / Non-Goals

**Goals:** que nada se corte, que la hoja de resultado no se contradiga, que el
copy diga la verdad y que los dos botones sin nombre lo tengan.

**Non-Goals:** desglose del resumen por desafío (issue aparte); auditoría
completa de accesibilidad; cambiar la coreografía de la hoja de resultado más
allá de cuándo aparecen sus cifras.

## Decisions

**D1. Encoger antes que cortar en la cabecera del camino.** El apodo y la línea
de progreso van en `FittedBox(fit: scaleDown, alignment: centerLeft)`. Con el
ancho normal se ven igual que hoy; solo se encogen cuando la píldora de puntos
crece. El formato compacto «Nivel N/M · E/T ★» reduce cuánto hay que encoger.
- *Alternativa:* quitar elementos de la barra. Se descarta porque es un cambio
  de diseño.

**D2. Nombre de la parada en su propia línea.** En `_TarjetaDeProgreso`, la fila
«Desafío N de M · NOMBRE» pasa a ser dos líneas. La tarjeta crece unos 14 px de
alto, que tapan mapa bajo la cabecera, no bajo la hoja de resultado (INT-121).

**D3. Rótulo del pin con `SingleChildLayoutDelegate`.** `_PinDelMapa` recibe el
ancho del mapa. Un delegado coloca el rótulo centrado y lo restringe a
`[8, ancho - 8]` en coordenadas del mapa, usando el ancho **real** del rótulo,
conocido en el layout. Sustituye al `OverflowBox` centrado.

**D4. «—» hasta que cuente.** `_HojaDeRevelado` recibe el avance de cada
contador. Con avance 0 pinta «—»; el desglose usa el avance de los puntos como
opacidad. No se tocan los tiempos de la coreografía.

**D5. Tono del resumen por tramos.** Una función pura
`animoNoSuperado(porcentaje)` devuelve título y frase. Se prueba con una tabla.

**D6. «Películas» por migración de datos.** Mismo patrón que INT-142: `update`
condicionado al valor viejo (idempotente, no pisa cambios desde el panel), y
`seed.sql` actualizado. Se aplica en producción solo con luz verde explícita,
después de la revisión de `ecc:database-reviewer`.

**D7. Accesibilidad tras las revisiones de ECC.**
- Los dos botones de solo icono llevan la acción en su `Semantics` (`onTap`),
  porque `excludeSemantics` oculta la del `GestureDetector`/`InkWell` de dentro.
- La X de la pista tiene una diana de 44 px con el mismo aspecto de 30.
- Las dos cabeceras que encogen texto van en
  `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)`. Sin tope, una
  escala de sistema alta haría que `FittedBox` las dejara ilegibles.
- La hoja de resultado se anuncia con los valores finales de la respuesta, no
  con «—» ni con la cifra que se está animando.
- La píldora de puntos lleva un ancho máximo en vez de `Flexible`, que
  competiría por flex con el texto de la cabecera.

## Risks / Trade-offs

- [Texto encogido en la cabecera del camino] → Con 16 caracteres y 6 cifras de
  puntos baja a ~85 % del tamaño, legible. Es mejor que una elipsis.
- [Tarjeta de progreso más alta] → Unos 14 px más de mapa tapado arriba. Se
  acepta a cambio de leer el nombre de la parada.
