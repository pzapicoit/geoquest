## 1. Controlador: transportar el nombre del lugar

- [x] 1.1 `MapaMundiController.revelarUbicacion` gana el parámetro nombrado
      `required String nombre`; guarda el valor en un campo privado
      `_nombrePinReal`
- [x] 1.2 Exponer `String? get nombrePinReal`
- [x] 1.3 `limpiarRevelado()` resetea `_nombrePinReal` a `null` junto con
      `_pinReal` y `_progresoDeLaLinea`
- [x] 1.4 Actualizar el call site en
      `app/lib/screens/nivel_juego_screen.dart:232` para pasar
      `nombre: revelado.respuesta.nombreLugar`

## 2. `_PinDelMapa`: caja propia, píldora y truncado

- [x] 2.1 Envolver el `Text` del rótulo en un `OverflowBox` (`maxWidth:
      200`, centrado) para desacoplar su ancho del cuadro fijo de 160×160
      del pin
- [x] 2.2 Envolver el texto en un `Container` con `BoxDecoration` de
      píldora: fondo `Color(0xFF0E1620)` a ~72% de opacidad, borde 1px
      blanco al 14%, `borderRadius` de píldora y padding horizontal/vertical
      coherente con `_BotonesDeZoom`
- [x] 2.3 `maxLines: 1` + `TextOverflow.ellipsis` en el texto del rótulo
- [x] 2.4 Mantener la animación de opacidad de entrada existente
      (`entrada.clamp(0.0, 1.0)`) envolviendo la píldora completa, no solo
      el texto

## 3. `_PinDelMapa`: posición del rótulo arriba/abajo

- [x] 3.1 Añadir parámetro `rotuloDebajo` (`bool`, por defecto `false`) a
      `_PinDelMapa`
- [x] 3.2 Cuando `rotuloDebajo` es `true`, posicionar la píldora por debajo
      del pin (reflejo vertical del offset que hoy usa el rótulo de arriba);
      cuando es `false`, mantener el posicionamiento actual por encima
- [x] 3.3 En `MapaMundi.build`, pasar `rotuloDebajo: true` en la llamada de
      `_PinDelMapa` del pin del jugador (el caso en que ya se le pone
      rótulo: cuando existe `pinReal`); dejar el valor por defecto en la
      llamada del pin real

## 4. Rótulo del pin real: nombre en vez de "Real"

- [x] 4.1 En `MapaMundi.build`, pasar `rotulo: controller.nombrePinReal` en
      la llamada de `_PinDelMapa` del pin real, en vez del literal `'Real'`

## 5. Tests

- [x] 5.1 `app/test/mapa_mundi_test.dart`: el pin real muestra el nombre
      recibido por el controlador en vez de "Real"
- [x] 5.2 `app/test/mapa_mundi_test.dart`: un nombre de lugar largo se
      trunca con elipsis y no rompe el layout del pin (no lanza overflow,
      el widget del rótulo no excede su `maxWidth`)
- [x] 5.3 `app/test/mapa_mundi_test.dart`: con pin y pin real muy próximos,
      el rótulo del jugador aparece por debajo de su pin y el real por
      encima del suyo
- [x] 5.4 `app/test/mapa_mundi_controller_test.dart` (si existe cobertura
      equivalente): `revelarUbicacion` expone `nombrePinReal`, y
      `limpiarRevelado` lo limpia

## 6. Verificación manual

- [ ] 6.1 Probar el revelado en el simulador/dispositivo con un nombre de
      lugar corto, uno medio y uno largo ("Parque Nacional Torres del
      Paine"), comprobando legibilidad sobre tierra y sobre océano
- [ ] 6.2 Probar un desafío donde el pin del jugador y el real caigan muy
      cerca (zoom alto de INT-102) y confirmar que los rótulos no se
      solapan
