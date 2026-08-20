# challenge-scoring Specification

## Purpose
TBD - created by archiving change int-78-calcular-distancia-puntaje. Update Purpose after archive.

## Requirements

### Requirement: Cálculo de distancia entre coordenadas
El sistema SHALL proveer una función que calcule la distancia en
kilómetros entre dos pares de coordenadas (latitud/longitud) usando la
fórmula de Haversine.

#### Scenario: Misma ubicación exacta
- **WHEN** se calcula la distancia entre dos coordenadas idénticas
- **THEN** el resultado es 0 (o un valor despreciable por redondeo de
  punto flotante)

#### Scenario: Extremos opuestos del globo
- **WHEN** se calcula la distancia entre dos coordenadas antipodales
  (extremos opuestos de la Tierra)
- **THEN** el resultado es aproximadamente la circunferencia media
  terrestre entre antípodas (~20000 km)

### Requirement: Cálculo del componente de distancia del puntaje
El sistema SHALL traducir una distancia en kilómetros al componente de
puntaje por precisión mediante una curva exponencial con suelo, de forma
que puntúe a cualquier distancia: puntaje máximo (`MAX`) en distancia 0,
decreciente de forma exponencial según una escala de kilómetros (`k`), sin
llegar nunca a 0 y sin bajar nunca del suelo mínimo configurado (`PISO`).
Este componente es la base sobre la que se aplica el bonus por rapidez
(ver "Bonus por rapidez sobre el puntaje"); no es, por sí solo, el puntaje
final que se persiste en `respuestas_desafio.puntos`.

#### Scenario: Distancia cero
- **WHEN** la distancia calculada es 0
- **THEN** el componente de distancia es exactamente el puntaje máximo
  configurado (`MAX`)

#### Scenario: Distancia en las antípodas
- **WHEN** la distancia calculada es la máxima posible entre dos puntos del
  globo (~20.015 km)
- **THEN** el componente de distancia es exactamente el suelo mínimo
  configurado (`PISO`)

#### Scenario: Distancia intermedia
- **WHEN** la distancia calculada está entre 0 y la distancia máxima posible
  entre dos puntos del globo
- **THEN** el componente de distancia decrece de forma exponencial según la
  distancia y queda estrictamente entre `PISO` y `MAX`

#### Scenario: A mayor distancia, nunca más componente de distancia
- **WHEN** se comparan dos distancias donde la primera es menor que la
  segunda
- **THEN** el componente de distancia calculado para la primera es mayor o
  igual que el calculado para la segunda

#### Scenario: El componente de distancia nunca baja del suelo ni sube del máximo
- **WHEN** se calcula el componente de distancia para cualquier distancia no
  negativa
- **THEN** el resultado está siempre en el rango cerrado `[PISO, MAX]`

### Requirement: RPC para registrar la respuesta de un jugador a un desafío
El sistema SHALL exponer una RPC de Supabase que reciba el intento, el
desafío y la coordenada adivinada por el jugador (ausente cuando el tiempo
se agotó sin pin colocado — ver `challenge-timer`), calcule distancia,
tiempo transcurrido y puntaje en el servidor, los persista en
`respuestas_desafio` y devuelva, junto con la respuesta registrada, el
revelado del desafío que se acaba de responder: su coordenada real, el
nombre del lugar, la ciudad del objetivo y el puntaje máximo alcanzable.

La ciudad SHALL viajar tal cual está en `desafios.ciudad`, incluido `NULL`
cuando ese desafío no tiene ciudad registrada: distinguir "sin ciudad" de
"ciudad vacía" es lo que permite a la app decidir qué rotular.

El revelado SHALL entregarse únicamente como resultado de registrar la
jugada. La RPC SHALL no ofrecer ninguna vía para consultar la coordenada
real de un desafío sin responderlo, y el resto de superficies de lectura
(`desafios`, `desafios_para_jugar`, `iniciar_intento_parada`) SHALL seguir
sin exponer ni la coordenada real, ni `nombre_lugar`, ni `ciudad`.

#### Scenario: Un jugador responde a un desafío de su propio intento
- **WHEN** un usuario autenticado llama a la RPC con un `intento_id` que le
  pertenece, un `desafio_id` válido y una coordenada adivinada
- **THEN** se inserta una fila en `respuestas_desafio` con la distancia y
  el puntaje calculados por el servidor
- **AND** la respuesta de la RPC incluye esa distancia y ese puntaje

#### Scenario: La respuesta revela la ubicación del desafío respondido
- **WHEN** un usuario autenticado registra su respuesta a un desafío
- **THEN** la respuesta de la RPC incluye `lat_real`, `lng_real`,
  `nombre_lugar` y `ciudad` de ese desafío, más el puntaje máximo que se
  podía conseguir (incluido el bonus por rapidez)

#### Scenario: La respuesta de un desafío sin ciudad registrada
- **WHEN** un usuario autenticado registra su respuesta a un desafío cuya
  `ciudad` es `NULL`
- **THEN** la respuesta de la RPC incluye `ciudad` en `null`, y el resto del
  revelado llega igual que en cualquier otra respuesta

#### Scenario: La respuesta desglosa el puntaje en precisión y bonus
- **WHEN** un usuario autenticado registra su respuesta con un pin colocado
- **THEN** la respuesta de la RPC incluye, además de `puntos` (el total),
  `puntos_distancia` (el componente de precisión) y `puntos_bonus`
  (`puntos - puntos_distancia`)

#### Scenario: El desglose es cero en una respuesta sin pin
- **WHEN** un usuario autenticado registra una respuesta sin coordenadas
  (tiempo agotado sin pin colocado)
- **THEN** `puntos`, `puntos_distancia` y `puntos_bonus` son todos `0` en la
  respuesta de la RPC

#### Scenario: Un jugador intenta responder a un intento ajeno
- **WHEN** un usuario autenticado llama a la RPC con un `intento_id` que no
  le pertenece
- **THEN** la llamada se rechaza, no se inserta ninguna fila y no se revela
  ninguna coordenada real

#### Scenario: Un jugador intenta volver a responder el mismo desafío del intento
- **WHEN** un usuario autenticado llama a la RPC con un `intento_id` y un
  `desafio_id` para los que ya hay respuesta registrada
- **THEN** la llamada se rechaza sin registrar una segunda respuesta

#### Scenario: La ubicación real sigue oculta fuera de la jugada
- **WHEN** un jugador (incluida una sesión anónima) intenta leer la
  coordenada real, el `nombre_lugar` o la `ciudad` de un desafío por
  cualquier otra vía —`select` sobre `desafios`, `desafios_para_jugar` o la
  respuesta de `iniciar_intento_parada`—
- **THEN** no los obtiene por ninguna de ellas

### Requirement: Persistencia de distancia, tiempo y puntaje siempre calculados por el servidor
Toda fila insertada en `respuestas_desafio` SHALL tener, sin importar la
vía de inserción, `distancia_km`, `segundos_transcurridos` y `puntos`
recalculados por el servidor —a partir de `lat_adivinada`/`lng_adivinada`
(cuando estén presentes) y las coordenadas reales del desafío referenciado,
y de `intento_desafios.mostrado_en`—, descartando cualquier valor recibido
en el `insert` para esas columnas.

#### Scenario: Insert directo con valores manipulados
- **WHEN** se inserta una fila en `respuestas_desafio` indicando un
  `distancia_km`/`puntos` arbitrario junto con `lat_adivinada`/
  `lng_adivinada` válidas
- **THEN** la fila queda guardada con `distancia_km`/`puntos` calculados
  por el servidor, no con los valores recibidos en el `insert`

#### Scenario: Insert directo con segundos_transcurridos manipulado
- **WHEN** se inserta una fila en `respuestas_desafio` indicando un
  `segundos_transcurridos` arbitrario
- **THEN** la fila queda guardada con `segundos_transcurridos` calculado
  por el servidor a partir de `intento_desafios.mostrado_en`, no con el
  valor recibido en el `insert`

### Requirement: Bonus por rapidez sobre el puntaje
El sistema SHALL sumar al componente de distancia un bonus por rapidez
proporcional tanto a la fracción de tiempo restante como a la fracción de
acierto (componente de distancia normalizado entre `PISO` y `MAX`), de
forma que una respuesta en el suelo de precisión no reciba bonus por rápida
que sea, y una respuesta que agota el tiempo no reciba bonus por precisa
que sea. El puntaje final (`respuestas_desafio.puntos`) SHALL ser la suma
del componente de distancia y este bonus, con un máximo por desafío de
`MAX + BONUS_MAX`.

#### Scenario: Máximo puntaje posible
- **WHEN** la distancia es 0 y el tiempo transcurrido es 0
- **THEN** el puntaje es `MAX + BONUS_MAX`

#### Scenario: Precisión perfecta pero tiempo agotado
- **WHEN** la distancia es 0 pero el tiempo transcurrido iguala o supera
  `segundos_por_desafio`
- **THEN** el bonus es 0 y el puntaje es exactamente `MAX`

#### Scenario: Respuesta en el suelo de precisión, aunque sea instantánea
- **WHEN** el componente de distancia de la respuesta es exactamente
  `PISO`, sin importar cuánto tiempo transcurrido tenga
- **THEN** el bonus es 0 y el puntaje es exactamente `PISO`

#### Scenario: Respuesta intermedia y a mitad de tiempo
- **WHEN** el componente de distancia está estrictamente entre `PISO` y
  `MAX`, y el tiempo transcurrido es menor que `segundos_por_desafio`
- **THEN** el bonus es mayor que 0 y el puntaje final es mayor que el
  componente de distancia solo
