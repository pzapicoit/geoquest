import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  fetchPregunta,
  fetchTematicasParaPregunta,
  validarArchivoMedia,
  subirMediaDesafio,
  guardarPregunta,
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
  it('devuelve una pregunta con sus campos en camelCase, incluida temática y dificultad', async () => {
    const single = vi.fn().mockResolvedValue({
      data: {
        id: 'd-1',
        nombre: 'Torre Eiffel',
        tipo: 'imagen',
        nombre_lugar: 'Torre Eiffel, París',
        pista: 'Se ilumina cada hora al anochecer',
        pais: 'Francia',
        texto_pregunta: null,
        imagen_url: 'https://example.test/eiffel.jpg',
        video_url: null,
        lat_real: 48.8584,
        lng_real: 2.2945,
        activo: true,
        tematica_id: 't-1',
        dificultad: 'dificil',
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
      nombre: 'Torre Eiffel',
      tipo: 'imagen',
      nombreLugar: 'Torre Eiffel, París',
      pista: 'Se ilumina cada hora al anochecer',
      pais: 'Francia',
      textoPregunta: null,
      imagenUrl: 'https://example.test/eiffel.jpg',
      videoUrl: null,
      latReal: 48.8584,
      lngReal: 2.2945,
      activo: true,
      tematicaId: 't-1',
      dificultad: 'dificil',
    })
  })

  it('propaga el error si la pregunta no existe o falla la consulta', async () => {
    const single = vi.fn().mockResolvedValue({ data: null, error: { message: 'no encontrada' } })
    from.mockReturnValue({ select: () => ({ eq: () => ({ single }) }) })

    await expect(fetchPregunta('d-x')).rejects.toThrow('no encontrada')
  })
})

describe('fetchTematicasParaPregunta', () => {
  it('devuelve las temáticas ordenadas por orden', async () => {
    const order = vi.fn().mockResolvedValue({
      data: [
        { id: 't-1', nombre: 'Paisajes' },
        { id: 't-2', nombre: 'Patrimonio' },
      ],
      error: null,
    })
    from.mockReturnValue({ select: () => ({ order }) })

    const tematicas = await fetchTematicasParaPregunta()

    expect(from).toHaveBeenCalledWith('tematicas')
    expect(tematicas).toEqual([
      { id: 't-1', nombre: 'Paisajes' },
      { id: 't-2', nombre: 'Patrimonio' },
    ])
  })

  it('propaga el error si falla la consulta', async () => {
    const order = vi.fn().mockResolvedValue({ data: null, error: { message: 'fallo de red' } })
    from.mockReturnValue({ select: () => ({ order }) })

    await expect(fetchTematicasParaPregunta()).rejects.toThrow('fallo de red')
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

  it('crea una pregunta de tipo texto generando un id nuevo, con temática y dificultad', async () => {
    const upsert = mockUpsert()

    const { id } = await guardarPregunta({
      id: null,
      nombre: 'Machu Picchu',
      tipo: 'pregunta_texto',
      nombreLugar: 'Machu Picchu, Perú',
      pista: '  Está a más de 2000 m de altitud  ',
      pais: '  Perú  ',
      textoPregunta: '¿Ciudadela inca?',
      latReal: -13.1631,
      lngReal: -72.545,
      activo: true,
      tematicaId: 't-1',
      dificultad: 'normal',
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
        nombre: 'Machu Picchu',
        tipo: 'pregunta_texto',
        imagen_url: null,
        video_url: null,
        texto_pregunta: '¿Ciudadela inca?',
        nombre_lugar: 'Machu Picchu, Perú',
        pista: 'Está a más de 2000 m de altitud',
        pais: 'Perú',
        activo: true,
        tematica_id: 't-1',
        dificultad: 'normal',
      }),
    )
  })

  it('guarda la pista vacía como null', async () => {
    const upsert = mockUpsert()

    await guardarPregunta({
      id: null,
      nombre: 'Machu Picchu',
      tipo: 'pregunta_texto',
      nombreLugar: 'Machu Picchu, Perú',
      pista: '   ',
      pais: null,
      textoPregunta: '¿Ciudadela inca?',
      latReal: -13.1631,
      lngReal: -72.545,
      activo: true,
      tematicaId: 't-1',
      dificultad: 'normal',
      archivo: null,
      imagenUrlActual: null,
      videoUrlActual: null,
    })

    expect(upsert).toHaveBeenCalledWith(expect.objectContaining({ pista: null }))
  })

  it('guarda el país vacío como null', async () => {
    const upsert = mockUpsert()

    await guardarPregunta({
      id: null,
      nombre: 'Machu Picchu',
      tipo: 'pregunta_texto',
      nombreLugar: 'Machu Picchu, Perú',
      pista: null,
      pais: '   ',
      textoPregunta: '¿Ciudadela inca?',
      latReal: -13.1631,
      lngReal: -72.545,
      activo: true,
      tematicaId: 't-1',
      dificultad: 'normal',
      archivo: null,
      imagenUrlActual: null,
      videoUrlActual: null,
    })

    expect(upsert).toHaveBeenCalledWith(expect.objectContaining({ pais: null }))
  })

  it('guarda el país cuando se rellena', async () => {
    const upsert = mockUpsert()

    await guardarPregunta({
      id: null,
      nombre: 'Machu Picchu',
      tipo: 'pregunta_texto',
      nombreLugar: 'Machu Picchu, Perú',
      pista: null,
      pais: '  Perú  ',
      textoPregunta: '¿Ciudadela inca?',
      latReal: -13.1631,
      lngReal: -72.545,
      activo: true,
      tematicaId: 't-1',
      dificultad: 'normal',
      archivo: null,
      imagenUrlActual: null,
      videoUrlActual: null,
    })

    expect(upsert).toHaveBeenCalledWith(expect.objectContaining({ pais: 'Perú' }))
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
      nombre: 'Torre Eiffel',
      tipo: 'imagen',
      nombreLugar: 'Torre Eiffel, París',
      pista: null,
      pais: null,
      textoPregunta: null,
      latReal: 48.8584,
      lngReal: 2.2945,
      activo: true,
      tematicaId: 't-1',
      dificultad: 'facil',
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
      nombre: 'Torre Eiffel',
      tipo: 'imagen',
      nombreLugar: 'Torre Eiffel, París (actualizado)',
      pista: null,
      pais: null,
      textoPregunta: null,
      latReal: 48.8584,
      lngReal: 2.2945,
      activo: true,
      tematicaId: 't-1',
      dificultad: 'dificil',
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
        nombre: 'X',
        tipo: 'pregunta_texto',
        nombreLugar: 'X',
        pista: null,
        pais: null,
        textoPregunta: 'Y',
        latReal: 0,
        lngReal: 0,
        activo: true,
        tematicaId: 't-1',
        dificultad: 'normal',
        archivo: null,
        imagenUrlActual: null,
        videoUrlActual: null,
      }),
    ).rejects.toThrow('restricción violada')
  })
})
