## 1. Migración: vista de contenido seguro

- [x] 1.1 Crear migración `vista_desafios_arranque_intento` en
      `backend/supabase/migrations/`
- [x] 1.2 Vista `desafios_para_jugar` (D1: sin `security_invoker`) con
      `id`, `tipo`, `imagen_url`, `video_url`, `texto_pregunta`, `activo`
      — sin `lat_real`/`lng_real`/`nombre_lugar`
- [x] 1.3 `grant select on desafios_para_jugar to authenticated`

## 2. Migración: RPC de arranque de intento

- [x] 2.1 Función `iniciar_intento_nivel(p_nivel_id uuid) returns jsonb`
      (D2: `security invoker`)
- [x] 2.2 Validar que el nivel existe y `activo = true` (D5); lanzar
      excepción si no
- [x] 2.3 Insertar `intento_nivel` con `usuario_id = auth.uid()`,
      `nivel_id = p_nivel_id`
- [x] 2.4 Seleccionar los desafíos de la partida desde `nivel_desafios` +
      `desafios_para_jugar` respetando `niveles.preguntas_por_partida`
      (D3: `order by random() limit` condicional)
- [x] 2.5 Construir y devolver el `jsonb` con `intento_id` + `desafios`
      (D4)
- [x] 2.6 `revoke execute ... from public` /
      `grant execute ... to authenticated`, igual que D2.2 de INT-78

## 3. Verificación manual contra el proyecto remoto

- [x] 3.1 `supabase db push` contra el proyecto remoto enlazado
- [x] 3.2 Un usuario autenticado lee `desafios_para_jugar` → recibe
      `id`/`tipo`/`imagen_url`/`video_url`/`texto_pregunta`/`activo`, sin
      `lat_real`/`lng_real`/`nombre_lugar`
- [x] 3.3 Llamar `iniciar_intento_nivel` sobre un nivel con
      `preguntas_por_partida = NULL` → devuelve todos los desafíos
      asignados
- [x] 3.4 Llamar `iniciar_intento_nivel` sobre un nivel con
      `preguntas_por_partida = N` (N menor que el total asignado) →
      devuelve exactamente N desafíos, distintos en llamadas sucesivas
- [x] 3.5 Llamar `iniciar_intento_nivel` con un `nivel_id` inexistente o
      con `activo = false` → falla, no crea fila en `intentos_nivel`
- [x] 3.6 Confirmar que la fila creada en `intentos_nivel` tiene el
      `usuario_id` de quien llamó, no uno manipulado
- [x] 3.7 Caso de seguridad (checklist INT-95): con sesión de jugador
      (incluida anónima), confirmar que `select` directo sobre `desafios`
      sigue sin devolver filas — no requiere código nuevo, solo confirma
      que INT-77 sigue vigente
- [x] 3.8 Caso de seguridad (checklist INT-95): confirmar en
      `pg_proc`/`\df+ responder_desafio` que sigue siendo `security
      definer` — no requiere código nuevo, solo confirma que INT-78 sigue
      vigente
- [x] 3.9 Confirmar que ninguna respuesta de esta tarea (vista o RPC)
      expone `lat_real`, `lng_real` ni `nombre_lugar`, en ningún campo
