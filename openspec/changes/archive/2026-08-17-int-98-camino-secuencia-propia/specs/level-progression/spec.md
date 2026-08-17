## REMOVED Requirements

### Requirement: Desbloqueo del siguiente nivel de la temática
**Reason**: El desbloqueo deja de basarse en la relación "siguiente nivel
de la misma temática" y pasa a basarse exclusivamente en la posición que
ocupa un nivel dentro del camino, con independencia de su temática.
**Migration**: Sustituido por "Desbloqueo de posiciones del camino por
estrellas acumuladas". Un nivel que antes se desbloqueaba automáticamente
por ser "el siguiente de la temática" ahora se desbloquea si su posición en
`camino` alcanza el umbral de estrellas correspondiente.

### Requirement: Desbloqueo de la siguiente temática por estrellas acumuladas
**Reason**: `tematicas.estrellas_requeridas` se elimina del esquema; el
umbral de desbloqueo pasa a vivir en `camino.estrellas_requeridas`, por
posición, y ya no en la temática.
**Migration**: Sustituido por "Desbloqueo de posiciones del camino por
estrellas acumuladas". El concepto de "temática siguiente" desaparece de la
lógica de desbloqueo: la progresión es una única secuencia (el camino) que
puede intercalar temáticas.

## ADDED Requirements

### Requirement: Desbloqueo de posiciones del camino por estrellas acumuladas
El sistema SHALL, al cerrar un intento con `superado = true`, recalcular la
suma de `mejores_estrellas` del usuario sobre todos los niveles referenciados
por `camino`, y SHALL desbloquear (`desbloqueado = true` en
`progreso_usuario_nivel`) todas las posiciones de `camino` cuyo
`estrellas_requeridas` sea menor o igual que esa suma, sin exigir que el
usuario haya completado la posición inmediatamente anterior del camino.

#### Scenario: Las estrellas acumuladas alcanzan varias posiciones a la vez
- **WHEN** tras cerrar un intento, la suma de `mejores_estrellas` del
  usuario sobre los niveles del camino alcanza el `estrellas_requeridas` de
  las posiciones 4 y 5, que antes estaban bloqueadas
- **THEN** ambas posiciones quedan `desbloqueado = true` en
  `progreso_usuario_nivel` para ese usuario en la misma operación

#### Scenario: Las estrellas acumuladas no alcanzan la siguiente posición
- **WHEN** tras cerrar un intento, la suma de `mejores_estrellas` del
  usuario sobre los niveles del camino es menor que `estrellas_requeridas`
  de la siguiente posición bloqueada
- **THEN** ninguna posición adicional del camino se desbloquea

#### Scenario: El intento cerrado no queda superado
- **WHEN** se cierra un intento con `superado = false`
- **THEN** no se recalcula ni modifica ningún desbloqueo de posiciones del
  camino

#### Scenario: El nivel cerrado no pertenece a ninguna posición del camino
- **WHEN** se cierra un intento superado de un nivel que no tiene ninguna
  fila asociada en `camino`
- **THEN** sus estrellas no participan en el cálculo de desbloqueo de
  posiciones del camino
