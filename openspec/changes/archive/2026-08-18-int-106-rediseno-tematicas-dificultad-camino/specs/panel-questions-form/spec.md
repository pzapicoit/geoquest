## ADDED Requirements

### Requirement: Selector de temática obligatorio
El formulario SHALL ofrecer un selector obligatorio de temática (`tematica_id`), listando las temáticas existentes, y SHALL bloquear el guardado si no se elige ninguna. Este campo sustituye a la asignación indirecta de temática que hoy se deducía de a qué nivel se asignaba la pregunta.

#### Scenario: Guardar sin elegir temática
- **WHEN** un admin intenta guardar una pregunta nueva sin seleccionar ninguna temática
- **THEN** el formulario bloquea el guardado y muestra un error en ese campo

#### Scenario: Preguntas ya existentes antes de este cambio
- **WHEN** un admin abre para editar una pregunta creada antes de la existencia de `desafios.tematica_id`
- **THEN** el selector muestra la temática que la migración le asignó, editable como cualquier otra pregunta

### Requirement: Selector de dificultad
El formulario SHALL mostrar el selector de dificultad definido en `question-difficulty`, con los 5 valores del catálogo, y SHALL bloquear el guardado si no se elige ninguno.

#### Scenario: Se cambia la dificultad de una pregunta existente
- **WHEN** un admin edita una pregunta existente y cambia su dificultad de "Normal" a "Difícil"
- **THEN** al guardar, la fila de `desafios` queda con `dificultad = 'dificil'`

## REMOVED Requirements

### Requirement: Asignación opcional a niveles solo al crear
**Reason**: Ya no existe curación manual de niveles ni la tabla `nivel_desafios`. En cuanto se guarda una pregunta con su temática y dificultad, queda disponible automáticamente en el pool de esa pareja para cualquier parada del camino que la resuelva.

**Migration**: No hace falta ninguna acción del admin al crear la pregunta más allá de elegir su temática y dificultad correctamente.
