-- INT-74: esquema del juego (temáticas -> niveles -> desafíos -> progreso).
--
-- Sin RLS (INT-77), sin funciones/RPC (INT-78, INT-79, INT-87, INT-95,
-- INT-96) y sin trigger de creación de profiles (INT-75). Ver design.md de
-- openspec/changes/int-74-esquema-base-datos para el porqué de cada
-- decisión referenciada como D1-D7 en los comentarios.

-- 1.2 / 1.3 Tipos enumerados (D2)
create type rol_usuario as enum ('admin', 'jugador');
create type tipo_desafio as enum ('imagen', 'pregunta_texto', 'video');

-- 1.4 profiles (D1: id = auth.users.id, sin columna "usuario" propia)
create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nombre text not null,
  avatar_url text,
  role rol_usuario not null default 'jugador'
);

-- 1.5 tematicas
create table tematicas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  imagen_portada text not null,
  orden integer not null unique,
  estrellas_requeridas integer not null default 0 check (estrellas_requeridas >= 0),
  activo boolean not null default true
);

-- 2.1 niveles
create table niveles (
  id uuid primary key default gen_random_uuid(),
  tematica_id uuid not null references tematicas (id) on delete cascade,
  orden integer not null,
  puntaje_minimo_superar integer not null check (puntaje_minimo_superar >= 0),
  umbral_estrella_1 integer not null check (umbral_estrella_1 >= 0),
  umbral_estrella_2 integer not null,
  umbral_estrella_3 integer not null,
  activo boolean not null default true,
  unique (tematica_id, orden),
  check (puntaje_minimo_superar <= umbral_estrella_1),
  check (umbral_estrella_1 <= umbral_estrella_2),
  check (umbral_estrella_2 <= umbral_estrella_3)
);

-- 2.2 desafios: banco independiente, sin nivel fijo (D3: exclusividad por CHECK)
create table desafios (
  id uuid primary key default gen_random_uuid(),
  tipo tipo_desafio not null,
  imagen_url text,
  video_url text,
  texto_pregunta text,
  lat_real double precision not null check (lat_real between -90 and 90),
  lng_real double precision not null check (lng_real between -180 and 180),
  nombre_lugar text not null,
  activo boolean not null default true,
  check (
    (tipo = 'imagen' and imagen_url is not null and video_url is null and texto_pregunta is null)
    or (tipo = 'video' and video_url is not null and imagen_url is null and texto_pregunta is null)
    or (tipo = 'pregunta_texto' and texto_pregunta is not null and imagen_url is null and video_url is null)
  )
);

-- 2.3 nivel_desafios: asigna preguntas del banco a un nivel (D4, D5)
create table nivel_desafios (
  nivel_id uuid not null references niveles (id) on delete cascade,
  desafio_id uuid not null references desafios (id) on delete restrict,
  orden integer not null,
  primary key (nivel_id, desafio_id),
  unique (nivel_id, orden)
);

-- 3.1 intentos_nivel
create table intentos_nivel (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references profiles (id) on delete cascade,
  nivel_id uuid not null references niveles (id) on delete cascade,
  puntaje_total integer not null default 0 check (puntaje_total >= 0),
  superado boolean not null default false,
  estrellas_obtenidas smallint not null default 0 check (estrellas_obtenidas between 0 and 3),
  fecha timestamptz not null default now()
);

-- 3.2 respuestas_desafio (D5: restrict hacia desafios, conserva el historial)
create table respuestas_desafio (
  id uuid primary key default gen_random_uuid(),
  intento_id uuid not null references intentos_nivel (id) on delete cascade,
  desafio_id uuid not null references desafios (id) on delete restrict,
  lat_adivinada double precision not null check (lat_adivinada between -90 and 90),
  lng_adivinada double precision not null check (lng_adivinada between -180 and 180),
  distancia_km numeric not null check (distancia_km >= 0),
  puntos integer not null check (puntos >= 0),
  respondido_en timestamptz not null default now(),
  unique (intento_id, desafio_id)
);

-- 3.3 progreso_usuario_nivel (D6: fila creada de forma perezosa, no pre-sembrada)
create table progreso_usuario_nivel (
  usuario_id uuid not null references profiles (id) on delete cascade,
  nivel_id uuid not null references niveles (id) on delete cascade,
  superado boolean not null default false,
  mejor_puntaje integer not null default 0 check (mejor_puntaje >= 0),
  mejores_estrellas smallint not null default 0 check (mejores_estrellas between 0 and 3),
  desbloqueado boolean not null default false,
  actualizado_en timestamptz not null default now(),
  primary key (usuario_id, nivel_id)
);

-- 4.1 Índices sobre columnas de FK no cubiertas ya por una PK/unique
create index niveles_tematica_id_idx on niveles (tematica_id);
create index nivel_desafios_desafio_id_idx on nivel_desafios (desafio_id);
create index intentos_nivel_usuario_id_idx on intentos_nivel (usuario_id);
create index intentos_nivel_nivel_id_idx on intentos_nivel (nivel_id);
create index respuestas_desafio_intento_id_idx on respuestas_desafio (intento_id);
create index respuestas_desafio_desafio_id_idx on respuestas_desafio (desafio_id);
