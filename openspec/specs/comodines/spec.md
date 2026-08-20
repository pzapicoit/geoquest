# comodines Specification

## Purpose
TBD - created by archiving change int-119-comodines-inventario-uso. Update Purpose after archive.

## Requirements

### Requirement: Catálogo cerrado de tipos de comodín

El sistema SHALL reconocer exactamente 4 tipos de comodín: `tiempo` (detiene el cronómetro del desafío en curso), `pais` (revela el país del objetivo), `km1000` y `km500` (acotan el objetivo a ese radio).

#### Scenario: Se consulta el inventario de un jugador

- **WHEN** un jugador autenticado consulta su inventario de comodines
- **THEN** recibe una cantidad (posiblemente 0) para cada uno de los 4 tipos, nunca un tipo desconocido ni ausente

### Requirement: Semilla de inventario al crear el perfil

Todo perfil nuevo SHALL recibir 1 unidad de `tiempo`, `pais` y `km1000`, y 0 unidades de `km500`.

#### Scenario: Se crea una sesión anónima nueva

- **WHEN** se crea un nuevo usuario (alta anónima u otra vía) y su perfil correspondiente
- **THEN** su inventario de comodines queda en `{tiempo: 1, pais: 1, km1000: 1, km500: 0}`

### Requirement: Como máximo un comodín por intento

Un intento de parada SHALL permitir el uso de como mucho 1 comodín (de cualquier tipo), sin importar cuántos desafíos tenga ese intento.

#### Scenario: Se usa un comodín en el primer desafío del intento

- **WHEN** un jugador usa un comodín en el desafío 1 de un intento con varios desafíos
- **THEN** el comodín se consume del inventario
- **AND** ningún comodín (del mismo tipo o de otro) puede usarse en el resto de desafíos de ese mismo intento

#### Scenario: Se intenta usar un segundo comodín en el mismo intento

- **WHEN** un jugador que ya usó un comodín en un intento intenta usar otro comodín (del mismo tipo o distinto) en un desafío posterior del mismo intento
- **THEN** el sistema rechaza la operación sin descontar inventario

#### Scenario: Un intento nuevo no hereda la restricción del anterior

- **WHEN** un jugador empieza un intento nuevo (de la misma parada o de otra) tras haber usado un comodín en un intento previo ya cerrado
- **THEN** puede volver a usar un comodín en este intento nuevo, sujeto solo a que le quede inventario

### Requirement: Efecto del comodín "tiempo"

Consumir el comodín `tiempo` SHALL detener el cronómetro del desafío en curso por completo: sin límite de tiempo ni auto-envío para esa pregunta, sin afectar al cálculo de puntaje del servidor (que sigue basándose en el tiempo real transcurrido desde que se marcó el desafío como mostrado).

#### Scenario: Se consume el comodín tiempo con la cuenta atrás corriendo

- **WHEN** un jugador con al menos 1 unidad de `tiempo` lo consume durante un desafío en curso
- **THEN** el cronómetro de ese desafío se detiene por completo: no vuelve a disminuir ni dispara el auto-envío
- **AND** el bonus de puntuación por rapidez del servidor para ese desafío se sigue calculando sobre el tiempo real transcurrido, sin ningún ajuste por este consumo

### Requirement: Efecto del comodín "país" y su disponibilidad

Consumir el comodín `pais` SHALL revelar el país real del objetivo del desafío en curso, sin exponer `nombre_lugar` ni las coordenadas exactas. Si el desafío en curso no tiene país registrado, el sistema SHALL rechazar el consumo sin descontar inventario ni marcar el intento como comodín-usado.

#### Scenario: Se consume el comodín país en un desafío con país registrado

- **WHEN** un jugador con al menos 1 unidad de `pais` lo consume en un desafío cuyo país está registrado
- **THEN** recibe el nombre del país real del objetivo
- **AND** no recibe `nombre_lugar` ni coordenadas exactas en esa misma respuesta

#### Scenario: Se intenta consumir el comodín país en un desafío sin país registrado

- **WHEN** un jugador intenta consumir `pais` en un desafío cuyo país es `NULL`
- **THEN** el sistema rechaza la operación con un motivo identificable (`pais_no_disponible`)
- **AND** el inventario del jugador y la marca de comodín-usado del intento quedan sin cambios

### Requirement: Efecto de los comodines de radio

Consumir `km1000` o `km500` SHALL devolver la posición real del objetivo del desafío en curso junto con el radio correspondiente (500 km para `km1000`, 150 km para `km500`), para que el cliente dibuje un círculo de acierto sobre el mapa, sin revelar `nombre_lugar`.

#### Scenario: Se consume un comodín de radio

- **WHEN** un jugador con al menos 1 unidad de `km1000` o `km500` lo consume en un desafío en curso
- **THEN** recibe la coordenada real del objetivo y el radio correspondiente al tipo consumido (500 km para `km1000`, 150 km para `km500`)
- **AND** no recibe `nombre_lugar` en esa misma respuesta

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
