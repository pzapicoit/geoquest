import { describe, it, expect, vi, beforeEach } from 'vitest'
import { guardarLoteIA, type CandidatoParaGuardar } from './loteIA'

const subirMediaDesafio = vi.fn()
const insert = vi.fn()
const remove = vi.fn()

vi.mock('./preguntaForm', async () => {
  const actual = await vi.importActual<typeof import('./preguntaForm')>('./preguntaForm')
  return {
    ...actual,
    subirMediaDesafio: (...args: unknown[]) => subirMediaDesafio(...args),
  }
})

vi.mock('./supabaseClient', () => ({
  supabase: {
    from: () => ({ insert: (...args: unknown[]) => insert(...args) }),
    storage: { from: () => ({ remove: (...args: unknown[]) => remove(...args) }) },
  },
}))

function candidato(nombre: string, conImagen = true): CandidatoParaGuardar {
  return {
    nombre,
    lat: 41.8902,
    lng: 12.4922,
    imagen: conImagen ? new Blob(['imagen'], { type: 'image/webp' }) : null,
  }
}

beforeEach(() => {
  subirMediaDesafio.mockReset()
  insert.mockReset()
  remove.mockReset()
  subirMediaDesafio.mockImplementation((id: string) =>
    Promise.resolve(`https://cdn.test/challenge-media/imagen/${id}.webp`),
  )
  insert.mockResolvedValue({ error: null })
  remove.mockResolvedValue({ error: null })
})

describe('guardarLoteIA', () => {
  it('crea una fila de tipo imagen por candidato, con su imagen subida', async () => {
    const resultados = await guardarLoteIA({
      tematicaId: 'tematica-1',
      dificultad: 'intermedio',
      activo: true,
      candidatos: [candidato('Coliseo, Roma'), candidato('Torre Eiffel')],
    })

    expect(resultados).toEqual([
      { nombre: 'Coliseo, Roma', guardado: true, motivo: null },
      { nombre: 'Torre Eiffel', guardado: true, motivo: null },
    ])
    expect(subirMediaDesafio).toHaveBeenCalledTimes(2)
    expect(insert).toHaveBeenCalledTimes(2)

    const fila = insert.mock.calls[0][0]
    expect(fila).toMatchObject({
      nombre: 'Coliseo, Roma',
      tipo: 'imagen',
      texto_pregunta: null,
      video_url: null,
      nombre_lugar: 'Coliseo, Roma',
      lat_real: 41.8902,
      lng_real: 12.4922,
      activo: true,
      tematica_id: 'tematica-1',
      dificultad: 'intermedio',
    })
    // El id de la fila es el mismo con el que se subió la imagen, para respetar
    // la convención imagen/{desafio_id}.{extension}.
    expect(subirMediaDesafio).toHaveBeenNthCalledWith(1, fila.id, 'imagen', expect.anything())
    expect(fila.imagen_url).toContain(fila.id)
  })

  it('guarda como inactivas cuando el lote no se publica', async () => {
    await guardarLoteIA({
      tematicaId: 'tematica-1',
      dificultad: 'facil',
      activo: false,
      candidatos: [candidato('Coliseo, Roma')],
    })

    expect(insert.mock.calls[0][0].activo).toBe(false)
  })

  it('omite el candidato que no tiene imagen', async () => {
    const resultados = await guardarLoteIA({
      tematicaId: 'tematica-1',
      dificultad: 'facil',
      activo: true,
      candidatos: [candidato('Sin ilustrar', false), candidato('Coliseo, Roma')],
    })

    expect(resultados[0]).toEqual({
      nombre: 'Sin ilustrar',
      guardado: false,
      motivo: 'sin_imagen',
    })
    expect(resultados[1].guardado).toBe(true)
    expect(insert).toHaveBeenCalledTimes(1)
  })

  it('informa del fallo de subida y sigue con el resto del lote', async () => {
    subirMediaDesafio.mockRejectedValueOnce(new Error('bucket caído'))

    const resultados = await guardarLoteIA({
      tematicaId: 'tematica-1',
      dificultad: 'facil',
      activo: true,
      candidatos: [candidato('Coliseo, Roma'), candidato('Torre Eiffel')],
    })

    expect(resultados[0]).toEqual({
      nombre: 'Coliseo, Roma',
      guardado: false,
      motivo: 'fallo_subida',
    })
    expect(resultados[1].guardado).toBe(true)
    expect(insert).toHaveBeenCalledTimes(1)
  })

  it('borra la imagen subida si la inserción falla, para no dejar huérfanos', async () => {
    insert.mockResolvedValueOnce({ error: { message: 'permiso denegado' } })

    const resultados = await guardarLoteIA({
      tematicaId: 'tematica-1',
      dificultad: 'facil',
      activo: true,
      candidatos: [candidato('Coliseo, Roma')],
    })

    expect(resultados[0].motivo).toBe('fallo_insercion')
    const id = insert.mock.calls[0][0].id
    expect(remove).toHaveBeenCalledWith([`imagen/${id}.webp`])
  })

  it('devuelve una lista vacía si no hay candidatos', async () => {
    expect(
      await guardarLoteIA({
        tematicaId: 'tematica-1',
        dificultad: 'facil',
        activo: true,
        candidatos: [],
      }),
    ).toEqual([])
    expect(insert).not.toHaveBeenCalled()
  })
})
