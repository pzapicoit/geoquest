-- INT-117: supabase db lint --linked senalaba "target type is different type
-- than source type" en los 3 RETURN de anuncio_debido -- los literales de
-- texto necesitan cast explicito al enum tipo_anuncio_pendiente. Mismo tipo
-- de fix que 20260820170100_corrige_lint_usar_comodin.sql para INT-119.
create or replace function anuncio_debido(p_camino_id uuid)
returns tipo_anuncio_pendiente
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_orden integer;
  v_es_desbloqueo boolean;
  v_contador integer;
begin
  select orden into v_orden from camino where id = p_camino_id;

  if not found then
    raise exception 'La parada % no existe', p_camino_id;
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
