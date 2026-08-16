## Why

Las preguntas ya se gestionan como banco reutilizable (INT-82/INT-83), pero
no existe ninguna pantalla para configurar un nivel concreto ni para decidir
qué preguntas de ese banco forman su recorrido y en qué orden. Hoy esa
gestión solo es posible a mano contra Supabase.

## What Changes

- Nueva pantalla de detalle de nivel (`/niveles/:id`) con breadcrumb
  Temáticas > [temática] > [nivel] (informativo; los listados de temáticas y
  niveles todavía no existen como pantallas).
- Tarjeta "Configuración del nivel" editable: nombre del nivel, puntaje
  mínimo para superar y umbrales de 1/2/3 estrellas, con la misma validación
  de orden ascendente que ya exige la base de datos
  (`puntaje_minimo_superar <= umbral_estrella_1 <= umbral_estrella_2 <= umbral_estrella_3`).
- Contador "X preguntas en este recorrido" y lista ordenada y arrastrable de
  las preguntas asignadas al nivel vía `nivel_desafios`: posición, miniatura,
  nombre del lugar, badge de tipo.
- Acción "Quitar del recorrido" por fila: borra solo la asignación en
  `nivel_desafios` (la pregunta sigue en el banco) y renumera el `orden` de
  las que quedan.
- Reordenar arrastrando persiste el nuevo orden llamando a la RPC existente
  `reordenar_preguntas_nivel` (INT-87).
- Botón "Añadir pregunta existente": selector/buscador sobre el banco de
  preguntas que excluye las ya asignadas a este nivel; al elegir una, se
  inserta en `nivel_desafios` al final del orden actual.
- Botón "Crear pregunta nueva": navega a `/preguntas/nueva` (INT-83).
- Estado vacío cuando el nivel no tiene ninguna pregunta asignada todavía.

## Capabilities

### New Capabilities
- `panel-level-detail`: pantalla de detalle de un nivel — configuración de
  umbrales y gestión del recorrido ordenado de preguntas asignadas.

### Modified Capabilities
- `game-data-model`: `niveles` gana una columna `nombre` (texto, opcional)
  para que el nivel pueda mostrar un nombre editable además de su `orden`.

## Impact

- `panel/src/pages/`: nueva página `NivelRecorrido.tsx`.
- `panel/src/lib/`: nuevas funciones de datos (obtener nivel + su recorrido,
  guardar configuración del nivel, añadir/quitar preguntas del recorrido,
  reordenar).
- `panel/src/App.tsx`: nueva ruta `/niveles/:id`.
- `backend/supabase`: nueva migración que añade `niveles.nombre` (nullable).
  No se toca RLS ni la RPC `reordenar_preguntas_nivel`, ya cubiertas por
  `game-data-model` y `content-reordering`.
- La navegación lateral ("Temáticas"/"Niveles") sigue deshabilitada: esta
  pantalla se alcanza por URL directa hasta que exista su listado.
