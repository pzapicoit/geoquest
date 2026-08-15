## 1. Migración: funciones de cálculo

- [x] 1.1 Crear migración `calcular_distancia_puntaje` en
      `backend/supabase/migrations/`
- [x] 1.2 Función `calcular_distancia_km(lat1, lng1, lat2, lng2) returns
      double precision` — Haversine, `immutable`, `security invoker`
- [x] 1.3 Función `calcular_puntaje(distancia_km) returns integer` —
      decaimiento lineal con `puntaje_maximo`/`distancia_umbral_km` como
      constantes documentadas, `immutable`, `security invoker`

## 2. Migración: RPC y trigger

- [x] 2.1 Función `responder_desafio(p_intento_id uuid, p_desafio_id uuid,
      p_lat_adivinada double precision, p_lng_adivinada double precision)
      returns respuestas_desafio` — `security definer`: valida a mano que
      `p_intento_id` pertenece a `auth.uid()`, lee `lat_real`/`lng_real` de
      `desafios`, calcula, inserta y devuelve la fila (sin `lat_real`/
      `lng_real` en la respuesta)
- [x] 2.2 `grant execute on function responder_desafio to authenticated`
- [x] 2.3 Función de trigger `security definer` que recalcula
      `distancia_km`/`puntos` de `new` a partir de `new.lat_adivinada`/
      `new.lng_adivinada` y el desafío de `new.desafio_id`
- [x] 2.4 `create trigger ... before insert on respuestas_desafio`
      ejecutando la función de 2.3

## 3. Verificación manual (casos límite)

- [x] 3.1 `supabase db push` contra el proyecto remoto enlazado
- [x] 3.2 Caso límite: llamar a `responder_desafio` con coordenada
      adivinada igual a la real de un desafío de prueba → distancia 0,
      puntaje máximo
- [x] 3.3 Caso límite: llamar con coordenada en las antípodas del desafío →
      distancia ~20000km, puntaje 0
- [x] 3.4 Caso de seguridad: llamar a `responder_desafio` con un
      `intento_id` que no pertenece al usuario autenticado → falla, no
      inserta fila
- [x] 3.5 Caso de integridad: `insert` directo en `respuestas_desafio` con
      `distancia_km`/`puntos` inventados → el trigger los sobrescribe con
      los valores calculados
- [x] 3.6 Confirmar que la respuesta de `responder_desafio` no expone
      `lat_real`/`lng_real` del desafío
