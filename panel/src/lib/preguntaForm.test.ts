import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  fetchPregunta,
  fetchNivelesParaAsignar,
  validarArchivoMedia,
  subirMediaDesafio,
  guardarPregunta,
  asignarPreguntaANiveles,
} from './preguntaForm'

const from = vi.fn()
const storageFrom = vi.fn()

vi.mock('./supabaseClient', () => ({
  supabase: {
    from: (...args: unknown[]) => from(...args),
    storage: { from: (...args: unknown[]) => storageFrom(...args) },
  },
}))

beforeEach(() => {
  from.mockReset()
  storageFrom.mockReset()
})

function archivo(nombre: string, tipo: string, bytes = 1024) {
  return new File([new Uint8Array(bytes)], nombre, { type: tipo })
}

describe('fetchPregunta', () => {
  it('devuelve una pregunta con sus campos en camelCase', async () => {
    const single = vi.fn().mockResolvedValue({
      data: {
        id: 'd-1',
        tipo: 'imagen',
        nombre_lugar: 'Torre Eiffel',
        texto_pregunta: null,
        imagen_url: 'https://example.test/eiffel.jpg',
        video_url: null,
        lat_real: 48.8584,
        lng_real: 2.2945,
        activo: true,
      },
      error: null,
    })
    const eq = vi.fn().mockReturnValue({ single })
    from.mockReturnValue({ select: () => ({ eq }) })

    const pregunta = await fetchPregunta('d-1')

    expect(from).toHaveBeenCalledWith('desafios')
    expect(eq).toHaveBeenCalledWith('id', 'd-1')
    expect(pregunta).toEqual({
      id: 'd-1',
      tipo: 'imagen',
      nombreLugar: 'Torre Eiffel',
      textoPregunta: null,
      imagenUrl: 'https://example.test/eiffel.jpg',
      videoUrl: null,
      latReal: 48.8584,
      lngReal: 2.2945,
      activo: true,
    })
  })

  it('propaga el error si la pregunta no existe o falla la consulta', async () => {
    const single = vi.fn().mockResolvedValue({ data: null, error: { message: 'no encontrada' } })
    from.mockReturnValue({ select: () => ({ eq: () => ({ single }) }) })

    await expect(fetchPregunta('d-x')).rejects.toThrow('no encontrada')
  })
})

describe('fetchNivelesParaAsignar', () => {
  it('combina niveles, temáticas y conteo de asignaciones, ordenado por temática y nivel', async () => {
    from.mockImplementation((table: string) => ({
      select: () => {
        if (table === 'niveles') {
          return Promise.resolve({
            data: [
              { id: 'n-2', orden: 2, tematica_id: 't-patrimonio' },
              { id: 'n-1', orden: 3, tematica_id: 't-paisajes' },
            ],
            error: null,
          })
        }
        if (table === 'tematicas') {
          return Promise.resolve({
            data: [
              { id: 't-paisajes', nombre: 'Paisajes' },
              { id: 't-patrimonio', nombre: 'Patrimonio' },
            ],
            error: null,
          })
        }
        if (table === 'nivel_desafios') {
          return Promise.resolve({
            data: [{ nivel_id: 'n-1' }, { nivel_id: 'n-1' }, { nivel_id: 'n-2' }],
            error: null,
          })
        }
        throw new Error(`tabla inesperada: ${table}`)
      },
    }))

    const niveles = await fetchNivelesParaAsignar()

    expect(niveles).toEqual([
      { id: 'n-1', tematicaNombre: 'Paisajes', nivelOrden: 3, cantidadPreguntas: 2 },
      { id: 'n-2', tematicaNombre: 'Patrimonio', nivelOrden: 2, cantidadPreguntas: 1 },
    ])
  })

  it('un nivel sin asignaciones tiene cantidadPreguntas 0', async () => {
    from.mockImplementation((table: string) => ({
      select: () => {
        if (table === 'niveles') {
          return Promise.resolve({
            data: [{ id: 'n-1', orden: 1, tematica_id: 't-1' }],
            error: null,
          })
        }
        if (table === 'tematicas') {
          return Promise.resolve({ data: [{ id: 't-1', nombre: 'Geografía' }], error: null })
        }
        return Promise.resolve({ data: [], error: null })
      },
    }))

    const niveles = await fetchNivelesParaAsignar()

    expect(niveles[0]).toMatchObject({ cantidadPreguntas: 0 })
  })
})

describe('validarArchivoMedia', () => {
  it('acepta una imagen jpg/png/webp dentro del límite de tamaño', () => {
    expect(validarArchivoMedia('imagen', archivo('foto.png', 'image/png'))).toBeNull()
  })

  it('rechaza un tipo MIME no permitido para imagen', () => {
    expect(validarArchivoMedia('imagen', archivo('doc.pdf', 'application/pdf'))).toMatch(
      /JPG, PNG o WEBP/,
    )
  })

  it('rechaza un vídeo que no sea mp4', () => {
    expect(validarArchivoMedia('video', archivo('clip.webm', 'video/webm'))).toMatch(/MP4/)
  })

  it('rechaza un archivo que supera 50 MiB', () => {
    const grande = archivo('foto.png', 'image/png', 51 * 1024 * 1024)
    expect(validarArchivoMedia('imagen', grande)).toMatch(/50 MiB/)
  })
})

describe('subirMediaDesafio', () => {
  it('sube el archivo a {tipo}/{id}.{extension} y devuelve la URL pública', async () => {
    const upload = vi.fn().mockResolvedValue({ error: null })
    const getPublicUrl = vi
      .fn()
      .mockReturnValue({ data: { publicUrl: 'https://cdn/imagen/d-1.png' } })
    storageFrom.mockReturnValue({ upload, getPublicUrl })

    const url = await subirMediaDesafio('d-1', 'imagen', archivo('foto.png', 'image/png'))

    expect(storageFrom).toHaveBeenCalledWith('challenge-media')
    expect(upload).toHaveBeenCalledWith(
      'imagen/d-1.png',
      expect.any(File),
      expect.objectContaining({ upsert: true, contentType: 'image/png' }),
    )
    expect(url).toBe('https://cdn/imagen/d-1.png')
  })

  it('propaga el error si Storage rechaza la subida', async () => {
    storageFrom.mockReturnValue({
      upload: vi.fn().mockResolvedValue({ error: { message: 'archivo demasiado grande' } }),
      getPublicUrl: vi.fn(),
    })

    await expect(
      subirMediaDesafio('d-1', 'video', archivo('clip.mp4', 'video/mp4')),
    ).rejects.toThrow('archivo demasiado grande')
  })
})

describe('guardarPregunta', () => {
  function mockUpsert(error: unknown = null) {
    const upsert = vi.fn().mockResolvedValue({ error })
    from.mockReturnValue({ upsert })
    return upsert
  }

  it('crea una pregunta de tipo texto generando un id nuevo', async () => {
    const upsert = mockUpsert()

    const { id } = await guardarPregunta({
      id: null,
      tipo: 'pregunta_texto',
      nombreLugar: 'Machu Picchu',
      textoPregunta: '¿Ciudadela inca?',
      latReal: -13.1631,
      lngReal: -72.545,
      activo: true,
      archivo: null,
      imagenUrlActual: null,
      videoUrlActual: null,
    })

    expect(id).toEqual(expect.any(String))
    expect(id.length).toBeGreaterThan(0)
    expect(storageFrom).not.toHaveBeenCalled()
    expect(upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        id,
        tipo: 'pregunta_texto',
        imagen_url: null,
        video_url: null,
        texto_pregunta: '¿Ciudadela inca?',
        nombre_lugar: 'Machu Picchu',
        activo: true,
      }),
    )
  })

  it('crea una pregunta de tipo imagen subiendo el archivo con el id generado', async () => {
    const upload = vi.fn().mockResolvedValue({ error: null })
    const getPublicUrl = vi
      .fn()
      .mockReturnValue({ data: { publicUrl: 'https://cdn/imagen/x.png' } })
    storageFrom.mockReturnValue({ upload, getPublicUrl })
    const upsert = mockUpsert()

    const { id } = await guardarPregunta({
      id: null,
      tipo: 'imagen',
      nombreLugar: 'Torre Eiffel',
      textoPregunta: null,
      latReal: 48.8584,
      lngReal: 2.2945,
      activo: true,
      archivo: archivo('foto.png', 'image/png'),
      imagenUrlActual: null,
      videoUrlActual: null,
    })

    expect(upload).toHaveBeenCalledWith(`imagen/${id}.png`, expect.any(File), expect.anything())
    expect(upsert).toHaveBeenCalledWith(
      expect.objectContaining({ imagen_url: 'https://cdn/imagen/x.png' }),
    )
  })

  it('al editar sin subir archivo nuevo conserva la URL de media existente', async () => {
    const upsert = mockUpsert()

    await guardarPregunta({
      id: 'd-1',
      tipo: 'imagen',
      nombreLugar: 'Torre Eiffel (actualizado)',
      textoPregunta: null,
      latReal: 48.8584,
      lngReal: 2.2945,
      activo: true,
      archivo: null,
      imagenUrlActual: 'https://cdn/imagen/d-1.png',
      videoUrlActual: null,
    })

    expect(storageFrom).not.toHaveBeenCalled()
    expect(upsert).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'd-1', imagen_url: 'https://cdn/imagen/d-1.png' }),
    )
  })

  it('propaga el error si el guardado en desafios falla', async () => {
    mockUpsert({ message: 'restricción violada' })

    await expect(
      guardarPregunta({
        id: null,
        tipo: 'pregunta_texto',
        nombreLugar: 'X',
        textoPregunta: 'Y',
        latReal: 0,
        lngReal: 0,
        activo: true,
        archivo: null,
        imagenUrlActual: null,
        videoUrlActual: null,
      }),
    ).rejects.toThrow('restricción violada')
  })
})

describe('asignarPreguntaANiveles', () => {
  it('no consulta nada si no se seleccionó ningún nivel', async () => {
    const resultado = await asignarPreguntaANiveles('d-1', [])

    expect(resultado).toEqual([])
    expect(from).not.toHaveBeenCalled()
  })

  it('inserta cada nivel con orden = max(orden) + 1 de ese nivel', async () => {
    const insert = vi.fn().mockResolvedValue({ error: null })
    from.mockImplementation((table: string) => {
      if (table === 'nivel_desafios') {
        return {
          select: () => ({
            in: () =>
              Promise.resolve({
                data: [
                  { nivel_id: 'n-1', orden: 2 },
                  { nivel_id: 'n-1', orden: 1 },
                ],
                error: null,
              }),
          }),
          insert,
        }
      }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const resultado = await asignarPreguntaANiveles('d-1', ['n-1', 'n-2'])

    expect(insert).toHaveBeenCalledWith({ nivel_id: 'n-1', desafio_id: 'd-1', orden: 3 })
    expect(insert).toHaveBeenCalledWith({ nivel_id: 'n-2', desafio_id: 'd-1', orden: 1 })
    expect(resultado).toEqual(
      expect.arrayContaining([
        { nivelId: 'n-1', error: null },
        { nivelId: 'n-2', error: null },
      ]),
    )
  })

  it('reporta el error de una asignación sin afectar a las demás', async () => {
    const insert = vi
      .fn()
      .mockImplementation(({ nivel_id: nivelId }: { nivel_id: string }) =>
        Promise.resolve(
          nivelId === 'n-1' ? { error: { message: 'conflicto de orden' } } : { error: null },
        ),
      )
    from.mockImplementation(() => ({
      select: () => ({ in: () => Promise.resolve({ data: [], error: null }) }),
      insert,
    }))

    const resultado = await asignarPreguntaANiveles('d-1', ['n-1', 'n-2'])

    expect(resultado).toEqual(
      expect.arrayContaining([
        { nivelId: 'n-1', error: 'conflicto de orden' },
        { nivelId: 'n-2', error: null },
      ]),
    )
  })
})
