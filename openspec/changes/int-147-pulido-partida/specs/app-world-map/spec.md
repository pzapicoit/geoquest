## ADDED Requirements

### Requirement: Los rótulos de los pines quedan dentro del mapa
El rótulo de un pin («TU PIN» o el nombre del lugar real) SHALL centrarse sobre su pin y, si así se saliera del ancho visible del mapa, SHALL desplazarse horizontalmente lo justo para quedar dentro, a un margen fijo del borde.

#### Scenario: Pin junto al borde izquierdo
- **WHEN** el revelado encuadra un pin real cuyo centro queda a 20 px del borde izquierdo del mapa
- **THEN** su rótulo se ve entero, empezando a 8 px del borde izquierdo, en vez de cortarse

#### Scenario: Pin fuera del mapa
- **WHEN** el pin queda fuera del ancho visible (p. ej. antes de que la cámara del revelado lo encuadre)
- **THEN** su rótulo se queda con él, fuera de la vista, en vez de pegarse al borde sin pin al que señalar

#### Scenario: Pin en el centro
- **WHEN** el pin queda lejos de los bordes
- **THEN** su rótulo aparece centrado sobre él, como hasta ahora
