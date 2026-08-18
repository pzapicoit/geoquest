## MODIFIED Requirements

### Requirement: Cada dificultad define el límite de tiempo por desafío, sobreescribible por parada
`dificultad_defaults` SHALL tener una columna `segundos_por_desafio` de tipo
entero, no nula, con restricción de que sea mayor que 0, para cada una de
las 5 dificultades. `camino` SHALL tener una columna `segundos_por_desafio`
opcional (nullable) que, cuando esté rellena, sobreescribe el valor de
`dificultad_defaults` para esa posición concreta. Toda parada, con o sin
override, SHALL tener un límite de tiempo por desafío efectivo válido.

#### Scenario: Una parada sin override usa el valor de su dificultad
- **WHEN** una parada tiene `dificultad = 'normal'` y su `segundos_por_desafio`
  propio en `NULL`, y `dificultad_defaults` tiene `segundos_por_desafio = 75`
  para `'normal'`
- **THEN** el límite efectivo de esa parada es 75

#### Scenario: Un admin fija un límite propio para una parada
- **WHEN** se actualiza una parada de `camino` con `segundos_por_desafio = 45`
- **THEN** su límite efectivo pasa a ser 45, sin importar el valor de
  `dificultad_defaults` para su dificultad

#### Scenario: Se intenta un límite inválido
- **WHEN** se intenta insertar o actualizar una fila de `dificultad_defaults`
  o un override de `camino` con `segundos_por_desafio = 0` o negativo
- **THEN** la base de datos rechaza la operación

### Requirement: El tiempo transcurrido siempre lo calcula el servidor
Al registrar una respuesta, el sistema SHALL calcular
`segundos_transcurridos` como el tiempo entre `intento_desafios.mostrado_en`
y el instante de la respuesta, acotado entre 0 y el `segundos_por_desafio`
efectivo de la parada del intento. Cuando `mostrado_en` sea `NULL` (no se
llamó a `marcar_desafio_mostrado` para ese desafío), el sistema SHALL
tratarlo como tiempo agotado (`segundos_transcurridos` igual al
`segundos_por_desafio` efectivo) en vez de rechazar la respuesta.

#### Scenario: Respuesta bien dentro del tiempo
- **WHEN** se responde a un desafío de una parada cuyo `segundos_por_desafio`
  efectivo es 60, a los 12 segundos de haberlo marcado como mostrado
- **THEN** la fila registrada queda con `segundos_transcurridos = 12`

#### Scenario: Respuesta que llega después del límite de la parada
- **WHEN** se responde a un desafío 90 segundos después de marcarlo como
  mostrado, en una parada cuyo `segundos_por_desafio` efectivo es 60
- **THEN** la fila registrada queda con `segundos_transcurridos = 60`, no
  90

#### Scenario: Se responde sin haber marcado el desafío como mostrado
- **WHEN** se llama a `responder_desafio` para un desafío cuyo
  `intento_desafios.mostrado_en` es `NULL`
- **THEN** la respuesta se registra igualmente, con `segundos_transcurridos`
  igual al `segundos_por_desafio` efectivo de la parada
