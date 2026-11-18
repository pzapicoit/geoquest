## MODIFIED Requirements

### Requirement: Auto-centrado en la parada actual al cargar
Al montar la Home, la app SHALL desplazar automáticamente el scroll del camino hasta dejar visible la parada `es_actual`, sin requerir ninguna acción del jugador. Al volver a la Home desde otra pantalla, el scroll SHALL conservarse donde estaba —nunca saltar al principio del contenido ni a la última parada— y SHALL volver a centrarse solo si la recarga trae una parada `es_actual` distinta de aquella en la que se centró, de modo que un desbloqueo lleve a la parada nueva sin quitarle al jugador la posición a la que había desplazado a mano.

#### Scenario: Carga inicial con progreso intermedio
- **WHEN** la Home termina de cargar el camino de un jugador con
  progreso intermedio
- **THEN** el scroll queda posicionado mostrando la parada marcada como
  `es_actual`, sin que el jugador haya desplazado nada

#### Scenario: Camino completo sin ninguna parada actual
- **WHEN** un jugador superó todas las posiciones del camino (ninguna
  fila trae `es_actual = true`)
- **THEN** el scroll se posiciona al final del camino ya superado

#### Scenario: Vuelve de jugar sin desbloquear nada
- **WHEN** el jugador vuelve a la Home desde el resumen de un nivel ("Volver al camino") sin haber desbloqueado ninguna parada
- **THEN** el scroll queda donde estaba al entrar a jugar (la parada `es_actual` sigue a la vista), no en el principio del contenido ni en la última parada del camino

#### Scenario: Vuelve de otra pantalla tras desplazar a mano
- **WHEN** el jugador desplaza el camino a mano, abre la clasificación o los comodines y vuelve sin que cambie la parada `es_actual`
- **THEN** el scroll conserva la posición a la que había desplazado

#### Scenario: Vuelve de jugar habiendo desbloqueado una parada
- **WHEN** el jugador vuelve a la Home y la recarga trae como `es_actual` una parada distinta de la anterior
- **THEN** el scroll queda centrado en la nueva parada `es_actual`

### Requirement: El camino recarga su progreso al volver de jugar

La Home SHALL volver a leer `camino_jugador` al volver de la pantalla de
juego de un nivel (desde el resumen del nivel, ya sea "Continuar" o "Volver
al camino"), en vez de conservar los datos con los que se cargó antes de
entrar a jugar. Esa única lectura SHALL refrescar a la vez el progreso, los
puntos totales y el acumulado de cada parada.

Mientras dura esa recarga, la Home SHALL seguir mostrando el camino que ya tenía,
sin sustituirlo por un indicador de carga a pantalla completa; el indicador de
carga a pantalla completa SHALL reservarse para la primera carga, cuando todavía
no hay camino que mostrar.

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

#### Scenario: La recarga no vacía la pantalla

- **WHEN** el jugador vuelve a la Home y la lectura de `camino_jugador` todavía no ha respondido
- **THEN** la Home sigue mostrando las paradas que ya tenía, sin un indicador de carga a pantalla completa

### Requirement: Indicador de puntos totales junto a cada parada
El indicador de la columna izquierda de cada parada **desbloqueada** SHALL mostrar los puntos
**acumulados hasta esa parada** — la suma de `mejor_puntaje` de todas las
paradas cuyo `orden` es menor o igual al de esa parada —, formateados con
separador de miles, en vez del número de estrellas requeridas para esa parada
y en vez del total del jugador repetido en todas.

Las paradas bloqueadas SHALL NOT mostrar ninguna cifra en el riel: conservan su marca atenuada y un hueco del mismo alto en lugar del número, para que no parezca que ya tienen puntos.

Cuando la última parada del camino está desbloqueada, su acumulado SHALL coincidir por construcción
con el total que muestra la barra superior.

#### Scenario: Cada parada muestra su propio acumulado
- **WHEN** la Home renderiza un camino cuyas tres paradas, todas desbloqueadas, tienen
  `mejor_puntaje` 300, 500 y 0
- **THEN** los indicadores izquierdos muestran 300, 800 y 800
  respectivamente, formateados con separador de miles

#### Scenario: El acumulado no decrece a lo largo del camino
- **WHEN** la Home renderiza un camino con varias paradas desbloqueadas
- **THEN** el valor del indicador de cada una es mayor o igual que el de
  la parada desbloqueada anterior, nunca menor

#### Scenario: La última parada coincide con la barra superior
- **WHEN** la Home renderiza el camino completo de un jugador con puntos y la parada de mayor `orden` está desbloqueada
- **THEN** el indicador de esa parada muestra el mismo valor
  que la píldora de puntos de la barra superior

#### Scenario: Paradas desbloqueadas sin jugar repiten el acumulado anterior
- **WHEN** una parada desbloqueada tiene `mejor_puntaje = 0` y las anteriores suman 800
- **THEN** su indicador muestra 800, igual que la parada anterior

#### Scenario: Las paradas bloqueadas no muestran cifra
- **WHEN** la Home renderiza un camino con paradas bloqueadas y el jugador lleva 3727 puntos
- **THEN** ninguna parada bloqueada muestra cifra en el riel
- **AND** su marca del riel se sigue viendo, atenuada

#### Scenario: Jugador sin puntos todavía
- **WHEN** un jugador sin respuestas registradas (todas las paradas con
  `mejor_puntaje = 0`) abre la Home
- **THEN** el indicador izquierdo de cada parada desbloqueada muestra 0, y las bloqueadas no muestran cifra
