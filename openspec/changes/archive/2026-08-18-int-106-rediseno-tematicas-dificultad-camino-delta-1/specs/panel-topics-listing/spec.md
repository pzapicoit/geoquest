## ADDED Requirements

### Requirement: Edición inline del estado por fila
Cada fila SHALL permitir cambiar `activo` (toggle) directamente desde el listado de temáticas, persistiendo el cambio al momento sin abrir el panel lateral de edición. Mientras el toggle de una fila esté guardando, SHALL quedar deshabilitado; si el guardado falla, la fila SHALL mostrar un mensaje de error y revertir visualmente al valor anterior.

#### Scenario: Desactivar una temática desde el listado
- **WHEN** un admin desactiva el toggle de estado de una temática activa
- **THEN** la temática se guarda como inactiva sin abrir el panel lateral, y su indicador de estado pasa a "Inactiva"

#### Scenario: El guardado inline falla
- **WHEN** el cambio de estado de una fila falla al guardarse (error de red o del servidor)
- **THEN** la fila muestra un mensaje de error junto al toggle y el toggle vuelve a mostrar el valor que tenía antes del cambio
