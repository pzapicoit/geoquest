## ADDED Requirements

### Requirement: Lenguaje de movimiento común
La app SHALL definir en un único sitio las duraciones y curvas de animación con nombre, y una única forma de consultar si el jugador ha pedido «reducir movimiento» en el sistema. Las transiciones entre pantallas SHALL tomar sus duraciones y curvas de ahí.

#### Scenario: Una transición usa los valores comunes
- **WHEN** se construye cualquier transición entre pantallas de la app
- **THEN** su duración y su curva salen de la base de movimiento común y no de valores escritos en la propia pantalla

### Requirement: Transición del juego al entrar en una pantalla
Al apilar una pantalla sobre la actual (camino → nivel, camino → ranking, camino → comodines), la app SHALL usar una transición de profundidad propia del juego (escala y fundido), no la transición por defecto de la plataforma. En iOS SHALL conservarse la transición nativa con el gesto de deslizar para volver.

#### Scenario: Entrar en un nivel desde el camino en Android o web
- **WHEN** el jugador toca una parada desbloqueada del camino en Android o en web
- **THEN** la pantalla de juego entra con la transición de profundidad del juego

#### Scenario: Volver al camino
- **WHEN** el jugador vuelve atrás desde una pantalla apilada
- **THEN** la transición se reproduce a la inversa y el camino recupera su lugar

#### Scenario: Entrar en el ranking en iOS
- **WHEN** el jugador abre el ranking en iOS
- **THEN** la pantalla entra con la transición nativa de iOS y puede volver deslizando desde el borde

### Requirement: Transición de relevo al sustituir una pantalla
Al sustituir la pantalla actual por otra (splash → login, login → camino, apodo → camino, nivel → resumen, resumen → reintentar el nivel), la app SHALL usar un fundido cruzado propio del juego en todas las plataformas.

#### Scenario: Terminar un nivel
- **WHEN** el jugador cierra el último desafío y la app pasa al resumen del nivel
- **THEN** la pantalla de juego se desvanece y el resumen aparece con el fundido cruzado del juego

#### Scenario: Arranque de la app
- **WHEN** el splash termina de resolver la sesión y navega a la pantalla de entrada
- **THEN** el cambio se hace con el fundido cruzado del juego

### Requirement: Reducir movimiento en las transiciones
Si el sistema tiene activado «reducir movimiento», todas las transiciones entre pantallas SHALL limitarse a un fundido de opacidad, sin escala ni desplazamiento.

#### Scenario: Navegar con reducir movimiento activo
- **WHEN** el jugador tiene activado «reducir movimiento» y navega entre dos pantallas
- **THEN** la nueva pantalla aparece con un fundido, sin escalar ni desplazarse

### Requirement: Las transiciones terminan
Toda transición entre pantallas SHALL tener una duración finita, de modo que los widget tests que navegan puedan esperar a que la pantalla quede estable con `pumpAndSettle()`.

#### Scenario: Test que navega
- **WHEN** un widget test provoca una navegación y llama a `pumpAndSettle()`
- **THEN** la llamada termina y la pantalla de destino queda visible
