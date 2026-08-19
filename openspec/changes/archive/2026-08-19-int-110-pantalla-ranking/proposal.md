## Why

Hoy la app no tiene ninguna pantalla de clasificación entre jugadores: cada uno solo ve su propio progreso. El backend de clasificación (INT-109, ya en Done) expone `clasificacion_global`, `clasificacion_por_camino` y `clasificacion_por_tematica`, pero no hay ningún consumidor en la app. Sin esta pantalla ese trabajo de backend no aporta valor visible al jugador, y el panel de admin también tiene un enlace "Ranking" pendiente a la espera de que exista el concepto en la app.

## What Changes

- Nueva pantalla "Clasificación" en la app, con 3 pestañas navegables: **Global** (acumulado histórico), **Nivel** (selector de parada del camino) y **Temática** (selector de temática).
- Selector de chips horizontales para elegir parada/temática, visible solo en las pestañas Nivel y Temática.
- Podio destacado (oro/plata/bronce) para el top 3 de cada clasificación, con avatar por inicial, nombre y puntos.
- Lista scrollable con el resto de posiciones (puesto, avatar, nombre, dato contextual, puntos).
- Fila fija al pie con la posición y puntuación del propio jugador, siempre visible aunque quede fuera del top cargado.
- Estados de carga y vacío por pestaña.
- Acceso a la pantalla desde algún punto de la navegación existente de la app (a definir en design.md).
- **Fuera de alcance / simplificado respecto al mockup**, por límites del backend actual (ver `player-ranking` spec, ya archivada):
  - El indicador de variación ▲/▼ requiere histórico inexistente hoy: se omite (no se muestra ni en neutro para no sugerir un dato que no existe).
  - El dato contextual de la fila ("racha", "intentos", "% acierto") no lo devuelven las funciones RPC actuales, que solo exponen `niveles_superados` (Global/Temática) y `superado` (Nivel). El dato contextual se simplifica a lo que el backend sí soporta.
  - El concepto de "temporada" del subtítulo Global (mockup) no existe en el modelo de datos: el subtítulo de Global se ajusta a "acumulado histórico" en vez de "Temporada 3 · quedan 12 días".

## Capabilities

### New Capabilities
- `app-ranking`: pantalla de clasificación en la app móvil (3 pestañas, podio, lista, fila propia fija, estados de carga/vacío) y su integración con las RPC de `clasificacion_global`/`clasificacion_por_camino`/`clasificacion_por_tematica`.

### Modified Capabilities
(ninguna — se consume `player-ranking` tal cual está especificado; no se le piden cambios de contrato)

## Impact

- App Flutter: nueva pantalla + widgets (podio, fila de ranking, chips, tabs), nuevo gateway/repositorio para invocar las 3 RPC de Supabase, posible nuevo provider de estado.
- Navegación de la app: se añade un punto de entrada a la pantalla (Home / barra inferior / botón en Camino — a decidir en design.md).
- Sin cambios de backend ni de esquema — solo consumo de RPC ya existentes de INT-109.
