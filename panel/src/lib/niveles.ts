import { supabase } from './supabaseClient'

export interface NivelListado {
  id: string
  nombre: string | null
  orden: number
  puntajeMinimoSuperar: number
  activo: boolean
  cantidadPreguntas: number
}

export interface NivelesTematica {
  tematicaId: string
  tematicaNombre: string
  tematicaOrden: number
  niveles: NivelListado[]
}

interface TematicaRow {
  id: string
  nombre: string
  orden: number
}

interface NivelRow {
  id: string
  nombre: string | null
  orden: number
  puntaje_minimo_superar: number
  activo: boolean
}

interface NivelDesafioRow {
  nivel_id: string
}

export async function fetchNivelesTematica(tematicaId: string): Promise<NivelesTematica> {
  const { data: tematica, error: tematicaError } = await supabase
    .from('tematicas')
    .select('id, nombre, orden')
    .eq('id', tematicaId)
    .single()
  if (tematicaError) throw new Error(tematicaError.message)

  const tematicaRow = tematica as TematicaRow

  const { data: niveles, error: nivelesError } = await supabase
    .from('niveles')
    .select('id, nombre, orden, puntaje_minimo_superar, activo')
    .eq('tematica_id', tematicaId)
    .order('orden', { ascending: true })
  if (nivelesError) throw new Error(nivelesError.message)

  const nivelRows = (niveles ?? []) as NivelRow[]
  const nivelIds = nivelRows.map((nivel) => nivel.id)

  const { data: asignaciones, error: asignacionesError } =
    nivelIds.length > 0
      ? await supabase.from('nivel_desafios').select('nivel_id').in('nivel_id', nivelIds)
      : { data: [] as NivelDesafioRow[], error: null }
  if (asignacionesError) throw new Error(asignacionesError.message)

  const cantidadPorNivel = new Map<string, number>()
  for (const fila of (asignaciones ?? []) as NivelDesafioRow[]) {
    cantidadPorNivel.set(fila.nivel_id, (cantidadPorNivel.get(fila.nivel_id) ?? 0) + 1)
  }

  return {
    tematicaId: tematicaRow.id,
    tematicaNombre: tematicaRow.nombre,
    tematicaOrden: tematicaRow.orden,
    niveles: nivelRows.map((nivel) => ({
      id: nivel.id,
      nombre: nivel.nombre,
      orden: nivel.orden,
      puntajeMinimoSuperar: nivel.puntaje_minimo_superar,
      activo: nivel.activo,
      cantidadPreguntas: cantidadPorNivel.get(nivel.id) ?? 0,
    })),
  }
}

export async function crearNivel(tematicaId: string, nombre: string): Promise<{ id: string }> {
  const nombreLimpio = nombre.trim()
  if (!nombreLimpio) {
    throw new Error('El nombre del nivel es obligatorio.')
  }

  const { data: existentes, error: ordenError } = await supabase
    .from('niveles')
    .select('orden')
    .eq('tematica_id', tematicaId)
  if (ordenError) throw new Error(ordenError.message)

  const siguienteOrden =
    Math.max(0, ...((existentes ?? []) as { orden: number }[]).map((nivel) => nivel.orden)) + 1

  const id = crypto.randomUUID()

  const { error } = await supabase.from('niveles').insert({
    id,
    tematica_id: tematicaId,
    orden: siguienteOrden,
    nombre: nombreLimpio,
    puntaje_minimo_superar: 0,
    umbral_estrella_1: 0,
    umbral_estrella_2: 0,
    umbral_estrella_3: 0,
    // Explícito en vez de fiarse del default de columna (60): documenta aquí,
    // junto al resto de valores de partida de un nivel nuevo, cuál es el
    // punto de partida real sin tener que ir a mirar la migración.
    segundos_por_desafio: 60,
  })
  if (error) throw new Error(error.message)

  return { id }
}

export async function reordenarNiveles(tematicaId: string, idsEnOrden: string[]): Promise<void> {
  const { error } = await supabase.rpc('reordenar_niveles', {
    p_tematica_id: tematicaId,
    ids_en_orden: idsEnOrden,
  })
  if (error) throw new Error(error.message)
}

export async function eliminarNivel(tematicaId: string, id: string): Promise<void> {
  const { error: deleteError } = await supabase.from('niveles').delete().eq('id', id)
  if (deleteError) throw new Error(deleteError.message)

  const { data: restantes, error: restantesError } = await supabase
    .from('niveles')
    .select('id')
    .eq('tematica_id', tematicaId)
    .order('orden', { ascending: true })
  if (restantesError) throw new Error(restantesError.message)

  const idsEnOrden = ((restantes ?? []) as { id: string }[]).map((nivel) => nivel.id)
  if (idsEnOrden.length === 0) return

  await reordenarNiveles(tematicaId, idsEnOrden)
}
