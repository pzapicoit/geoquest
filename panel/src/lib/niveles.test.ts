import { describe, it, expect, vi, beforeEach } from 'vitest'
import { fetchNivelesTematica, crearNivel, reordenarNiveles, eliminarNivel } from './niveles'

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

function selectEqSingle(data: unknown, error: unknown = null) {
  return { eq: () => ({ single: () => Promise.resolve({ data, error }) }) }
}

function selectEq(data: unknown, error: unknown = null) {
  return { eq: () => Promise.resolve({ data, error }) }
}

function selectEqOrder(data: unknown, error: unknown = null) {
  return { eq: () => ({ order: () => Promise.resolve({ data, error }) }) }
}

function selectIn(data: unknown, error: unknown = null) {
  return { in: () => Promise.resolve({ data, error }) }
}

describe('fetchNivelesTematica', () => {
  it('devuelve la temática, sus niveles ordenados y el recuento de preguntas', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'tematicas') {
        return {
          select: () =>
            selectEqSingle({
              id: 't-2',
              nombre: 'Paisajes de Europa',
              orden: 2,
            }),
        }
      }
      if (table === 'niveles') {
        return {
          select: () =>
            selectEqOrder([
              { id: 'n-1', nombre: 'Nivel 1', orden: 1, puntaje_minimo_superar: 900, activo: true },
              { id: 'n-2', nombre: null, orden: 2, puntaje_minimo_superar: 1000, activo: false },
            ]),
        }
      }
      if (table === 'nivel_desafios') {
        return { select: () => selectIn([{ nivel_id: 'n-1' }, { nivel_id: 'n-1' }]) }
      }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const resultado = await fetchNivelesTematica('t-2')

    expect(resultado).toEqual({
      tematicaId: 't-2',
      tematicaNombre: 'Paisajes de Europa',
      tematicaOrden: 2,
      niveles: [
        {
          id: 'n-1',
          nombre: 'Nivel 1',
          orden: 1,
          puntajeMinimoSuperar: 900,
          activo: true,
          cantidadPreguntas: 2,
        },
        {
          id: 'n-2',
          nombre: null,
          orden: 2,
          puntajeMinimoSuperar: 1000,
          activo: false,
          cantidadPreguntas: 0,
        },
      ],
    })
  })

  it('una temática sin niveles devuelve la lista vacía sin consultar nivel_desafios', async () => {
    const fromNivelDesafios = vi.fn()
    from.mockImplementation((table: string) => {
      if (table === 'tematicas') {
        return {
          select: () =>
            selectEqSingle({
              id: 't-1',
              nombre: 'Capitales del mundo',
              orden: 1,
            }),
        }
      }
      if (table === 'niveles') return { select: () => selectEqOrder([]) }
      if (table === 'nivel_desafios') {
        fromNivelDesafios()
        return { select: () => selectIn([]) }
      }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const resultado = await fetchNivelesTematica('t-1')

    expect(resultado.niveles).toEqual([])
    expect(fromNivelDesafios).not.toHaveBeenCalled()
  })

  it('propaga el error si falla la consulta de la temática', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'tematicas') {
        return { select: () => selectEqSingle(null, { message: 'no encontrada' }) }
      }
      throw new Error(`tabla inesperada: ${table}`)
    })

    await expect(fetchNivelesTematica('t-x')).rejects.toThrow('no encontrada')
  })
})

describe('crearNivel', () => {
  it('crea un nivel con orden = max(orden) + 1 y umbrales/puntaje en 0', async () => {
    const insert = vi.fn().mockResolvedValue({ error: null })
    from.mockImplementation((table: string) => {
      if (table === 'niveles') {
        return {
          select: () => selectEq([{ orden: 1 }, { orden: 2 }]),
          insert,
        }
      }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const { id } = await crearNivel('t-1', '  Nivel nuevo  ')

    expect(insert).toHaveBeenCalledWith(
      expect.objectContaining({
        id,
        tematica_id: 't-1',
        orden: 3,
        nombre: 'Nivel nuevo',
        puntaje_minimo_superar: 0,
        umbral_estrella_1: 0,
        umbral_estrella_2: 0,
        umbral_estrella_3: 0,
      }),
    )
  })

  it('crea el primer nivel de la temática con orden 1 cuando no hay niveles previos', async () => {
    const insert = vi.fn().mockResolvedValue({ error: null })
    from.mockImplementation(() => ({
      select: () => selectEq([]),
      insert,
    }))

    await crearNivel('t-1', 'Primer nivel')

    expect(insert).toHaveBeenCalledWith(expect.objectContaining({ orden: 1 }))
  })

  it('lanza un error si el nombre está vacío', async () => {
    await expect(crearNivel('t-1', '   ')).rejects.toThrow(/nombre/i)
    expect(from).not.toHaveBeenCalled()
  })

  it('propaga el error de la inserción', async () => {
    from.mockImplementation(() => ({
      select: () => selectEq([]),
      insert: vi.fn().mockResolvedValue({ error: { message: 'no autorizado' } }),
    }))

    await expect(crearNivel('t-1', 'Nivel')).rejects.toThrow('no autorizado')
  })
})

describe('reordenarNiveles', () => {
  it('llama a la RPC reordenar_niveles con la temática y el orden dado', async () => {
    rpc.mockResolvedValue({ error: null })

    await reordenarNiveles('t-1', ['n-2', 'n-1'])

    expect(rpc).toHaveBeenCalledWith('reordenar_niveles', {
      p_tematica_id: 't-1',
      ids_en_orden: ['n-2', 'n-1'],
    })
  })

  it('propaga el error de la RPC', async () => {
    rpc.mockResolvedValue({ error: { message: 'rechazado' } })

    await expect(reordenarNiveles('t-1', ['n-1'])).rejects.toThrow('rechazado')
  })
})

describe('eliminarNivel', () => {
  it('borra el nivel y recompacta el orden de los niveles restantes', async () => {
    const eqDelete = vi.fn().mockResolvedValue({ error: null })
    from.mockImplementation((table: string) => {
      if (table === 'niveles') {
        return {
          delete: () => ({ eq: eqDelete }),
          select: () => selectEqOrder([{ id: 'n-1' }, { id: 'n-3' }]),
        }
      }
      throw new Error(`tabla inesperada: ${table}`)
    })
    rpc.mockResolvedValue({ error: null })

    await eliminarNivel('t-1', 'n-2')

    expect(eqDelete).toHaveBeenCalledWith('id', 'n-2')
    expect(rpc).toHaveBeenCalledWith('reordenar_niveles', {
      p_tematica_id: 't-1',
      ids_en_orden: ['n-1', 'n-3'],
    })
  })

  it('no llama a la RPC de reorden si no quedan niveles restantes', async () => {
    from.mockImplementation(() => ({
      delete: () => ({ eq: vi.fn().mockResolvedValue({ error: null }) }),
      select: () => selectEqOrder([]),
    }))

    await eliminarNivel('t-1', 'n-1')

    expect(rpc).not.toHaveBeenCalled()
  })

  it('propaga el error del borrado', async () => {
    from.mockImplementation(() => ({
      delete: () => ({ eq: vi.fn().mockResolvedValue({ error: { message: 'no autorizado' } }) }),
    }))

    await expect(eliminarNivel('t-1', 'n-1')).rejects.toThrow('no autorizado')
  })
})
