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
    activo: true,
    prompt_imagen: 'la bandera sobre fondo neutro',
  },
  {
    id: 't-2',
    nombre: 'Paisajes de Europa',
    imagen_portada: 'https://example.test/t-2.jpg',
    orden: 2,
    activo: true,
    prompt_imagen: null,
  },
]

const CAMINO = [{ tematica_id: 't-1' }, { tematica_id: 't-1' }, { tematica_id: 't-2' }]

describe('fetchTematicas', () => {
  it('devuelve las temáticas ordenadas con el recuento de paradas del camino calculado', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'tematicas') return { select: () => selectable(TEMATICAS) }
      if (table === 'camino')
        return { select: () => Promise.resolve({ data: CAMINO, error: null }) }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const tematicas = await fetchTematicas()

    expect(tematicas).toEqual([
      {
        id: 't-1',
        nombre: 'Capitales del mundo',
        imagenPortada: 'https://example.test/t-1.jpg',
        orden: 1,
        activo: true,
        cantidadParadas: 2,
        promptImagen: 'la bandera sobre fondo neutro',
      },
      {
        id: 't-2',
        nombre: 'Paisajes de Europa',
        imagenPortada: 'https://example.test/t-2.jpg',
        orden: 2,
        activo: true,
        cantidadParadas: 1,
        promptImagen: null,
      },
    ])
  })

  it('una temática sin paradas en el camino tiene cantidadParadas 0', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'tematicas') return { select: () => selectable(TEMATICAS) }
      if (table === 'camino') return { select: () => Promise.resolve({ data: [], error: null }) }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const tematicas = await fetchTematicas()

    expect(tematicas.every((t) => t.cantidadParadas === 0)).toBe(true)
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
      activo: true,
      archivo: null,
      imagenPortadaActual: 'https://example.test/existing.jpg',
      promptImagen: null,
    })

    expect(insert).toHaveBeenCalledWith(
      expect.objectContaining({
        id,
        nombre: 'Nueva temática',
        orden: 3,
        activo: true,
      }),
    )
  })

  it('actualiza una temática existente por id', async () => {
    const eq = vi.fn().mockResolvedValue({ error: null })
    const update = vi.fn().mockReturnValue({ eq })
    from.mockReturnValue({ update })

    await guardarTematica({
      id: 't-1',
      nombre: 'Editada',
      activo: false,
      archivo: null,
      imagenPortadaActual: 'https://example.test/existing.jpg',
      promptImagen: null,
    })

    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({ nombre: 'Editada', activo: false }),
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
      activo: true,
      archivo: archivo('nueva.jpg', 'image/jpeg'),
      imagenPortadaActual: 'https://example.test/vieja.jpg',
      promptImagen: null,
    })

    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({ imagen_portada: 'https://cdn.test/nueva.jpg' }),
    )
  })

  it('guarda el prompt de imagen de la temática', async () => {
    const eq = vi.fn().mockResolvedValue({ error: null })
    const update = vi.fn().mockReturnValue({ eq })
    from.mockReturnValue({ update })

    await guardarTematica({
      id: 't-1',
      nombre: 'Banderas',
      activo: true,
      archivo: null,
      imagenPortadaActual: 'https://example.test/existing.jpg',
      promptImagen: '  la bandera sobre fondo neutro  ',
    })

    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({ prompt_imagen: 'la bandera sobre fondo neutro' }),
    )
  })

  it('guarda el prompt vacío como null, para no distinguir dos formas de "sin estilo"', async () => {
    const eq = vi.fn().mockResolvedValue({ error: null })
    const update = vi.fn().mockReturnValue({ eq })
    from.mockReturnValue({ update })

    await guardarTematica({
      id: 't-1',
      nombre: 'Banderas',
      activo: true,
      archivo: null,
      imagenPortadaActual: 'https://example.test/existing.jpg',
      promptImagen: '   ',
    })

    expect(update).toHaveBeenCalledWith(expect.objectContaining({ prompt_imagen: null }))
  })

  it('lanza un error si no hay portada (ni nueva ni actual)', async () => {
    await expect(
      guardarTematica({
        id: null,
        nombre: 'Sin portada',
        activo: true,
        archivo: null,
        imagenPortadaActual: null,
        promptImagen: null,
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

  it('traduce la violación de FK (desafíos propios) a un mensaje legible', async () => {
    const eq = vi.fn().mockResolvedValue({ error: { code: '23503' } })
    from.mockReturnValue({ delete: () => ({ eq }) })

    await expect(eliminarTematica('t-1')).rejects.toThrow(/preguntas propias/)
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
