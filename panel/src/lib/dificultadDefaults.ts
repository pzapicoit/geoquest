import { supabase } from './supabaseClient'
import { DIFICULTADES, type Dificultad } from './dificultad'

export interface DificultadDefault {
  dificultad: Dificultad
  preguntasPorPartida: number
  segundosPorDesafio: number
  puntajeMinimoSuperar: number
  umbralEstrella2: number
  umbralEstrella3: number
}

interface DificultadDefaultRow {
  dificultad: Dificultad
  preguntas_por_partida: number
  segundos_por_desafio: number
  puntaje_minimo_superar: number
  umbral_estrella_2: number
  umbral_estrella_3: number
}

export async function fetchDificultadDefaults(): Promise<DificultadDefault[]> {
  const { data, error } = await supabase
    .from('dificultad_defaults')
    .select(
      'dificultad, preguntas_por_partida, segundos_por_desafio, puntaje_minimo_superar, umbral_estrella_2, umbral_estrella_3',
    )
  if (error) throw new Error(error.message)

  const porDificultad = new Map(
    ((data ?? []) as DificultadDefaultRow[]).map((fila) => [fila.dificultad, fila]),
  )

  return DIFICULTADES.map(({ valor }) => {
    const fila = porDificultad.get(valor)
    if (!fila) throw new Error(`Falta la fila de valores por defecto para "${valor}".`)
    return {
      dificultad: fila.dificultad,
      preguntasPorPartida: fila.preguntas_por_partida,
      segundosPorDesafio: fila.segundos_por_desafio,
      puntajeMinimoSuperar: fila.puntaje_minimo_superar,
      umbralEstrella2: fila.umbral_estrella_2,
      umbralEstrella3: fila.umbral_estrella_3,
    }
  })
}

export interface GuardarDificultadDefaultInput {
  dificultad: Dificultad
  preguntasPorPartida: number
  segundosPorDesafio: number
  puntajeMinimoSuperar: number
  umbralEstrella2: number
  umbralEstrella3: number
}

function enteroPositivo(n: number): boolean {
  return Number.isInteger(n) && n > 0
}

export function validarDificultadDefault(input: GuardarDificultadDefaultInput): string | null {
  if (!enteroPositivo(input.preguntasPorPartida)) {
    return 'Las preguntas por partida deben ser un entero positivo.'
  }
  if (!enteroPositivo(input.segundosPorDesafio)) {
    return 'Los segundos por desafío deben ser un entero positivo.'
  }
  if (!enteroPositivo(input.puntajeMinimoSuperar)) {
    return 'La puntuación mínima debe ser un entero positivo.'
  }
  if (!enteroPositivo(input.umbralEstrella2)) {
    return 'El umbral de 2 estrellas debe ser un entero positivo.'
  }
  if (!enteroPositivo(input.umbralEstrella3)) {
    return 'El umbral de 3 estrellas debe ser un entero positivo.'
  }
  if (
    input.puntajeMinimoSuperar > input.umbralEstrella2 ||
    input.umbralEstrella2 > input.umbralEstrella3
  ) {
    return 'Los umbrales deben ser ascendentes: mínimo ≤ 2 estrellas ≤ 3 estrellas.'
  }
  return null
}

export async function guardarDificultadDefault(
  input: GuardarDificultadDefaultInput,
): Promise<void> {
  const errorValidacion = validarDificultadDefault(input)
  if (errorValidacion) throw new Error(errorValidacion)

  const { error } = await supabase
    .from('dificultad_defaults')
    .update({
      preguntas_por_partida: input.preguntasPorPartida,
      segundos_por_desafio: input.segundosPorDesafio,
      puntaje_minimo_superar: input.puntajeMinimoSuperar,
      umbral_estrella_2: input.umbralEstrella2,
      umbral_estrella_3: input.umbralEstrella3,
    })
    .eq('dificultad', input.dificultad)
  if (error) throw new Error(error.message)
}
