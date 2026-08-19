import { describe, it, expect, vi, beforeEach } from 'vitest'
import { fetchJugadores, reiniciarProgresoJugador } from './jugadores'

const rpc = vi.fn()

vi.mock('./supabaseClient', () => ({
  supabase: {
    rpc: (...args: unknown[]) => rpc(...args),
  },
}))

beforeEach(() => {
  rpc.mockReset()
})

describe('fetchJugadores', () => {
  it('mapea las filas de jugadores_listado a camelCase, incluyendo nulos', async () => {
    rpc.mockResolvedValue({
      data: [
        {
          jugador_id: 'jugador-1',
          alias: 'mapachedeluxe',
          niveles_superados: 2,
          parada_maxima: 3,
          puntos_totales: '73389',
          tasa_superacion: '0.6667',
          ultima_partida: '2026-08-18T18:12:28.769947+00:00',
        },
        {
          jugador_id: 'jugador-2',
          alias: 'sinpartidas',
          niveles_superados: 0,
          parada_maxima: null,
          puntos_totales: 0,
          tasa_superacion: null,
          ultima_partida: null,
        },
      ],
      error: null,
    })

    const jugadores = await fetchJugadores()

    expect(rpc).toHaveBeenCalledWith('jugadores_listado')
    expect(jugadores).toEqual([
      {
        id: 'jugador-1',
        alias: 'mapachedeluxe',
        nivelesSuperados: 2,
        paradaMaxima: 3,
        puntosTotales: 73389,
        tasaSuperacion: 0.6667,
        ultimaPartida: '2026-08-18T18:12:28.769947+00:00',
      },
      {
        id: 'jugador-2',
        alias: 'sinpartidas',
        nivelesSuperados: 0,
        paradaMaxima: null,
        puntosTotales: 0,
        tasaSuperacion: null,
        ultimaPartida: null,
      },
    ])
  })

  it('devuelve una lista vacía si la RPC no trae filas', async () => {
    rpc.mockResolvedValue({ data: null, error: null })

    expect(await fetchJugadores()).toEqual([])
  })

  it('propaga el error si la RPC falla', async () => {
    rpc.mockResolvedValue({ data: null, error: new Error('rechazado') })

    await expect(fetchJugadores()).rejects.toThrow('rechazado')
  })
})

describe('reiniciarProgresoJugador', () => {
  it('invoca reiniciar_progreso_jugador con el id del jugador', async () => {
    rpc.mockResolvedValue({ data: null, error: null })

    await reiniciarProgresoJugador('jugador-1')

    expect(rpc).toHaveBeenCalledWith('reiniciar_progreso_jugador', { p_jugador_id: 'jugador-1' })
  })

  it('propaga el error si la RPC falla', async () => {
    rpc.mockResolvedValue({ data: null, error: new Error('Solo un admin puede reiniciar') })

    await expect(reiniciarProgresoJugador('jugador-1')).rejects.toThrow(
      'Solo un admin puede reiniciar',
    )
  })
})
