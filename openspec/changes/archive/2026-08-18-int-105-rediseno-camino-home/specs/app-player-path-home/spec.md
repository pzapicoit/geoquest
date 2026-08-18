## REMOVED Requirements

### Requirement: Parada frontera entre temáticas consecutivas distintas
**Reason**: El mock de referencia definitivo (`[App] - Camino vertical.dc.html`,
localizado y leído en INT-105) no contempla ninguna parada "frontera" entre
temáticas: el camino muestra solo paradas de nivel, una tras otra. Mantenerla
diverge del diseño y añade una pieza sintética que ningún criterio visual
sigue pidiendo.
**Migration**: Se elimina `ParadaFrontera`/`intercalarFronteras` del gateway
y `_FronteraTile` de la pantalla. `CaminoJugador.entradas` pasa de
`List<CaminoEntrada>` a `List<ParadaCamino>`. No hay dato persistido que
migrar: la frontera siempre fue sintética, construida en el cliente.

## MODIFIED Requirements

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

## ADDED Requirements

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
