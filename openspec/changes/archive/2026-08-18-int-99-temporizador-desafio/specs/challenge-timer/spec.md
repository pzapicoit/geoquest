## ADDED Requirements

### Requirement: Cada nivel define su límite de tiempo por desafío
`niveles` SHALL tener una columna `segundos_por_desafio` de tipo entero, no
nula, con un valor por defecto de 60 y una restricción de que sea mayor que
0. Todo nivel, exista ya o se cree a partir de ahora, SHALL tener un límite
de tiempo por desafío válido.

#### Scenario: Se crea un nivel sin especificar los segundos por desafío
- **WHEN** se inserta un nivel sin indicar `segundos_por_desafio`
- **THEN** la fila queda con `segundos_por_desafio = 60`

#### Scenario: Un admin fija un límite propio para un nivel
- **WHEN** se actualiza un nivel con `segundos_por_desafio = 45`
- **THEN** la fila queda con ese valor

#### Scenario: Se intenta un límite inválido
- **WHEN** se intenta insertar o actualizar un nivel con
  `segundos_por_desafio = 0` o negativo
- **THEN** la base de datos rechaza la operación

### Requirement: Marcado del inicio de un desafío dentro de un intento
El sistema SHALL exponer una RPC `marcar_desafio_mostrado(intento_id,
desafio_id)` que fije `intento_desafios.mostrado_en = now()` la primera vez
que se llama para ese par, y no haga nada las llamadas siguientes para el
mismo par. La RPC SHALL rechazar la llamada si el `intento_id` no pertenece
al usuario autenticado actual, sin modificar ninguna fila.

#### Scenario: Primera vez que se muestra un desafío
- **WHEN** un usuario autenticado llama a `marcar_desafio_mostrado` para un
  desafío de su propio intento que todavía no tiene `mostrado_en`
- **THEN** la fila de `intento_desafios` correspondiente queda con
  `mostrado_en` igual al instante de la llamada

#### Scenario: Se reabre la pista de un desafío ya mostrado
- **WHEN** un usuario autenticado llama a `marcar_desafio_mostrado` por
  segunda vez para el mismo desafío del mismo intento
- **THEN** `mostrado_en` conserva su valor original, sin actualizarse

#### Scenario: Se intenta marcar un desafío de un intento ajeno
- **WHEN** un usuario autenticado llama a `marcar_desafio_mostrado` con un
  `intento_id` que no le pertenece
- **THEN** la llamada se rechaza y no se modifica ninguna fila

### Requirement: El tiempo transcurrido siempre lo calcula el servidor
Al registrar una respuesta, el sistema SHALL calcular
`segundos_transcurridos` como el tiempo entre `intento_desafios.mostrado_en`
y el instante de la respuesta, acotado entre 0 y el `segundos_por_desafio`
del nivel del intento. Cuando `mostrado_en` sea `NULL` (no se llamó a
`marcar_desafio_mostrado` para ese desafío), el sistema SHALL tratarlo como
tiempo agotado (`segundos_transcurridos` igual a `segundos_por_desafio`) en
vez de rechazar la respuesta.

#### Scenario: Respuesta bien dentro del tiempo
- **WHEN** se responde a un desafío de un nivel con `segundos_por_desafio =
  60` a los 12 segundos de haberlo marcado como mostrado
- **THEN** la fila registrada queda con `segundos_transcurridos = 12`

#### Scenario: Respuesta que llega después del límite del nivel
- **WHEN** se responde a un desafío 90 segundos después de marcarlo como
  mostrado, en un nivel con `segundos_por_desafio = 60`
- **THEN** la fila registrada queda con `segundos_transcurridos = 60`, no
  90

#### Scenario: Se responde sin haber marcado el desafío como mostrado
- **WHEN** se llama a `responder_desafio` para un desafío cuyo
  `intento_desafios.mostrado_en` es `NULL`
- **THEN** la respuesta se registra igualmente, con `segundos_transcurridos`
  igual al `segundos_por_desafio` del nivel

### Requirement: Registro de tiempo agotado sin pin colocado
El sistema SHALL permitir registrar una respuesta sin coordenadas: la RPC
`responder_desafio` SHALL aceptar latitud y longitud ausentes. Cuando
ambas sean ausentes, la fila registrada SHALL tener `lat_adivinada`,
`lng_adivinada` y `distancia_km` en `NULL` y `puntos = 0`, sin invocar el
cálculo de distancia ni el bonus de tiempo. El sistema SHALL rechazar la
llamada si se proporciona solo una de las dos coordenadas.

#### Scenario: Se agota el tiempo sin ningún pin colocado
- **WHEN** un usuario autenticado llama a `responder_desafio` sin latitud
  ni longitud para un desafío de su propio intento
- **THEN** se inserta una fila en `respuestas_desafio` con
  `lat_adivinada`, `lng_adivinada` y `distancia_km` en `NULL` y
  `puntos = 0`

#### Scenario: Se envía solo una coordenada
- **WHEN** se llama a `responder_desafio` con latitud presente pero
  longitud ausente (o viceversa)
- **THEN** la llamada se rechaza y no se inserta ninguna fila
