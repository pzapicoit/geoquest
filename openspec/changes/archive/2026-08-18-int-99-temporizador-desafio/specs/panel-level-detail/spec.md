## MODIFIED Requirements

### Requirement: Tarjeta de configuración del nivel editable
La pantalla SHALL ofrecer una tarjeta "Configuración del nivel" con campos
editables para: el nombre del nivel; el puntaje mínimo para superarlo
(equivalente a ⭐, en puntos absolutos); los umbrales de 2 y 3 estrellas
introducidos como **porcentaje del puntaje máximo del nivel** (`N ×
MAX_PUNTOS_DESAFIO`, con `N` = `preguntas_por_partida` si está definido, o
el número de preguntas del recorrido si no lo está, y `MAX_PUNTOS_DESAFIO`
igual al máximo por desafío incluido el bonus por rapidez); el número de
preguntas por partida (`preguntas_por_partida`, opcional); y los segundos
por desafío (`segundos_por_desafio`, entero mayor que 0, 60 por defecto).
Junto al puntaje mínimo y a cada umbral de estrella, la tarjeta SHALL
mostrar la distancia media en kilómetros que implica alcanzarlo **asumiendo
que no hay bonus por rapidez** (el caso más exigente en precisión). La
tarjeta SHALL bloquear el guardado si no se cumple `puntaje_minimo_superar
<= umbral_estrella_2_absoluto <= umbral_estrella_3_absoluto` (absolutos
derivados de los porcentajes), si `preguntas_por_partida` es mayor que el
número de preguntas ya asignadas al nivel en `nivel_desafios`, o si
`segundos_por_desafio` no es un entero mayor que 0. Al guardar,
`umbral_estrella_1` SHALL persistirse automáticamente con el mismo valor
que `puntaje_minimo_superar`, sin tener un campo propio en el formulario.

#### Scenario: Guardar una configuración válida
- **WHEN** un admin edita el nombre, el puntaje mínimo, los porcentajes de
  umbral 2 y 3 estrellas y los segundos por desafío, manteniendo el orden
  ascendente exigido en sus absolutos derivados, y pulsa "Guardar"
- **THEN** la fila de `niveles` se actualiza con el nombre, el puntaje
  mínimo, los absolutos de `umbral_estrella_2/3` calculados a partir de los
  porcentajes introducidos, `umbral_estrella_1` igual al puntaje mínimo, y
  `segundos_por_desafio`

#### Scenario: Porcentajes fuera de orden
- **WHEN** un admin introduce un porcentaje para el umbral de 3 estrellas
  cuyo absoluto derivado resulta menor que el absoluto derivado del umbral
  de 2 estrellas
- **THEN** el formulario bloquea el guardado y muestra un error indicando
  que los umbrales deben ser ascendentes

#### Scenario: Se muestra la distancia media de cada umbral
- **WHEN** un admin visualiza la tarjeta de configuración de un nivel con
  puntaje mínimo y umbrales de estrella ya definidos
- **THEN** junto a cada uno de los tres (puntaje mínimo, umbral 2 estrellas,
  umbral 3 estrellas) se muestra la distancia media en km que ese puntaje
  implica según la curva de puntuación vigente, sin contar ningún bonus por
  rapidez

#### Scenario: Se define un número válido de preguntas por partida
- **WHEN** un admin fija `preguntas_por_partida = 5` en un nivel que tiene
  8 preguntas asignadas en su recorrido
- **THEN** el formulario guarda el valor sin error

#### Scenario: Se intenta pedir más preguntas de las disponibles
- **WHEN** un admin fija `preguntas_por_partida = 8` en un nivel que solo
  tiene 5 preguntas asignadas en su recorrido
- **THEN** el formulario bloquea el guardado y muestra un error indicando
  que el valor no puede superar el número de preguntas del recorrido

#### Scenario: Se deja preguntas_por_partida sin definir
- **WHEN** un admin guarda la configuración del nivel sin rellenar
  `preguntas_por_partida`
- **THEN** el formulario guarda `NULL`, sin bloquear el guardado, y el
  puntaje máximo del nivel usado para los porcentajes de umbral se calcula
  con el número de preguntas del recorrido

#### Scenario: Se edita el límite de tiempo por desafío
- **WHEN** un admin fija `segundos_por_desafio = 45` y pulsa "Guardar"
- **THEN** la fila de `niveles` se actualiza con `segundos_por_desafio =
  45`, sin afectar al resto de la configuración

#### Scenario: Se intenta un límite de tiempo inválido
- **WHEN** un admin introduce `segundos_por_desafio = 0` o un valor no
  entero
- **THEN** el formulario bloquea el guardado y muestra un error
