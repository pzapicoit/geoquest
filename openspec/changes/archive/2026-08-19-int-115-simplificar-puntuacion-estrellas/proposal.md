## Why

Los umbrales de estrellas y `estrellas_requeridas` son enteros absolutos escritos a mano, desacoplados de `preguntas_por_partida` (la única variable que determina el máximo real alcanzable). Cambiar `preguntas_por_partida` de una parada deja los umbrales desincronizados —silenciosamente más fáciles o directamente inalcanzables— sin ningún aviso. Además, los valores sembrados se calcularon sobre una base de `preguntas × 5000` (sin el bonus de rapidez añadido después), así que los porcentajes reales ya están descuadrados entre dificultades hoy mismo (Difícil exige superar el 65% del máximo real; Muy difícil el 77%, más que el ★2 de Fácil).

## What Changes

- Nueva función `puntaje_maximo_por_desafio()` que deriva el máximo por pregunta (5500) de `calcular_puntaje(0, 0, 60)` — ningún literal `5500` en el código.
- Nueva función `estrellas_requeridas_por_orden(orden)` = `floor((orden - 1) × 3 × 0.6)`: el desbloqueo de una posición pasa a ser una función de su `orden`, recalculada en cada lectura.
- Nueva función `umbrales_parada(dificultad, preguntas_por_partida)` que devuelve `maximo`/`minimo`/`umbral_estrella_2`/`umbral_estrella_3` a partir de porcentajes fijos por dificultad (constantes en código, crecientes con la dificultad) y `puntaje_maximo_por_desafio()`.
- **BREAKING**: se eliminan las columnas `puntaje_minimo_superar`, `umbral_estrella_2`, `umbral_estrella_3` de `dificultad_defaults` y sus 3 overrides equivalentes + `estrellas_requeridas` de `camino` (con sus checks de orden ascendente). Nada de esto se vuelve a almacenar.
- `cerrar_intento_parada` resuelve los umbrales por fórmula sobre el número real de desafíos persistidos del intento (`intento_desafios`, no la config vigente), y añade `puntaje_maximo` a su respuesta.
- `camino_jugador` y el desbloqueo de `cerrar_intento_parada` calculan `estrellas_requeridas` con `estrellas_requeridas_por_orden(orden)` en vez de leer una columna.
- **BREAKING**: el panel deja de ofrecer los 3 campos de umbral en Dificultades y en overrides de Camino, y el input de `estrellas_requeridas` en Camino. Pasan a un bloque informativo de solo lectura (máximo, ★1/★2/★3, posición de desbloqueo) que se recalcula en vivo al editar `preguntas_por_partida`, antes de guardar.
- `preguntas_por_partida` y `segundos_por_desafio` siguen siendo configurables (default por dificultad + override por parada) — son la única causa que dispara el recálculo.

## Capabilities

### New Capabilities

(ninguna — todo el cambio modifica capabilities existentes)

### Modified Capabilities

- `game-data-model`: `dificultad_defaults` y `camino` pierden las columnas de umbral/estrellas requeridas; los overrides de `camino` bajan de 5 a 2 campos.
- `difficulty-defaults`: la tabla y la pantalla del panel pasan de 5 campos a 2; los umbrales dejan de ser editables y se exponen como derivados de solo lectura; nuevos requisitos para las funciones de máximo y porcentajes por dificultad.
- `level-progression`: la resolución de umbrales efectivos y de `estrellas_requeridas` para desbloqueo pasa de coalesce(override, default) / columna almacenada a cálculo por fórmula sobre el tamaño real del intento y el `orden` de la parada; la respuesta de cierre gana `puntaje_maximo`.
- `player-path`: `camino_jugador` calcula `estrellas_requeridas` con la fórmula sobre `orden` en vez de leer la columna (mismo contrato de columna, origen distinto).
- `panel-path-listing`: se elimina la edición de `estrellas_requeridas` y de los 3 umbrales por posición; el listado muestra `estrellas_requeridas` en solo lectura y gana un bloque informativo de umbrales derivados con recálculo en vivo.

`app-level-summary` y `app-player-path-home` no cambian de requisitos: el contrato de campos que consumen (`puntaje_minimo_superar`, `estrellas_requeridas`, `mejor_puntaje_anterior`) se preserva exactamente; solo hay que verificar que sus tests siguen pasando.

## Impact

- **Backend** (`backend/supabase/migrations/`): nueva migración con las 3 funciones; `cerrar_intento_parada` reescrita; `camino_jugador` con `CREATE OR REPLACE VIEW` (mismo nombre/orden de columnas); nueva vista `camino_panel` para que el panel liste `estrellas_requeridas` derivada sin tocar `camino` directamente; `drop column` × 3 en `dificultad_defaults` (+ 2 checks) y × 4 en `camino` (+ 2 checks).
- **Panel** (`panel/src/`): `lib/dificultadDefaults.ts`, `pages/DificultadDefaults.tsx`, `lib/camino.ts`, `pages/Camino.tsx` y sus tests (`dificultadDefaults.test.ts`, `camino.test.ts`, `Camino.test.tsx`).
- **App**: sin cambios de código; se verifica que `resumen_nivel_screen.dart`/`nivel_juego_gateway.dart` y `camino_gateway.dart`/`camino_screen.dart` siguen funcionando con el mismo contrato de respuesta.
- **Specs OpenSpec afectadas**: `game-data-model`, `difficulty-defaults`, `level-progression`, `player-path`, `panel-path-listing`.
