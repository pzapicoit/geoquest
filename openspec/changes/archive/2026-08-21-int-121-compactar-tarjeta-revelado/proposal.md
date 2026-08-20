## Why

La hoja de resultado del revelado (`_HojaDeRevelado`) ha ido acumulando
información hasta ocupar casi la mitad de la pantalla, justo cuando lo que el
jugador quiere ver es el mapa que hay detrás: su pin, el pin real y la línea
que los une. Cuatro de esos elementos no aportan nada a la lectura del
resultado y sí quitan mapa: el botón "Repetir animación" (que nadie necesita
para entender qué ha pasado), la línea "/ máximo" bajo los puntos, las
coordenadas del lugar real (un dato que el jugador ya ve en el mapa) y el
desglose de precisión/bonus apilado en dos líneas cuando cabe de sobra en una.

## What Changes

- Quitar el botón "Repetir animación" del revelado (`nivel-juego-repetir`) y,
  con él, el parámetro `onRepetir` de `_HojaDeRevelado`. La coreografía sigue
  lanzándose sola al confirmar y al agotarse el tiempo: `_lanzarElRevelado`
  se queda, solo deja de tener una entrada manual.
- Quitar la línea "/ máximo" de `_TarjetaDePuntos`
  (`nivel-juego-puntos-maximos`). La tarjeta enseña solo los puntos ganados.
  `RespuestaDesafio.puntosMaximos` se queda en el modelo (el RPC lo devuelve
  y el parseo estricto avisa si el contrato cambia), pero tras este cambio no
  lo pinta ninguna pantalla: la referencia de "qué tal lo he hecho" la da el
  resumen del nivel, con el umbral para superarlo y las estrellas.
- Quitar las coordenadas reales de `_LugarRevelado`
  (`nivel-juego-coordenadas-reales`). `formatearCoordenadas` se mantiene: la
  sigue usando el chip del pin del jugador en la fase de adivinar.
- Unir precisión y bonus en una sola línea en `_DesgloseDePuntaje`, separados
  por un punto medio ("4.301 puntos de precisión · +80 por rapidez"), con las
  mismas claves, el mismo copy y la misma regla de hoy (sin línea de bonus
  cuando es 0).
- Ajustar el margen inferior del encuadre del revelado
  (`_margenesDelRevelado`, hoy `alto * 0.48`) a la altura real de la hoja.
  Medido a 390×844: la hoja de hoy ocupa 465 px y la franja de 0.48 reserva
  405, así que hoy **se queda corta** y el encuadre puede dejar un pin justo
  detrás del borde superior de la hoja. Podada, la hoja baja a 373 px, y la
  franja pasa a `alto * 0.46` más la barra inferior del sistema (que el
  `SafeArea` de la hoja suma tal cual): así cubre la hoja en cualquier móvil
  sin reservar de más. Es la misma regla de encuadre de siempre ("el más
  cercano que deje los dos pines dentro del área útil"), aplicada a un área
  útil que ahora sí está bien medida.

Sin cambios de esquema, de RPC ni de cálculo de puntos: todo es presentación.
Ningún cambio breaking de API.

## Capabilities

### New Capabilities
<!-- Ninguna: la hoja de revelado ya está cubierta por `app-game-screen`. -->

### Modified Capabilities
- `app-game-screen`: la descripción del contenido de la hoja de resultado deja
  de incluir las coordenadas del lugar real y el máximo alcanzable junto a los
  puntos; desaparece la acción de repetir la animación (requirement y
  escenario); y el desglose de precisión/bonus pasa a mostrarse en una sola
  línea.

## Impact

- `app/lib/screens/nivel_juego_screen.dart`: `_HojaDeRevelado` (botón
  quitado, parámetro `onRepetir` fuera), `_LugarRevelado`, `_TarjetaDePuntos`
  (parámetro `maximo` fuera), `_DesgloseDePuntaje` (Column → línea única) y
  la constante del margen inferior de `_margenesDelRevelado`.
- `app/test/nivel_juego_screen_test.dart`: se cae el test "repetir la
  animación no vuelve a llamar al servidor"; hay que reescribir el test del
  lugar real (ya sin coordenadas) y las aserciones que buscan "/ 5.000"; y
  añadir aserciones nuevas de que las tres piezas quitadas ya no están y de
  que precisión y bonus comparten línea.
- `app/lib/services/nivel_juego_gateway.dart`: sin cambios, pero su campo
  `puntosMaximos` queda sin ningún consumidor de UI (ver arriba).
- Sin impacto en el panel, en Postgres ni en `resumen_nivel_screen.dart`, que
  conserva su propio "Repetir animación" (fuera del alcance de esta historia).
- Riesgo: el desglose en una línea puede no caber con tamaños de fuente de
  accesibilidad grandes; se resuelve dejándolo replegar a dos líneas en vez
  de recortar texto (ver `design.md`).
