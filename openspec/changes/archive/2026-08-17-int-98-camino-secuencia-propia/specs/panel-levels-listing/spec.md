## MODIFIED Requirements

### Requirement: Subtítulo con recuento o con estado vacío
Cuando la temática tenga niveles, el subtítulo SHALL mostrar el número de
niveles, cuántos están activos y el total de preguntas asignadas en todos
ellos. Cuando la temática no tenga ningún nivel, el subtítulo SHALL
mostrar en su lugar el texto "Sin niveles todavía", sin referencia a
estrellas requeridas ni a otras temáticas (el desbloqueo ya no depende de
la temática, sino de la posición de cada nivel en el camino).

#### Scenario: Temática con niveles
- **WHEN** una temática tiene 6 niveles, 4 activos y un total de 25
  preguntas asignadas entre todos
- **THEN** el subtítulo muestra "6 niveles · 4 activos · 25 preguntas
  asignadas en total"

#### Scenario: Temática sin niveles
- **WHEN** una temática no tiene ningún nivel todavía
- **THEN** el subtítulo muestra "Sin niveles todavía", sin importar el
  `orden` de la temática ni si existe una temática anterior
