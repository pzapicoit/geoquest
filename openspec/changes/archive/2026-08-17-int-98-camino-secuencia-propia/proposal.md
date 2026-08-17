## Why

El modelo actual desbloquea contenido por temática completa ("juega todos los niveles de Monumentos antes de desbloquear Banderas"), pero el diseño de producto quiere un **camino único** donde el admin intercale niveles de distintas temáticas en el orden que prefiera, y donde cada partida presente un **subconjunto aleatorio** de las preguntas configuradas en el nivel (no siempre las mismas, en el mismo orden). Esto afecta a piezas ya implementadas (`INT-74` esquema, `INT-79` lógica de desbloqueo, `INT-84` panel de recorrido) y condiciona cómo se deben construir las piezas aún pendientes (`INT-95`, `INT-96`, `INT-90`), por lo que hace falta resolverlo ahora, antes de seguir construyendo sobre el modelo antiguo.

## What Changes

- Se añade una tabla `camino` que define una secuencia global y ordenada de posiciones, cada una apuntando a un `nivel_id` concreto (pudiendo intercalar temáticas libremente) y con su propio umbral de estrellas requeridas para desbloquearla.
- Se añade `niveles.preguntas_por_partida`: cuántas preguntas al azar, de las configuradas en `nivel_desafios`, se juegan en cada intento.
- **BREAKING**: la lógica de desbloqueo (`cerrar_intento_nivel`) deja de basarse en "estrellas acumuladas en la temática actual" y pasa a basarse en "estrellas acumuladas en todo el camino recorrido", comparadas contra el umbral de cada posición de `camino`. No se exige haber completado la posición anterior — solo alcanzar el umbral de estrellas (decisión confirmada con el usuario).
- **BREAKING**: se elimina `tematicas.estrellas_requeridas` (columna y su uso), ya que el umbral de desbloqueo pasa a vivir en `camino`, por posición, no en la temática.
- Panel: nueva pantalla "Camino" donde el admin ordena las posiciones de la secuencia global, elige qué (temática, nivel) va en cada una, y configura el umbral de estrellas de cada posición.
- Panel: la pantalla de detalle de nivel (`INT-84`, Recorrido) añade el campo `preguntas_por_partida` a la tarjeta de configuración.
- Panel: el listado de temáticas deja de mostrar la columna "requisito de estrellas" (ya no determina el desbloqueo entre temáticas).

**Fuera de alcance de este cambio** (quedan desbloqueadas por el nuevo esquema, pero se implementan en sus propios tickets ya existentes en backlog):
- `INT-95`: el RPC `iniciar_intento_nivel` que selecciona al azar `preguntas_por_partida` desafíos del pool del nivel.
- `INT-96`: la vista del camino del jugador construida sobre la tabla `camino`.
- `INT-90`: la pantalla Home de la app (Flutter) que renderiza el camino como mapa de paradas.

## Capabilities

### New Capabilities
- `panel-path-listing`: pantalla de panel para gestionar la secuencia global del camino (crear/reordenar posiciones, asignar nivel a cada una, configurar umbral de estrellas por posición).

### Modified Capabilities
- `game-data-model`: añade la tabla `camino` y la columna `niveles.preguntas_por_partida`; elimina `tematicas.estrellas_requeridas`.
- `level-progression`: sustituye el desbloqueo "siguiente nivel de la temática" + "siguiente temática por estrellas" por un único mecanismo: desbloqueo de posiciones del camino por estrellas acumuladas en todo el camino.
- `panel-level-detail`: añade el campo `preguntas_por_partida` a la tarjeta "Configuración del nivel".
- `panel-topics-listing`: elimina la columna "requisito de estrellas" del listado de temáticas.
- `content-reordering`: añade la RPC `reordenar_camino`, con las mismas garantías de admin-only y conjunto completo que las RPC de reorden existentes.
- `panel-levels-listing`: el subtítulo de una temática sin niveles deja de mostrar "estrellas requeridas para desbloquear" y la temática anterior (dependían de `tematicas.estrellas_requeridas`).

## Impact

- **Backend**: nueva migración SQL en `backend/supabase/migrations/` (tabla `camino`, columna `niveles.preguntas_por_partida`, drop de `tematicas.estrellas_requeridas`, reescritura de la función `cerrar_intento_nivel`), y sus policies de RLS asociadas para `camino`.
- **Panel**: `panel/src/lib/tematicas.ts` (quitar `estrellasRequeridas`), `panel/src/lib/niveles.ts` / `nivelRecorrido.ts` (añadir `preguntas_por_partida`), `panel/src/pages/Tematicas.tsx` (quitar columna), nueva página + módulo `panel/src/pages/Camino.tsx` / `panel/src/lib/camino.ts`, y navegación lateral.
- **OpenSpec**: deltas sobre `game-data-model`, `level-progression`, `panel-level-detail`, `panel-topics-listing`; nueva capability `panel-path-listing`.
- **No afecta** todavía a la app Flutter (`app/lib/`): la pantalla Home sigue siendo el placeholder actual hasta `INT-90`.
