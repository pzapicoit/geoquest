## 1. Migración: tabla `intento_desafios`

- [x] 1.1 Crear migración `persistir_desafios_intento` en
      `backend/supabase/migrations/`
- [x] 1.2 Tabla `intento_desafios (intento_id, desafio_id, orden)` (D1):
      PK compuesta `(intento_id, desafio_id)`, `unique (intento_id, orden)`,
      `desafio_id references desafios (id) on delete restrict`,
      `intento_id references intentos_nivel (id) on delete cascade`
- [x] 1.3 `enable row level security` + policies `intento_desafios_select_own`
      e `intento_desafios_insert_own` (D2), sin policy de `update` ni
      `delete`

## 2. Migración: `iniciar_intento_nivel` persiste su selección

- [x] 2.1 `create or replace function iniciar_intento_nivel` (D3):
      materializar la selección (CTE `materialized`) para que el mismo
      `random()` se use al ordenar/recortar y al numerar el `orden`
      persistido
- [x] 2.2 Insertar la selección en `intento_desafios` (`intento_id`,
      `desafio_id`, `orden`) antes de construir la respuesta
- [x] 2.3 Confirmar que la forma del `jsonb` de respuesta
      (`{"intento_id", "desafios": [...]}`) no cambia

## 3. Migración: `cerrar_intento_nivel` cuenta contra `intento_desafios`

- [x] 3.1 `create or replace function cerrar_intento_nivel` (D4): el conteo
      de completitud pasa de `nivel_desafios` a `intento_desafios`
- [x] 3.2 Añadir la comprobación explícita `v_total_desafios = 0 ->
      raise exception` (intento sin selección persistida)
- [x] 3.3 La agregación de puntaje (`sum(rd.puntos)`) pasa a unirse contra
      `intento_desafios` en vez de `nivel_desafios`
- [x] 3.4 Confirmar que el resto de la función (superación, estrellas,
      `progreso_usuario_nivel`, desbloqueo del camino) no cambia

## 4. Verificación manual contra el proyecto remoto

- [x] 4.1 `supabase db push` contra el proyecto remoto enlazado
- [x] 4.2 Nivel con `preguntas_por_partida` menor que el total asignado (2
      de 3, sobre el nivel real "Monumentos de Europa"): `iniciar_intento_nivel`
      devuelve 2 desafíos y `intento_desafios` registra esas mismas 2 filas
      para ese `intento_id`
- [x] 4.3 Responder esos 2 desafíos y llamar `cerrar_intento_nivel` →
      cierra correctamente, sin el error "2 de 3" del bug original
- [x] 4.4 Nivel con `preguntas_por_partida = NULL` y un desafío
      `activo = false` entre sus asignados: `iniciar_intento_nivel` no lo
      incluye, `intento_desafios` tampoco; responder el resto y cerrar
      funciona sin exigir el desafío inactivo
- [x] 4.5 Desactivar uno de los desafíos ya seleccionados de un intento en
      curso (después de `iniciar_intento_nivel`, antes de cerrarlo);
      responderlo igualmente y confirmar que el cierre procede con
      normalidad
- [x] 4.6 Insertar un `intento_nivel` directamente por SQL (con la policy
      `intentos_nivel_insert_own`, sin pasar por `iniciar_intento_nivel`) e
      intentar cerrarlo → falla con la excepción de "sin selección
      persistida" (3.2), no se cierra en falso con puntaje 0
- [x] 4.7 Repetir el caso ya cubierto en INT-79/INT-98 (nivel sin límite,
      todos los desafíos respondidos, "Banderas del Mundo 01") para
      confirmar que no hay regresión en el camino feliz existente
- [x] 4.8 Confirmar en `intento_desafios` que un usuario no puede leer ni
      insertar filas de un intento ajeno (policies de 1.3)

**Cómo se verificó**: los 8 casos de arriba se ejecutaron en una única
transacción contra el proyecto remoto enlazado (`supabase db query --linked`),
simulando dos jugadores reales ya existentes vía `set local role authenticated`
+ `request.jwt.claim.sub`, usando contenido real ya sembrado ("Monumentos de
Europa", 3 desafíos; "Banderas del Mundo 01", 1 desafío). Cada caso afirma su
resultado con `raise exception` si falla; la transacción entera termina en
`rollback`, así que no queda ningún rastro en el proyecto remoto. Se confirmó
además (con un `raise exception` deliberado fuera de la suite) que este canal
sí devuelve un error visible (exit code ≠ 0) cuando una aserción falla — la
ejecución real de la suite terminó con exit code 0 y sin errores, es decir,
las 8 aserciones pasaron.

## 5. Correcciones de la revisión adversarial (APROBADO CON HALLAZGOS)

- [x] 5.1 CTE `seleccion` marcada explícitamente `materialized` en
      `iniciar_intento_nivel` (ya se comportaba así por defecto al estar
      referenciada dos veces, pero queda explícito en vez de depender de
      ese comportamiento implícito)
- [x] 5.2 Mensaje de excepción de `cerrar_intento_nivel` (3.2) ampliado
      para cubrir también el caso de un nivel sin ningún desafío asignado,
      no solo "creado sin pasar por iniciar_intento_nivel"
- [x] 5.3 Ambas correcciones aplicadas al remoto (la migración ya estaba
      pushada; `create or replace function` re-ejecutado directamente vía
      `supabase db query --linked` para que el remoto coincida con el
      fichero corregido) y re-verificadas con la suite completa de la
      sección 4 (exit code 0, sin residuos)
