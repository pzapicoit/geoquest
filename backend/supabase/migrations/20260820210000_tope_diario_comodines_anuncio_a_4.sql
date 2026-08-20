-- INT-117 delta-1: se activa la via de obtencion de comodines por video
-- bajo demanda (ComodinesScreen, deshabilitada desde INT-119 esperando esta
-- integracion). Tope diario decidido: 4 concesiones/jugador/dia (D5 de
-- design.md del delta) -- solo cambia el default, sin tocar el resto de la
-- logica.
create or replace function conceder_comodin_por_anuncio(p_tope_diario integer default 4)
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
