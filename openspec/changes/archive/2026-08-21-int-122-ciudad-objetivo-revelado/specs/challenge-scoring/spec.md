## MODIFIED Requirements

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
