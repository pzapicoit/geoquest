import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  fetchCamino,
  fetchNivelesNoAsignados,
  agregarNivelAlCamino,
  reordenarCamino,
  actualizarEstrellasRequeridas,
  quitarDelCamino,
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
  { id: 'c-1', orden: 1, nivel_id: 'n-1', estrellas_requeridas: 0 },
  { id: 'c-2', orden: 2, nivel_id: 'n-2', estrellas_requeridas: 5 },
]

const NIVELES = [
  { id: 'n-1', nombre: 'Torres', orden: 1, tematica_id: 't-1' },
  { id: 'n-2', nombre: null, orden: 2, tematica_id: 't-2' },
]

const TEMATICAS = [
  { id: 't-1', nombre: 'Monumentos' },
  { id: 't-2', nombre: 'Banderas' },
]

describe('fetchCamino', () => {
  it('devuelve las posiciones con nivel y temática resueltos, en orden', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'camino') return { select: () => selectOrder(CAMINO_ROWS) }
      if (table === 'niveles') return { select: () => selectIn(NIVELES) }
      if (table === 'tematicas') return { select: () => selectIn(TEMATICAS) }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const resultado = await fetchCamino()

    expect(resultado).toEqual([
      {
        id: 'c-1',
        orden: 1,
        nivelId: 'n-1',
        nivelNombre: 'Torres',
        tematicaNombre: 'Monumentos',
        estrellasRequeridas: 0,
      },
      {
        id: 'c-2',
        orden: 2,
        nivelId: 'n-2',
        nivelNombre: 'Nivel 2',
        tematicaNombre: 'Banderas',
        estrellasRequeridas: 5,
      },
    ])
  })

  it('un nivel que ya no existe se muestra como "Nivel eliminado"', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'camino') return { select: () => selectOrder([CAMINO_ROWS[0]]) }
      if (table === 'niveles') return { select: () => selectIn([]) }
      if (table === 'tematicas') return { select: () => selectIn([]) }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const resultado = await fetchCamino()

    expect(resultado[0]).toMatchObject({ nivelNombre: 'Nivel eliminado', tematicaNombre: '—' })
  })

  it('un camino vacío no consulta niveles ni tematicas', async () => {
    const fromNiveles = vi.fn()
    from.mockImplementation((table: string) => {
      if (table === 'camino') return { select: () => selectOrder([]) }
      if (table === 'niveles') {
        fromNiveles()
        return { select: () => selectIn([]) }
      }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const resultado = await fetchCamino()

    expect(resultado).toEqual([])
    expect(fromNiveles).not.toHaveBeenCalled()
  })

  it('propaga el error si falla la consulta del camino', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'camino') return { select: () => selectOrder(null, { message: 'rechazado' }) }
      throw new Error(`tabla inesperada: ${table}`)
    })

    await expect(fetchCamino()).rejects.toThrow('rechazado')
  })
})

describe('fetchNivelesNoAsignados', () => {
  it('excluye los niveles ya presentes en el camino', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'niveles')
        return { select: () => Promise.resolve({ data: NIVELES, error: null }) }
      if (table === 'tematicas')
        return { select: () => Promise.resolve({ data: TEMATICAS, error: null }) }
      if (table === 'camino')
        return { select: () => Promise.resolve({ data: [{ nivel_id: 'n-1' }], error: null }) }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const resultado = await fetchNivelesNoAsignados()

    expect(resultado).toEqual([{ id: 'n-2', nombre: 'Nivel 2', tematicaNombre: 'Banderas' }])
  })

  it('propaga el error si falla alguna de las consultas', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'niveles')
        return { select: () => Promise.resolve({ data: null, error: { message: 'rechazado' } }) }
      return { select: () => Promise.resolve({ data: [], error: null }) }
    })

    await expect(fetchNivelesNoAsignados()).rejects.toThrow('rechazado')
  })
})

describe('agregarNivelAlCamino', () => {
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

    const { id } = await agregarNivelAlCamino('n-9')

    expect(id).toBe('c-9')
    expect(insert).toHaveBeenCalledWith({ nivel_id: 'n-9', orden: 3, estrellas_requeridas: 0 })
  })

  it('traduce el error de unicidad a un mensaje legible', async () => {
    const single = vi.fn().mockResolvedValue({ data: null, error: { code: '23505' } })
    from.mockImplementation(() => ({
      select: () => Promise.resolve({ data: [], error: null }),
      insert: () => ({ select: () => ({ single }) }),
    }))

    await expect(agregarNivelAlCamino('n-9')).rejects.toThrow(/a la vez/)
  })

  it('propaga otros errores de la inserción', async () => {
    const single = vi.fn().mockResolvedValue({ data: null, error: { message: 'no autorizado' } })
    from.mockImplementation(() => ({
      select: () => Promise.resolve({ data: [], error: null }),
      insert: () => ({ select: () => ({ single }) }),
    }))

    await expect(agregarNivelAlCamino('n-9')).rejects.toThrow('no autorizado')
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

  it('rechaza un valor no entero sin llamar a supabase', async () => {
    await expect(actualizarEstrellasRequeridas('c-1', 1.5)).rejects.toThrow(/igual o mayor a 0/)
    expect(from).not.toHaveBeenCalled()
  })

  it('propaga el error de la base de datos', async () => {
    const eq = vi.fn().mockResolvedValue({ error: { message: 'no autorizado' } })
    from.mockReturnValue({ update: () => ({ eq }) })

    await expect(actualizarEstrellasRequeridas('c-1', 5)).rejects.toThrow('no autorizado')
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

  it('no llama a la RPC de reorden si no quedan posiciones restantes', async () => {
    from.mockImplementation(() => ({
      delete: () => ({ eq: vi.fn().mockResolvedValue({ error: null }) }),
      select: () => selectOrder([]),
    }))

    await quitarDelCamino('c-1')

    expect(rpc).not.toHaveBeenCalled()
  })

  it('propaga el error del borrado', async () => {
    from.mockImplementation(() => ({
      delete: () => ({ eq: vi.fn().mockResolvedValue({ error: { message: 'no autorizado' } }) }),
    }))

    await expect(quitarDelCamino('c-1')).rejects.toThrow('no autorizado')
  })
})
