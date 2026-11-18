## 1. Piezas de movimiento reutilizables

- [ ] 1.1 `app/lib/motion/presencia.dart`: `Presencia` con estilos deslizar y fundido, retraso, salida con último hijo guardado, `IgnorePointer` y `ExcludeSemantics` durante la salida y fundido con «reducir movimiento»
- [ ] 1.2 `app/lib/motion/pulsable.dart`: `Pulsable` con escala al pulsar, sin reacción si está deshabilitado o con «reducir movimiento»
- [ ] 1.3 `app/lib/motion/fondo_de_carga.dart`: `FondoDeCarga` con brillo en bucle, quieto con «reducir movimiento»
- [ ] 1.4 Tests de las tres piezas: entrada y salida, ignorar toques al salir, reducir movimiento, `pumpAndSettle` termina cuando no hay bucle

## 2. Fases de la pantalla de juego

- [ ] 2.1 Envolver en `Presencia` la tarjeta de pista (deslizar), los controles de adivinar y la bandeja (fundido), la hoja del revelado (deslizar) y el aviso (fundido)
- [ ] 2.2 Pasar las entradas existentes de `_ToastPista` y `_HojaDeRevelado` a `Presencia` con `Movimiento` (D8), incluido el fondo oscuro de la pista
- [ ] 2.3 Entrada de la pista del siguiente desafío con retraso `Movimiento.media` tras continuar desde el revelado, sin cambiar la lógica de `_avanzarDesdeElRevelado` (D2)
- [ ] 2.4 Tests: la pista sale animada al cerrarla, los controles aparecen con fundido, la hoja sale antes de que entre la siguiente pista, y un toque durante la salida no hace nada

## 3. Pin, vibración y respuesta al pulsar

- [ ] 3.1 Caída con rebote de `_PinDelMapa` del jugador, que se repite con cada coordenada nueva y no ocurre con «reducir movimiento»
- [ ] 3.2 Vibración: `selectionClick` al colocar el pin, `mediumImpact` al confirmar a mano y `heavyImpact` una vez por revelado con puntos
- [ ] 3.3 `Pulsable` en Confirmar, Ver la pista, Listo, Continuar y los botones de cristal
- [ ] 3.4 Tests: vibraciones interceptadas en el canal de plataforma (también que no vibra con 0 puntos ni al agotarse el tiempo), escala del botón pulsado y deshabilitado, y caída del pin

## 4. Cargas

- [ ] 4.1 `_CargandoIntento` con logo, pulso y texto en lugar del `CircularProgressIndicator` de la carga del intento
- [ ] 4.2 `frameBuilder` en `_PistaImagen` y `_MiniaturaDeLaPista`: `FondoDeCarga` y fundido si la imagen llega de red, directa si viene de caché
- [ ] 4.3 Actualizar los tests que buscaban `CircularProgressIndicator` y añadir tests de imagen de caché frente a imagen de red, comprobando que el provider sigue coincidiendo con la precarga (INT-120)

## 5. Verificación

- [ ] 5.1 Suite completa de `flutter test`, `flutter analyze` y `dart format`
- [ ] 5.2 Prueba en el iPhone en release: fases, cambio de desafío, pin, vibración y carga de imágenes, con y sin «reducir movimiento»
