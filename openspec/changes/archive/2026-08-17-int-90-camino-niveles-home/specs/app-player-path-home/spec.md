## ADDED Requirements

### Requirement: Home del jugador muestra el camino completo con progreso
La app SHALL presentar, tras el splash con nombre de usuario ya
guardado, una pantalla Home que lea `camino_jugador` y muestre una
parada por cada posición devuelta, en un camino vertical desplazable
(scroll) que las conecta en orden de `orden` ascendente.

#### Scenario: El jugador abre la Home con progreso parcial
- **WHEN** un jugador con nombre de usuario guardado abre la app
- **THEN** la Home muestra una parada por cada fila de `camino_jugador`,
  conectadas por un camino vertical desplazable

### Requirement: Barra superior con identidad, progreso y puntos totales
La Home SHALL mostrar una barra superior fija con el nombre de usuario
guardado, un acceso al perfil y los puntos totales acumulados del
jugador, calculados sumando `puntos` de todas sus filas de
`respuestas_desafio`.

#### Scenario: Se cargan los puntos totales del jugador
- **WHEN** la Home termina de cargar el progreso del jugador
- **THEN** la barra superior muestra la suma de `puntos` de todas las
  respuestas del jugador autenticado

#### Scenario: Jugador sin respuestas todavía
- **WHEN** un jugador que nunca respondió ningún desafío abre la Home
- **THEN** la barra superior muestra 0 puntos totales

### Requirement: Estado visual de parada superada
Toda parada cuya posición de `camino_jugador` traiga `superado = true`
SHALL mostrarse a color (sin atenuar) y con sus `estrellas_obtenidas`
(1 a 3) representadas visualmente.

#### Scenario: Parada con dos estrellas obtenidas
- **WHEN** una posición trae `superado = true` y
  `estrellas_obtenidas = 2`
- **THEN** su parada se muestra a color con exactamente 2 estrellas
  marcadas como conseguidas

### Requirement: Estado visual de parada actual
La parada cuya posición traiga `es_actual = true` SHALL mostrarse
visualmente destacada respecto al resto (superadas y bloqueadas).

#### Scenario: Hay una parada actual
- **WHEN** una posición trae `es_actual = true`
- **THEN** esa parada se renderiza con un tratamiento visual distinto
  al de las paradas superadas y bloqueadas

### Requirement: Estado visual de parada bloqueada y no interactiva
Toda parada cuya posición traiga `desbloqueado = false` SHALL mostrarse
en gris/atenuada, sin estrellas visibles, y no SHALL responder a toques.

#### Scenario: El jugador toca una parada bloqueada
- **WHEN** un jugador toca una parada cuya posición trae
  `desbloqueado = false`
- **THEN** la app no navega a ninguna pantalla de juego

### Requirement: Parada frontera entre temáticas consecutivas distintas
La Home SHALL insertar una parada "frontera" entre cada par de
posiciones consecutivas de `camino_jugador` cuyo `tematica_id` difiera,
mostrando un candado y, si la posición siguiente trae
`desbloqueado = false`, un mensaje con cuántas estrellas faltan para
desbloquearla (`estrellas_requeridas` de esa posición menos
`estrellas_acumuladas_usuario`, con un mínimo de 1).

#### Scenario: Frontera bloqueada entre dos temáticas
- **WHEN** dos posiciones consecutivas del camino tienen distinto
  `tematica_id` y la segunda trae `desbloqueado = false` con
  `estrellas_requeridas = 500` y `estrellas_acumuladas_usuario = 480`
- **THEN** aparece una parada frontera entre ambas con candado y el
  mensaje indica que faltan 20 estrellas

#### Scenario: Frontera ya desbloqueada
- **WHEN** dos posiciones consecutivas del camino tienen distinto
  `tematica_id` y la segunda trae `desbloqueado = true`
- **THEN** aparece una parada frontera entre ambas sin candado ni
  mensaje de estrellas faltantes

#### Scenario: Dos posiciones consecutivas de la misma temática
- **WHEN** dos posiciones consecutivas del camino comparten
  `tematica_id`
- **THEN** no aparece ninguna parada frontera entre ellas

### Requirement: Auto-centrado en la parada actual al cargar
Al montar la Home, la app SHALL desplazar automáticamente el scroll del
camino hasta dejar visible la parada `es_actual`, sin requerir ninguna
acción del jugador.

#### Scenario: Carga inicial con progreso intermedio
- **WHEN** la Home termina de cargar el camino de un jugador con
  progreso intermedio
- **THEN** el scroll queda posicionado mostrando la parada marcada como
  `es_actual`, sin que el jugador haya desplazado nada

#### Scenario: Camino completo sin ninguna parada actual
- **WHEN** un jugador superó todas las posiciones del camino (ninguna
  fila trae `es_actual = true`)
- **THEN** el scroll se posiciona al final del camino ya superado

### Requirement: Toque en parada desbloqueada navega al nivel
Tocar una parada cuya posición traiga `desbloqueado = true` (superada o
actual) SHALL iniciar la navegación hacia la pantalla de juego de ese
nivel, identificándolo por su `nivel_id`.

#### Scenario: El jugador toca la parada actual
- **WHEN** un jugador toca la parada cuya posición trae
  `es_actual = true`
- **THEN** la app navega hacia la pantalla de juego del `nivel_id` de
  esa posición

#### Scenario: El jugador toca una parada ya superada
- **WHEN** un jugador toca una parada cuya posición trae
  `superado = true`
- **THEN** la app navega hacia la pantalla de juego del `nivel_id` de
  esa posición, permitiendo rejugarla

### Requirement: Arte de cada parada desde la portada de su temática
Cada parada (salvo la frontera) SHALL mostrar como ilustración la
imagen de portada (`imagen_portada`) de la temática de su nivel,
resuelta a URL pública del bucket `challenge-media`, en vez de un icono
genérico.

#### Scenario: Dos niveles comparten temática
- **WHEN** dos posiciones del camino apuntan a niveles de la misma
  temática
- **THEN** ambas paradas muestran la misma imagen de portada de esa
  temática

### Requirement: Ambientación por temática mediante color de acento
Cada parada (salvo la frontera) SHALL aplicar un color de acento
derivado de su `tematica_id` a los elementos de progreso de esa parada
(marca del riel y detalles de la tarjeta), variando sutilmente la
ambientación entre temáticas distintas sin depender de un asset nuevo.

#### Scenario: Paradas de temáticas distintas
- **WHEN** dos paradas consecutivas pertenecen a temáticas distintas
- **THEN** el color de acento de sus elementos de progreso difiere
  entre ambas
