-- INT-106: dificultad fija por pregunta y valores por defecto por
-- dificultad, sustituyendo la curacion manual de niveles/nivel_desafios.
-- Ver design.md de openspec/changes/int-106-rediseno-tematicas-dificultad-camino
-- para el porque de cada decision referenciada como D1-D7/D1b en los
-- comentarios. Esta es la primera de cuatro migraciones (esquema nuevo,
-- sin backfill todavia -- eso llega en la siguiente).

-- 1.1 (D3) catalogo cerrado de dificultad. No editable por el admin: no hay
-- RPC ni policy que permita anadir/quitar valores.
create type dificultad as enum ('facil', 'normal', 'intermedio', 'dificil', 'muy_dificil');

-- 1.2 (D3) valores por defecto por dificultad -- una fila por valor,
-- sembradas aqui mismo. Ver proposal.md para la justificacion de las
-- cifras (base = preguntas_por_partida x 5000 sin bonus de rapidez, %
-- exigido creciendo geometricamente por dificultad).
create table dificultad_defaults (
  dificultad dificultad primary key,
  preguntas_por_partida integer not null check (preguntas_por_partida > 0),
  segundos_por_desafio integer not null check (segundos_por_desafio > 0),
  puntaje_minimo_superar integer not null check (puntaje_minimo_superar >= 0),
  umbral_estrella_2 integer not null,
  umbral_estrella_3 integer not null,
  check (puntaje_minimo_superar <= umbral_estrella_2),
  check (umbral_estrella_2 <= umbral_estrella_3)
);

insert into dificultad_defaults
  (dificultad, preguntas_por_partida, segundos_por_desafio, puntaje_minimo_superar, umbral_estrella_2, umbral_estrella_3)
values
  ('facil', 8, 90, 18000, 29000, 36700),
  ('normal', 8, 75, 21200, 30600, 37180),
  ('intermedio', 6, 60, 18600, 24300, 28290),
  ('dificil', 6, 45, 21600, 25800, 28740),
  ('muy_dificil', 5, 30, 21250, 23125, 24438);

-- Catalogo fijo: nunca se borra ninguna fila (difficulty-defaults). No hay
-- RPC de alta/baja de dificultades, asi que solo hace falta impedir el
-- borrado -- el propio enum ya impide un insert con un valor no valido, y
-- la PK ya impide duplicar uno existente.
create function dificultad_defaults_bloquear_borrado()
returns trigger
language plpgsql
as $$
begin
  raise exception 'dificultad_defaults es un catalogo fijo: no se puede borrar la fila %', old.dificultad;
end;
$$;

create trigger dificultad_defaults_no_delete
before delete on dificultad_defaults
for each row execute function dificultad_defaults_bloquear_borrado();

-- 1.3 (D4) desafios.dificultad: default temporal 'normal' solo para que la
-- siguiente migracion pueda backfillear las filas existentes sin violar
-- el not null; se quita el default en cuanto ese backfill termina, para
-- que toda alta nueva exija el valor explicito (question-difficulty).
alter table desafios
  add column dificultad dificultad not null default 'normal';

-- 1.4 (D1b) desafios.tematica_id: no existia -- hoy la tematica de un
-- desafio se deducia indirectamente via nivel_desafios -> niveles. Nullable
-- en esta migracion; se backfillea y se intenta poner not null en la
-- siguiente (puede quedar nullable si aparecen huerfanos sin ninguna
-- asignacion previa, ver esa migracion).
alter table desafios
  add column tematica_id uuid references tematicas (id) on delete restrict;

create index desafios_tematica_id_idx on desafios (tematica_id);

-- 1.5 (D1) camino absorbe la configuracion que hoy vive en niveles: cada
-- posicion pasa a apuntar a una pareja tematica_id+dificultad (en vez de a
-- un nivel_id curado) y gana nombre/activo (antes en niveles) mas overrides
-- opcionales que sustituyen a dificultad_defaults cuando estan rellenos.
-- Todas nullable en esta migracion; tematica_id/dificultad se backfillean y
-- se ponen not null en la siguiente (aqui no hay caso de huerfanos posible:
-- camino.nivel_id ya era not null y niveles.tematica_id tambien).
alter table camino
  add column tematica_id uuid references tematicas (id) on delete cascade,
  add column dificultad dificultad,
  add column nombre text,
  add column activo boolean not null default true,
  add column preguntas_por_partida integer check (preguntas_por_partida > 0),
  add column segundos_por_desafio integer check (segundos_por_desafio > 0),
  add column puntaje_minimo_superar integer check (puntaje_minimo_superar >= 0),
  add column umbral_estrella_2 integer,
  add column umbral_estrella_3 integer,
  add check (puntaje_minimo_superar is null or umbral_estrella_2 is null or puntaje_minimo_superar <= umbral_estrella_2),
  add check (umbral_estrella_2 is null or umbral_estrella_3 is null or umbral_estrella_2 <= umbral_estrella_3);

create index camino_tematica_id_dificultad_idx on camino (tematica_id, dificultad);
