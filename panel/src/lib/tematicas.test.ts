import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  fetchTematicas,
  validarImagenPortada,
  subirPortadaTematica,
  guardarTematica,
  eliminarTematica,
  reordenarTematicas,
} from './tematicas'

const from = vi.fn()
const rpc = vi.fn()
const storageFrom = vi.fn()

vi.mock('./supabaseClient', () => ({
  supabase: {
    from: (...args: unknown[]) => from(...args),
    rpc: (...args: unknown[]) => rpc(...args),
    storage: { from: (...args: unknown[]) => storageFrom(...args) },
  },
}))

beforeEach(() => {
  from.mockReset()
  rpc.mockReset()
  storageFrom.mockReset()
})

function archivo(nombre: string, tipo: string, bytes = 1024) {
  return new File([new Uint8Array(bytes)], nombre, { type: tipo })
}

function selectable(data: unknown[] | null, error: unknown = null) {
  return { order: () => Promise.resolve({ data, error }) }
}

const TEMATICAS = [
  {
    id: 't-1',
    nombre: 'Capitales del mundo',
    imagen_portada: 'https://example.test/t-1.jpg',
    orden: 1,
    estrellas_requeridas: 0,
    activo: true,
  },
  {
    id: 't-2',
    nombre: 'Paisajes de Europa',
    imagen_portada: 'https://example.test/t-2.jpg',
    orden: 2,
    estrellas_requeridas: 18,
    activo: true,
  },
]

const NIVELES = [{ tematica_id: 't-1' }, { tematica_id: 't-1' }, { tematica_id: 't-2' }]

describe('fetchTematicas', () => {
  it('devuelve las temáticas ordenadas con el recuento de niveles calculado', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'tematicas') return { select: () => selectable(TEMATICAS) }
      if (table === 'niveles')
        return { select: () => Promise.resolve({ data: NIVELES, error: null }) }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const tematicas = await fetchTematicas()

    expect(tematicas).toEqual([
      {
        id: 't-1',
        nombre: 'Capitales del mundo',
        imagenPortada: 'https://example.test/t-1.jpg',
        orden: 1,
        estrellasRequeridas: 0,
        activo: true,
        cantidadNiveles: 2,
      },
      {
        id: 't-2',
        nombre: 'Paisajes de Europa',
        imagenPortada: 'https://example.test/t-2.jpg',
        orden: 2,
        estrellasRequeridas: 18,
        activo: true,
        cantidadNiveles: 1,
      },
    ])
  })

  it('una temática sin niveles tiene cantidadNiveles 0', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'tematicas') return { select: () => selectable(TEMATICAS) }
      if (table === 'niveles') return { select: () => Promise.resolve({ data: [], error: null }) }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const tematicas = await fetchTematicas()

    expect(tematicas.every((t) => t.cantidadNiveles === 0)).toBe(true)
  })

  it('propaga el error si falla la consulta de temáticas', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'tematicas') return { select: () => selectable(null, new Error('rechazado')) }
      return { select: () => Promise.resolve({ data: [], error: null }) }
    })

    await expect(fetchTematicas()).rejects.toThrow('rechazado')
  })
})

describe('validarImagenPortada', () => {
  it('acepta un jpg dentro del límite de tamaño', () => {
    expect(validarImagenPortada(archivo('portada.jpg', 'image/jpeg', 1024))).toBeNull()
  })

  it('rechaza un tipo no permitido', () => {
    expect(validarImagenPortada(archivo('portada.webp', 'image/webp'))).toMatch(/JPG o PNG/)
  })

  it('rechaza un archivo que supera 4 MB', () => {
    expect(validarImagenPortada(archivo('portada.png', 'image/png', 4 * 1024 * 1024 + 1))).toMatch(
      /4 MB/,
    )
  })
})

describe('subirPortadaTematica', () => {
  it('sube el archivo a tematicas/{id}.{extension} y devuelve la URL pública', async () => {
    const upload = vi.fn().mockResolvedValue({ error: null })
    const getPublicUrl = vi
      .fn()
      .mockReturnValue({ data: { publicUrl: 'https://cdn.test/t-1.jpg' } })
    storageFrom.mockReturnValue({ upload, getPublicUrl })

    const url = await subirPortadaTematica('t-1', archivo('portada.jpg', 'image/jpeg'))

    expect(storageFrom).toHaveBeenCalledWith('challenge-media')
    expect(upload).toHaveBeenCalledWith(
      'tematicas/t-1.jpg',
      expect.any(File),
      expect.objectContaining({ upsert: true, contentType: 'image/jpeg' }),
    )
    expect(url).toBe('https://cdn.test/t-1.jpg')
  })

  it('propaga el error de la subida', async () => {
    storageFrom.mockReturnValue({
      upload: vi.fn().mockResolvedValue({ error: { message: 'cuota superada' } }),
    })

    await expect(subirPortadaTematica('t-1', archivo('portada.jpg', 'image/jpeg'))).rejects.toThrow(
      'cuota superada',
    )
  })
})

describe('guardarTematica', () => {
  it('crea una temática nueva con orden = max(orden) + 1', async () => {
    const insert = vi.fn().mockResolvedValue({ error: null })
    from.mockImplementation((table: string) => {
      if (table === 'tematicas') {
        return {
          select: () => Promise.resolve({ data: [{ orden: 1 }, { orden: 2 }], error: null }),
          insert,
        }
      }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const { id } = await guardarTematica({
      id: null,
      nombre: 'Nueva temática',
      estrellasRequeridas: 12,
      activo: true,
      esPrimera: false,
      archivo: null,
      imagenPortadaActual: 'https://example.test/existing.jpg',
    })

    expect(insert).toHaveBeenCalledWith(
      expect.objectContaining({
        id,
        nombre: 'Nueva temática',
        orden: 3,
        estrellas_requeridas: 12,
        activo: true,
      }),
    )
  })

  it('fuerza estrellas_requeridas a 0 cuando esPrimera es true', async () => {
    const insert = vi.fn().mockResolvedValue({ error: null })
    from.mockImplementation(() => ({
      select: () => Promise.resolve({ data: [], error: null }),
      insert,
    }))

    await guardarTematica({
      id: null,
      nombre: 'Primera',
      estrellasRequeridas: 40,
      activo: true,
      esPrimera: true,
      archivo: null,
      imagenPortadaActual: 'https://example.test/existing.jpg',
    })

    expect(insert).toHaveBeenCalledWith(expect.objectContaining({ estrellas_requeridas: 0 }))
  })

  it('actualiza una temática existente por id', async () => {
    const eq = vi.fn().mockResolvedValue({ error: null })
    const update = vi.fn().mockReturnValue({ eq })
    from.mockReturnValue({ update })

    await guardarTematica({
      id: 't-1',
      nombre: 'Editada',
      estrellasRequeridas: 20,
      activo: false,
      esPrimera: false,
      archivo: null,
      imagenPortadaActual: 'https://example.test/existing.jpg',
    })

    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({ nombre: 'Editada', estrellas_requeridas: 20, activo: false }),
    )
    expect(eq).toHaveBeenCalledWith('id', 't-1')
  })

  it('sube la portada nueva antes de guardar cuando se selecciona un archivo', async () => {
    const upload = vi.fn().mockResolvedValue({ error: null })
    const getPublicUrl = vi
      .fn()
      .mockReturnValue({ data: { publicUrl: 'https://cdn.test/nueva.jpg' } })
    storageFrom.mockReturnValue({ upload, getPublicUrl })

    const eq = vi.fn().mockResolvedValue({ error: null })
    const update = vi.fn().mockReturnValue({ eq })
    from.mockReturnValue({ update })

    await guardarTematica({
      id: 't-1',
      nombre: 'Editada',
      estrellasRequeridas: 20,
      activo: true,
      esPrimera: false,
      archivo: archivo('nueva.jpg', 'image/jpeg'),
      imagenPortadaActual: 'https://example.test/vieja.jpg',
    })

    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({ imagen_portada: 'https://cdn.test/nueva.jpg' }),
    )
  })

  it('lanza un error si no hay portada (ni nueva ni actual)', async () => {
    await expect(
      guardarTematica({
        id: null,
        nombre: 'Sin portada',
        estrellasRequeridas: 0,
        activo: true,
        esPrimera: true,
        archivo: null,
        imagenPortadaActual: null,
      }),
    ).rejects.toThrow(/portada/i)
  })
})

describe('eliminarTematica', () => {
  it('borra la temática', async () => {
    const eq = vi.fn().mockResolvedValue({ error: null })
    from.mockReturnValue({ delete: () => ({ eq }) })

    await expect(eliminarTematica('t-1')).resolves.toBeUndefined()
    expect(from).toHaveBeenCalledWith('tematicas')
    expect(eq).toHaveBeenCalledWith('id', 't-1')
  })

  it('propaga el error de la base de datos', async () => {
    const eq = vi.fn().mockResolvedValue({ error: { message: 'no autorizado' } })
    from.mockReturnValue({ delete: () => ({ eq }) })

    await expect(eliminarTematica('t-1')).rejects.toThrow('no autorizado')
  })
})

describe('reordenarTematicas', () => {
  it('llama a la RPC reordenar_tematicas con el orden dado', async () => {
    rpc.mockResolvedValue({ error: null })

    await reordenarTematicas(['t-2', 't-1'])

    expect(rpc).toHaveBeenCalledWith('reordenar_tematicas', { ids_en_orden: ['t-2', 't-1'] })
  })

  it('propaga el error de la RPC', async () => {
    rpc.mockResolvedValue({ error: { message: 'rechazado' } })

    await expect(reordenarTematicas(['t-1'])).rejects.toThrow('rechazado')
  })
})
