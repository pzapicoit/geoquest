import { supabase } from './supabaseClient'
import { DIFICULTADES, type Dificultad } from './dificultad'

export interface DificultadDefault {
  dificultad: Dificultad
  preguntasPorPartida: number
  segundosPorDesafio: number
}

interface DificultadDefaultRow {
  dificultad: Dificultad
  preguntas_por_partida: number
  segundos_por_desafio: number
}

export async function fetchDificultadDefaults(): Promise<DificultadDefault[]> {
  const { data, error } = await supabase
    .from('dificultad_defaults')
    .select('dificultad, preguntas_por_partida, segundos_por_desafio')
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
    }
  })
}

export interface GuardarDificultadDefaultInput {
  dificultad: Dificultad
  preguntasPorPartida: number
  segundosPorDesafio: number
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
    })
    .eq('dificultad', input.dificultad)
  if (error) throw new Error(error.message)
}

export interface UmbralesParada {
  maximo: number
  minimo: number
  umbralEstrella2: number
  umbralEstrella3: number
}

interface UmbralesParadaRow {
  maximo: number
  minimo: number
  umbral_estrella_2: number
  umbral_estrella_3: number
}

// Deriva el máximo alcanzable y los tres umbrales de estrellas para una
// dificultad y un número de preguntas por partida dados. Se pide siempre al
// backend (RPC `umbrales_parada`) en vez de replicar el máximo por desafío en
// TypeScript: ese máximo sale de `calcular_puntaje` y no debe existir como
// literal fuera de esa función.
export async function fetchUmbralesParada(
  dificultad: Dificultad,
  preguntasPorPartida: number,
): Promise<UmbralesParada> {
  const { data, error } = await supabase
    .rpc('umbrales_parada', {
      p_dificultad: dificultad,
      p_preguntas_por_partida: preguntasPorPartida,
    })
    .single()
  if (error) throw new Error(error.message)

  const fila = data as UmbralesParadaRow
  return {
    maximo: fila.maximo,
    minimo: fila.minimo,
    umbralEstrella2: fila.umbral_estrella_2,
    umbralEstrella3: fila.umbral_estrella_3,
  }
}
