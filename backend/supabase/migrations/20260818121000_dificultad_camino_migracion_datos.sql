-- INT-106: backfill de datos y repunteo de FKs de nivel_id -> camino_id.
-- Segunda de cuatro migraciones. Ver design.md D1b/D5; los pasos marcados
-- "no estaba en design.md" son casos de borde que aparecieron al escribir
-- esta migracion y se resuelven aqui con el mismo criterio de D1b
-- (backfill lo que se pueda deducir, avisar sin bloquear el despliegue
-- por lo que no se pueda).

-- 2.1 (D1b) backfill desafios.tematica_id desde su primera asignacion en
-- nivel_desafios: el nivel de menor `orden` entre sus asignaciones, como
-- desempate deterministico cuando un desafio esta en niveles de tematicas
-- distintas.
with primera_asignacion as (
  select nd.desafio_id,
         n.tematica_id,
         row_number() over (partition by nd.desafio_id order by n.orden) as prioridad
  from nivel_desafios nd
  join niveles n on n.id = nd.nivel_id
)
update desafios d
set tematica_id = pa.tematica_id
from primera_asignacion pa
where pa.desafio_id = d.id
  and pa.prioridad = 1;

-- Aviso de auditoria (no bloqueante): desafios cuyas asignaciones abarcaban
-- mas de una tematica distinta se quedaron con la de menor orden de nivel
-- (arriba) -- esto solo deja constancia de cuales fueron, por si el
-- resultado no es el esperado.
do $$
declare
  v_multi integer;
begin
  select count(*) into v_multi
  from (
    select nd.desafio_id
    from nivel_desafios nd
    join niveles n on n.id = nd.nivel_id
    group by nd.desafio_id
    having count(distinct n.tematica_id) > 1
  ) sub;

  if v_multi > 0 then
    raise warning 'INT-106: % desafio(s) tenian asignaciones a niveles de mas de una tematica distinta -- se quedaron con la tematica del nivel de menor orden, revisar manualmente si el resultado no es el esperado', v_multi;
  end if;
end $$;

-- Aviso de auditoria (no bloqueante): desafios sin ninguna asignacion previa
-- en nivel_desafios no tienen de donde inferir su tematica y quedan sin
-- tematica_id -- se desactivan para que no puedan entrar en ningun pool
-- hasta que un admin les asigne tematica manualmente desde el panel.
do $$
declare
  v_huerfanos integer;
  v_ids text;
begin
  select count(*), string_agg(id::text, ', ')
  into v_huerfanos, v_ids
  from desafios
  where tematica_id is null;

  if v_huerfanos > 0 then
    raise warning 'INT-106: % desafio(s) sin ninguna asignacion previa en nivel_desafios quedan sin tematica_id y se desactivan -- requieren asignacion manual de tematica desde el panel antes de reactivarse: %',
      v_huerfanos, v_ids;
    update desafios set activo = false where tematica_id is null;
  end if;
end $$;

-- 2.2 (D4/D1b) tras el backfill: dificultad ya no necesita el default de la
-- migracion anterior (question-difficulty exige el valor explicito en toda
-- alta nueva). tematica_id pasa a not null salvo que queden huerfanos sin
-- resolver (aviso arriba) -- en ese caso se deja nullable para no bloquear
-- el despliegue; forzar not null en una migracion posterior una vez el
-- admin los haya resuelto.
alter table desafios alter column dificultad drop default;

do $$
begin
  if not exists (select 1 from desafios where tematica_id is null) then
    execute 'alter table desafios alter column tematica_id set not null';
  else
    raise warning 'INT-106: desafios.tematica_id se deja NULLABLE por los huerfanos de arriba -- forzar NOT NULL en una migracion posterior tras resolverlos';
  end if;
end $$;

-- 2.3 (D5) backfill de camino desde cada nivel referenciado por camino.
-- tematica_id es deterministico (niveles.tematica_id es not null desde
-- INT-74) y dificultad fija a 'normal' (consecuencia de que todas las
-- preguntas existentes migran a 'normal' arriba); los valores de
-- configuracion del nivel se copian como OVERRIDES EXPLICITOS -- el
-- comportamiento no cambia el dia del despliegue.
update camino c
set tematica_id = n.tematica_id,
    dificultad = 'normal',
    nombre = n.nombre,
    activo = n.activo,
    preguntas_por_partida = n.preguntas_por_partida,
    segundos_por_desafio = n.segundos_por_desafio,
    puntaje_minimo_superar = n.puntaje_minimo_superar,
    umbral_estrella_2 = n.umbral_estrella_2,
    umbral_estrella_3 = n.umbral_estrella_3
from niveles n
where n.id = c.nivel_id;

alter table camino
  alter column tematica_id set not null,
  alter column dificultad set not null;

-- 2.4 (no estaba en design.md: caso de borde encontrado al escribir esta
-- migracion) un nivel puede tener historial de juego (intentos_nivel /
-- progreso_usuario_nivel) sin tener ninguna fila en `camino` -- por
-- ejemplo si se quito del camino con "Quitar del camino"
-- (panel-path-listing) despues de haberse jugado. Hoy ese historial ya es
-- invisible para el jugador (camino_jugador solo muestra filas de
-- `camino`, nunca niveles sueltos) y no participa en el desbloqueo
-- (cerrar_intento_nivel solo suma estrellas de niveles que SI estan en
-- camino). Migrarlo a un camino_id inventado resucitaria esas estrellas en
-- el calculo de desbloqueo, cambiando comportamiento; dejarlo sin
-- camino_id preserva el dato (no se borra nada) y mantiene exactamente la
-- misma invisibilidad/no-participacion que tiene hoy. Por eso camino_id se
-- deja NULLABLE en vez de reproducir el not null que tenia nivel_id.
alter table intentos_nivel add column camino_id uuid;
alter table progreso_usuario_nivel add column camino_id uuid;

with mapeo as (
  select nivel_id, id as camino_id,
         row_number() over (partition by nivel_id order by orden) as prioridad
  from camino
  where nivel_id is not null
)
update intentos_nivel it
set camino_id = m.camino_id
from mapeo m
where m.nivel_id = it.nivel_id
  and m.prioridad = 1;

with mapeo as (
  select nivel_id, id as camino_id,
         row_number() over (partition by nivel_id order by orden) as prioridad
  from camino
  where nivel_id is not null
)
update progreso_usuario_nivel pun
set camino_id = m.camino_id
from mapeo m
where m.nivel_id = pun.nivel_id
  and m.prioridad = 1;

-- Aviso de auditoria (no bloqueante): niveles con mas de una posicion en el
-- camino antiguo (el panel ya lo evitaba por UI, pero no habia constraint
-- de base de datos que lo impidiera) se repuntaron a la posicion de menor
-- `orden`.
do $$
declare
  v_multi integer;
begin
  select count(*) into v_multi
  from (
    select nivel_id from camino where nivel_id is not null
    group by nivel_id having count(*) > 1
  ) sub;

  if v_multi > 0 then
    raise warning 'INT-106: % nivel(es) tenian mas de una posicion en el camino antiguo -- intentos_nivel/progreso_usuario_nivel se repuntaron a la de menor orden, revisar manualmente si el resultado no es el esperado', v_multi;
  end if;
end $$;

-- Aviso de auditoria (no bloqueante): historial huerfano (nivel sin ninguna
-- posicion en camino) que queda con camino_id NULL, ver comentario de 2.4.
do $$
declare
  v_intentos_huerfanos integer;
  v_progreso_huerfano integer;
begin
  select count(*) into v_intentos_huerfanos from intentos_nivel where camino_id is null;
  select count(*) into v_progreso_huerfano from progreso_usuario_nivel where camino_id is null;

  if v_intentos_huerfanos > 0 or v_progreso_huerfano > 0 then
    raise warning 'INT-106: % fila(s) de intentos_nivel y % de progreso_usuario_nivel quedan con camino_id NULL (historial de niveles que nunca estuvieron o ya no estan en el camino) -- se conservan pero no participan en el calculo de desbloqueo, igual que hoy',
      v_intentos_huerfanos, v_progreso_huerfano;
  end if;
end $$;

-- FK a camino(id) sin exigir not null (D anterior). on delete cascade igual
-- que la FK a niveles que sustituye.
alter table intentos_nivel
  add constraint intentos_nivel_camino_id_fkey foreign key (camino_id) references camino (id) on delete cascade;

create index intentos_nivel_camino_id_idx on intentos_nivel (camino_id);
drop index if exists intentos_nivel_nivel_id_idx;
alter table intentos_nivel drop column nivel_id;

-- progreso_usuario_nivel.nivel_id y camino.nivel_id NO se dropean aqui: la
-- vista camino_jugador (20260817120100) todavia los referencia (`c.nivel_id`,
-- `pun.nivel_id`) en este punto de la migracion, y DROP COLUMN fallaria por
-- la dependencia de la vista (a diferencia de intentos_nivel.nivel_id, que
-- ningun objeto con dependencia trackeada usa). Ese repunteo de PK/columna
-- se hace en 20260818122000, justo despues de recrear camino_jugador sin
-- esas columnas.
