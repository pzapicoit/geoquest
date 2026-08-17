import { supabase } from './supabaseClient'

export interface PosicionCamino {
  id: string
  orden: number
  nivelId: string
  nivelNombre: string
  tematicaNombre: string
  estrellasRequeridas: number
}

export interface NivelDisponible {
  id: string
  nombre: string
  tematicaNombre: string
}

interface CaminoRow {
  id: string
  orden: number
  nivel_id: string
  estrellas_requeridas: number
}

interface NivelRow {
  id: string
  nombre: string | null
  orden: number
  tematica_id: string
}

interface TematicaRow {
  id: string
  nombre: string
}

function nombreNivel(nivel: { nombre: string | null; orden: number }): string {
  const nombre = nivel.nombre?.trim()
  return nombre ? nombre : `Nivel ${nivel.orden}`
}

export async function fetchCamino(): Promise<PosicionCamino[]> {
  const { data: camino, error: caminoError } = await supabase
    .from('camino')
    .select('id, orden, nivel_id, estrellas_requeridas')
    .order('orden', { ascending: true })
  if (caminoError) throw new Error(caminoError.message)

  const filas = (camino ?? []) as CaminoRow[]
  const nivelIds = filas.map((fila) => fila.nivel_id)

  const { data: niveles, error: nivelesError } =
    nivelIds.length > 0
      ? await supabase.from('niveles').select('id, nombre, orden, tematica_id').in('id', nivelIds)
      : { data: [] as NivelRow[], error: null }
  if (nivelesError) throw new Error(nivelesError.message)

  const nivelRows = (niveles ?? []) as NivelRow[]
  const nivelPorId = new Map(nivelRows.map((nivel) => [nivel.id, nivel]))
  const tematicaIds = [...new Set(nivelRows.map((nivel) => nivel.tematica_id))]

  const { data: tematicas, error: tematicasError } =
    tematicaIds.length > 0
      ? await supabase.from('tematicas').select('id, nombre').in('id', tematicaIds)
      : { data: [] as TematicaRow[], error: null }
  if (tematicasError) throw new Error(tematicasError.message)

  const tematicaPorId = new Map(((tematicas ?? []) as TematicaRow[]).map((t) => [t.id, t.nombre]))

  return filas.map((fila) => {
    const nivel = nivelPorId.get(fila.nivel_id)
    return {
      id: fila.id,
      orden: fila.orden,
      nivelId: fila.nivel_id,
      nivelNombre: nivel ? nombreNivel(nivel) : 'Nivel eliminado',
      tematicaNombre: (nivel && tematicaPorId.get(nivel.tematica_id)) ?? '—',
      estrellasRequeridas: fila.estrellas_requeridas,
    }
  })
}

export async function fetchNivelesNoAsignados(): Promise<NivelDisponible[]> {
  const [
    { data: niveles, error: nivelesError },
    { data: tematicas, error: tematicasError },
    { data: camino, error: caminoError },
  ] = await Promise.all([
    supabase.from('niveles').select('id, nombre, orden, tematica_id'),
    supabase.from('tematicas').select('id, nombre'),
    supabase.from('camino').select('nivel_id'),
  ])
  if (nivelesError) throw new Error(nivelesError.message)
  if (tematicasError) throw new Error(tematicasError.message)
  if (caminoError) throw new Error(caminoError.message)

  const asignados = new Set((camino ?? []).map((fila) => fila.nivel_id as string))
  const tematicaPorId = new Map(((tematicas ?? []) as TematicaRow[]).map((t) => [t.id, t.nombre]))

  return ((niveles ?? []) as NivelRow[])
    .filter((nivel) => !asignados.has(nivel.id))
    .map((nivel) => ({
      id: nivel.id,
      nombre: nombreNivel(nivel),
      tematicaNombre: tematicaPorId.get(nivel.tematica_id) ?? '—',
    }))
}

export async function agregarNivelAlCamino(nivelId: string): Promise<{ id: string }> {
  const { data: existentes, error: ordenError } = await supabase.from('camino').select('orden')
  if (ordenError) throw new Error(ordenError.message)

  const maxOrden = (existentes ?? []).reduce((max, fila) => Math.max(max, fila.orden as number), 0)

  const { data, error } = await supabase
    .from('camino')
    .insert({ nivel_id: nivelId, orden: maxOrden + 1, estrellas_requeridas: 0 })
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

export async function actualizarEstrellasRequeridas(
  id: string,
  estrellasRequeridas: number,
): Promise<void> {
  if (!Number.isInteger(estrellasRequeridas) || estrellasRequeridas < 0) {
    throw new Error('Las estrellas requeridas deben ser un número entero igual o mayor a 0.')
  }

  const { error } = await supabase
    .from('camino')
    .update({ estrellas_requeridas: estrellasRequeridas })
    .eq('id', id)
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
