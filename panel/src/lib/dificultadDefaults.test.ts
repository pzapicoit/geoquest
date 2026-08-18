import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  fetchDificultadDefaults,
  guardarDificultadDefault,
  validarDificultadDefault,
} from './dificultadDefaults'

const from = vi.fn()

vi.mock('./supabaseClient', () => ({
  supabase: { from: (...args: unknown[]) => from(...args) },
}))

beforeEach(() => {
  from.mockReset()
})

function filaDb(
  dificultad: string,
  overrides: Partial<{
    preguntas_por_partida: number
    segundos_por_desafio: number
    puntaje_minimo_superar: number
    umbral_estrella_2: number
    umbral_estrella_3: number
  }> = {},
) {
  return {
    dificultad,
    preguntas_por_partida: 8,
    segundos_por_desafio: 60,
    puntaje_minimo_superar: 18000,
    umbral_estrella_2: 29000,
    umbral_estrella_3: 36700,
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
      puntajeMinimoSuperar: 18000,
      umbralEstrella2: 29000,
      umbralEstrella3: 36700,
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
    puntajeMinimoSuperar: 18000,
    umbralEstrella2: 29000,
    umbralEstrella3: 36700,
  }

  it('acepta valores válidos y ascendentes', () => {
    expect(validarDificultadDefault(base)).toBeNull()
  })

  it('rechaza un valor no entero o no positivo', () => {
    expect(validarDificultadDefault({ ...base, preguntasPorPartida: 0 })).toMatch(
      /preguntas por partida/,
    )
    expect(validarDificultadDefault({ ...base, segundosPorDesafio: 1.5 })).toMatch(/segundos/)
  })

  it('rechaza umbrales fuera de orden', () => {
    expect(
      validarDificultadDefault({ ...base, umbralEstrella2: 10000, umbralEstrella3: 5000 }),
    ).toMatch(/ascendentes/)
    expect(validarDificultadDefault({ ...base, puntajeMinimoSuperar: 40000 })).toMatch(
      /ascendentes/,
    )
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
      puntajeMinimoSuperar: 21600,
      umbralEstrella2: 25800,
      umbralEstrella3: 28740,
    })

    expect(from).toHaveBeenCalledWith('dificultad_defaults')
    expect(update).toHaveBeenCalledWith({
      preguntas_por_partida: 6,
      segundos_por_desafio: 45,
      puntaje_minimo_superar: 21600,
      umbral_estrella_2: 25800,
      umbral_estrella_3: 28740,
    })
    expect(eq).toHaveBeenCalledWith('dificultad', 'dificil')
  })

  it('no llama a supabase si la validación falla', async () => {
    await expect(
      guardarDificultadDefault({
        dificultad: 'facil',
        preguntasPorPartida: 8,
        segundosPorDesafio: 90,
        puntajeMinimoSuperar: 30000,
        umbralEstrella2: 20000,
        umbralEstrella3: 36700,
      }),
    ).rejects.toThrow(/ascendentes/)
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
        puntajeMinimoSuperar: 18000,
        umbralEstrella2: 29000,
        umbralEstrella3: 36700,
      }),
    ).rejects.toThrow('no autorizado')
  })
})
