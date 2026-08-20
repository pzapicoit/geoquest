-- INT-119: corrige usar_comodin/conceder_comodin_por_anuncio -- se
-- declararon "security invoker" por error, pero comodines_inventario y
-- comodines_concesiones_anuncio deliberadamente no tienen policy de
-- insert/update para authenticated (ver 20260820090000): la unica via de
-- escritura debe ser estas funciones, no REST directo. Con security
-- invoker, sus propios update/insert quedaban sujetos a RLS y fallaban con
-- "new row violates row-level security policy" -- confirmado contra el
-- proyecto remoto. security definer + los filtros por auth.uid() ya
-- presentes en el cuerpo (sin cambios) siguen acotando cada operacion al
-- usuario que llama.

create or replace function usar_comodin(p_intento_id uuid, p_desafio_id uuid, p_tipo tipo_comodin)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pais text;
  v_lat double precision;
  v_lng double precision;
  v_actualizado integer;
begin
  if not exists (
    select 1
    from intentos_nivel it
    join intento_desafios idf on idf.intento_id = it.id
    where it.id = p_intento_id
      and it.usuario_id = auth.uid()
      and idf.desafio_id = p_desafio_id
      and not exists (
        select 1 from respuestas_desafio rd
        where rd.intento_id = p_intento_id and rd.desafio_id = p_desafio_id
      )
  ) then
    raise exception 'intento_o_desafio_invalido';
  end if;

  if p_tipo = 'pais' then
    select d.pais into v_pais from desafios d where d.id = p_desafio_id;
    if v_pais is null then
      raise exception 'pais_no_disponible';
    end if;
  end if;

  update comodines_inventario
  set cantidad = cantidad - 1
  where usuario_id = auth.uid() and tipo = p_tipo and cantidad > 0
  returning cantidad into v_actualizado;

  if v_actualizado is null then
    raise exception 'sin_comodines_disponibles';
  end if;

  update intentos_nivel
  set comodin_usado = p_tipo
  where id = p_intento_id and usuario_id = auth.uid() and comodin_usado is null;

  if not found then
    raise exception 'comodin_ya_usado_en_este_intento';
  end if;

  case p_tipo
    when 'tiempo' then
      return jsonb_build_object('tipo', p_tipo, 'extra_segundos', 15);
    when 'pais' then
      return jsonb_build_object('tipo', p_tipo, 'pais', v_pais);
    when 'km1000', 'km500' then
      select d.lat_real, d.lng_real into v_lat, v_lng from desafios d where d.id = p_desafio_id;
      return jsonb_build_object(
        'tipo', p_tipo,
        'lat', v_lat,
        'lng', v_lng,
        'radio_km', case p_tipo when 'km1000' then 1000 else 500 end
      );
  end case;
end;
$$;

create or replace function conceder_comodin_por_anuncio(p_tope_diario integer default 5)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tipo tipo_comodin;
  v_tipos constant tipo_comodin[] := array['tiempo', 'pais', 'km1000', 'km500'];
  v_concedidas_hoy integer;
begin
  insert into comodines_concesiones_anuncio (usuario_id, fecha, cantidad)
  values (auth.uid(), current_date, 0)
  on conflict (usuario_id, fecha) do nothing;

  select cantidad into v_concedidas_hoy
  from comodines_concesiones_anuncio
  where usuario_id = auth.uid() and fecha = current_date
  for update;

  if v_concedidas_hoy >= p_tope_diario then
    raise exception 'tope_diario_alcanzado';
  end if;

  v_tipo := v_tipos[1 + floor(random() * array_length(v_tipos, 1))::int];

  update comodines_inventario
  set cantidad = cantidad + 1
  where usuario_id = auth.uid() and tipo = v_tipo;

  update comodines_concesiones_anuncio
  set cantidad = cantidad + 1
  where usuario_id = auth.uid() and fecha = current_date;

  return jsonb_build_object('tipo', v_tipo);
end;
$$;
