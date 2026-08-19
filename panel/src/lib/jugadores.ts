import { supabase } from './supabaseClient'

export interface Jugador {
  id: string
  alias: string
  nivelesSuperados: number
  paradaMaxima: number | null
  puntosTotales: number
  tasaSuperacion: number | null
  ultimaPartida: string | null
}

interface JugadorRow {
  jugador_id: string
  alias: string
  niveles_superados: number
  parada_maxima: number | null
  puntos_totales: number | string
  tasa_superacion: number | string | null
  ultima_partida: string | null
}

export async function fetchJugadores(): Promise<Jugador[]> {
  const { data, error } = await supabase.rpc('jugadores_listado')
  if (error) throw error

  return ((data ?? []) as JugadorRow[]).map((row) => ({
    id: row.jugador_id,
    alias: row.alias,
    nivelesSuperados: row.niveles_superados,
    paradaMaxima: row.parada_maxima,
    puntosTotales: Number(row.puntos_totales),
    tasaSuperacion: row.tasa_superacion === null ? null : Number(row.tasa_superacion),
    ultimaPartida: row.ultima_partida,
  }))
}

export async function reiniciarProgresoJugador(jugadorId: string): Promise<void> {
  const { error } = await supabase.rpc('reiniciar_progreso_jugador', {
    p_jugador_id: jugadorId,
  })
  if (error) throw error
}
