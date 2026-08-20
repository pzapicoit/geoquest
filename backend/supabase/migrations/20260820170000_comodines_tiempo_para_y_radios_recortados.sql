-- INT-119 delta-1: feedback tras testing local en dispositivo.
-- - "tiempo" deja de dar +15s: ahora el jugador se queda sin limite de
--   tiempo para esa pregunta (la app llama a CuentaAtrasDeDesafio.parar(),
--   no a extender()) -- el payload ya no necesita extra_segundos.
-- - Los radios de km1000/km500 se recortan: 1000->500, 500->150. Solo el
--   literal numerico cambia, los identificadores del enum no se tocan.

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
      -- D1/D2 del delta: ya no hay duracion que comunicar, el cliente para
      -- el cronometro por completo.
      return jsonb_build_object('tipo', p_tipo);
    when 'pais' then
      return jsonb_build_object('tipo', p_tipo, 'pais', v_pais);
    when 'km1000', 'km500' then
      select d.lat_real, d.lng_real into v_lat, v_lng from desafios d where d.id = p_desafio_id;
      return jsonb_build_object(
        'tipo', p_tipo,
        'lat', v_lat,
        'lng', v_lng,
        'radio_km', case p_tipo when 'km1000' then 500 else 150 end
      );
  end case;
end;
$$;
