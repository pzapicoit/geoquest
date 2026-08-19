import { supabase } from './supabaseClient'
import { DIFICULTAD_LABEL, type Dificultad } from './dificultad'

export interface OverridesParada {
  preguntasPorPartida: number | null
  segundosPorDesafio: number | null
}

export interface PosicionCamino extends OverridesParada {
  id: string
  orden: number
  tematicaId: string
  tematicaNombre: string
  dificultad: Dificultad
  nombre: string | null
}

export interface TematicaOpcion {
  id: string
  nombre: string
}

interface CaminoPanelRow {
  id: string
  orden: number
  tematica_id: string
  tematica_nombre: string
  dificultad: Dificultad
  nombre: string | null
  preguntas_por_partida: number | null
  segundos_por_desafio: number | null
}

const SELECT_CAMINO_PANEL =
  'id, orden, tematica_id, tematica_nombre, dificultad, nombre, preguntas_por_partida, segundos_por_desafio'

// estrellas_requeridas se deriva siempre de `orden` en el momento de pintar
// (ver `estrellas_requeridas_por_orden` en el backend): nunca se guarda en
// `PosicionCamino`, para que un reorden optimista en el cliente (antes de que
// el servidor confirme) recalcule el requisito de inmediato en vez de mostrar
// un valor congelado en el momento de la carga.
export function calcularEstrellasRequeridas(orden: number): number {
  return Math.floor((orden - 1) * 3 * 0.6)
}

export function nombreParada(posicion: {
  nombre: string | null
  tematicaNombre: string
  dificultad: Dificultad
}): string {
  const nombre = posicion.nombre?.trim()
  return nombre ? nombre : `${posicion.tematicaNombre} · ${DIFICULTAD_LABEL[posicion.dificultad]}`
}

export async function fetchCamino(): Promise<PosicionCamino[]> {
  const { data, error } = await supabase
    .from('camino_panel')
    .select(SELECT_CAMINO_PANEL)
    .order('orden', { ascending: true })
  if (error) throw new Error(error.message)

  return ((data ?? []) as CaminoPanelRow[]).map((fila) => ({
    id: fila.id,
    orden: fila.orden,
    tematicaId: fila.tematica_id,
    tematicaNombre: fila.tematica_nombre,
    dificultad: fila.dificultad,
    nombre: fila.nombre,
    preguntasPorPartida: fila.preguntas_por_partida,
    segundosPorDesafio: fila.segundos_por_desafio,
  }))
}

export async function fetchTematicasParaCamino(): Promise<TematicaOpcion[]> {
  const { data, error } = await supabase
    .from('tematicas')
    .select('id, nombre')
    .order('orden', { ascending: true })
  if (error) throw new Error(error.message)
  return (data ?? []) as TematicaOpcion[]
}

export async function agregarParadaAlCamino(
  tematicaId: string,
  dificultad: Dificultad,
): Promise<{ id: string }> {
  const { data: existentes, error: ordenError } = await supabase.from('camino').select('orden')
  if (ordenError) throw new Error(ordenError.message)

  const maxOrden = (existentes ?? []).reduce((max, fila) => Math.max(max, fila.orden as number), 0)

  const { data, error } = await supabase
    .from('camino')
    .insert({ tematica_id: tematicaId, dificultad, orden: maxOrden + 1 })
    .select('id')
    .single()
  if (error) {
    if (error.code === '23505') {
      throw new Error(
        'Otra persona ha modificado el camino a la vez. Recarga la página e inténtalo de nuevo.',
      )
    }
    throw new Error(error.message)
  }

  return { id: (data as { id: string }).id }
}

export async function reordenarCamino(idsEnOrden: string[]): Promise<void> {
  const { error } = await supabase.rpc('reordenar_camino', { ids_en_orden: idsEnOrden })
  if (error) throw new Error(error.message)
}

export async function quitarDelCamino(id: string): Promise<void> {
  const { error: deleteError } = await supabase.from('camino').delete().eq('id', id)
  if (deleteError) throw new Error(deleteError.message)

  const { data: restantes, error: restantesError } = await supabase
    .from('camino')
    .select('id')
    .order('orden', { ascending: true })
  if (restantesError) throw new Error(restantesError.message)

  const idsEnOrden = ((restantes ?? []) as { id: string }[]).map((fila) => fila.id)
  if (idsEnOrden.length === 0) return

  await reordenarCamino(idsEnOrden)
}

function enteroPositivoONull(n: number | null): boolean {
  return n === null || (Number.isInteger(n) && n > 0)
}

// Valida los overrides de una parada: cada campo, o entero positivo, o vacío
// (usa el valor por defecto de su dificultad). Ya no hay orden ascendente que
// comprobar entre campos: preguntasPorPartida y segundosPorDesafio son
// independientes entre sí.
export function validarOverrides(overrides: OverridesParada): string | null {
  if (
    !enteroPositivoONull(overrides.preguntasPorPartida) ||
    !enteroPositivoONull(overrides.segundosPorDesafio)
  ) {
    return 'Cada override debe ser un entero positivo, o quedar vacío para usar el valor por defecto.'
  }
  return null
}

export async function actualizarOverridesParada(
  id: string,
  overrides: OverridesParada,
): Promise<void> {
  const { error } = await supabase
    .from('camino')
    .update({
      preguntas_por_partida: overrides.preguntasPorPartida,
      segundos_por_desafio: overrides.segundosPorDesafio,
    })
    .eq('id', id)
  if (error) throw new Error(error.message)
}
