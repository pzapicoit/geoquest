-- INT-96: vista camino_jugador -- el camino completo con el progreso del
-- usuario autenticado, en una sola consulta. Ver design.md de
-- openspec/changes/int-96-vista-camino-jugador para el porque de cada
-- decision referenciada como D1-D4 en los comentarios.

-- D1: sin `security_invoker` -- esta vista, como `desafios_uso` (D4 de
-- INT-87), la crea la migracion como `postgres`, dueno de las tablas y con
-- `bypassrls`: sin ese flag corre con los privilegios del dueno y por tanto
-- ignora la RLS de `progreso_usuario_nivel`. El aislamiento por jugador NO
-- sale de la RLS de esa tabla, sino del filtro explicito
-- `pun.usuario_id = auth.uid()` en el left join de mas abajo. Si esta vista
-- gana en el futuro una columna que lea otra tabla con RLS por usuario, esa
-- lectura necesita el mismo filtro explicito -- no lo da gratis la vista.
--
-- D2: `estrellas_acumuladas` va en un CTE aparte, no en una subconsulta
-- correlacionada por fila del camino: su valor es el total del jugador
-- sobre TODO el camino, no depende de la posicion que se esta mostrando.
--
-- D3: `desbloqueado` reproduce la regla de `cerrar_intento_nivel`
-- (estrellas acumuladas del camino >= estrellas_requeridas de la posicion),
-- no se limita a leer `progreso_usuario_nivel.desbloqueado` -- esa fila no
-- existe todavia para un jugador que nunca cerro un intento (D6 de
-- INT-74), y sin este recalculo la primera posicion (umbral 0) aparaceria
-- bloqueada para un jugador nuevo.
--
-- D4: `es_actual` es la primera posicion por `orden` con `superado = false`,
-- sin exigir que este desbloqueada: con el desbloqueo no secuencial de
-- INT-98 esa posicion puede estar bloqueada si el jugador salto estrellas
-- hacia adelante, y la app la usa igual para centrar el scroll y mostrar el
-- candado. `coalesce(..., false)` porque `min(...) over ()` da NULL cuando
-- no queda ninguna posicion sin superar (camino completo) -- sin el
-- coalesce, esa fila leeria `es_actual = null` en vez de `false`.
create view camino_jugador
with (security_invoker = false)
as
with estrellas_acumuladas as (
  select coalesce(sum(pun.mejores_estrellas), 0) as total
  from progreso_usuario_nivel pun
  join camino c on c.nivel_id = pun.nivel_id
  where pun.usuario_id = auth.uid()
)
select
  c.id as camino_id,
  c.orden,
  c.estrellas_requeridas,
  n.id as nivel_id,
  n.nombre as nivel_nombre,
  t.id as tematica_id,
  t.nombre as tematica_nombre,
  coalesce(pun.superado, false) as superado,
  coalesce(pun.mejores_estrellas, 0) as estrellas_obtenidas,
  ea.total as estrellas_acumuladas_usuario,
  coalesce(pun.desbloqueado, false)
    or c.estrellas_requeridas <= ea.total as desbloqueado,
  coalesce(
    c.orden = min(case when not coalesce(pun.superado, false) then c.orden end)
      over (),
    false
  ) as es_actual
from camino c
join niveles n on n.id = c.nivel_id
join tematicas t on t.id = n.tematica_id
left join progreso_usuario_nivel pun
  on pun.nivel_id = n.id and pun.usuario_id = auth.uid()
cross join estrellas_acumuladas ea
order by c.orden;
