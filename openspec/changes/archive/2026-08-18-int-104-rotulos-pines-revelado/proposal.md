## Why

Al revelar la respuesta, el pin de la ubicación real se rotula con la
palabra fija `"Real"` en vez del nombre del sitio, aunque ese nombre ya
llega a la pantalla y hoy solo se pinta en la hoja de resultado, no en el
mapa —justo donde el jugador está mirando cuando aparece el pin—. Además el
rótulo se dibuja como texto suelto de 10px sin fondo, encajado en el mismo
cuadro fijo de 160×160 del pin: con un nombre real largo ("Parque Nacional
Torres del Paine") se sale del cuadro, y sobre zonas claras del mapa se lee
mal. INT-102 ya deja acercar más en el revelado, así que los pines van a
caer cerca con más frecuencia y sus rótulos solaparse.

## What Changes

- `revelarUbicacion` pasa a recibir también el nombre del lugar, y
  `MapaMundiController` lo expone junto al resto del estado del pin real.
- El rótulo del pin real muestra ese nombre en vez de `"Real"`.
- El rótulo de cualquiera de los dos pines se dibuja sobre una píldora con
  fondo propio, en una caja independiente del cuadro de 160×160 del pin, con
  truncado de una línea y elipsis para nombres que no quepan.
- El rótulo del pin del jugador se dibuja por debajo de su pin y el de la
  ubicación real por encima, para que nunca se solapen entre sí
  independientemente de lo cerca que caigan los dos pines en pantalla.
- El rótulo del pin del jugador sigue siendo `"Tu pin"`: con la píldora
  nueva ya no depende solo del color para distinguirse del real.

## Capabilities

### New Capabilities

(ninguna)

### Modified Capabilities

- `app-world-map`: dos requisitos cambian.
  - "El mapa muestra la ubicación real junto al pin del jugador" — el
    rótulo del pin real pasa a ser el nombre del lugar (no la palabra fija
    "Real"), ambos rótulos se dibujan con una píldora propia que trunca
    nombres largos, y su posición relativa al pin (arriba/abajo) queda
    definida para que nunca se solapen.
  - "El mapa dibuja el mundo sin ningún topónimo" — se acota a antes de
    revelar la respuesta: una vez revelada, el rótulo del pin real sí puede
    nombrar el lugar, porque el desafío ya está resuelto y deja de ser una
    pista.

## Impact

- `app/lib/mapa/mapa_mundi.dart`: `_PinDelMapa` gana caja de rótulo propia,
  píldora de fondo, truncado y posición configurable arriba/abajo.
- `app/lib/mapa/mapa_mundi_controller.dart`: `revelarUbicacion` recibe el
  nombre; `MapaMundiController` lo expone y `limpiarRevelado` lo limpia.
- `app/lib/screens/nivel_juego_screen.dart`: la llamada a
  `revelarUbicacion` pasa `revelado.respuesta.nombreLugar`.
- `app/test/mapa_mundi_test.dart` y, si aplica,
  `app/test/mapa_mundi_controller_test.dart`: cobertura del nombre mostrado
  y de nombres largos.
