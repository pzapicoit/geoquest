## Why

Un jugador no tiene ningún camino para ver el contenido de un desafío (foto,
vídeo o pregunta) ni para arrancar un intento de nivel: `desafios` está
bloqueada por RLS para no-admins (INT-77, a propósito — protege
`lat_real`/`lng_real`/`nombre_lugar`), y no existe ninguna vista ni RPC que
exponga lo mínimo necesario para jugar. INT-91 (pantalla de pista) e INT-92
(pantalla de mapa) no tienen ningún dato real que consumir sin esto.

## What Changes

- Nueva vista `desafios_para_jugar`: expone `id`, `tipo`, `imagen_url`,
  `video_url`, `texto_pregunta` y `activo` de cada desafío — nunca
  `lat_real`, `lng_real` ni `nombre_lugar`. Lectura permitida a cualquier
  autenticado (incluida sesión anónima), igual que `tematicas`/`niveles`.
- Nueva RPC `iniciar_intento_nivel(nivel_id)`: valida el nivel, crea el
  `intento_nivel` del usuario actual y selecciona los desafíos de esa
  partida a partir de `nivel_desafios` — todos si `niveles.preguntas_por_partida`
  es `NULL`, o esa cantidad elegida al azar si no lo es — devolviendo en una
  sola llamada el `intento_id` y la lista de desafíos a jugar (con el mismo
  contenido que expone `desafios_para_jugar`). Cierra el hueco que
  `game-data-model` ya había dejado anotado para `preguntas_por_partida`.
- Verificación de que lo que INT-77/INT-78 ya dejaron listo sigue vigente:
  `desafios` sigue sin política de `select` para no-admins, y
  `responder_desafio` sigue siendo `security definer` — ninguno de los dos
  necesita cambios de código, solo un caso de prueba explícito.

## Capabilities

### New Capabilities
- `challenge-play`: acceso de lectura seguro a desafíos para jugar
  (`desafios_para_jugar`) y arranque de un intento de nivel con selección
  de sus desafíos (`iniciar_intento_nivel`).

### Modified Capabilities
(ninguna — `desafios` ya no era legible por jugadores desde INT-77, y
`responder_desafio` ya era `security definer` desde INT-78; este cambio no
altera esos requisitos, solo añade uno nuevo sobre la vista/RPC.)

## Impact

- **Código nuevo**: una migración en `backend/supabase/migrations/` con la
  vista `desafios_para_jugar` y la función `iniciar_intento_nivel`.
- **Código modificado**: ninguno — no toca `app/` ni `panel/` (INT-91/INT-92
  consumirán esto más adelante).
- **Dependencias externas**: ninguna nueva.
- **Backend**: aplica sobre el esquema de `game-data-model`
  (`desafios`, `nivel_desafios`, `niveles`, `intentos_nivel`) sin migrar
  datos existentes.
