## ADDED Requirements

### Requirement: Edición inline de dificultad y estado por fila
Cada fila SHALL permitir cambiar `dificultad` (selector) y `activo` (toggle) directamente desde el listado, persistiendo el cambio al momento sin navegar al formulario completo. Mientras un campo de una fila esté guardando, ese control SHALL quedar deshabilitado; si el guardado falla, la fila SHALL mostrar un mensaje de error y revertir visualmente al valor anterior.

#### Scenario: Cambiar la dificultad desde el listado
- **WHEN** un admin cambia el selector de dificultad de una fila de "Fácil" a "Difícil"
- **THEN** la fila guarda el cambio sin recargar el listado ni navegar a otra pantalla, y el badge de dificultad pasa a reflejar "Difícil"

#### Scenario: Cambiar el estado activo/inactivo desde el listado
- **WHEN** un admin desactiva el toggle de estado de una pregunta activa
- **THEN** la pregunta se guarda como inactiva y su indicador de estado pasa a "Inactivo"

#### Scenario: El guardado inline falla
- **WHEN** el cambio de dificultad o estado de una fila falla al guardarse (error de red o del servidor)
- **THEN** la fila muestra un mensaje de error junto al control afectado y el control vuelve a mostrar el valor que tenía antes del cambio
