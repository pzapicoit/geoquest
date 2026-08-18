import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  fetchCamino,
  fetchTematicasParaCamino,
  agregarParadaAlCamino,
  reordenarCamino,
  actualizarEstrellasRequeridas,
  quitarDelCamino,
  actualizarOverridesParada,
  validarOverrides,
  nombreParada,
} from './camino'

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

function selectOrder(data: unknown[] | null, error: unknown = null) {
  return { order: () => Promise.resolve({ data, error }) }
}

function selectIn(data: unknown[] | null, error: unknown = null) {
  return { in: () => Promise.resolve({ data, error }) }
}

const CAMINO_ROWS = [
  {
    id: 'c-1',
    orden: 1,
    tematica_id: 't-1',
    dificultad: 'facil',
    nombre: 'Torres',
    estrellas_requeridas: 0,
    preguntas_por_partida: null,
    segundos_por_desafio: null,
    puntaje_minimo_superar: null,
    umbral_estrella_2: null,
    umbral_estrella_3: null,
  },
  {
    id: 'c-2',
    orden: 2,
    tematica_id: 't-2',
    dificultad: 'dificil',
    nombre: null,
    estrellas_requeridas: 5,
    preguntas_por_partida: 6,
    segundos_por_desafio: 45,
    puntaje_minimo_superar: 21600,
    umbral_estrella_2: 25800,
    umbral_estrella_3: 28740,
  },
]

const TEMATICAS = [
  { id: 't-1', nombre: 'Monumentos' },
  { id: 't-2', nombre: 'Banderas' },
]

describe('fetchCamino', () => {
  it('devuelve las posiciones con temática, dificultad y overrides resueltos, en orden', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'camino') return { select: () => selectOrder(CAMINO_ROWS) }
      if (table === 'tematicas') return { select: () => selectIn(TEMATICAS) }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const resultado = await fetchCamino()

    expect(resultado).toEqual([
      {
        id: 'c-1',
        orden: 1,
        tematicaId: 't-1',
        tematicaNombre: 'Monumentos',
        dificultad: 'facil',
        nombre: 'Torres',
        estrellasRequeridas: 0,
        preguntasPorPartida: null,
        segundosPorDesafio: null,
        puntajeMinimoSuperar: null,
        umbralEstrella2: null,
        umbralEstrella3: null,
      },
      {
        id: 'c-2',
        orden: 2,
        tematicaId: 't-2',
        tematicaNombre: 'Banderas',
        dificultad: 'dificil',
        nombre: null,
        estrellasRequeridas: 5,
        preguntasPorPartida: 6,
        segundosPorDesafio: 45,
        puntajeMinimoSuperar: 21600,
        umbralEstrella2: 25800,
        umbralEstrella3: 28740,
      },
    ])
  })

  it('una temática que ya no existe se muestra como "Temática eliminada"', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'camino') return { select: () => selectOrder([CAMINO_ROWS[0]]) }
      if (table === 'tematicas') return { select: () => selectIn([]) }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const resultado = await fetchCamino()

    expect(resultado[0]).toMatchObject({ tematicaNombre: 'Temática eliminada' })
  })

  it('un camino vacío no consulta temáticas', async () => {
    const fromTematicas = vi.fn()
    from.mockImplementation((table: string) => {
      if (table === 'camino') return { select: () => selectOrder([]) }
      if (table === 'tematicas') {
        fromTematicas()
        return { select: () => selectIn([]) }
      }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const resultado = await fetchCamino()

    expect(resultado).toEqual([])
    expect(fromTematicas).not.toHaveBeenCalled()
  })

  it('propaga el error si falla la consulta del camino', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'camino') return { select: () => selectOrder(null, { message: 'rechazado' }) }
      throw new Error(`tabla inesperada: ${table}`)
    })

    await expect(fetchCamino()).rejects.toThrow('rechazado')
  })
})

describe('fetchTematicasParaCamino', () => {
  it('devuelve las temáticas ordenadas', async () => {
    from.mockReturnValue({ select: () => selectOrder(TEMATICAS) })

    const resultado = await fetchTematicasParaCamino()

    expect(resultado).toEqual(TEMATICAS)
  })
})

describe('agregarParadaAlCamino', () => {
  it('inserta en la última posición con estrellas_requeridas en 0 y devuelve el id', async () => {
    const single = vi.fn().mockResolvedValue({ data: { id: 'c-9' }, error: null })
    const insert = vi.fn().mockReturnValue({ select: () => ({ single }) })
    from.mockImplementation((table: string) => {
      if (table === 'camino') {
        return {
          select: () => Promise.resolve({ data: [{ orden: 1 }, { orden: 2 }], error: null }),
          insert,
        }
      }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const { id } = await agregarParadaAlCamino('t-9', 'muy_dificil')

    expect(id).toBe('c-9')
    expect(insert).toHaveBeenCalledWith({
      tematica_id: 't-9',
      dificultad: 'muy_dificil',
      orden: 3,
      estrellas_requeridas: 0,
    })
  })

  it('traduce el error de unicidad a un mensaje legible', async () => {
    const single = vi.fn().mockResolvedValue({ data: null, error: { code: '23505' } })
    from.mockImplementation(() => ({
      select: () => Promise.resolve({ data: [], error: null }),
      insert: () => ({ select: () => ({ single }) }),
    }))

    await expect(agregarParadaAlCamino('t-9', 'facil')).rejects.toThrow(/a la vez/)
  })

  it('propaga otros errores de la inserción', async () => {
    const single = vi.fn().mockResolvedValue({ data: null, error: { message: 'no autorizado' } })
    from.mockImplementation(() => ({
      select: () => Promise.resolve({ data: [], error: null }),
      insert: () => ({ select: () => ({ single }) }),
    }))

    await expect(agregarParadaAlCamino('t-9', 'facil')).rejects.toThrow('no autorizado')
  })
})

describe('reordenarCamino', () => {
  it('llama a la RPC reordenar_camino con el orden dado', async () => {
    rpc.mockResolvedValue({ error: null })

    await reordenarCamino(['c-2', 'c-1'])

    expect(rpc).toHaveBeenCalledWith('reordenar_camino', { ids_en_orden: ['c-2', 'c-1'] })
  })

  it('propaga el error de la RPC', async () => {
    rpc.mockResolvedValue({ error: { message: 'rechazado' } })

    await expect(reordenarCamino(['c-1'])).rejects.toThrow('rechazado')
  })
})

describe('actualizarEstrellasRequeridas', () => {
  it('actualiza la fila con un valor válido', async () => {
    const eq = vi.fn().mockResolvedValue({ error: null })
    const update = vi.fn().mockReturnValue({ eq })
    from.mockReturnValue({ update })

    await actualizarEstrellasRequeridas('c-1', 5)

    expect(update).toHaveBeenCalledWith({ estrellas_requeridas: 5 })
    expect(eq).toHaveBeenCalledWith('id', 'c-1')
  })

  it('rechaza un valor negativo sin llamar a supabase', async () => {
    await expect(actualizarEstrellasRequeridas('c-1', -1)).rejects.toThrow(/igual o mayor a 0/)
    expect(from).not.toHaveBeenCalled()
  })
})

describe('quitarDelCamino', () => {
  it('borra la posición y recompacta el orden de las restantes', async () => {
    const eqDelete = vi.fn().mockResolvedValue({ error: null })
    from.mockImplementation((table: string) => {
      if (table === 'camino') {
        return {
          delete: () => ({ eq: eqDelete }),
          select: () => selectOrder([{ id: 'c-1' }, { id: 'c-3' }]),
        }
      }
      throw new Error(`tabla inesperada: ${table}`)
    })
    rpc.mockResolvedValue({ error: null })

    await quitarDelCamino('c-2')

    expect(eqDelete).toHaveBeenCalledWith('id', 'c-2')
    expect(rpc).toHaveBeenCalledWith('reordenar_camino', { ids_en_orden: ['c-1', 'c-3'] })
  })

  it('propaga el error del borrado', async () => {
    from.mockImplementation(() => ({
      delete: () => ({ eq: vi.fn().mockResolvedValue({ error: { message: 'no autorizado' } }) }),
    }))

    await expect(quitarDelCamino('c-1')).rejects.toThrow('no autorizado')
  })
})

describe('validarOverrides', () => {
  const defaults = { puntajeMinimoSuperar: 18000, umbralEstrella2: 29000, umbralEstrella3: 36700 }
  const vacio = {
    preguntasPorPartida: null,
    segundosPorDesafio: null,
    puntajeMinimoSuperar: null,
    umbralEstrella2: null,
    umbralEstrella3: null,
  }

  it('acepta todos los overrides vacíos (usa los defaults, que ya son ascendentes)', () => {
    expect(validarOverrides(vacio, defaults)).toBeNull()
  })

  it('acepta un override parcial que mantiene el orden efectivo', () => {
    expect(validarOverrides({ ...vacio, puntajeMinimoSuperar: 25000 }, defaults)).toBeNull()
  })

  it('rechaza un override que rompe el orden efectivo con los defaults', () => {
    expect(validarOverrides({ ...vacio, puntajeMinimoSuperar: 30000 }, defaults)).toMatch(
      /ascendentes/,
    )
  })

  it('rechaza un override no entero o no positivo', () => {
    expect(validarOverrides({ ...vacio, preguntasPorPartida: 0 }, defaults)).toMatch(
      /entero positivo/,
    )
  })
})

describe('actualizarOverridesParada', () => {
  it('actualiza los 5 campos de override de la parada', async () => {
    const eq = vi.fn().mockResolvedValue({ error: null })
    const update = vi.fn().mockReturnValue({ eq })
    from.mockReturnValue({ update })

    await actualizarOverridesParada('c-1', {
      preguntasPorPartida: 5,
      segundosPorDesafio: null,
      puntajeMinimoSuperar: 25000,
      umbralEstrella2: null,
      umbralEstrella3: null,
    })

    expect(update).toHaveBeenCalledWith({
      preguntas_por_partida: 5,
      segundos_por_desafio: null,
      puntaje_minimo_superar: 25000,
      umbral_estrella_2: null,
      umbral_estrella_3: null,
    })
    expect(eq).toHaveBeenCalledWith('id', 'c-1')
  })

  it('propaga el error de la base de datos', async () => {
    const eq = vi.fn().mockResolvedValue({ error: { message: 'no autorizado' } })
    from.mockReturnValue({ update: () => ({ eq }) })

    await expect(
      actualizarOverridesParada('c-1', {
        preguntasPorPartida: null,
        segundosPorDesafio: null,
        puntajeMinimoSuperar: null,
        umbralEstrella2: null,
        umbralEstrella3: null,
      }),
    ).rejects.toThrow('no autorizado')
  })
})

describe('nombreParada', () => {
  it('usa el nombre propio si existe', () => {
    expect(
      nombreParada({
        nombre: 'Costas del Mediterráneo',
        tematicaNombre: 'Paisajes',
        dificultad: 'facil',
      }),
    ).toBe('Costas del Mediterráneo')
  })

  it('usa "temática · dificultad" cuando no hay nombre propio', () => {
    expect(nombreParada({ nombre: null, tematicaNombre: 'Paisajes', dificultad: 'facil' })).toBe(
      'Paisajes · Fácil',
    )
  })
})
