## ADDED Requirements

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

### Requirement: Cálculo de puntaje a partir de la distancia
El sistema SHALL traducir una distancia en kilómetros a un puntaje entero
no negativo: puntaje máximo cuando la distancia es 0, decreciente de forma
lineal, y exactamente 0 a partir de un umbral de distancia configurado.

#### Scenario: Distancia cero
- **WHEN** la distancia calculada es 0
- **THEN** el puntaje es el puntaje máximo configurado

#### Scenario: Distancia igual o mayor al umbral
- **WHEN** la distancia calculada es igual o mayor al umbral configurado
- **THEN** el puntaje es 0

#### Scenario: Distancia intermedia
- **WHEN** la distancia calculada está entre 0 y el umbral configurado
- **THEN** el puntaje es proporcional a cuánto de ese rango se ha
  recorrido, redondeado a un entero

### Requirement: RPC para registrar la respuesta de un jugador a un desafío
El sistema SHALL exponer una RPC de Supabase que reciba el intento, el
desafío y la coordenada adivinada por el jugador, calcule distancia y
puntaje en el servidor, y los persista en `respuestas_desafio` sin exponer
nunca la coordenada real del desafío al llamante.

#### Scenario: Un jugador responde a un desafío de su propio intento
- **WHEN** un usuario autenticado llama a la RPC con un `intento_id` que le
  pertenece, un `desafio_id` válido y una coordenada adivinada
- **THEN** se inserta una fila en `respuestas_desafio` con la distancia y
  el puntaje calculados por el servidor
- **AND** la respuesta de la RPC no incluye `lat_real` ni `lng_real` del
  desafío

#### Scenario: Un jugador intenta responder a un intento ajeno
- **WHEN** un usuario autenticado llama a la RPC con un `intento_id` que no
  le pertenece
- **THEN** la llamada se rechaza y no se inserta ninguna fila

### Requirement: Persistencia de distancia y puntaje siempre calculados por el servidor
Toda fila insertada en `respuestas_desafio`, sin importar la vía de
inserción, SHALL tener `distancia_km` y `puntos` recalculados por el
servidor a partir de `lat_adivinada`/`lng_adivinada` y las coordenadas
reales del desafío referenciado, descartando cualquier valor recibido en
el `insert` para esas dos columnas.

#### Scenario: Insert directo con valores manipulados
- **WHEN** se inserta una fila en `respuestas_desafio` indicando un
  `distancia_km`/`puntos` arbitrario junto con `lat_adivinada`/
  `lng_adivinada` válidas
- **THEN** la fila queda guardada con `distancia_km`/`puntos` calculados
  por el servidor, no con los valores recibidos en el `insert`
