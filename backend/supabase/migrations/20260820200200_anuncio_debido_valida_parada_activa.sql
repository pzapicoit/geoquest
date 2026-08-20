-- INT-117 (hallazgo menor de la revision adversarial): anuncio_debido no
-- comprobaba camino.activo, asi que podia sugerir un anuncio para una
-- parada inactiva que iniciar_intento_parada iba a rechazar de todos modos.
-- Sin riesgo real (fail-open ya cubria la excepcion resultante), pero mas
-- limpio devolver 'ninguno' directamente para una parada muerta.
create or replace function anuncio_debido(p_camino_id uuid)
returns tipo_anuncio_pendiente
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_orden integer;
  v_activo boolean;
  v_es_desbloqueo boolean;
  v_contador integer;
begin
  select orden, activo into v_orden, v_activo from camino where id = p_camino_id;

  if not found then
    raise exception 'La parada % no existe', p_camino_id;
  end if;

  if not v_activo then
    return 'ninguno'::tipo_anuncio_pendiente;
  end if;

  v_es_desbloqueo := v_orden > 1 and not exists (
    select 1 from intentos_nivel
    where usuario_id = auth.uid() and camino_id = p_camino_id
  );

  if v_es_desbloqueo then
    return 'desbloqueo'::tipo_anuncio_pendiente;
  end if;

  select intentos_desde_ultimo_anuncio_cadencia into v_contador
  from profiles where id = auth.uid();

  if coalesce(v_contador, 0) + 1 >= 3 then
    return 'cadencia'::tipo_anuncio_pendiente;
  end if;

  return 'ninguno'::tipo_anuncio_pendiente;
end;
$$;
