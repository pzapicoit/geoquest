## ADDED Requirements

### Requirement: `desafios_uso` solo accesible a admin

La vista `desafios_uso` SHALL devolver cero filas para cualquier usuario
autenticado que no tenga `profiles.role = 'admin'`.

#### Scenario: Un jugador consulta `desafios_uso`

- **WHEN** un usuario autenticado sin rol `admin` hace `select` sobre
  `desafios_uso`
- **THEN** la consulta devuelve cero filas

### Requirement: Conteo de niveles que usan cada desafío

`desafios_uso` SHALL exponer, para cada fila de `desafios`, cuántas filas
de `nivel_desafios` lo referencian (`usos`), incluyendo con `usos = 0` los
desafíos que no están asignados a ningún nivel.

#### Scenario: Desafío reutilizado en varios niveles

- **WHEN** un desafío está asignado a 3 niveles distintos vía
  `nivel_desafios`
- **THEN** su fila en `desafios_uso` tiene `usos = 3`

#### Scenario: Desafío sin asignar a ningún nivel

- **WHEN** un desafío del banco no tiene ninguna fila en `nivel_desafios`
  que lo referencie
- **THEN** su fila en `desafios_uso` tiene `usos = 0`
