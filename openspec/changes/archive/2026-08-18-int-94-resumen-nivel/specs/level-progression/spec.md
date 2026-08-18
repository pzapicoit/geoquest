## ADDED Requirements

### Requirement: Respuesta de cierre enriquecida para el resumen del nivel

El sistema SHALL devolver, al cerrar un `intento_nivel`, además del
resultado del propio intento (`puntaje_total`, `superado`,
`estrellas_obtenidas`), el `puntaje_minimo_superar` del nivel y el
`mejor_puntaje` que el usuario tenía registrado en `progreso_usuario_nivel`
para ese nivel **antes** de este cierre. El sistema SHALL capturar ese
mejor puntaje previo antes de que el propio cierre actualice
`progreso_usuario_nivel`, y SHALL devolverlo vacío cuando el usuario no
tuviera ninguna fila previa en `progreso_usuario_nivel` para ese nivel.

#### Scenario: Cierre con un resultado anterior registrado

- **WHEN** un usuario con `mejor_puntaje = 1820` en `progreso_usuario_nivel`
  para un nivel cierra un nuevo intento de ese nivel con `puntaje_total =
  2140`
- **THEN** la respuesta del cierre incluye `puntaje_total = 2140` y el
  mejor puntaje previo de 1820, sin importar que
  `progreso_usuario_nivel.mejor_puntaje` quede actualizado a 2140 en la
  misma operación

#### Scenario: Cierre sin resultado anterior

- **WHEN** un usuario sin ninguna fila previa en `progreso_usuario_nivel`
  para un nivel cierra su primer intento de ese nivel
- **THEN** la respuesta del cierre incluye el mejor puntaje previo vacío,
  no cero

#### Scenario: La respuesta incluye el mínimo del nivel

- **WHEN** se cierra un intento de un nivel cuyo `puntaje_minimo_superar`
  es 1500
- **THEN** la respuesta del cierre incluye ese mismo valor, sin importar
  si el intento quedó superado o no
