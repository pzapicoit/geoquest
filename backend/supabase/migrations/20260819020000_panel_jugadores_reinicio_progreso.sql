-- INT-111: pantalla "Jugadores" del panel (listado) y reinicio de progreso.
-- Ver design.md de openspec/changes/int-111-panel-jugadores para el porque
-- de cada decision referenciada como D1-D4 en los comentarios.

-- D3: tabla de auditoria del reinicio. jugador_id SIN FK a proposito: si la
-- cuenta del jugador se borra mas adelante por otra via, el registro de
-- auditoria debe sobrevivir -- por eso ademas se guarda alias_jugador como
-- snapshot en vez de resolverlo por join en el momento de leer. Solo la RPC
-- de mas abajo (security definer, dueno postgres con bypassrls) escribe en
-- esta tabla; no hay policy de insert/update/delete para ningun rol.
create table auditoria_reinicio_progreso (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references profiles (id),
  jugador_id uuid not null,
  alias_jugador text not null,
  creado_en timestamptz not null default now()
);

alter table auditoria_reinicio_progreso enable row level security;

create policy "auditoria_reinicio_progreso_select_admin"
on auditoria_reinicio_progreso
for select
to authenticated
using (is_admin());

-- D1: jugadores_listado(), mismo patron que metricas_home/alertas_contenido/
-- actividad_reciente (INT-87) y clasificacion_global (INT-109) -- security
-- definer + is_admin() como primera linea, agregando sobre TODOS los
-- jugadores (RLS de progreso_usuario_nivel/intentos_nivel es "cada cual lo
-- suyo", aqui hace falta ver a todos). tasa_superacion sustituye al "%% de
-- acierto" del mock: la puntuacion es por distancia, no hay un booleano de
-- acierto por respuesta, asi que se redefine como niveles superados sobre
-- paradas con al menos un intento (mismo concepto que ya usa
-- alertas_contenido para "nivel con baja tasa de superacion"). NULL (no 0)
-- cuando el jugador no tiene ningun intento, para no mostrar un "0%%"
-- enganoso en el panel.
create function jugadores_listado()
returns table (
  jugador_id uuid,
  alias text,
  niveles_superados integer,
  parada_maxima integer,
  puntos_totales bigint,
  tasa_superacion numeric,
  ultima_partida timestamptz
)
language plpgsql
security definer
stable
set search_path = public
as $$
begin
  if not is_admin() then
    raise exception 'Solo un admin puede consultar el listado de jugadores';
  end if;

  return query
  with progreso as (
    select
      pun.usuario_id,
      count(*) filter (where pun.superado)::integer as niveles_superados,
      max(c.orden) filter (where pun.superado) as parada_maxima
    from progreso_usuario_nivel pun
    join camino c on c.id = pun.camino_id
    group by pun.usuario_id
  ),
  intentos as (
    select
      it.usuario_id,
      count(distinct it.camino_id)::integer as paradas_intentadas,
      max(it.fecha) as ultima_partida
    from intentos_nivel it
    group by it.usuario_id
  ),
  puntos as (
    select
      it.usuario_id,
      sum(rd.puntos)::bigint as puntos_totales
    from respuestas_desafio rd
    join intentos_nivel it on it.id = rd.intento_id
    group by it.usuario_id
  )
  select
    p.id as jugador_id,
    p.nombre as alias,
    coalesce(pr.niveles_superados, 0) as niveles_superados,
    pr.parada_maxima,
    coalesce(pt.puntos_totales, 0) as puntos_totales,
    case
      when coalesce(i.paradas_intentadas, 0) > 0
        then round(coalesce(pr.niveles_superados, 0)::numeric / i.paradas_intentadas, 4)
      else null
    end as tasa_superacion,
    i.ultima_partida
  from profiles p
  left join progreso pr on pr.usuario_id = p.id
  left join intentos i on i.usuario_id = p.id
  left join puntos pt on pt.usuario_id = p.id
  where p.role = 'jugador';
end;
$$;

revoke execute on function jugadores_listado() from public;
grant execute on function jugadores_listado() to authenticated;

-- D2: reiniciar_progreso_jugador() -- security definer (mismo mecanismo de
-- bypass de RLS que jugadores_listado de arriba) para poder borrar filas de
-- un jugador que no es quien llama. Borra progreso_usuario_nivel (vuelve el
-- camino a "sin superar, sin estrellas") e intentos_nivel, que en cascada
-- por FK existente (INT-74) se lleva respuestas_desafio -- deja los puntos
-- totales y el historial de partidas a cero. profiles/auth.users no se
-- tocan: la cuenta, el alias y el acceso del jugador sobreviven.
create function reiniciar_progreso_jugador(p_jugador_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alias text;
begin
  if not is_admin() then
    raise exception 'Solo un admin puede reiniciar el progreso de un jugador';
  end if;

  select nombre into v_alias
  from profiles
  where id = p_jugador_id and role = 'jugador';

  if v_alias is null then
    raise exception 'El jugador % no existe o no tiene rol de jugador', p_jugador_id;
  end if;

  -- La fila de auditoria se inserta antes de borrar nada, con el alias
  -- vigente en este momento.
  insert into auditoria_reinicio_progreso (admin_id, jugador_id, alias_jugador)
  values (auth.uid(), p_jugador_id, v_alias);

  delete from progreso_usuario_nivel where usuario_id = p_jugador_id;
  delete from intentos_nivel where usuario_id = p_jugador_id;
end;
$$;

revoke execute on function reiniciar_progreso_jugador(uuid) from public;
grant execute on function reiniciar_progreso_jugador(uuid) to authenticated;
