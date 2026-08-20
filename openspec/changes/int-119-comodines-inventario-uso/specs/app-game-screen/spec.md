## ADDED Requirements

### Requirement: Bandeja de comodines sobre el mapa

La pantalla de juego SHALL mostrar una bandeja de comodines plegada por defecto sobre el mapa, que se despliega en una fila con los 4 tipos y su cantidad al tocarla, y se repliega al tocarla de nuevo o tocar fuera.

#### Scenario: La bandeja empieza plegada

- **WHEN** se entra en la fase de adivinar de un desafío
- **THEN** la bandeja de comodines se muestra plegada (solo una pestaña visible)

#### Scenario: Se despliega la bandeja

- **WHEN** el jugador toca la pestaña plegada
- **THEN** la bandeja se despliega mostrando los 4 tipos con su cantidad actual

### Requirement: Estado de cada comodín en la bandeja

Cada comodín de la bandeja SHALL mostrarse deshabilitado cuando no quede inventario de ese tipo o cuando ya se haya usado un comodín en el intento en curso. Para el tipo `pais`, cuya disponibilidad depende de un dato del desafío (`desafios.pais`) que el cliente no conoce hasta consumir el comodín, la falta de dato SHALL resolverse como un rechazo normal al tocarlo (sin descontar inventario ni marcar el intento), no como un deshabilitado previo.

#### Scenario: Comodín sin inventario

- **WHEN** el jugador no tiene unidades de un tipo de comodín
- **THEN** ese comodín se muestra atenuado y no se puede tocar

#### Scenario: Ya se usó un comodín en este intento

- **WHEN** el jugador ya consumió un comodín (de cualquier tipo) en el intento en curso
- **THEN** el resto de comodines se muestran deshabilitados para el resto de desafíos de ese intento, aunque tengan inventario

#### Scenario: Comodín país sin dato disponible

- **WHEN** el jugador toca el comodín `pais` en un desafío que no tiene país registrado
- **THEN** el sistema rechaza el consumo con un aviso claro, sin descontar inventario ni marcar el intento como comodín-usado
- **AND** el icono no se muestra deshabilitado de antemano, porque el cliente no puede saber la disponibilidad hasta tocarlo

### Requirement: Overlay de radio en el mapa

Al consumir un comodín `km1000` o `km500`, el mapa SHALL dibujar un círculo centrado en la posición real del objetivo con el radio correspondiente.

#### Scenario: Se consume un comodín de radio

- **WHEN** el jugador consume `km1000` o `km500` con éxito
- **THEN** el mapa dibuja un círculo del radio correspondiente centrado en la posición real del objetivo, visible mientras el jugador sigue en la fase de adivinar de ese desafío
