## Context

El mockup de Claude Design (`[App] - Ranking.dc.html`) se actualizó tras testing local: Camino y Temática pasan de un selector de chips a una **rejilla de tarjetas de dos niveles** — rejilla de tarjetas → tocas una → clasificación de esa tarjeta (podio+lista+fila propia, sin cambios); el botón ‹ vuelve de la clasificación a la rejilla en vez de salir de la pantalla.

Los identificadores `ChipCamino`/`ChipTematica`/`derivarChipsCamino`/`derivarChipsTematica` (de INT-110 y su delta-1) siguen siendo válidos como modelo de datos — cada uno sigue siendo "una parada/temática seleccionable"; lo que cambia es el widget que los pinta (rejilla de tarjetas en vez de fila de chips) y qué significa tener uno "seleccionado" (antes: cuál está resaltado en la fila de chips, con auto-selección del primero; ahora: cuál se ha "abierto" para ver su clasificación, sin auto-selección — por defecto no hay ninguno seleccionado y se ve la rejilla).

## Goals / Non-Goals

**Goals:**
- Camino y Temática muestran una rejilla de tarjetas (2 columnas); tocar una tarjeta lleva a su clasificación; el botón ‹ vuelve a la rejilla si hay una tarjeta abierta, o sale de la pantalla si no la hay (o en Global).
- Las tarjetas de Temática usan la imagen real de portada ya disponible (`ParadaCamino.imagenPortadaUrl`); las de Camino usan una insignia de color con el número de parada (sin imagen), igual que el mockup.
- Cada tarjeta adelanta la posición propia en esa clasificación concreta ("Tú #N" / "Sin jugar"), resuelta con las RPC ya existentes (`p_limite: 1`, en paralelo).

**Non-Goals:**
- Contador de "N jugadores" o "N preguntas" por tarjeta — el backend actual no expone ni un total de participantes ni un conteo de preguntas por temática; se omiten en vez de aproximarlos o pedir una RPC nueva (mismo criterio que las simplificaciones ya documentadas en el cambio padre).
- Persistir qué tarjeta estaba abierta al cambiar de pestaña o salir de la pantalla — cambiar de pestaña siempre vuelve a la rejilla (igual que el mockup: `sels[i] = null` en cada cambio de pestaña).
- Paginación o scroll infinito en la rejilla — 13 tarjetas (Camino) y 6 (Temática) caben en un `GridView`/`Wrap` simple sin paginar.

## Decisions

### 1. Reutilizar `_caminoIdSeleccionado`/`_tematicaIdSeleccionada` como "tarjeta abierta", sin auto-selección
Antes (delta-1): al entrar en la pestaña se auto-seleccionaba la primera parada/temática (`??= primero`). Ahora: al entrar en Camino o Temática, la selección se resetea a `null` (se ve la rejilla); solo se fija al tocar una tarjeta. Cambiar de pestaña siempre resetea la selección de la pestaña nueva a `null`, igual que el mockup.

**Alternativa descartada**: un estado nuevo separado (`_tarjetaAbierta`) además de los IDs seleccionados. Se descarta por redundante — el ID seleccionado ya codifica exactamente "qué tarjeta está abierta" (`null` = ninguna = rejilla).

### 2. El botón ‹ de la cabecera es contextual: cierra la selección antes que la pantalla
`RankingScreen` calcula el callback de `onBack` según el estado actual: si `_pestana` es Camino o Temática y hay una selección activa, `onBack` limpia esa selección (vuelve a la rejilla) sin tocar el `Navigator`; en cualquier otro caso (rejilla sin selección, o pestaña Global), `onBack` hace `Navigator.of(context).pop()` como hasta ahora.

### 3. Adelanto de posición por tarjeta: RPC existentes con `p_limite: 1`, en paralelo
Al entrar en la rejilla de una pestaña (o en cuanto `_paradas` esté disponible), se lanza un `Future.wait` con una llamada `fetchClasificacionPorCamino(caminoId, limite: 1)` (o `fetchClasificacionPorTematica`) por cada tarjeta, y se queda solo con la fila `es_usuario_actual` de cada respuesta (garantizada por el contrato de la RPC — D4 de `player-ranking`). `p_limite: 1` mantiene cada respuesta mínima (1-2 filas) aunque se disparen hasta 13 llamadas a la vez. El resultado se cachea en un `Future<Map<String, EntradaRanking>>` por pestaña, calculado una sola vez por apertura de pestaña (no se recalcula si se vuelve a la rejilla tras cerrar una tarjeta).

**Alternativa descartada**: pedir una RPC nueva que devuelva "mi posición en todos los caminos/temáticas" en una sola llamada. Sería más eficiente en red, pero es alcance de backend nuevo para un adelanto que no es crítico; se deja para una futura iteración si el número de llamadas en paralelo resultara un problema real (13 es un límite conocido y acotado, no crece).

### 4. Las paradas individuales siguen llamándose "Nivel N"; solo la pestaña es "Camino"
El mockup actualizado confirma esta distinción: la pestaña (el agrupador) es "Camino", pero cada tarjeta/parada individual dentro de ella sigue etiquetada "Nivel N" — igual que `camino_screen.dart` ya muestra "Nivel N de M" en la Home. Esto revierte parcialmente delta-1: el subtítulo al entrar en una parada vuelve a ser "Nivel N · <temática>" (no "Camino N · <temática>"), y la etiqueta de cada tarjeta de Camino es "Nivel N". El nombre de la pestaña, los identificadores internos (`_Pestana.camino`, `ChipCamino`, etc.) y las claves de test con prefijo `camino` NO cambian — ya están bien nombrados desde delta-1.

### 5. Imagen de cada tarjeta de Temática: primera parada con esa `tematicaId`
`ParadaCamino.imagenPortadaUrl` ya resuelve la portada por temática (via `CaminoGateway`); para la tarjeta de una temática se usa el `imagenPortadaUrl` de la primera parada de `_paradas` que tenga esa `tematicaId`. Si es `null` (temática sin portada subida), la tarjeta cae a un bloque de color (`_colorTematica`) en vez de una imagen rota.

## Risks / Trade-offs

- **[Riesgo] 13 llamadas RPC en paralelo al abrir la pestaña Camino** → con `p_limite: 1` cada respuesta es mínima, y es una única ráfaga (no secuencial); se acepta como coste razonable de la mejora visual. *Mitigación*: si en el futuro se nota lento, migrar a una RPC agregada es la vía natural (alternativa descartada en D3).
- **[Trade-off] Sin contador de jugadores/preguntas por tarjeta** → la rejilla se ve "más vacía" que el mockup. *Mitigación*: aceptado explícitamente en el proposal; prioriza no inventar datos que el backend no tiene.
- **[Riesgo] Revertir "Camino N" a "Nivel N" tras delta-1** → podría leerse como ir y venir sobre la misma decisión. *Mitigación*: no es una reversión completa — la pestaña sigue siendo "Camino" (lo que pidió el usuario); solo la etiqueta de cada parada individual vuelve a "Nivel", que es coherente con el resto de la app y con el mockup actualizado.
