import { supabase } from './supabaseClient'
import type { TipoDesafio } from './preguntas'

// Deben coincidir con las constantes de calcular_puntaje en
// backend/supabase/migrations/20260817220000_curva_puntuacion_exponencial.sql
// (fuente de verdad de la curva real). Duplicadas aquí porque el cálculo de
// absoluto/distancia media es puramente presentacional y no justifica una RPC.
export const MAX_PUNTOS_DESAFIO = 5000
export const PISO_PUNTOS_DESAFIO = 50
export const K_DISTANCIA_KM = 1500

/** Preguntas que se juegan realmente en una partida del nivel. */
export function preguntasEfectivasPorPartida(
  preguntasPorPartida: number | null,
  preguntasAsignadas: number,
): number {
  return preguntasPorPartida ?? preguntasAsignadas
}

/** Puntaje total máximo alcanzable en el nivel (N desafíos a puntaje MAX). */
export function puntajeMaximoNivel(
  preguntasPorPartida: number | null,
  preguntasAsignadas: number,
): number {
  return preguntasEfectivasPorPartida(preguntasPorPartida, preguntasAsignadas) * MAX_PUNTOS_DESAFIO
}

export function absolutoDesdePorcentaje(porcentaje: number, maximoNivel: number): number {
  return Math.round((porcentaje / 100) * maximoNivel)
}

export function porcentajeDesdeAbsoluto(absoluto: number, maximoNivel: number): number {
  if (maximoNivel <= 0) return 0
  return (absoluto / maximoNivel) * 100
}

/**
 * Distancia media en km que implica un puntaje total, invirtiendo la curva
 * de calcular_puntaje sobre el puntaje medio por desafío. `null` cuando el
 * puntaje está en el suelo o por debajo: cualquier distancia lo cumple.
 */
export function distanciaMediaKm(puntajeTotal: number, preguntasEfectivas: number): number | null {
  if (preguntasEfectivas <= 0) return null
  const puntosPorDesafio = puntajeTotal / preguntasEfectivas
  const fraccion =
    (puntosPorDesafio - PISO_PUNTOS_DESAFIO) / (MAX_PUNTOS_DESAFIO - PISO_PUNTOS_DESAFIO)
  if (fraccion <= 0) return null
  if (fraccion >= 1) return 0
  return -K_DISTANCIA_KM * Math.log(fraccion)
}

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
  umbralEstrella2: number
  umbralEstrella3: number
  preguntasPorPartida: number | null
  preguntas: PreguntaRecorrido[]
}

interface NivelRow {
  id: string
  nombre: string | null
  orden: number
  tematica_id: string
  puntaje_minimo_superar: number
  umbral_estrella_2: number
  umbral_estrella_3: number
  preguntas_por_partida: number | null
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
      'id, nombre, orden, tematica_id, puntaje_minimo_superar, umbral_estrella_2, umbral_estrella_3, preguntas_por_partida',
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
    umbralEstrella2: row.umbral_estrella_2,
    umbralEstrella3: row.umbral_estrella_3,
    preguntasPorPartida: row.preguntas_por_partida,
    preguntas,
  }
}

export interface ConfiguracionNivel {
  nombre: string | null
  puntajeMinimoSuperar: number
  umbralEstrella2: number
  umbralEstrella3: number
  preguntasPorPartida: number | null
}

export function validarConfiguracionNivel(
  config: ConfiguracionNivel,
  preguntasAsignadas: number,
): string | null {
  const { puntajeMinimoSuperar, umbralEstrella2, umbralEstrella3 } = config
  const ascendente = puntajeMinimoSuperar <= umbralEstrella2 && umbralEstrella2 <= umbralEstrella3
  if (!ascendente) {
    return 'Los umbrales deben ser ascendentes: puntaje mínimo ≤ 2 estrellas ≤ 3 estrellas.'
  }
  if (config.preguntasPorPartida !== null && config.preguntasPorPartida > preguntasAsignadas) {
    return 'Las preguntas por partida no pueden superar el número de preguntas del recorrido.'
  }
  return null
}

export async function guardarConfiguracionNivel(
  id: string,
  config: ConfiguracionNivel,
  preguntasAsignadas: number,
): Promise<void> {
  const errorValidacion = validarConfiguracionNivel(config, preguntasAsignadas)
  if (errorValidacion) throw new Error(errorValidacion)

  const { error } = await supabase
    .from('niveles')
    .update({
      nombre: config.nombre,
      puntaje_minimo_superar: config.puntajeMinimoSuperar,
      // umbral_estrella_1 es una columna muerta (cerrar_intento_nivel no la
      // lee, ver design.md de INT-101): se fija = puntaje_minimo_superar
      // para seguir cumpliendo el CHECK de la tabla sin campo propio en el
      // formulario.
      umbral_estrella_1: config.puntajeMinimoSuperar,
      umbral_estrella_2: config.umbralEstrella2,
      umbral_estrella_3: config.umbralEstrella3,
      preguntas_por_partida: config.preguntasPorPartida,
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
  if (!error) return

  if (error.code === '23505') {
    throw new Error(
      'Otra persona ha modificado este recorrido a la vez. Recarga la página e inténtalo de nuevo.',
    )
  }
  throw new Error(error.message)
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
