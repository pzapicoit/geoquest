## Why

En la pantalla de juego casi todo aparece y desaparece de golpe. La pista y la hoja del revelado tienen animación de entrada, pero no de salida. Los controles, la bandeja de comodines y los avisos se cortan en seco al cambiar de fase. No hay vibración en ningún momento, los botones no reaccionan al pulsarlos y la carga del intento es el indicador circular por defecto.

En la prueba en iPhone de INT-151 se vio además que la imagen de la pista tarda en llegar y mientras tanto no se ve nada. Las imágenes pesan entre 1,1 y 1,8 MB (WebP sin pérdida o PNG, 1024 px). Optimizar ese peso es trabajo de backend y va en otra issue; aquí se cubre la espera.

INT-151 dejó la base de movimiento (`app/lib/motion/`) para esto.

## What Changes

- **Entradas y salidas** de cada fase de la pantalla de juego:
  - La pista y la hoja del revelado entran y salen deslizándose.
  - Los controles de adivinar, la bandeja de comodines y los avisos entran y salen con fundido.
  - Las entradas que ya existían pasan a la base de movimiento común.
- **Paso de un desafío al siguiente:** la hoja del revelado sale antes de que entre la pista del siguiente, en vez de cambiar todo en el mismo fotograma.
- **Pin:** cae con un pequeño rebote cada vez que se coloca o se mueve.
- **Vibración** (iOS y Android; en web no hace nada):
  - leve al colocar el pin;
  - media al confirmar;
  - de éxito cuando termina de contar los puntos del revelado.
- **Botones que reaccionan** al pulsarlos (ligera reducción de escala): Confirmar, Ver la pista, Listo, Continuar y los botones de cristal.
- **Carga del intento** con el estilo del juego en vez del `CircularProgressIndicator`.
- **Carga de la imagen de la pista:** se ve un fondo animado mientras llega y la imagen aparece con un fundido. Igual en la miniatura del revelado.
- Con **«reducir movimiento»**, nada se desplaza, escala ni rebota: las entradas y salidas son fundidos y el fondo de carga queda quieto. La vibración se mantiene, porque no es movimiento en pantalla.

## Capabilities

### New Capabilities
<!-- Ninguna -->

### Modified Capabilities
- `app-game-screen`: se añaden requisitos sobre transiciones de las fases, pin, vibración, respuesta al pulsar y aspecto de las cargas. Ningún requisito existente cambia de comportamiento.

## Impact

- `app/lib/screens/nivel_juego_screen.dart`: capa visual del `build`, `_ToastPista`, `_HojaDeRevelado`, `_ControlesAdivinar`, `_Aviso`, `_PistaImagen`, `_MiniaturaDeLaPista` y el estado de carga.
- `app/lib/mapa/mapa_mundi.dart`: animación de caída de `_PinDelMapa`.
- `app/lib/screens/bandeja_comodines.dart`: solo si hace falta para el fundido de entrada y salida.
- Nuevas piezas reutilizables en `app/lib/motion/` (presencia animada, pulsable, fondo de carga), que usará también INT-153.
- Sin cambios en backend, RPC ni lógica de juego: la coreografía del revelado, la cuenta atrás y el tope de lectura (INT-143, INT-114) no se tocan.
