import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  fetchCamino,
  fetchTematicasParaCamino,
  agregarParadaAlCamino,
  reordenarCamino,
  quitarDelCamino,
  actualizarOverridesParada,
  validarOverrides,
  calcularEstrellasRequeridas,
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

const CAMINO_PANEL_ROWS = [
  {
    id: 'c-1',
    orden: 1,
    tematica_id: 't-1',
    tematica_nombre: 'Monumentos',
    dificultad: 'facil',
    nombre: 'Torres',
    preguntas_por_partida: null,
    segundos_por_desafio: null,
  },
  {
    id: 'c-2',
    orden: 2,
    tematica_id: 't-2',
    tematica_nombre: 'Banderas',
    dificultad: 'dificil',
    nombre: null,
    preguntas_por_partida: 6,
    segundos_por_desafio: 45,
  },
]

describe('fetchCamino', () => {
  it('devuelve las posiciones con temática, dificultad y overrides resueltos, en orden', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'camino_panel') return { select: () => selectOrder(CAMINO_PANEL_ROWS) }
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
        preguntasPorPartida: null,
        segundosPorDesafio: null,
      },
      {
        id: 'c-2',
        orden: 2,
        tematicaId: 't-2',
        tematicaNombre: 'Banderas',
        dificultad: 'dificil',
        nombre: null,
        preguntasPorPartida: 6,
        segundosPorDesafio: 45,
      },
    ])
  })

  it('propaga el error si falla la consulta del camino', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'camino_panel') return { select: () => selectOrder(null, { message: 'rechazado' }) }
      throw new Error(`tabla inesperada: ${table}`)
    })

    await expect(fetchCamino()).rejects.toThrow('rechazado')
  })
})

describe('fetchTematicasParaCamino', () => {
  it('devuelve las temáticas ordenadas', async () => {
    const tematicas = [
      { id: 't-1', nombre: 'Monumentos' },
      { id: 't-2', nombre: 'Banderas' },
    ]
    from.mockReturnValue({ select: () => selectOrder(tematicas) })

    const resultado = await fetchTematicasParaCamino()

    expect(resultado).toEqual(tematicas)
  })
})

describe('agregarParadaAlCamino', () => {
  it('inserta en la última posición sin overrides y devuelve el id', async () => {
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

describe('calcularEstrellasRequeridas', () => {
  it('la posición 1 exige 0 estrellas', () => {
    expect(calcularEstrellasRequeridas(1)).toBe(0)
  })

  it('crece con la posición según floor((orden - 1) * 1.8)', () => {
    expect([1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(calcularEstrellasRequeridas)).toEqual([
      0, 1, 3, 5, 7, 9, 10, 12, 14, 16,
    ])
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
  const vacio = { preguntasPorPartida: null, segundosPorDesafio: null }

  it('acepta todos los overrides vacíos', () => {
    expect(validarOverrides(vacio)).toBeNull()
  })

  it('acepta overrides positivos', () => {
    expect(validarOverrides({ preguntasPorPartida: 6, segundosPorDesafio: 45 })).toBeNull()
  })

  it('rechaza un override no entero o no positivo', () => {
    expect(validarOverrides({ ...vacio, preguntasPorPartida: 0 })).toMatch(/entero positivo/)
    expect(validarOverrides({ ...vacio, segundosPorDesafio: 1.5 })).toMatch(/entero positivo/)
  })
})

describe('actualizarOverridesParada', () => {
  it('actualiza los 2 campos de override de la parada', async () => {
    const eq = vi.fn().mockResolvedValue({ error: null })
    const update = vi.fn().mockReturnValue({ eq })
    from.mockReturnValue({ update })

    await actualizarOverridesParada('c-1', { preguntasPorPartida: 5, segundosPorDesafio: null })

    expect(update).toHaveBeenCalledWith({
      preguntas_por_partida: 5,
      segundos_por_desafio: null,
    })
    expect(eq).toHaveBeenCalledWith('id', 'c-1')
  })

  it('propaga el error de la base de datos', async () => {
    const eq = vi.fn().mockResolvedValue({ error: { message: 'no autorizado' } })
    from.mockReturnValue({ update: () => ({ eq }) })

    await expect(
      actualizarOverridesParada('c-1', { preguntasPorPartida: null, segundosPorDesafio: null }),
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
