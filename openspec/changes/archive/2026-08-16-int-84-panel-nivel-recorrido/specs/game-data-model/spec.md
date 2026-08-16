## ADDED Requirements

### Requirement: `niveles` admite un nombre editable opcional

`niveles` SHALL tener una columna `nombre` de tipo texto, opcional
(nullable, sin valor por defecto), independiente de `orden`. Los niveles
existentes sin `nombre` SHALL seguir identificándose por su `orden` en
cualquier pantalla que ya lo hiciera así.

#### Scenario: Se asigna un nombre a un nivel existente
- **WHEN** se actualiza un nivel existente estableciendo `nombre = 'Costas
  del Mediterráneo'`
- **THEN** la fila queda con ese `nombre` sin afectar a su `orden` ni a sus
  asignaciones en `nivel_desafios`

#### Scenario: Un nivel sin nombre asignado
- **WHEN** se crea o consulta un nivel cuyo `nombre` nunca se ha establecido
- **THEN** la columna `nombre` es `NULL` y el nivel sigue siendo válido e
  identificable por `tematica_id` + `orden`
