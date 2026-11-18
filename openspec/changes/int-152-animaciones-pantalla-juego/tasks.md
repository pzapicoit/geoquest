## 1. Piezas de movimiento reutilizables

- [x] 1.1 `app/lib/motion/presencia.dart`: `Presencia` con estilos deslizar y fundido, retraso, salida con último hijo guardado, `IgnorePointer` y `ExcludeSemantics` durante la salida y fundido con «reducir movimiento»
- [x] 1.2 `app/lib/motion/pulsable.dart`: `Pulsable` con escala al pulsar, sin reacción si está deshabilitado o con «reducir movimiento»
- [x] 1.3 `app/lib/motion/fondo_de_carga.dart`: `FondoDeCarga` con brillo en bucle, quieto con «reducir movimiento»
- [x] 1.4 Tests de las tres piezas: entrada y salida, ignorar toques al salir, reducir movimiento, `pumpAndSettle` termina cuando no hay bucle

## 2. Fases de la pantalla de juego

- [x] 2.1 Envolver en `Presencia` la tarjeta de pista (deslizar), los controles de adivinar y la bandeja (fundido), la hoja del revelado (deslizar) y el aviso (fundido)
- [x] 2.2 Pasar las entradas existentes de `_ToastPista` y `_HojaDeRevelado` a `Presencia` con `Movimiento` (D8), incluido el fondo oscuro de la pista
- [x] 2.3 Entrada de la pista del siguiente desafío con retraso `Movimiento.media` tras continuar desde el revelado, sin cambiar la lógica de `_avanzarDesdeElRevelado` (D2)
- [x] 2.4 Tests: la pista sale animada al cerrarla, los controles aparecen con fundido, la hoja sale antes de que entre la siguiente pista, y un toque durante la salida no hace nada

## 3. Pin, vibración y respuesta al pulsar

- [x] 3.1 Caída con rebote de `_PinDelMapa` del jugador, que se repite con cada coordenada nueva y no ocurre con «reducir movimiento»
- [x] 3.2 Vibración: `selectionClick` al colocar el pin, `mediumImpact` al confirmar a mano y `heavyImpact` una vez por revelado con puntos
- [x] 3.3 `Pulsable` en Confirmar, Ver la pista, Listo, Continuar y los botones de cristal
- [x] 3.4 Tests: vibraciones interceptadas en el canal de plataforma (también que no vibra con 0 puntos ni al agotarse el tiempo), escala del botón pulsado y deshabilitado, y caída del pin

## 4. Cargas

- [x] 4.1 `_CargandoIntento` con logo, pulso y texto en lugar del `CircularProgressIndicator` de la carga del intento
- [x] 4.2 `frameBuilder` en `_PistaImagen` y `_MiniaturaDeLaPista`: `FondoDeCarga` y fundido si la imagen llega de red, directa si viene de caché
- [x] 4.3 Actualizar los tests que buscaban `CircularProgressIndicator` y probar los tres casos de `apareceAlCargar` (caché, red sin fotograma, red con fotograma); los tests de INT-120 que comparan el provider siguen pasando sin cambios

## 5. Correcciones de la revisión adversarial

- [x] 5.1 Marco de tiempo crítico y barra de cuenta atrás con `Presencia`, y HUD sin salto de alto
- [x] 5.2 «Reducir movimiento» en «Ver la pista», el punto que late y el destello de los puntos; spec acotada a lo decorativo
- [x] 5.3 Guardas contra un segundo envío por teclado, mapa inerte durante el paso al siguiente desafío y Confirmar sin parpadeo al salir
- [x] 5.4 Tests: pista y «Ver la pista» con «reducir movimiento», destello con y sin el ajuste, tiempo agotado con pin sin vibrar como confirmar y doble «Siguiente» durante la salida
- [x] 5.5 Sección de movimiento de `.devplugin/architecture.md` con las piezas nuevas y la vibración

## 6. Verificación

- [x] 6.1 Suite completa de `flutter test`, `flutter analyze` y `dart format`
- [ ] 6.2 Prueba en el iPhone en release: fases, cambio de desafío, pin, vibración y carga de imágenes, con y sin «reducir movimiento»
