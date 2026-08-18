## Why

Hoy el admin cura niveles a mano: crea un `nivel` dentro de una temática, le asigna preguntas concretas en un orden fijo (`nivel_desafios`) y define su propio `puntaje_minimo_superar`/`umbral_estrella_*`/`preguntas_por_partida`. Esto obliga a curar manualmente cada nivel del `camino`, no escala con el banco de preguntas, y hace que dos niveles de la "misma dificultad" en la práctica tengan configuraciones distintas por descuido del admin. Sustituir la curación manual por una dificultad fija por pregunta permite que el camino se construya eligiendo temática+dificultad, y que el sistema resuelva la partida por sorteo sobre todo el banco activo de esa combinación.

## What Changes

- Cada pregunta (`desafios`) se etiqueta con una **dificultad** fija de un catálogo cerrado de 5 valores: Fácil, Normal, Intermedio, Difícil, Muy difícil.
- Cada dificultad tiene valores por defecto, editables desde el panel: preguntas por partida, segundos por desafío y puntuación mínima para superarla (con sus umbrales de estrella derivados).
- **BREAKING**: `niveles` y `nivel_desafios` desaparecen como entidades curadas a mano. Cada posición de `camino` pasa a apuntar directamente a una pareja **temática + dificultad** (con overrides opcionales de esos tres valores), en vez de a un `nivel_id` con preguntas curadas.
- Al iniciar una partida en una posición del camino, el sistema elige al azar N preguntas (N = preguntas por partida de esa dificultad, o el override de la posición) de entre **todas** las preguntas activas de esa temática+dificultad, en orden aleatorio.
- Migración automática: cada nivel manual existente se mapea a la pareja temática+dificultad que mejor represente las preguntas que ya tenía, y el camino se reconstruye sobre esas paradas.
- Panel: nuevo selector de dificultad en el formulario de preguntas; nueva pantalla de configuración de dificultades (valores por defecto); el constructor del camino elige temática+dificultad en vez de un nivel ya armado; se retiran las pantallas de listado de niveles y de detalle/recorrido de nivel (ya no hay nada que curar a mano).
- App: sin cambio de UI de juego; la Home y el arranque de intento pasan a identificar cada parada por su fila de `camino` en vez de por un `nivel_id`.

## Capabilities

### New Capabilities
- `question-difficulty`: catálogo cerrado de 5 dificultades y columna `dificultad` en `desafios`, con su selector en el formulario de preguntas del panel.
- `difficulty-defaults`: configuración editable de valores por defecto (preguntas por partida, segundos por desafío, puntuación mínima, umbrales de estrella) por dificultad, con su pantalla en el panel.

### Modified Capabilities
Renombrados que atraviesan varias capabilities: `iniciar_intento_nivel(nivel_id)` → `iniciar_intento_parada(camino_id)`; `cerrar_intento_nivel` → `cerrar_intento_parada`; la columna `nivel_id` de `intentos_nivel`/`progreso_usuario_nivel` → `camino_id`. El vocabulario de cara al jugador ("nivel", "camino de niveles") no cambia — solo el esquema y las RPCs internas.

- `game-data-model`: `camino` pasa a tener `tematica_id` + `dificultad` (con overrides opcionales de configuración) en vez de `nivel_id`; `niveles`/`nivel_desafios` se eliminan tras migrar sus datos; `intentos_nivel`/`progreso_usuario_nivel`/`intento_desafios` pasan a identificarse por `camino_id` en vez de por `nivel_id`.
- `challenge-play`: la RPC de arranque de intento (renombrada `iniciar_intento_parada`) resuelve la selección aleatoria sobre el pool de temática+dificultad de la parada, no sobre `nivel_desafios` curado.
- `level-progression`: el mínimo para superar y los umbrales de estrella de una parada salen de `difficulty-defaults` (o su override en `camino`), no de una fila de `niveles`; el desbloqueo del camino y el progreso agregado pasan a calcularse por `camino_id`.
- `panel-questions-form`: añade el selector de dificultad; retira la sección de "asignación opcional a niveles al crear" (ya no existe curación manual — la pregunta queda disponible automáticamente en el pool de su temática+dificultad).
- `panel-path-listing`: "Añadir al camino" pasa a elegir temática+dificultad (con overrides opcionales) en vez de un nivel ya curado.
- `player-path` (`camino_jugador`): expone temática+dificultad(+nombre de la parada) en vez de "el nivel al que apunta"; sus columnas de identificación pasan de `nivel_id` a `camino_id`.
- `app-player-path-home`: sus escenarios de navegación pasan a identificar la parada por `camino_id` en vez de `nivel_id` (sin cambio visual).
- `app-game-screen`: llama a `iniciar_intento_parada`/`cerrar_intento_parada`; el resto de la mecánica (toast de pista, revelado, cuenta atrás) no cambia.
- `app-level-summary`: llama a `cerrar_intento_parada`; sin cambio de contenido del resumen.
- `challenge-scoring`: actualiza la mención de `iniciar_intento_nivel` a `iniciar_intento_parada` como superficie que sigue sin exponer la ubicación real.
- `challenge-timer`: `segundos_por_desafio` pasa a vivir en `difficulty-defaults` (con override opcional en `camino`) en vez de en `niveles`.
- `content-alerts`: la alerta de tasa de superación baja pasa a calcularse por `camino_id` en vez de por `nivel_id`.
- `content-reordering`: `reordenar_niveles` y `reordenar_preguntas_nivel` se retiran (ya no hay niveles ni asignaciones que reordenar); `reordenar_tematicas` y `reordenar_camino` no cambian.
- `panel-home-dashboard`: el acceso rápido "nuevo nivel" y la referencia a `panel-levels-listing` en la navegación se retiran; la actividad reciente y las alertas resuelven nombres vía `camino`/`tematicas` en vez de `niveles`.
- `panel-home-metrics`: `niveles_activos` se sustituye por `paradas_activas` (conteo de filas activas de `camino`).
- `panel-questions-listing`: el indicador "usado en N niveles" y su filtro se sustituyen por un badge/filtro de dificultad; se retira el filtro "sin asignar a ningún nivel".
- `panel-recent-activity`: el evento `nivel_superado` pasa a incluir `camino_id` en vez de `nivel_id` en su `detalle`.
- `panel-topics-listing`: se retira el recuento de niveles por fila y el enlace al listado de niveles (pantalla retirada); el diálogo de borrado en cascada pasa a mencionar las paradas del camino de esa temática en vez de niveles.
- `panel-levels-listing`: se retira la pantalla completa (listado de niveles por temática); ya no hay niveles que gestionar de forma independiente al camino.
- `panel-level-detail`: se retira la pantalla completa (detalle/recorrido de un nivel); la configuración de puntuación pasa a `difficulty-defaults` (con overrides desde `panel-path-listing`).
- `challenge-usage`: se retira (`desafios_uso`/"usos" median curación manual en `nivel_desafios`, que deja de existir).

## Impact

- **Backend**: migración de esquema (columna `dificultad` en `desafios`; tabla de configuración por dificultad; columnas nuevas en `camino`; migración de datos de `niveles`/`nivel_desafios` al nuevo modelo; `intentos_nivel`/`progreso_usuario_nivel`/`intento_desafios` repuntan a `camino` en vez de a `niveles`); RPCs de arranque de intento y cierre de intento reescritas; RLS actualizada para las tablas nuevas/eliminadas.
- **Panel**: formulario de preguntas, constructor del camino, nueva pantalla de configuración de dificultades; retirada de las pantallas de niveles (listado y detalle).
- **App**: sin cambios de UI; ajuste de los identificadores que usa la Home y el arranque de intento (posición de camino en vez de `nivel_id`).
- **Datos existentes**: niveles y camino actuales se migran automáticamente, no se pierden.
