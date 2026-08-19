## 1. Estado de selección y navegación rejilla ↔ clasificación

- [x] 1.1 Quitar la auto-selección de la primera parada/temática al entrar en Camino/Temática (`_onCambiarPestana`, `_cargarParadas`): al cambiar a esas pestañas, `_caminoIdSeleccionado`/`_tematicaIdSeleccionada` quedan en `null` (rejilla), nunca se auto-fijan.
- [x] 1.2 Al cambiar de pestaña, resetear siempre a `null` la selección de la pestaña destino (si ya tenía una tarjeta abierta de una visita anterior).
- [x] 1.3 Cambiar `onBack` de `_Cabecera`: si `_pestana` es Camino/Temática y hay selección activa, limpiar la selección (sin `Navigator.pop`); si no, `Navigator.of(context).pop()` como hasta ahora.

## 2. Adelanto de posición por tarjeta

- [x] 2.1 Añadir a `RankingGateway`/`SupabaseRankingGateway` (o reutilizar los métodos existentes con `limite: 1`) la capacidad de pedir solo la fila propia de una parada/temática.
- [x] 2.2 Función `_cargarPreviasCamino()`: `Future.wait` de `fetchClasificacionPorCamino(caminoId, limite: 1)` para cada parada de `_chipsCamino`, devolviendo un `Map<String, EntradaRanking>` (caminoId → fila propia).
- [x] 2.3 Función equivalente `_cargarPreviasTematica()` para `_chipsTematica`.
- [x] 2.4 Disparar la carga de previas la primera vez que se entra en la rejilla de cada pestaña (cuando `_paradas` ya está disponible); cachear el `Future` por pestaña para no repetir las llamadas al volver a la rejilla.

## 3. Rejilla de tarjetas (UI)

- [x] 3.1 Quitar `_SelectorChips`/`_ChipDato` de `ranking_screen.dart` (ya no se usan) — mantener `ChipCamino`/`ChipTematica`/`derivarChipsCamino`/`derivarChipsTematica` (siguen siendo el modelo de datos de la rejilla).
- [x] 3.2 Nuevo widget `_RejillaTarjetas`: `GridView`/`Wrap` de 2 columnas, una tarjeta por elemento, con estado de carga (mientras se resuelven las previas) y estado de error con reintentar.
- [x] 3.3 Tarjeta de Camino: insignia de color con el número de parada, etiqueta "Nivel N", nombre de la temática de esa parada, adelanto de posición ("Tú #N"/"Sin jugar").
- [x] 3.4 Tarjeta de Temática: imagen de portada (`ParadaCamino.imagenPortadaUrl` de la primera parada con esa `tematicaId`, con fallback a bloque de color si es `null`), punto de color, nombre de la temática, número de niveles de esa temática (`_paradas.where(...).length`), adelanto de posición.
- [x] 3.5 Subtítulo de la cabecera: "Elige una parada del camino · N paradas" / "Elige una temática · N colecciones" cuando la rejilla está visible; "Nivel N · <temática>" / "<Temática> · ranking" cuando hay una tarjeta abierta (revertir el subtítulo de parada de "Camino N" a "Nivel N", ver design.md decisión 4).
- [x] 3.6 Body de `build()`: Global → clasificación directa (sin cambios); Camino/Temática → rejilla si no hay selección, clasificación si la hay (reutilizando el `FutureBuilder` de `_futuro` ya existente para la clasificación).

## 4. Tests

- [x] 4.1 Reescribir los tests que dependían de `_SelectorChips`/claves `ranking-chip-*` (incluido el test de "no se recorta") para la nueva rejilla de tarjetas.
- [x] 4.2 Test: entrar en Camino/Temática muestra la rejilla, no la clasificación, sin tarjeta preseleccionada.
- [x] 4.3 Test: tocar una tarjeta muestra su clasificación; volver con ‹ vuelve a la rejilla (sin salir de la pantalla); volver con ‹ desde la rejilla sí sale de la pantalla (usando un `Navigator` real en el test, como ya hace `camino_screen_test.dart`).
- [x] 4.4 Test: cambiar de pestaña con una tarjeta abierta, al volver se ve la rejilla, no la clasificación anterior.
- [x] 4.5 Test: adelanto de posición — una tarjeta con posición real muestra "Tú #N"; una sin puntuación agregable muestra "Sin jugar".
- [x] 4.6 Ejecutar `flutter test`, `flutter analyze` y `dart format --set-exit-if-changed` en `app/` y confirmar que todo pasa sin regresiones.
- [x] 4.7 Sincronizar `openspec/specs/app-ranking/spec.md` con los requisitos `MODIFIED` de este delta al archivar.
