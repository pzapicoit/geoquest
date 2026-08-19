-- INT-109: test de clasificacion_global / clasificacion_por_camino /
-- clasificacion_por_tematica. Ver D8 de design.md de
-- openspec/changes/int-109-clasificacion-global-camino-tematica para el
-- porque de la estrategia.
--
-- No hay pgTAP en el proyecto (ver architecture.md): script autonomo, no un
-- framework instalado. A diferencia de test_calcular_puntaje.sql (funcion
-- pura, sin datos), estas tres funciones dependen de auth.uid() y de datos
-- de varios jugadores, asi que todo el script:
--   1. Va envuelto en BEGIN/ROLLBACK -- nunca deja fixtures en el remoto,
--      ni siquiera si una asercion falla a mitad (el ROLLBACK final tambien
--      descarta lo que ya se hubiera insertado si el DO aborta antes).
--   2. Crea jugadores fixture via auth.users (el trigger on_auth_user_created
--      les crea su fila en profiles automaticamente).
--   3. Simula "ser" cada jugador con
--      set_config('request.jwt.claim.sub', <uuid>, true) -- la misma GUC que
--      lee auth.uid() en este proyecto (confirmado via
--      pg_get_functiondef('auth.uid()'::regprocedure)), sin necesitar un JWT
--      real.
--
-- Nota sobre datos preexistentes: este es un remoto compartido con datos
-- reales de partidas de desarrollo -- clasificacion_global agrega TODA la
-- tabla respuestas_desafio, no solo la de este test, asi que las
-- aserciones de esa funcion evitan depender de conteos totales o de
-- posiciones absolutas (podria haber jugadores reales por delante) y en su
-- lugar comprueban valores/relaciones propias de los jugadores fixture.
-- clasificacion_por_camino/clasificacion_por_tematica si se prueban con
-- conteos y posiciones exactas: usan un camino/tematica recien creados en
-- esta misma transaccion, que ningun dato preexistente puede referenciar.
--
-- Ejecutar con:
--   supabase db query --linked -f backend/supabase/tests/test_clasificacion.sql
begin;

do $$
declare
  -- Jugadores fixture. A domina en puntuacion; B, C empatan con A en
  -- camino_1 (tres vias, para probar que el desempate por usuario_id deja
  -- fuera del top fisico a exactamente uno de los tres); D nunca juega
  -- nada ("sin puntuacion agregable"); E responde pero fuera de tiempo
  -- (puntuacion 0, pero SI clasificado, a diferencia de D).
  v_jug_a uuid := 'aaaaaaaa-0000-0000-0000-000000000001';
  v_jug_b uuid := 'aaaaaaaa-0000-0000-0000-000000000002';
  v_jug_c uuid := 'aaaaaaaa-0000-0000-0000-000000000003';
  v_jug_d uuid := 'aaaaaaaa-0000-0000-0000-000000000004';
  v_jug_e uuid := 'aaaaaaaa-0000-0000-0000-000000000005';

  v_tematica uuid := 'bbbbbbbb-0000-0000-0000-000000000001';
  v_tematica_inexistente uuid := 'bbbbbbbb-9999-9999-9999-999999999999';
  v_camino_1 uuid := 'cccccccc-0000-0000-0000-000000000001';
  v_camino_2 uuid := 'cccccccc-0000-0000-0000-000000000002';
  v_camino_inexistente uuid := 'cccccccc-9999-9999-9999-999999999999';
  v_desafio_1 uuid := 'dddddddd-0000-0000-0000-000000000001';
  v_desafio_2 uuid := 'dddddddd-0000-0000-0000-000000000002';

  v_intento_a uuid;
  v_intento_b uuid;
  v_intento_c uuid;
  v_intento_e uuid;

  -- Escalares de scratch reutilizados en cada asercion.
  v_n integer;
  v_puntuacion bigint;
  v_puntuacion_int integer;
  v_posicion_a bigint;
  v_posicion_b bigint;
  v_posicion_c bigint;
  v_posicion_e bigint;
  v_posicion bigint;
  v_niveles integer;
  v_actual boolean;
  v_superado boolean;
  v_nombre text;
begin
  -- 1) Jugadores: auth.users dispara handle_new_user, que crea profiles con
  -- nombre aleatorio -- lo sobrescribimos para poder comprobar el paso a
  -- traves de nombre/avatar_url.
  insert into auth.users (id) values (v_jug_a), (v_jug_b), (v_jug_c), (v_jug_d), (v_jug_e);
  update profiles set nombre = 'Jugador A', avatar_url = 'a.png' where id = v_jug_a;
  update profiles set nombre = 'Jugador B', avatar_url = 'b.png' where id = v_jug_b;
  update profiles set nombre = 'Jugador C', avatar_url = 'c.png' where id = v_jug_c;
  update profiles set nombre = 'Jugador D', avatar_url = null where id = v_jug_d;
  update profiles set nombre = 'Jugador E', avatar_url = null where id = v_jug_e;

  -- 2) Tematica + dos paradas de camino (dificultad 'facil', ya seedeada en
  -- dificultad_defaults). Orden muy alto para no chocar con datos reales.
  insert into tematicas (id, nombre, imagen_portada, orden)
  values (v_tematica, 'Test INT-109', 'x.png', 900001);
  insert into camino (id, orden, tematica_id, dificultad, nombre)
  values
    (v_camino_1, 900001, v_tematica, 'facil', 'Test parada 1'),
    (v_camino_2, 900002, v_tematica, 'facil', 'Test parada 2');

  -- 3) progreso_usuario_nivel: se inserta directo (sin RPC), esta tabla no
  -- tiene trigger que recalcule sus columnas. Fuente de clasificacion_por_
  -- camino/tematica.
  --   A, B y C empatan en camino_1 (300, superado) -- tres jugadores para
  --   dos huecos de top: el desempate por usuario_id debe dejar a C fuera
  --   del top fisico aunque su posicion siga empatada con A/B.
  --   A ademas supera camino_2 (200) -- domina la tematica agregada (500).
  --   E jugo camino_1 sin superarlo (50).
  --   D no tiene ninguna fila -- "sin puntuacion agregable".
  insert into progreso_usuario_nivel (usuario_id, camino_id, superado, mejor_puntaje, desbloqueado)
  values
    (v_jug_a, v_camino_1, true, 300, true),
    (v_jug_a, v_camino_2, true, 200, true),
    (v_jug_b, v_camino_1, true, 300, true),
    (v_jug_c, v_camino_1, true, 300, true),
    (v_jug_e, v_camino_1, false, 50, true);

  -- 4) respuestas_desafio: fuente de clasificacion_global. El trigger
  -- respuestas_desafio_calcular_antes_de_insertar RECALCULA puntos/
  -- distancia_km siempre -- no vale insertar "puntos" a mano. Con
  -- lat_adivinada = lat_real (0,0) la distancia es 0 y, al no existir fila
  -- en intento_desafios (sin mostrado_en), el trigger trata el tiempo como
  -- agotado -> bonus de rapidez 0 -> puntos = calcular_puntaje_por_distancia(0)
  -- = 5000 exactos (ver test_calcular_puntaje.sql). Con lat/lng NULL
  -- (sin pin) el trigger deja puntos = 0 exactos, sin pasar por la curva.
  insert into desafios (id, tipo, texto_pregunta, lat_real, lng_real, nombre_lugar, tematica_id, dificultad)
  values
    (v_desafio_1, 'pregunta_texto', 'Test 1', 0, 0, 'Test lugar 1', v_tematica, 'facil'),
    (v_desafio_2, 'pregunta_texto', 'Test 2', 0, 0, 'Test lugar 2', v_tematica, 'facil');

  insert into intentos_nivel (id, usuario_id, camino_id) values (gen_random_uuid(), v_jug_a, v_camino_1) returning id into v_intento_a;
  insert into intentos_nivel (id, usuario_id, camino_id) values (gen_random_uuid(), v_jug_b, v_camino_1) returning id into v_intento_b;
  insert into intentos_nivel (id, usuario_id, camino_id) values (gen_random_uuid(), v_jug_c, v_camino_1) returning id into v_intento_c;
  insert into intentos_nivel (id, usuario_id, camino_id) values (gen_random_uuid(), v_jug_e, v_camino_1) returning id into v_intento_e;

  -- A acierta los dos desafios: 5000 + 5000 = 10000
  insert into respuestas_desafio (intento_id, desafio_id, lat_adivinada, lng_adivinada)
  values (v_intento_a, v_desafio_1, 0, 0), (v_intento_a, v_desafio_2, 0, 0);
  -- B y C aciertan solo el primero: 5000 cada uno (empate)
  insert into respuestas_desafio (intento_id, desafio_id, lat_adivinada, lng_adivinada)
  values (v_intento_b, v_desafio_1, 0, 0);
  insert into respuestas_desafio (intento_id, desafio_id, lat_adivinada, lng_adivinada)
  values (v_intento_c, v_desafio_1, 0, 0);
  -- E responde sin pin (tiempo agotado): puntos = 0, pero SI tiene fila
  insert into respuestas_desafio (intento_id, desafio_id, lat_adivinada, lng_adivinada)
  values (v_intento_e, v_desafio_1, null, null);

  -- ======================================================================
  -- clasificacion_global (dataset compartido con datos reales -- ver nota
  -- de cabecera: solo se comprueban valores/relaciones propias, nunca
  -- conteos totales ni posiciones absolutas)
  -- ======================================================================

  perform set_config('request.jwt.claim.sub', v_jug_a::text, true);

  -- Suma correcta, niveles_superados agregado y nombre pasando a traves de
  -- profiles. Exactamente una fila para A (sin duplicados).
  select count(*) into v_n from clasificacion_global(50) t where t.usuario_id = v_jug_a;
  if v_n <> 1 then
    raise exception 'A deberia aparecer exactamente una vez en clasificacion_global, aparecio % veces', v_n;
  end if;

  select t.puntuacion, t.posicion, t.es_usuario_actual, t.niveles_superados, t.nombre
  into v_puntuacion, v_posicion_a, v_actual, v_niveles, v_nombre
  from clasificacion_global(50) t
  where t.usuario_id = v_jug_a;

  if v_puntuacion <> 10000 or v_posicion_a is null or not v_actual or v_niveles <> 2 or v_nombre <> 'Jugador A' then
    raise exception 'fila de A en clasificacion_global incorrecta: puntuacion=%, posicion=%, actual=%, niveles=%, nombre=%',
      v_puntuacion, v_posicion_a, v_actual, v_niveles, v_nombre;
  end if;

  -- Empate: B y C tienen la misma puntuacion (5000) y deben compartir
  -- posicion, y ambos por detras de A (que sumo el doble).
  select t.posicion into v_posicion_b from clasificacion_global(50) t where t.usuario_id = v_jug_b;
  select t.posicion into v_posicion_c from clasificacion_global(50) t where t.usuario_id = v_jug_c;
  if v_posicion_b <> v_posicion_c then
    raise exception 'B y C deberian empatar en posicion en clasificacion_global, dieron % y %', v_posicion_b, v_posicion_c;
  end if;
  if v_posicion_b <= v_posicion_a then
    raise exception 'B/C (5000 puntos) deberian quedar por detras de A (10000 puntos) en clasificacion_global';
  end if;

  -- E respondio (puntos 0) y SI aparece clasificado, distinto de "sin
  -- puntuacion agregable": posicion real (no null), y por detras de B/C.
  select t.puntuacion, t.posicion into v_puntuacion, v_posicion_e from clasificacion_global(50) t where t.usuario_id = v_jug_e;
  if v_puntuacion <> 0 or v_posicion_e is null then
    raise exception 'E deberia aparecer clasificado con puntuacion 0 y una posicion real (no NULL), dio puntuacion=% posicion=%', v_puntuacion, v_posicion_e;
  end if;
  if v_posicion_e <= v_posicion_b then
    raise exception 'E (0 puntos) deberia quedar por detras de B/C (5000 puntos) en clasificacion_global';
  end if;

  -- Fila propia siempre presente y sin duplicar, dentro o fuera del top
  -- fisico (con datos reales de por medio no se puede saber si A/E/D caen
  -- dentro del top-2 real, asi que solo se exige presencia unica).
  perform set_config('request.jwt.claim.sub', v_jug_e::text, true);
  select count(*) into v_n from clasificacion_global(2) t where t.usuario_id = v_jug_e;
  if v_n <> 1 then
    raise exception 'la fila propia de E en clasificacion_global(2) deberia aparecer exactamente una vez, aparecio % veces', v_n;
  end if;
  select t.es_usuario_actual, t.posicion into v_actual, v_posicion from clasificacion_global(2) t where t.usuario_id = v_jug_e;
  if not v_actual or v_posicion <> v_posicion_e then
    raise exception 'la fila propia de E en clasificacion_global(2) deberia llevar es_usuario_actual=true y la misma posicion que en el top completo';
  end if;

  -- Jugador sin ninguna puntuacion agregable: D nunca jugo, su fila debe
  -- llevar puntuacion 0 y posicion NULL (no compite), no una posicion
  -- inventada -- esto SI es independiente de los datos reales.
  perform set_config('request.jwt.claim.sub', v_jug_d::text, true);
  select count(*) into v_n from clasificacion_global(2) t where t.usuario_id = v_jug_d;
  if v_n <> 1 then
    raise exception 'la fila propia sintetica de D en clasificacion_global(2) deberia aparecer exactamente una vez, aparecio % veces', v_n;
  end if;
  select t.puntuacion, t.posicion, t.es_usuario_actual, t.niveles_superados
  into v_puntuacion, v_posicion, v_actual, v_niveles
  from clasificacion_global(2) t where t.usuario_id = v_jug_d;
  if v_puntuacion <> 0 or v_posicion is not null or not v_actual or v_niveles <> 0 then
    raise exception 'la fila sintetica de D en clasificacion_global deberia ser puntuacion=0, posicion=NULL, niveles=0, dio puntuacion=% posicion=% niveles=%',
      v_puntuacion, v_posicion, v_niveles;
  end if;

  -- Limite acotado por debajo (clamp a minimo 1): no debe lanzar excepcion
  -- con limite <= 0 (una LIMIT negativa sin clamp es un error de Postgres).
  -- (El tope superior de 100 se apoya en el mismo least()/greatest() ya
  -- usado aqui -- probarlo con 100+ jugadores reales excede el alcance de
  -- este test y se deja verificado por lectura del codigo, ver design.md D3.)
  select count(*) into v_n from clasificacion_global(0) t;
  if v_n < 1 then
    raise exception 'clasificacion_global(0) no deberia lanzar excepcion ni devolver el conjunto vacio (limite efectivo minimo 1), dio % filas', v_n;
  end if;
  select count(*) into v_n from clasificacion_global(-5) t;
  if v_n < 1 then
    raise exception 'clasificacion_global(-5) no deberia lanzar excepcion ni devolver el conjunto vacio (limite efectivo minimo 1), dio % filas', v_n;
  end if;

  raise notice 'clasificacion_global: casos OK';

  -- ======================================================================
  -- clasificacion_por_camino (camino_1 es nuevo en esta transaccion: nadie
  -- preexistente puede tener progreso ahi, conteos y posiciones exactas)
  -- ======================================================================

  -- A, B y C empatan a 300 -- tres jugadores para dos huecos de top. Se
  -- llama como E (ajeno al empate) para comprobar el desempate fisico sin
  -- que la regla "la fila propia siempre aparece" (D4) enmascare el
  -- resultado.
  perform set_config('request.jwt.claim.sub', v_jug_e::text, true);

  select count(*) into v_n from clasificacion_por_camino(v_camino_1, 2) t;
  if v_n <> 3 then
    raise exception 'clasificacion_por_camino(camino_1, 2) como E deberia devolver 3 filas (2 del top empatado + fila propia de E), dio %', v_n;
  end if;
  select count(*) into v_n from clasificacion_por_camino(v_camino_1, 2) t where t.usuario_id = v_jug_a;
  if v_n <> 1 then
    raise exception 'A (uuid menor) deberia entrar en el top fisico de clasificacion_por_camino(camino_1, 2)';
  end if;
  select count(*) into v_n from clasificacion_por_camino(v_camino_1, 2) t where t.usuario_id = v_jug_b;
  if v_n <> 1 then
    raise exception 'B (uuid intermedio) deberia entrar en el top fisico de clasificacion_por_camino(camino_1, 2)';
  end if;
  select count(*) into v_n from clasificacion_por_camino(v_camino_1, 2) t where t.usuario_id = v_jug_c;
  if v_n <> 0 then
    raise exception 'C (uuid mayor) NO deberia entrar en el top fisico de clasificacion_por_camino(camino_1, 2) -- el desempate por usuario_id deja fuera al de uuid mayor';
  end if;

  -- A y B, aunque solo B entra en el top fisico, comparten posicion=1 con
  -- C (rank() se calcula sobre TODO el conjunto, no solo lo devuelto).
  select t.posicion into v_posicion_a from clasificacion_por_camino(v_camino_1, 2) t where t.usuario_id = v_jug_a;
  select t.posicion into v_posicion_b from clasificacion_por_camino(v_camino_1, 2) t where t.usuario_id = v_jug_b;
  if v_posicion_a <> 1 or v_posicion_b <> 1 then
    raise exception 'A y B deberian tener posicion=1 en clasificacion_por_camino(camino_1), dieron % y %', v_posicion_a, v_posicion_b;
  end if;

  -- La fila propia de C (excluido del top fisico) SI debe aparecer cuando
  -- C mismo llama, con su posicion real (1, empatada) y superado=true.
  perform set_config('request.jwt.claim.sub', v_jug_c::text, true);
  select count(*) into v_n from clasificacion_por_camino(v_camino_1, 2) t;
  if v_n <> 3 then
    raise exception 'clasificacion_por_camino(camino_1, 2) como C deberia devolver 3 filas (top fisico de 2 + fila propia de C), dio %', v_n;
  end if;
  select t.puntuacion, t.superado, t.posicion, t.es_usuario_actual
  into v_puntuacion_int, v_superado, v_posicion, v_actual
  from clasificacion_por_camino(v_camino_1, 2) t
  where t.usuario_id = v_jug_c;
  if v_puntuacion_int <> 300 or not v_superado or v_posicion <> 1 or not v_actual then
    raise exception 'fila propia de C en clasificacion_por_camino incorrecta: puntuacion=%, superado=%, posicion=%, actual=%',
      v_puntuacion_int, v_superado, v_posicion, v_actual;
  end if;

  -- D no jugo camino_1: fila sintetica con puntuacion 0, superado false,
  -- posicion NULL.
  perform set_config('request.jwt.claim.sub', v_jug_d::text, true);
  select t.puntuacion, t.superado, t.posicion, t.es_usuario_actual
  into v_puntuacion_int, v_superado, v_posicion, v_actual
  from clasificacion_por_camino(v_camino_1, 2) t
  where t.usuario_id = v_jug_d;
  if v_puntuacion_int <> 0 or v_superado or v_posicion is not null or not v_actual then
    raise exception 'fila sintetica de D en clasificacion_por_camino incorrecta: puntuacion=%, superado=%, posicion=%, actual=%',
      v_puntuacion_int, v_superado, v_posicion, v_actual;
  end if;

  -- camino_id inexistente: el ranking sale vacio, sin excepcion; solo
  -- queda la fila propia sintetica de quien llama.
  select count(*) into v_n from clasificacion_por_camino(v_camino_inexistente, 50) t;
  if v_n <> 1 then
    raise exception 'clasificacion_por_camino con camino_id inexistente deberia devolver solo la fila propia sintetica, dio % filas', v_n;
  end if;

  raise notice 'clasificacion_por_camino: casos OK';

  -- ======================================================================
  -- clasificacion_por_tematica (misma garantia de aislamiento: tematica
  -- recien creada)
  -- ======================================================================

  -- A suma las dos paradas de la tematica (300+200=500, 2 superados) y
  -- domina en solitario; B y C solo tienen camino_1 (300, 1 superado cada
  -- uno) y empatan entre si.
  perform set_config('request.jwt.claim.sub', v_jug_c::text, true);

  select count(*) into v_n from clasificacion_por_tematica(v_tematica, 2) t;
  if v_n <> 3 then
    raise exception 'clasificacion_por_tematica(tematica, 2) como C deberia devolver 3 filas (top de 2 + fila propia), dio %', v_n;
  end if;

  select t.puntuacion, t.niveles_superados, t.posicion
  into v_puntuacion, v_niveles, v_posicion
  from clasificacion_por_tematica(v_tematica, 2) t
  where t.usuario_id = v_jug_a;
  if v_puntuacion <> 500 or v_niveles <> 2 or v_posicion <> 1 then
    raise exception 'fila de A en clasificacion_por_tematica incorrecta: puntuacion=%, niveles=%, posicion=%', v_puntuacion, v_niveles, v_posicion;
  end if;

  select t.puntuacion, t.niveles_superados, t.posicion, t.es_usuario_actual
  into v_puntuacion, v_niveles, v_posicion, v_actual
  from clasificacion_por_tematica(v_tematica, 2) t
  where t.usuario_id = v_jug_c;
  if v_puntuacion <> 300 or v_niveles <> 1 or v_posicion <> 2 or not v_actual then
    raise exception 'fila propia de C en clasificacion_por_tematica incorrecta: puntuacion=%, niveles=%, posicion=%, actual=%',
      v_puntuacion, v_niveles, v_posicion, v_actual;
  end if;

  -- B empata con C (mismos 300/1 superado): misma posicion.
  select t.posicion into v_posicion_b from clasificacion_por_tematica(v_tematica, 2) t where t.usuario_id = v_jug_b;
  if v_posicion_b <> v_posicion then
    raise exception 'B y C deberian empatar en posicion en clasificacion_por_tematica, dieron % y %', v_posicion_b, v_posicion;
  end if;

  -- tematica_id inexistente: el ranking sale vacio, sin excepcion; solo
  -- la fila propia sintetica de D.
  perform set_config('request.jwt.claim.sub', v_jug_d::text, true);
  select count(*), coalesce(sum(t.puntuacion), -1), bool_and(t.posicion is null)
  into v_n, v_puntuacion, v_actual
  from clasificacion_por_tematica(v_tematica_inexistente, 50) t;
  if v_n <> 1 or v_puntuacion <> 0 or not v_actual then
    raise exception 'clasificacion_por_tematica con tematica_id inexistente deberia devolver solo la fila propia sintetica (puntuacion=0, posicion=NULL), dio % filas, suma=%', v_n, v_puntuacion;
  end if;

  raise notice 'clasificacion_por_tematica: casos OK';
  raise notice 'test_clasificacion: todos los casos OK';
end $$;

rollback;
