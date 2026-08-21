## MODIFIED Requirements

### Requirement: Barra superior con identidad, progreso y puntos totales
La Home SHALL mostrar una barra superior fija con el nombre de usuario
guardado, un acceso al perfil y los puntos totales del jugador, calculados
sumando el mejor intento (`mejor_puntaje`) de todas las paradas que devuelve
`camino_jugador`.

La Home NO SHALL consultar `respuestas_desafio` para calcular ese total:
sale de la misma lectura de `camino_jugador` con la que pinta el camino.

#### Scenario: Se cargan los puntos totales del jugador
- **WHEN** la Home termina de cargar el progreso del jugador
- **THEN** la barra superior muestra la suma de `mejor_puntaje` de todas las
  paradas de su camino

#### Scenario: Jugador sin respuestas todavía
- **WHEN** un jugador que nunca respondió ningún desafío abre la Home
- **THEN** la barra superior muestra 0 puntos totales

#### Scenario: Repetir una parada no sube el total
- **WHEN** un jugador vuelve a jugar una parada ya superada y saca menos
  puntos que su mejor intento
- **THEN** el total de la barra superior no cambia

#### Scenario: El total se calcula sin consultar las respuestas
- **WHEN** la Home carga el progreso del jugador
- **THEN** no se emite ninguna consulta a `respuestas_desafio`

### Requirement: Indicador de puntos totales junto a cada parada
El indicador de la columna izquierda de cada parada SHALL mostrar los puntos
**acumulados hasta esa parada** — la suma de `mejor_puntaje` de todas las
paradas cuyo `orden` es menor o igual al de esa parada —, formateados con
separador de miles, en vez del número de estrellas requeridas para esa parada
y en vez del total del jugador repetido en todas.

El acumulado de la última parada del camino SHALL coincidir por construcción
con el total que muestra la barra superior.

#### Scenario: Cada parada muestra su propio acumulado
- **WHEN** la Home renderiza un camino cuyas tres paradas tienen
  `mejor_puntaje` 300, 500 y 0
- **THEN** los indicadores izquierdos muestran 300, 800 y 800
  respectivamente, formateados con separador de miles

#### Scenario: El acumulado no decrece a lo largo del camino
- **WHEN** la Home renderiza un camino con varias paradas
- **THEN** el valor del indicador de cada parada es mayor o igual que el de
  la parada anterior, nunca menor

#### Scenario: La última parada coincide con la barra superior
- **WHEN** la Home renderiza el camino completo de un jugador con puntos
- **THEN** el indicador de la parada de mayor `orden` muestra el mismo valor
  que la píldora de puntos de la barra superior

#### Scenario: Paradas sin jugar repiten el acumulado anterior
- **WHEN** una parada tiene `mejor_puntaje = 0` y las anteriores suman 800
- **THEN** su indicador muestra 800, igual que la parada anterior

#### Scenario: Jugador sin puntos todavía
- **WHEN** un jugador sin respuestas registradas (todas las paradas con
  `mejor_puntaje = 0`) abre la Home
- **THEN** el indicador izquierdo de cada parada muestra 0

### Requirement: El camino recarga su progreso al volver de jugar

La Home SHALL volver a leer `camino_jugador` al volver de la pantalla de
juego de un nivel (desde el resumen del nivel, ya sea "Continuar" o "Volver
al camino"), en vez de conservar los datos con los que se cargó antes de
entrar a jugar. Esa única lectura SHALL refrescar a la vez el progreso, los
puntos totales y el acumulado de cada parada.

#### Scenario: Vuelve con un nivel recién superado

- **WHEN** el jugador entra a jugar un nivel bloqueado en el camino,
  lo supera y pulsa "Continuar" en el resumen
- **THEN** la Home muestra ese nivel como superado, con sus estrellas y
  cualquier desbloqueo nuevo, sin necesidad de reabrir la app

#### Scenario: Vuelve sin terminar el nivel

- **WHEN** el jugador entra a jugar un nivel y sale antes de terminarlo
- **THEN** la Home recarga igualmente su progreso al volver

#### Scenario: Vuelve tras mejorar su marca en una parada ya superada

- **WHEN** el jugador repite una parada ya superada y mejora su
  `mejor_puntaje`
- **THEN** al volver, el indicador de esa parada y de todas las posteriores
  refleja el acumulado nuevo, igual que la barra superior
