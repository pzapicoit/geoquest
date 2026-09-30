## Why

Las tablas de juego (`intentos_nivel`, `intento_desafios`, `respuestas_desafio`, `progreso_usuario_nivel`) son escribibles directamente por cualquier jugador autenticado mediante políticas RLS `insert_own` / `update_own`, y `responder_desafio` no comprueba que el desafío pertenezca al intento. Con la clave publicable que lleva la app (y cualquier cliente REST) un jugador puede falsear su puntaje, sus estrellas y el ranking, desbloquear todas las paradas y conocer la ubicación real de cualquier desafío antes de responderlo, anulando la regla «la ciudad no viaja hasta que se responde». La frontera de seguridad del proyecto es RLS (no hay backend propio), así que esto no es un fallo de UI sino del modelo de confianza. Detectado en el análisis del proyecto; Linear INT-137.

## What Changes

- **BREAKING (solo para clientes que escriban directo)**: se eliminan las seis políticas de escritura (`insert`/`update`) de `intentos_nivel`, `progreso_usuario_nivel`, `respuestas_desafio` e `intento_desafios`, y se revocan `insert/update/delete/truncate` de esas tablas a `anon` y `authenticated`. Solo queda `select` sobre filas propias. La app y el panel no escriben en ellas directamente (verificado: solo usan RPC), así que no deberían verse afectados.
- `iniciar_intento_parada` y `cerrar_intento_parada` pasan de `security invoker` a `security definer` con `set search_path = public`, porque dependían de las políticas de escritura que se eliminan. Al perder el filtro RLS, `cerrar_intento_parada` debe comprobar explícitamente que el intento es de `auth.uid()`.
- `responder_desafio` exige, antes de leer nada de `desafios`, que `p_desafio_id` pertenezca a `intento_desafios` de `p_intento_id` y que no esté ya respondido. El trigger `respuestas_desafio_calcular_antes_de_insertar` aplica la misma comprobación como defensa en profundidad.
- Se añade el primer test SQL de RLS y antitrampas (con `set local role authenticated`), que hoy no existe.

Fuera de alcance (incidencias propias): tope diario de comodines (INT-138), reloj fijado por el servidor (INT-139).

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `game-data-model`: los jugadores ya no pueden crear ni actualizar filas de `intentos_nivel`, `respuestas_desafio`, `progreso_usuario_nivel` ni `intento_desafios` directamente; solo leerlas. Las escrituras se hacen exclusivamente vía RPC.
- `challenge-scoring`: la RPC de respuesta rechaza un desafío que no pertenece a la selección del intento y no revela nada de él.

## Impact

- **Backend**: una migración nueva en `backend/supabase/migrations/` (policies, revokes, tres funciones) y un test en `backend/supabase/tests/`.
- **App Flutter y panel React**: sin cambios de código previstos; se confirma por búsqueda que no escriben directo en esas tablas.
- **Despliegue**: aplicar la migración al proyecto remoto de Supabase es una acción externa y requiere luz verde explícita.
- **Seguridad**: cierra el falseo del ranking y de las estrellas, y la fuga de la ubicación real.
