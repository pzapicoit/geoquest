## ADDED Requirements

### Requirement: Tabla de valores por defecto sembrada con una fila por dificultad
El esquema SHALL exponer una tabla `dificultad_defaults` con `dificultad` como clave primaria (una fila por cada valor del catálogo) y columnas no nulas `preguntas_por_partida`, `segundos_por_desafio`, `puntaje_minimo_superar`, `umbral_estrella_2` y `umbral_estrella_3`. La migración que crea la tabla SHALL sembrar sus 5 filas.

#### Scenario: Las 5 dificultades tienen valores por defecto desde el despliegue
- **WHEN** se consulta `dificultad_defaults` justo después de desplegar este cambio
- **THEN** existen exactamente 5 filas, una por cada valor del catálogo, todas con sus columnas rellenas

#### Scenario: No se puede borrar una fila de valores por defecto
- **WHEN** se intenta borrar una fila de `dificultad_defaults`
- **THEN** la base de datos rechaza la operación, porque el catálogo de dificultades es fijo y cada una SHALL tener siempre sus valores por defecto

### Requirement: Lectura pública para autenticados, escritura solo admin
`dificultad_defaults` SHALL tener Row Level Security habilitado, con una policy que permita `select` a cualquier usuario autenticado (incluida una sesión anónima), y SHALL rechazar `insert`, `update` o `delete` de cualquier usuario para el que `is_admin()` devuelva `false`.

#### Scenario: Un jugador lee los valores por defecto
- **WHEN** un usuario autenticado (o con sesión anónima) hace `select` sobre `dificultad_defaults`
- **THEN** la operación se permite y devuelve las 5 filas

#### Scenario: Un jugador intenta editar un valor por defecto
- **WHEN** un usuario con `is_admin() = false` intenta `update` sobre `dificultad_defaults`
- **THEN** la operación se rechaza

#### Scenario: Un admin edita un valor por defecto
- **WHEN** un usuario con `is_admin() = true` hace `update` sobre una fila de `dificultad_defaults`
- **THEN** la operación se permite

### Requirement: Pantalla del panel para editar los valores por defecto
El panel SHALL ofrecer una pantalla que liste las 5 dificultades con sus valores actuales de `dificultad_defaults` (preguntas por partida, segundos por desafío, puntuación mínima, umbral de 2 estrellas y umbral de 3 estrellas) y permita editarlos. La pantalla SHALL exigir enteros positivos en los 5 campos y SHALL bloquear el guardado si no se cumple `puntaje_minimo_superar <= umbral_estrella_2 <= umbral_estrella_3`.

#### Scenario: Guardar valores válidos
- **WHEN** un admin edita los 5 campos de la dificultad "Difícil" manteniendo el orden ascendente exigido y pulsa "Guardar"
- **THEN** la fila de `dificultad_defaults` para `'dificil'` se actualiza con los nuevos valores

#### Scenario: Umbrales fuera de orden
- **WHEN** un admin introduce un umbral de 3 estrellas menor que el umbral de 2 estrellas
- **THEN** el formulario bloquea el guardado y muestra un error indicando que los umbrales deben ser ascendentes

#### Scenario: Valor no entero o no positivo
- **WHEN** un admin introduce `0` o un valor no entero en preguntas por partida o segundos por desafío
- **THEN** el formulario bloquea el guardado y muestra un error en ese campo

### Requirement: Los valores por defecto solo afectan a paradas sin override propio
Cambiar un valor en `dificultad_defaults` SHALL afectar únicamente a las posiciones de `camino` cuya columna equivalente esté en `NULL` (sin override). Las posiciones con un override explícito SHALL conservar su valor propio sin verse afectadas por el cambio.

#### Scenario: Se sube la puntuación mínima de una dificultad
- **WHEN** un admin sube `puntaje_minimo_superar` de "Normal" en `dificultad_defaults`, y existen paradas de "Normal" sin override y otras con override propio
- **THEN** las paradas sin override pasan a exigir el nuevo mínimo, y las que tienen override conservan el suyo sin cambios
