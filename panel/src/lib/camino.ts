import { supabase } from './supabaseClient'
import { DIFICULTAD_LABEL, type Dificultad } from './dificultad'

export interface OverridesParada {
  preguntasPorPartida: number | null
  segundosPorDesafio: number | null
  puntajeMinimoSuperar: number | null
  umbralEstrella2: number | null
  umbralEstrella3: number | null
}

export interface PosicionCamino extends OverridesParada {
  id: string
  orden: number
  tematicaId: string
  tematicaNombre: string
  dificultad: Dificultad
  nombre: string | null
  estrellasRequeridas: number
}

export interface TematicaOpcion {
  id: string
  nombre: string
}

interface CaminoRow {
  id: string
  orden: number
  tematica_id: string
  dificultad: Dificultad
  nombre: string | null
  estrellas_requeridas: number
  preguntas_por_partida: number | null
  segundos_por_desafio: number | null
  puntaje_minimo_superar: number | null
  umbral_estrella_2: number | null
  umbral_estrella_3: number | null
}

interface TematicaRow {
  id: string
  nombre: string
}

const SELECT_CAMINO =
  'id, orden, tematica_id, dificultad, nombre, estrellas_requeridas, preguntas_por_partida, segundos_por_desafio, puntaje_minimo_superar, umbral_estrella_2, umbral_estrella_3'

export function nombreParada(posicion: {
  nombre: string | null
  tematicaNombre: string
  dificultad: Dificultad
}): string {
  const nombre = posicion.nombre?.trim()
  return nombre ? nombre : `${posicion.tematicaNombre} · ${DIFICULTAD_LABEL[posicion.dificultad]}`
}

export async function fetchCamino(): Promise<PosicionCamino[]> {
  const { data: camino, error: caminoError } = await supabase
    .from('camino')
    .select(SELECT_CAMINO)
    .order('orden', { ascending: true })
  if (caminoError) throw new Error(caminoError.message)

  const filas = (camino ?? []) as CaminoRow[]
  const tematicaIds = [...new Set(filas.map((fila) => fila.tematica_id))]

  const { data: tematicas, error: tematicasError } =
    tematicaIds.length > 0
      ? await supabase.from('tematicas').select('id, nombre').in('id', tematicaIds)
      : { data: [] as TematicaRow[], error: null }
  if (tematicasError) throw new Error(tematicasError.message)

  const nombrePorTematica = new Map(
    ((tematicas ?? []) as TematicaRow[]).map((t) => [t.id, t.nombre]),
  )

  return filas.map((fila) => ({
    id: fila.id,
    orden: fila.orden,
    tematicaId: fila.tematica_id,
    tematicaNombre: nombrePorTematica.get(fila.tematica_id) ?? 'Temática eliminada',
    dificultad: fila.dificultad,
    nombre: fila.nombre,
    estrellasRequeridas: fila.estrellas_requeridas,
    preguntasPorPartida: fila.preguntas_por_partida,
    segundosPorDesafio: fila.segundos_por_desafio,
    puntajeMinimoSuperar: fila.puntaje_minimo_superar,
    umbralEstrella2: fila.umbral_estrella_2,
    umbralEstrella3: fila.umbral_estrella_3,
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
    .insert({ tematica_id: tematicaId, dificultad, orden: maxOrden + 1, estrellas_requeridas: 0 })
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

function enteroPositivoONull(n: number | null): boolean {
  return n === null || (Number.isInteger(n) && n > 0)
}

// Valida los overrides de una parada contra sus valores por defecto vigentes
// (override ?? default), igual que la validación de dificultad_defaults.
export function validarOverrides(
  overrides: OverridesParada,
  defaults: { puntajeMinimoSuperar: number; umbralEstrella2: number; umbralEstrella3: number },
): string | null {
  if (
    !enteroPositivoONull(overrides.preguntasPorPartida) ||
    !enteroPositivoONull(overrides.segundosPorDesafio) ||
    !enteroPositivoONull(overrides.puntajeMinimoSuperar) ||
    !enteroPositivoONull(overrides.umbralEstrella2) ||
    !enteroPositivoONull(overrides.umbralEstrella3)
  ) {
    return 'Cada override debe ser un entero positivo, o quedar vacío para usar el valor por defecto.'
  }

  const minimoEfectivo = overrides.puntajeMinimoSuperar ?? defaults.puntajeMinimoSuperar
  const estrella2Efectivo = overrides.umbralEstrella2 ?? defaults.umbralEstrella2
  const estrella3Efectivo = overrides.umbralEstrella3 ?? defaults.umbralEstrella3

  if (minimoEfectivo > estrella2Efectivo || estrella2Efectivo > estrella3Efectivo) {
    return 'Los umbrales efectivos deben ser ascendentes: mínimo ≤ 2 estrellas ≤ 3 estrellas.'
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
      puntaje_minimo_superar: overrides.puntajeMinimoSuperar,
      umbral_estrella_2: overrides.umbralEstrella2,
      umbral_estrella_3: overrides.umbralEstrella3,
    })
    .eq('id', id)
  if (error) throw new Error(error.message)
}
