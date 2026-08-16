import { supabase } from './supabaseClient'
import type { TipoDesafio } from './preguntas'

export interface PreguntaRecorrido {
  desafioId: string
  orden: number
  tipo: TipoDesafio
  nombreLugar: string
  imagenUrl: string | null
}

export interface NivelRecorrido {
  id: string
  nombre: string | null
  orden: number
  tematicaNombre: string
  puntajeMinimoSuperar: number
  umbralEstrella1: number
  umbralEstrella2: number
  umbralEstrella3: number
  preguntas: PreguntaRecorrido[]
}

interface NivelRow {
  id: string
  nombre: string | null
  orden: number
  tematica_id: string
  puntaje_minimo_superar: number
  umbral_estrella_1: number
  umbral_estrella_2: number
  umbral_estrella_3: number
}

interface DesafioBancoRow {
  id: string
  tipo: TipoDesafio
  nombre_lugar: string
  imagen_url: string | null
}

interface NivelDesafioRow {
  desafio_id: string
  orden: number
}

export async function fetchNivelRecorrido(id: string): Promise<NivelRecorrido> {
  const { data: nivel, error: nivelError } = await supabase
    .from('niveles')
    .select(
      'id, nombre, orden, tematica_id, puntaje_minimo_superar, umbral_estrella_1, umbral_estrella_2, umbral_estrella_3',
    )
    .eq('id', id)
    .single()
  if (nivelError) throw new Error(nivelError.message)

  const row = nivel as NivelRow

  const { data: tematica, error: tematicaError } = await supabase
    .from('tematicas')
    .select('nombre')
    .eq('id', row.tematica_id)
    .single()
  if (tematicaError) throw new Error(tematicaError.message)

  const { data: asignaciones, error: asignacionesError } = await supabase
    .from('nivel_desafios')
    .select('desafio_id, orden')
    .eq('nivel_id', id)
    .order('orden')
  if (asignacionesError) throw new Error(asignacionesError.message)

  const filas = (asignaciones ?? []) as NivelDesafioRow[]
  const desafioIds = filas.map((fila) => fila.desafio_id)

  const { data: desafios, error: desafiosError } =
    desafioIds.length > 0
      ? await supabase
          .from('desafios')
          .select('id, tipo, nombre_lugar, imagen_url')
          .in('id', desafioIds)
      : { data: [] as DesafioBancoRow[], error: null }
  if (desafiosError) throw new Error(desafiosError.message)

  const desafioPorId = new Map((desafios ?? []).map((d) => [d.id as string, d as DesafioBancoRow]))

  const preguntas: PreguntaRecorrido[] = []
  for (const fila of filas) {
    const desafio = desafioPorId.get(fila.desafio_id)
    if (!desafio) continue
    preguntas.push({
      desafioId: fila.desafio_id,
      orden: fila.orden,
      tipo: desafio.tipo,
      nombreLugar: desafio.nombre_lugar,
      imagenUrl: desafio.imagen_url,
    })
  }

  return {
    id: row.id,
    nombre: row.nombre,
    orden: row.orden,
    tematicaNombre: (tematica as { nombre: string }).nombre,
    puntajeMinimoSuperar: row.puntaje_minimo_superar,
    umbralEstrella1: row.umbral_estrella_1,
    umbralEstrella2: row.umbral_estrella_2,
    umbralEstrella3: row.umbral_estrella_3,
    preguntas,
  }
}

export interface ConfiguracionNivel {
  nombre: string | null
  puntajeMinimoSuperar: number
  umbralEstrella1: number
  umbralEstrella2: number
  umbralEstrella3: number
}

export function validarConfiguracionNivel(config: ConfiguracionNivel): string | null {
  const { puntajeMinimoSuperar, umbralEstrella1, umbralEstrella2, umbralEstrella3 } = config
  const ascendente =
    puntajeMinimoSuperar <= umbralEstrella1 &&
    umbralEstrella1 <= umbralEstrella2 &&
    umbralEstrella2 <= umbralEstrella3
  if (!ascendente) {
    return 'Los umbrales deben ser ascendentes: puntaje mínimo ≤ 1 estrella ≤ 2 estrellas ≤ 3 estrellas.'
  }
  return null
}

export async function guardarConfiguracionNivel(
  id: string,
  config: ConfiguracionNivel,
): Promise<void> {
  const errorValidacion = validarConfiguracionNivel(config)
  if (errorValidacion) throw new Error(errorValidacion)

  const { error } = await supabase
    .from('niveles')
    .update({
      nombre: config.nombre,
      puntaje_minimo_superar: config.puntajeMinimoSuperar,
      umbral_estrella_1: config.umbralEstrella1,
      umbral_estrella_2: config.umbralEstrella2,
      umbral_estrella_3: config.umbralEstrella3,
    })
    .eq('id', id)
  if (error) throw new Error(error.message)
}

export interface PreguntaBanco {
  id: string
  tipo: TipoDesafio
  nombreLugar: string
  imagenUrl: string | null
}

export async function fetchPreguntasNoAsignadas(nivelId: string): Promise<PreguntaBanco[]> {
  const [
    { data: desafios, error: desafiosError },
    { data: asignaciones, error: asignacionesError },
  ] = await Promise.all([
    supabase.from('desafios').select('id, tipo, nombre_lugar, imagen_url'),
    supabase.from('nivel_desafios').select('desafio_id').eq('nivel_id', nivelId),
  ])
  if (desafiosError) throw new Error(desafiosError.message)
  if (asignacionesError) throw new Error(asignacionesError.message)

  const asignados = new Set((asignaciones ?? []).map((fila) => fila.desafio_id as string))

  return ((desafios ?? []) as DesafioBancoRow[])
    .filter((desafio) => !asignados.has(desafio.id))
    .map((desafio) => ({
      id: desafio.id,
      tipo: desafio.tipo,
      nombreLugar: desafio.nombre_lugar,
      imagenUrl: desafio.imagen_url,
    }))
}

export async function agregarPreguntaAlRecorrido(
  nivelId: string,
  desafioId: string,
): Promise<void> {
  const { data: asignaciones, error: asignacionesError } = await supabase
    .from('nivel_desafios')
    .select('orden')
    .eq('nivel_id', nivelId)
  if (asignacionesError) throw new Error(asignacionesError.message)

  const maxOrden = (asignaciones ?? []).reduce(
    (max, fila) => Math.max(max, fila.orden as number),
    0,
  )

  const { error } = await supabase
    .from('nivel_desafios')
    .insert({ nivel_id: nivelId, desafio_id: desafioId, orden: maxOrden + 1 })
  if (error) throw new Error(error.message)
}

export async function reordenarRecorrido(nivelId: string, idsEnOrden: string[]): Promise<void> {
  const { error } = await supabase.rpc('reordenar_preguntas_nivel', {
    p_nivel_id: nivelId,
    ids_en_orden: idsEnOrden,
  })
  if (error) throw new Error(error.message)
}

export async function quitarPreguntaDelRecorrido(
  nivelId: string,
  desafioId: string,
): Promise<void> {
  const { error: deleteError } = await supabase
    .from('nivel_desafios')
    .delete()
    .eq('nivel_id', nivelId)
    .eq('desafio_id', desafioId)
  if (deleteError) throw new Error(deleteError.message)

  const { data: restantes, error: restantesError } = await supabase
    .from('nivel_desafios')
    .select('desafio_id, orden')
    .eq('nivel_id', nivelId)
    .order('orden')
  if (restantesError) throw new Error(restantesError.message)

  const idsEnOrden = (restantes ?? []).map((fila) => fila.desafio_id as string)
  if (idsEnOrden.length === 0) return

  await reordenarRecorrido(nivelId, idsEnOrden)
}
