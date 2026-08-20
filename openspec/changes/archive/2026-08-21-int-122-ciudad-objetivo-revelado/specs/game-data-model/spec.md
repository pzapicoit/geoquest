## ADDED Requirements

### Requirement: Campo de ciudad por desafío

`desafios` SHALL ganar una columna `ciudad` (texto, nullable) con la ciudad real del objetivo, independiente de `nombre_lugar` (el punto exacto que se revela) y de `pais`.

La columna SHALL admitir `NULL` como valor legítimo, no como dato pendiente: hay objetivos sin ciudad real —aguas internacionales, parajes despoblados, o una respuesta que es un país entero— y forzar un valor obligaría a inventarlo.

#### Scenario: Se crea un desafío sin ciudad

- **WHEN** se inserta un desafío sin especificar `ciudad`
- **THEN** la base de datos acepta la fila con `ciudad` en `NULL`

#### Scenario: Se crea un desafío con ciudad

- **WHEN** se inserta o actualiza un desafío especificando `ciudad`
- **THEN** la base de datos guarda ese valor sin validarlo contra ningún catálogo cerrado

#### Scenario: La ciudad no sustituye al lugar exacto

- **WHEN** un desafío tiene `nombre_lugar = 'Parque de bomberos Hook & Ladder 8, Tribeca, Nueva York'` y se le rellena `ciudad = 'Nueva York'`
- **THEN** `nombre_lugar` conserva su valor íntegro, y los dos campos coexisten con papeles distintos
