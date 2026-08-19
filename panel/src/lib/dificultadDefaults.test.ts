import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  fetchDificultadDefaults,
  fetchUmbralesParada,
  guardarDificultadDefault,
  validarDificultadDefault,
} from './dificultadDefaults'

const from = vi.fn()
const rpc = vi.fn()

vi.mock('./supabaseClient', () => ({
  supabase: {
    from: (...args: unknown[]) => from(...args),
    rpc: (...args: unknown[]) => rpc(...args),
  },
}))

beforeEach(() => {
  from.mockReset()
  rpc.mockReset()
})

function filaDb(
  dificultad: string,
  overrides: Partial<{ preguntas_por_partida: number; segundos_por_desafio: number }> = {},
) {
  return {
    dificultad,
    preguntas_por_partida: 8,
    segundos_por_desafio: 60,
    ...overrides,
  }
}

describe('fetchDificultadDefaults', () => {
  it('devuelve las 5 dificultades en el orden del catálogo, con campos en camelCase', async () => {
    from.mockReturnValue({
      select: () =>
        Promise.resolve({
          data: [
            filaDb('muy_dificil'),
            filaDb('facil'),
            filaDb('normal'),
            filaDb('dificil'),
            filaDb('intermedio'),
          ],
          error: null,
        }),
    })

    const filas = await fetchDificultadDefaults()

    expect(filas.map((f) => f.dificultad)).toEqual([
      'facil',
      'normal',
      'intermedio',
      'dificil',
      'muy_dificil',
    ])
    expect(filas[0]).toEqual({
      dificultad: 'facil',
      preguntasPorPartida: 8,
      segundosPorDesafio: 60,
    })
  })

  it('lanza un error si falta la fila de alguna dificultad', async () => {
    from.mockReturnValue({
      select: () => Promise.resolve({ data: [filaDb('facil')], error: null }),
    })

    await expect(fetchDificultadDefaults()).rejects.toThrow(/normal/)
  })

  it('propaga el error de la consulta', async () => {
    from.mockReturnValue({
      select: () => Promise.resolve({ data: null, error: { message: 'fallo de red' } }),
    })

    await expect(fetchDificultadDefaults()).rejects.toThrow('fallo de red')
  })
})

describe('validarDificultadDefault', () => {
  const base = {
    dificultad: 'facil' as const,
    preguntasPorPartida: 8,
    segundosPorDesafio: 90,
  }

  it('acepta valores válidos', () => {
    expect(validarDificultadDefault(base)).toBeNull()
  })

  it('rechaza un valor no entero o no positivo', () => {
    expect(validarDificultadDefault({ ...base, preguntasPorPartida: 0 })).toMatch(
      /preguntas por partida/,
    )
    expect(validarDificultadDefault({ ...base, segundosPorDesafio: 1.5 })).toMatch(/segundos/)
  })
})

describe('guardarDificultadDefault', () => {
  it('actualiza la fila de la dificultad correspondiente', async () => {
    const eq = vi.fn().mockResolvedValue({ error: null })
    const update = vi.fn().mockReturnValue({ eq })
    from.mockReturnValue({ update })

    await guardarDificultadDefault({
      dificultad: 'dificil',
      preguntasPorPartida: 6,
      segundosPorDesafio: 45,
    })

    expect(from).toHaveBeenCalledWith('dificultad_defaults')
    expect(update).toHaveBeenCalledWith({
      preguntas_por_partida: 6,
      segundos_por_desafio: 45,
    })
    expect(eq).toHaveBeenCalledWith('dificultad', 'dificil')
  })

  it('no llama a supabase si la validación falla', async () => {
    await expect(
      guardarDificultadDefault({
        dificultad: 'facil',
        preguntasPorPartida: 0,
        segundosPorDesafio: 90,
      }),
    ).rejects.toThrow(/entero positivo/)
    expect(from).not.toHaveBeenCalled()
  })

  it('propaga el error de supabase', async () => {
    const eq = vi.fn().mockResolvedValue({ error: { message: 'no autorizado' } })
    from.mockReturnValue({ update: () => ({ eq }) })

    await expect(
      guardarDificultadDefault({
        dificultad: 'facil',
        preguntasPorPartida: 8,
        segundosPorDesafio: 90,
      }),
    ).rejects.toThrow('no autorizado')
  })
})

describe('fetchUmbralesParada', () => {
  it('llama a la RPC umbrales_parada y devuelve los umbrales en camelCase', async () => {
    const single = vi.fn().mockResolvedValue({
      data: { maximo: 44000, minimo: 19800, umbral_estrella_2: 28600, umbral_estrella_3: 36080 },
      error: null,
    })
    rpc.mockReturnValue({ single })

    const resultado = await fetchUmbralesParada('facil', 8)

    expect(rpc).toHaveBeenCalledWith('umbrales_parada', {
      p_dificultad: 'facil',
      p_preguntas_por_partida: 8,
    })
    expect(resultado).toEqual({
      maximo: 44000,
      minimo: 19800,
      umbralEstrella2: 28600,
      umbralEstrella3: 36080,
    })
  })

  it('propaga el error de la RPC', async () => {
    const single = vi.fn().mockResolvedValue({ data: null, error: { message: 'rechazado' } })
    rpc.mockReturnValue({ single })

    await expect(fetchUmbralesParada('facil', 8)).rejects.toThrow('rechazado')
  })
})
