## MODIFIED Requirements

### Requirement: Efecto del comodín "tiempo"

Consumir el comodín `tiempo` SHALL detener el cronómetro del desafío en curso por completo: sin límite de tiempo ni auto-envío para esa pregunta, sin afectar al cálculo de puntaje del servidor (que sigue basándose en el tiempo real transcurrido desde que se marcó el desafío como mostrado).

#### Scenario: Se consume el comodín tiempo con la cuenta atrás corriendo

- **WHEN** un jugador con al menos 1 unidad de `tiempo` lo consume durante un desafío en curso
- **THEN** el cronómetro de ese desafío se detiene por completo: no vuelve a disminuir ni dispara el auto-envío
- **AND** el bonus de puntuación por rapidez del servidor para ese desafío se sigue calculando sobre el tiempo real transcurrido, sin ningún ajuste por este consumo

### Requirement: Efecto de los comodines de radio

Consumir `km1000` o `km500` SHALL devolver la posición real del objetivo del desafío en curso junto con el radio correspondiente (500 km para `km1000`, 150 km para `km500`), para que el cliente dibuje un círculo de acierto sobre el mapa, sin revelar `nombre_lugar`.

#### Scenario: Se consume un comodín de radio

- **WHEN** un jugador con al menos 1 unidad de `km1000` o `km500` lo consume en un desafío en curso
- **THEN** recibe la coordenada real del objetivo y el radio correspondiente al tipo consumido (500 km para `km1000`, 150 km para `km500`)
- **AND** no recibe `nombre_lugar` en esa misma respuesta
