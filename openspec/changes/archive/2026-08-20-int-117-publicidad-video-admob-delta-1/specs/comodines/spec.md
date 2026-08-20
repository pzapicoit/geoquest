## MODIFIED Requirements

### Requirement: Obtención de comodines por vídeo publicitario

El sistema SHALL permitir conceder 1 comodín de un tipo aleatorio (entre los 4, con igual probabilidad) tras el visionado completo de un vídeo publicitario recompensado (`RewardedAd`, iniciado por el jugador — distinto del `RewardedInterstitialAd` de gating de `video-ads`), hasta un tope de 4 concesiones por jugador y día. Esta vía SHALL ser la única forma de obtención implementada en esta capability; cualquier otra vía (canje de puntos, compra) SHALL mostrarse en la interfaz sin funcionalidad. El comodín SHALL concederse únicamente si el anuncio se cargó, se mostró y el jugador ganó la recompensa; si el anuncio no carga, falla o se cierra sin completar el visionado, el sistema SHALL rechazar la concesión sin tocar el servidor ni el inventario.

#### Scenario: Se concede un comodín tras ver un anuncio, bajo el tope

- **WHEN** un jugador que no ha alcanzado el tope diario completa el visionado de un anuncio y gana la recompensa
- **THEN** recibe 1 unidad de un tipo de comodín elegido al azar, sumada a su inventario

#### Scenario: Se alcanza el tope diario de concesiones por anuncio

- **WHEN** un jugador que ya alcanzó las 4 concesiones diarias por anuncio intenta obtener otro comodín por esta vía
- **THEN** el sistema rechaza la concesión sin modificar su inventario

#### Scenario: El anuncio no carga o no se completa

- **WHEN** un jugador toca "Ver un anuncio" pero el anuncio no llega a cargar, falla, o se cierra antes de ganar la recompensa
- **THEN** la app avisa sin conceder ningún comodín
- **AND** no se llama al servidor para conceder nada

#### Scenario: La vía de anuncio está disponible

- **WHEN** un jugador toca "Ver un anuncio" en la pantalla Comodines
- **THEN** la app intenta cargar y mostrar un anuncio real, sin mostrar un aviso de "próximamente"
