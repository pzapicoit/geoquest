-- INT-81: actividad_reciente() -- feed de altas de jugador y niveles
-- superados para la columna "Actividad reciente" del panel. Ver design.md
-- de openspec/changes/int-81-panel-home-dashboard para el porque de cada
-- decision referenciada como D1 en los comentarios.

-- D1: mismo patron que metricas_home/alertas_contenido (INT-87) -- security
-- definer + is_admin() como primera linea, agregando sobre TODOS los
-- jugadores. auth.users es legible desde una funcion security definer
-- propiedad de postgres (confirmado contra el remoto), igual que
-- handle_new_user (INT-75) ya la usa en sentido inverso (trigger de alta).
-- El feed combina 2 tipos de evento con UNION ALL (mismo criterio D5 de
-- INT-87: una sola llamada para una sola columna del panel) y se ordena/
-- acota sobre el resultado combinado -- "order by 2" referencia
-- posicionalmente ocurrido_en, unica forma valida de ordenar un UNION ALL
-- sin alias declarado en el primer SELECT.
create function actividad_reciente(p_limite integer default 20)
returns table (
  tipo text,
  ocurrido_en timestamptz,
  texto text,
  detalle jsonb
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_admin() then
    raise exception 'Solo un admin puede consultar la actividad reciente';
  end if;

  return query
  select
    'nuevo_registro'::text,
    u.created_at,
    p.nombre,
    '{}'::jsonb
  from profiles p
  join auth.users u on u.id = p.id
  where p.role = 'jugador'

  union all

  select
    'nivel_superado'::text,
    i.fecha,
    p.nombre,
    jsonb_build_object(
      'estrellas_obtenidas', i.estrellas_obtenidas,
      'nivel_id', i.nivel_id,
      'tematica_id', n.tematica_id
    )
  from intentos_nivel i
  join profiles p on p.id = i.usuario_id
  join niveles n on n.id = i.nivel_id
  where i.superado

  order by 2 desc
  limit p_limite;
end;
$$;
