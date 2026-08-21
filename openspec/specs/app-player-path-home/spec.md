# app-player-path-home Specification

## Purpose
TBD - created by archiving change int-90-camino-niveles-home. Update Purpose after archive.
## Requirements
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

### Requirement: Estado visual de parada superada
Toda parada cuya posición de `camino_jugador` traiga `superado = true` SHALL
mostrarse a color (sin atenuar) y con sus `estrellas_obtenidas` (1 a 3)
representadas visualmente.

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
íntegramente en gris/atenuada —portada en escala de grises, número de
nivel, título de la temática y borde de la tarjeta con tratamiento
atenuado, y su marca en el riel de progreso también atenuada—, sin
estrellas visibles, y no SHALL responder a toques.

#### Scenario: El jugador toca una parada bloqueada
- **WHEN** un jugador toca una parada cuya posición trae
  `desbloqueado = false`
- **THEN** la app no navega a ninguna pantalla de juego

#### Scenario: Una parada bloqueada se renderiza completa
- **WHEN** la Home renderiza una parada cuya posición trae
  `desbloqueado = false`
- **THEN** tanto su portada como su número de nivel, título, borde de
  tarjeta y marca en el riel se muestran con tratamiento atenuado, no solo
  la portada

### Requirement: Riel de progreso vertical junto a las paradas
La Home SHALL mostrar, junto a los indicadores de cada parada, un riel
vertical compuesto por una pista de fondo que recorre todo el camino y un
segmento relleno que marca el progreso ya recorrido: desde la marca de la
parada `es_actual` hasta el nivel de `orden` 1.

#### Scenario: Progreso parcial
- **WHEN** una posición del camino trae `es_actual = true` en un punto
  intermedio
- **THEN** el segmento relleno del riel cubre desde esa parada hasta el
  nivel 1, y el resto del camino muestra solo la pista de fondo

#### Scenario: Camino completo sin parada actual
- **WHEN** ninguna posición del camino trae `es_actual = true`
- **THEN** el segmento relleno del riel cubre el camino completo

### Requirement: Aparición animada de las paradas al hacer scroll
Cada parada SHALL animarse (opacidad, escala y desplazamiento vertical) en
función de su posición respecto al área visible del camino, mostrándose a
tamaño y opacidad completos dentro de una zona central segura, y
atenuándose/encogiéndose gradualmente cerca de los bordes superior e
inferior del camino visible.

#### Scenario: Parada dentro de la zona central visible
- **WHEN** una parada está completamente dentro de la zona segura del área
  visible, lejos de la cabecera y del botón de jugar
- **THEN** se muestra a opacidad y escala completas, sin desplazamiento
  adicional

#### Scenario: Parada cerca del borde superior o inferior
- **WHEN** el jugador hace scroll y una parada se acerca al borde ocupado
  por la cabecera o por el botón de jugar
- **THEN** su opacidad y escala se reducen gradualmente a medida que se
  acerca a ese borde

### Requirement: Contenido del camino se desvanece bajo la cabecera y el botón de jugar
Las tarjetas de parada SHALL desvanecerse gradualmente, sin cortarse en un
borde duro, al desplazarse bajo la cabecera fija o bajo el botón fijo de
jugar.

#### Scenario: Una parada se desplaza bajo la cabecera
- **WHEN** el jugador hace scroll y una parada pasa a quedar bajo la
  cabecera fija
- **THEN** la tarjeta se desvanece gradualmente hasta quedar invisible, en
  vez de cortarse en un límite visible

#### Scenario: Una parada se desplaza bajo el botón de jugar
- **WHEN** el jugador hace scroll y una parada pasa a quedar bajo el botón
  fijo de jugar
- **THEN** la tarjeta se desvanece gradualmente hasta quedar invisible, en
  vez de cortarse en un límite visible

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
La app SHALL iniciar la navegación hacia la pantalla de juego de una parada
cuando el jugador la toque y su posición traiga `desbloqueado = true`
(superada o actual), identificándola por su `camino_id`.

#### Scenario: El jugador toca la parada actual
- **WHEN** un jugador toca la parada cuya posición trae
  `es_actual = true`
- **THEN** la app navega hacia la pantalla de juego del `camino_id` de
  esa posición

#### Scenario: El jugador toca una parada ya superada
- **WHEN** un jugador toca una parada cuya posición trae
  `superado = true`
- **THEN** la app navega hacia la pantalla de juego del `camino_id` de
  esa posición, permitiendo rejugarla

### Requirement: Arte de cada parada desde la portada de su temática
Cada parada SHALL mostrar como ilustración la
imagen de portada (`imagen_portada`) de la temática de su nivel,
resuelta a URL pública del bucket `challenge-media`, en vez de un icono
genérico.

#### Scenario: Dos niveles comparten temática
- **WHEN** dos posiciones del camino apuntan a niveles de la misma
  temática
- **THEN** ambas paradas muestran la misma imagen de portada de esa
  temática

### Requirement: Ambientación por temática mediante color de acento
Cada parada SHALL aplicar un color de acento
derivado de su `tematica_id` a los elementos de progreso de esa parada
(marca del riel y detalles de la tarjeta), variando sutilmente la
ambientación entre temáticas distintas sin depender de un asset nuevo.

#### Scenario: Paradas de temáticas distintas
- **WHEN** dos paradas consecutivas pertenecen a temáticas distintas
- **THEN** el color de acento de sus elementos de progreso difiere
  entre ambas

### Requirement: Botón fijo para jugar la parada actual
La Home SHALL mostrar un botón fijo sobre el camino, siempre visible,
que navegue a la pantalla de juego de la parada `es_actual` cuando
exista una. Si ninguna posición trae `es_actual = true` (camino
completo), el botón no SHALL mostrarse.

#### Scenario: Hay una parada actual
- **WHEN** una posición del camino trae `es_actual = true`
- **THEN** la Home muestra un botón fijo que, al tocarlo, navega a la
  pantalla de juego del `camino_id` de esa posición

#### Scenario: Camino completo sin parada actual
- **WHEN** ninguna posición del camino trae `es_actual = true`
- **THEN** la Home no muestra el botón fijo de jugar

### Requirement: Camino corto queda apoyado sobre el botón, no pegado al fondo
La Home SHALL mantener el camino apoyado justo encima del botón fijo de jugar
(con un margen pequeño y fijo) cuando el conjunto de paradas no llene el espacio
visible entre la barra superior y ese botón, dejando el hueco sobrante hacia la
barra superior, en vez de anclarlo al borde inferior de la pantalla o centrarlo
repartiendo el hueco arriba y abajo.

#### Scenario: Camino con una sola parada
- **WHEN** el camino tiene una única posición y su altura es menor que
  el espacio visible entre la barra superior y el botón de jugar
- **THEN** esa parada se muestra apoyada justo encima del botón de
  jugar, no pegada al borde inferior de la pantalla

#### Scenario: Camino largo que ya llena la pantalla
- **WHEN** el conjunto de paradas ocupa más espacio que el
  disponible entre la barra superior y el botón de jugar
- **THEN** el camino se comporta igual que antes de este cambio:
  desplazable, sin centrado adicional

### Requirement: Altura de tarjeta de parada según el diseño de referencia
Cada tarjeta de parada SHALL usar la misma altura que la fila del mock
de referencia (`[App] - Camino vertical.dc.html`, `ROW_H = 208`), no
una altura reducida.

#### Scenario: Se renderiza una tarjeta de parada
- **WHEN** la Home renderiza una tarjeta de parada
- **THEN** su altura es de 208 puntos lógicos, igual que en el diseño
  de referencia

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

### Requirement: Candado visible en parada bloqueada
Toda parada cuya posición traiga `desbloqueado = false` SHALL mostrar
un icono de candado sobre su tarjeta, además del tratamiento atenuado
ya exigido para ese estado por "Estado visual de parada bloqueada y no
interactiva".

#### Scenario: Parada bloqueada muestra candado
- **WHEN** la Home renderiza una parada cuya posición trae
  `desbloqueado = false`
- **THEN** esa parada muestra un icono de candado visible sobre su
  tarjeta

#### Scenario: Parada desbloqueada no muestra candado
- **WHEN** la Home renderiza una parada cuya posición trae
  `desbloqueado = true`
- **THEN** esa parada no muestra ningún icono de candado

### Requirement: Pill de comodines en la cabecera del camino

La cabecera de la pantalla Home (camino vertical) SHALL mostrar un indicador con el recuento total de comodines del jugador (suma de los 4 tipos), que al tocarse navega a la pantalla de Comodines.

#### Scenario: Se muestra el recuento total

- **WHEN** el jugador entra en la Home
- **THEN** la cabecera muestra la suma de unidades de los 4 tipos de comodín

#### Scenario: Se navega a la pantalla de Comodines

- **WHEN** el jugador toca el indicador de comodines en la cabecera
- **THEN** se abre la pantalla de Comodines

