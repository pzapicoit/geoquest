# difficulty-defaults Specification

## Purpose
TBD - created by archiving change int-106-rediseno-tematicas-dificultad-camino. Update Purpose after archive.

## Requirements

### Requirement: Tabla de valores por defecto sembrada con una fila por dificultad
El esquema SHALL exponer una tabla `dificultad_defaults` con `dificultad` como clave primaria (una fila por cada valor del catálogo) y columnas no nulas `preguntas_por_partida` y `segundos_por_desafio`. La tabla SHALL NOT tener ninguna columna de umbral de estrellas: esos valores se derivan (ver "Máximo alcanzable por desafío derivado" y "Umbrales de estrellas derivados por dificultad"). La migración que crea la tabla SHALL sembrar sus 5 filas.

#### Scenario: Las 5 dificultades tienen valores por defecto desde el despliegue
- **WHEN** se consulta `dificultad_defaults` justo después de desplegar este cambio
- **THEN** existen exactamente 5 filas, una por cada valor del catálogo, todas con `preguntas_por_partida` y `segundos_por_desafio` rellenos

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
El panel SHALL ofrecer una pantalla que liste las 5 dificultades con sus valores actuales de `dificultad_defaults` (preguntas por partida y segundos por desafío) y permita editarlos. La pantalla SHALL exigir enteros positivos en ambos campos. Junto a cada dificultad, la pantalla SHALL mostrar en solo lectura el máximo alcanzable y los umbrales ★1/★2/★3 derivados de sus valores vigentes, recalculándolos en vivo mientras se edita `preguntas_por_partida`, antes de guardar.

#### Scenario: Guardar valores válidos
- **WHEN** un admin edita `preguntas_por_partida` y `segundos_por_desafio` de la dificultad "Difícil" y pulsa "Guardar"
- **THEN** la fila de `dificultad_defaults` para `'dificil'` se actualiza con los nuevos valores

#### Scenario: Valor no entero o no positivo
- **WHEN** un admin introduce `0` o un valor no entero en preguntas por partida o segundos por desafío
- **THEN** el formulario bloquea el guardado y muestra un error en ese campo

#### Scenario: El bloque informativo se recalcula al editar preguntas por partida
- **WHEN** un admin cambia `preguntas_por_partida` de una dificultad en el formulario, sin haber pulsado todavía "Guardar"
- **THEN** el máximo alcanzable y los tres umbrales mostrados junto a esa dificultad se actualizan para reflejar el nuevo valor

### Requirement: Los valores por defecto solo afectan a paradas sin override propio
Cambiar `preguntas_por_partida` o `segundos_por_desafio` en `dificultad_defaults` SHALL afectar únicamente a las posiciones de `camino` cuya columna equivalente esté en `NULL` (sin override). Las posiciones con un override explícito SHALL conservar su valor propio sin verse afectadas por el cambio.

#### Scenario: Se sube `preguntas_por_partida` de una dificultad
- **WHEN** un admin sube `preguntas_por_partida` de "Normal" en `dificultad_defaults`, y existen paradas de "Normal" sin override y otras con override propio
- **THEN** las paradas sin override pasan a jugarse con el nuevo número de preguntas (y sus umbrales derivados se recalculan en consecuencia), y las que tienen override conservan el suyo sin cambios

### Requirement: Máximo alcanzable por desafío derivado del cálculo de puntaje
El sistema SHALL exponer una función `puntaje_maximo_por_desafio()` que devuelva el puntaje máximo alcanzable en un único desafío, derivado de `calcular_puntaje(0, 0, s)` para cualquier `s > 0` (distancia y tiempo transcurrido perfectos). Ningún literal que represente ese máximo SHALL aparecer en ningún otro punto del código: toda cifra de máximo por desafío SHALL originarse en esta función.

#### Scenario: El máximo derivado coincide con la mejor respuesta posible
- **WHEN** se invoca `puntaje_maximo_por_desafio()`
- **THEN** el resultado es exactamente el puntaje que obtendría un jugador con distancia 0 y tiempo transcurrido 0 en un desafío con cualquier límite de segundos positivo

#### Scenario: Cambiar la curva de puntaje no exige tocar ningún otro código
- **WHEN** se modifican las constantes de la curva de puntaje (`v_max`, `v_bonus_max`) de las que depende `calcular_puntaje`
- **THEN** `puntaje_maximo_por_desafio()` y todo lo que lo consume (umbrales, máximo por parada) reflejan el nuevo valor sin ningún cambio adicional

### Requirement: Umbrales de estrellas derivados por dificultad como porcentajes fijos crecientes
El sistema SHALL definir, como constantes en código (no en tabla), un porcentaje de superación (★1), un porcentaje de ★2 y un porcentaje de ★3 para cada valor de `dificultad`, estrictamente ascendentes dentro de cada dificultad (★1 < ★2 < ★3), y con el porcentaje de ★3 estrictamente creciente entre dificultades, de Fácil a Muy difícil. El sistema SHALL exponer una función `umbrales_parada(dificultad, preguntas_por_partida)` que devuelva el máximo alcanzable (`preguntas_por_partida × puntaje_maximo_por_desafio()`) y los tres umbrales resultantes en puntos, redondeando siempre hacia abajo (`floor`).

#### Scenario: Se calculan los umbrales de una dificultad y un número de preguntas dados
- **WHEN** se invoca `umbrales_parada` con una dificultad y un `preguntas_por_partida` concretos
- **THEN** devuelve el máximo igual a `preguntas_por_partida × puntaje_maximo_por_desafio()`, y los tres umbrales como el `floor` de su porcentaje fijo aplicado a ese máximo

#### Scenario: El tercer umbral es siempre el más exigente
- **WHEN** se calculan los umbrales de cualquiera de las 5 dificultades
- **THEN** el umbral de ★3 es estrictamente mayor que el de ★2, que a su vez es estrictamente mayor que el mínimo para superar

#### Scenario: El porcentaje de ★3 crece con la dificultad
- **WHEN** se comparan los porcentajes de ★3 de las 5 dificultades, de Fácil a Muy difícil
- **THEN** cada porcentaje es estrictamente mayor que el de la dificultad anterior

#### Scenario: Los umbrales nunca superan el máximo, sin importar `preguntas_por_partida`
- **WHEN** se calculan los umbrales para cualquier dificultad y cualquier `preguntas_por_partida` positivo, incluyendo valores menores que los usados anteriormente para esa parada
- **THEN** los tres umbrales devueltos son siempre menores o iguales que el máximo devuelto en la misma llamada, porque cada uno es un porcentaje no mayor al 100% de ese mismo máximo
