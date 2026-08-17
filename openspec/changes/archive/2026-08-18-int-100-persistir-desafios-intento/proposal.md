## Why

Hoy hay niveles que **no se pueden superar nunca**: `cerrar_intento_nivel`
exige una respuesta para cada desafío de `nivel_desafios` (la asignación
completa del nivel), pero `iniciar_intento_nivel` (INT-95) nunca reparte esa
asignación completa — recorta a `niveles.preguntas_por_partida` al azar
(INT-98) y siempre excluye `activo = false`. El intento nunca llega a "todos
respondidos" y el cierre revienta, dejando `puntaje_total` en 0 y sin
desbloquear nada del camino. La causa raíz es que `iniciar_intento_nivel` no
persiste en ningún sitio qué desafíos le tocaron al intento: los devuelve en
su `jsonb` de respuesta y los olvida.

## What Changes

- Nueva tabla `intento_desafios (intento_id, desafio_id, orden)`: snapshot
  de qué desafíos (y en qué orden) le tocaron a un intento concreto,
  escrita una sola vez al arrancarlo.
- `iniciar_intento_nivel` persiste su selección (la misma lógica de hoy:
  todos si `preguntas_por_partida` es `NULL`, ese número al azar si no,
  siempre excluyendo `activo = false`) en `intento_desafios` antes de
  devolver la respuesta. La respuesta que recibe la app no cambia de forma.
- `cerrar_intento_nivel` deja de contar contra `nivel_desafios` (la
  asignación *actual* del nivel) y pasa a contar contra `intento_desafios`
  (la selección *de ese intento*), tanto para exigir que esté completo como
  para sumar el puntaje. Esto resuelve a la vez los dos casos del bug
  (`preguntas_por_partida` parcial y desafíos inactivos) y de propina deja
  el intento cerrable aunque un desafío se desactive o se reasigne a mitad
  de partida, porque ya no depende del estado en vivo de `nivel_desafios`.
- RLS de `intento_desafios`: mismo patrón que `respuestas_desafio` (select +
  insert solo de las propias filas, vía `intento_id -> intentos_nivel.usuario_id`;
  sin update).

## Capabilities

### New Capabilities
(ninguna nueva — `intento_desafios` es una tabla de soporte interna, no una
capability de cara a la app; su contrato de lectura/escritura se documenta
como parte de `game-data-model`)

### Modified Capabilities
- `game-data-model`: nuevo requisito de esquema para `intento_desafios`
  (estructura, RLS) como parte del modelo de datos de intentos.
- `challenge-play`: `iniciar_intento_nivel` pasa a persistir su selección en
  `intento_desafios`, sin cambiar la forma de su respuesta ni los criterios
  de selección ya especificados.
- `level-progression`: el requisito "El cierre exige que el intento esté
  completo" y el de "Agregación de puntaje del intento" pasan a definirse
  sobre la selección persistida del intento (`intento_desafios`), no sobre
  la asignación en vivo del nivel (`nivel_desafios`).

## Impact

- **Código nuevo**: una migración en `backend/supabase/migrations/` con la
  tabla `intento_desafios`, sus policies e índices.
- **Código modificado**: `iniciar_intento_nivel` y `cerrar_intento_nivel`
  (ambas via `create or replace function` en la misma migración).
- **Código sin tocar**: `app/` y `panel/` — la forma de la respuesta de
  `iniciar_intento_nivel` no cambia, y `responder_desafio` no necesita
  cambios (ya valida pertenencia del intento al usuario; no comprobaba ni
  comprobará pertenencia del desafío a la selección, fuera de alcance).
- **Dependencias externas**: ninguna nueva.
- **Backend**: aplica sobre el esquema de `game-data-model` (`intentos_nivel`,
  `nivel_desafios`, `desafios`) sin migrar intentos ya existentes (los
  intentos previos a esta migración no tienen fila en `intento_desafios`;
  ver design.md para cómo se trata ese caso).
