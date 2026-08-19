---
type: functional
parent: int-110-pantalla-ranking
reason: Feedback de testing local — el selector de chips de las pestañas Camino/Temática no convence visualmente; el usuario actualizó el mockup de Claude Design para sustituirlo por una rejilla de tarjetas grandes (con imagen real en Temática) donde tocar una tarjeta entra a su clasificación y un botón vuelve a la rejilla.
---

## Why

El mockup de Claude Design (`[App] - Ranking.dc.html`) se actualizó: las pestañas Camino y Temática ya no muestran un selector de chips horizontales — muestran una **rejilla de tarjetas** (2 columnas) que se navega en dos niveles: primero eliges una tarjeta (parada o temática), luego ves su clasificación (podio + lista + fila propia, sin cambios respecto a lo ya implementado); el botón ‹ de la cabecera vuelve de la clasificación a la rejilla, y solo cierra la pantalla cuando ya estás en la rejilla (o en Global, que no tiene rejilla).

Las tarjetas de Temática usan la imagen real de portada de cada temática (mismo asset que ya resuelve `CaminoGateway` como `imagenPortadaUrl`), y cada tarjeta muestra un adelanto de tu propia posición en esa clasificación concreta ("Tú #N" / "Sin jugar") antes de entrar.

## What Changes

- Las pestañas Camino y Temática pasan de un selector de chips a una **rejilla de tarjetas** (2 columnas), con dos estados por pestaña: rejilla (sin selección) y clasificación (con selección activa). Global no cambia — sigue yendo directa a la clasificación.
- Tarjeta de Camino: insignia de color con el número de parada, etiqueta **"Nivel N"** (se mantiene "Nivel" para la parada individual, igual que ya hace `camino_screen.dart` — solo la pestaña se llamaba mal, no cada parada), nombre de la temática de esa parada, y un adelanto de tu posición en esa parada ("Tú #N" / "Sin jugar").
- Tarjeta de Temática: imagen real de portada (`imagenPortadaUrl` de la primera parada de esa temática), punto de color, nombre de la temática, número de niveles de esa temática, y el mismo adelanto de tu posición ("Tú #N" / "Sin jugar").
- El botón ‹ de la cabecera cambia de comportamiento: si hay una tarjeta seleccionada, vuelve a la rejilla (no sale de la pantalla); si no hay selección (rejilla, o pestaña Global), sale de la pantalla como hasta ahora.
- El adelanto "Tú #N" de cada tarjeta se resuelve llamando a las RPC ya existentes (`clasificacion_por_camino`/`clasificacion_por_tematica`) con `p_limite: 1`, en paralelo para todas las tarjetas de la pestaña — sin RPC nueva.
- **Fuera de alcance / simplificado respecto al mockup**, por el mismo motivo que las simplificaciones ya documentadas en el cambio padre: el mockup muestra un contador "N jugadores" por tarjeta y "N preguntas" en las tarjetas de Temática — ninguno de los dos dato lo devuelven las funciones de clasificación actuales (que solo traen el top-N más tu fila, no un total de participantes ni un conteo de preguntas). Se omiten ambos contadores en vez de aproximarlos o pedir una RPC nueva.

## Capabilities

### Modified Capabilities
- `app-ranking`: las pestañas Camino y Temática pasan de selector de chips a rejilla de tarjetas de dos niveles (rejilla → clasificación, con vuelta); las tarjetas muestran un adelanto de la posición propia; se documenta la ausencia de contador de jugadores/preguntas por no estar disponible en el backend actual.

## Impact

- `app/lib/screens/ranking_screen.dart`: sustituye `_SelectorChips` por una rejilla de tarjetas para Camino/Temática; nuevo estado de selección de tarjeta por pestaña; nuevas llamadas paralelas de adelanto de posición; cambia el comportamiento del botón volver.
- Tests: se reescriben los tests que dependían del selector de chips (`ranking-chip-camino-*`, `ranking-chip-tematica-*`, el test de "no se recorta") para la nueva rejilla de tarjetas; se añaden tests de navegación rejilla↔clasificación y del adelanto de posición.
- Sin cambios de backend — reutiliza las RPC de INT-109 tal cual, solo con `p_limite` distinto según el uso (1 para el adelanto, el valor normal para la clasificación completa).
