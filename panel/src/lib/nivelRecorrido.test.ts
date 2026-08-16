import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  fetchNivelRecorrido,
  validarConfiguracionNivel,
  guardarConfiguracionNivel,
  fetchPreguntasNoAsignadas,
  agregarPreguntaAlRecorrido,
  reordenarRecorrido,
  quitarPreguntaDelRecorrido,
} from './nivelRecorrido'

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

const NIVEL_ROW = {
  id: 'n-1',
  nombre: null,
  orden: 3,
  tematica_id: 't-1',
  puntaje_minimo_superar: 10,
  umbral_estrella_1: 20,
  umbral_estrella_2: 30,
  umbral_estrella_3: 40,
}

describe('fetchNivelRecorrido', () => {
  it('combina nivel, temática y preguntas asignadas ordenadas por orden', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'niveles') {
        return {
          select: () => ({
            eq: () => ({ single: () => Promise.resolve({ data: NIVEL_ROW, error: null }) }),
          }),
        }
      }
      if (table === 'tematicas') {
        return {
          select: () => ({
            eq: () => ({
              single: () => Promise.resolve({ data: { nombre: 'Paisajes' }, error: null }),
            }),
          }),
        }
      }
      if (table === 'nivel_desafios') {
        return {
          select: () => ({
            eq: () => ({
              order: () =>
                Promise.resolve({
                  data: [
                    { desafio_id: 'd-2', orden: 2 },
                    { desafio_id: 'd-1', orden: 1 },
                  ],
                  error: null,
                }),
            }),
          }),
        }
      }
      if (table === 'desafios') {
        return {
          select: () => ({
            in: () =>
              Promise.resolve({
                data: [
                  {
                    id: 'd-1',
                    tipo: 'imagen',
                    nombre_lugar: 'Torre Eiffel',
                    imagen_url: 'https://x/eiffel.jpg',
                  },
                  { id: 'd-2', tipo: 'video', nombre_lugar: 'Coliseo', imagen_url: null },
                ],
                error: null,
              }),
          }),
        }
      }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const nivel = await fetchNivelRecorrido('n-1')

    expect(nivel.tematicaNombre).toBe('Paisajes')
    expect(nivel.puntajeMinimoSuperar).toBe(10)
    expect(nivel.preguntas.map((p) => p.desafioId)).toEqual(['d-2', 'd-1'])
    expect(nivel.preguntas[0]).toMatchObject({ orden: 2, nombreLugar: 'Coliseo', tipo: 'video' })
  })

  it('no consulta desafíos si el nivel no tiene preguntas asignadas', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'niveles') {
        return {
          select: () => ({
            eq: () => ({ single: () => Promise.resolve({ data: NIVEL_ROW, error: null }) }),
          }),
        }
      }
      if (table === 'tematicas') {
        return {
          select: () => ({
            eq: () => ({
              single: () => Promise.resolve({ data: { nombre: 'Paisajes' }, error: null }),
            }),
          }),
        }
      }
      if (table === 'nivel_desafios') {
        return {
          select: () => ({
            eq: () => ({ order: () => Promise.resolve({ data: [], error: null }) }),
          }),
        }
      }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const nivel = await fetchNivelRecorrido('n-1')

    expect(nivel.preguntas).toEqual([])
    expect(from).not.toHaveBeenCalledWith('desafios')
  })

  it('propaga el error si falla la consulta del nivel', async () => {
    from.mockReturnValue({
      select: () => ({
        eq: () => ({
          single: () => Promise.resolve({ data: null, error: { message: 'no encontrado' } }),
        }),
      }),
    })

    await expect(fetchNivelRecorrido('n-x')).rejects.toThrow('no encontrado')
  })
})

describe('validarConfiguracionNivel', () => {
  it('acepta umbrales ascendentes', () => {
    expect(
      validarConfiguracionNivel({
        nombre: null,
        puntajeMinimoSuperar: 10,
        umbralEstrella1: 20,
        umbralEstrella2: 30,
        umbralEstrella3: 40,
      }),
    ).toBeNull()
  })

  it('rechaza umbrales no ascendentes', () => {
    expect(
      validarConfiguracionNivel({
        nombre: null,
        puntajeMinimoSuperar: 10,
        umbralEstrella1: 30,
        umbralEstrella2: 20,
        umbralEstrella3: 40,
      }),
    ).toMatch(/ascendentes/)
  })
})

describe('guardarConfiguracionNivel', () => {
  it('actualiza la fila de niveles cuando la configuración es válida', async () => {
    const eq = vi.fn().mockResolvedValue({ error: null })
    const update = vi.fn().mockReturnValue({ eq })
    from.mockReturnValue({ update })

    await guardarConfiguracionNivel('n-1', {
      nombre: 'Costas',
      puntajeMinimoSuperar: 10,
      umbralEstrella1: 20,
      umbralEstrella2: 30,
      umbralEstrella3: 40,
    })

    expect(from).toHaveBeenCalledWith('niveles')
    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({
        nombre: 'Costas',
        puntaje_minimo_superar: 10,
        umbral_estrella_1: 20,
        umbral_estrella_2: 30,
        umbral_estrella_3: 40,
      }),
    )
    expect(eq).toHaveBeenCalledWith('id', 'n-1')
  })

  it('rechaza sin llamar a supabase si los umbrales no son ascendentes', async () => {
    await expect(
      guardarConfiguracionNivel('n-1', {
        nombre: null,
        puntajeMinimoSuperar: 10,
        umbralEstrella1: 5,
        umbralEstrella2: 30,
        umbralEstrella3: 40,
      }),
    ).rejects.toThrow(/ascendentes/)
    expect(from).not.toHaveBeenCalled()
  })

  it('propaga el error si la base de datos rechaza la actualización', async () => {
    const eq = vi.fn().mockResolvedValue({ error: { message: 'no autorizado' } })
    from.mockReturnValue({ update: () => ({ eq }) })

    await expect(
      guardarConfiguracionNivel('n-1', {
        nombre: null,
        puntajeMinimoSuperar: 10,
        umbralEstrella1: 20,
        umbralEstrella2: 30,
        umbralEstrella3: 40,
      }),
    ).rejects.toThrow('no autorizado')
  })
})

describe('fetchPreguntasNoAsignadas', () => {
  it('excluye las preguntas ya asignadas al nivel', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'desafios') {
        return {
          select: () =>
            Promise.resolve({
              data: [
                { id: 'd-1', tipo: 'imagen', nombre_lugar: 'Torre Eiffel', imagen_url: null },
                { id: 'd-2', tipo: 'video', nombre_lugar: 'Coliseo', imagen_url: null },
              ],
              error: null,
            }),
        }
      }
      if (table === 'nivel_desafios') {
        return {
          select: () => ({
            eq: () => Promise.resolve({ data: [{ desafio_id: 'd-1' }], error: null }),
          }),
        }
      }
      throw new Error(`tabla inesperada: ${table}`)
    })

    const resultado = await fetchPreguntasNoAsignadas('n-1')

    expect(resultado).toEqual([
      { id: 'd-2', tipo: 'video', nombreLugar: 'Coliseo', imagenUrl: null },
    ])
  })
})

describe('agregarPreguntaAlRecorrido', () => {
  it('inserta con orden = max(orden) + 1', async () => {
    const insert = vi.fn().mockResolvedValue({ error: null })
    from.mockImplementation((table: string) => {
      if (table === 'nivel_desafios') {
        return {
          select: () => ({
            eq: () => Promise.resolve({ data: [{ orden: 1 }, { orden: 3 }], error: null }),
          }),
          insert,
        }
      }
      throw new Error(`tabla inesperada: ${table}`)
    })

    await agregarPreguntaAlRecorrido('n-1', 'd-9')

    expect(insert).toHaveBeenCalledWith({ nivel_id: 'n-1', desafio_id: 'd-9', orden: 4 })
  })

  it('usa orden 1 cuando el nivel no tiene preguntas asignadas todavía', async () => {
    const insert = vi.fn().mockResolvedValue({ error: null })
    from.mockImplementation(() => ({
      select: () => ({ eq: () => Promise.resolve({ data: [], error: null }) }),
      insert,
    }))

    await agregarPreguntaAlRecorrido('n-1', 'd-9')

    expect(insert).toHaveBeenCalledWith({ nivel_id: 'n-1', desafio_id: 'd-9', orden: 1 })
  })

  it('da un mensaje amigable si el orden entra en conflicto por una inserción concurrente (23505)', async () => {
    from.mockImplementation((table: string) => {
      if (table === 'nivel_desafios') {
        return {
          select: () => ({ eq: () => Promise.resolve({ data: [{ orden: 1 }], error: null }) }),
          insert: () =>
            Promise.resolve({ error: { code: '23505', message: 'duplicate key value' } }),
        }
      }
      throw new Error(`tabla inesperada: ${table}`)
    })

    await expect(agregarPreguntaAlRecorrido('n-1', 'd-9')).rejects.toThrow(
      /otra persona ha modificado este recorrido/i,
    )
  })
})

describe('reordenarRecorrido', () => {
  it('llama a la RPC reordenar_preguntas_nivel con el orden dado', async () => {
    rpc.mockResolvedValue({ error: null })

    await reordenarRecorrido('n-1', ['d-2', 'd-1'])

    expect(rpc).toHaveBeenCalledWith('reordenar_preguntas_nivel', {
      p_nivel_id: 'n-1',
      ids_en_orden: ['d-2', 'd-1'],
    })
  })

  it('propaga el error de la RPC', async () => {
    rpc.mockResolvedValue({ error: { message: 'rechazado' } })

    await expect(reordenarRecorrido('n-1', ['d-1'])).rejects.toThrow('rechazado')
  })
})

describe('quitarPreguntaDelRecorrido', () => {
  it('borra la fila y reordena las restantes', async () => {
    const eqDelete2 = vi.fn().mockResolvedValue({ error: null })
    const eqDelete1 = vi.fn().mockReturnValue({ eq: eqDelete2 })
    const deleteFn = vi.fn().mockReturnValue({ eq: eqDelete1 })

    const order = vi.fn().mockResolvedValue({
      data: [
        { desafio_id: 'd-2', orden: 1 },
        { desafio_id: 'd-3', orden: 2 },
      ],
      error: null,
    })
    const eqSelect = vi.fn().mockReturnValue({ order })
    const select = vi.fn().mockReturnValue({ eq: eqSelect })

    from.mockReturnValue({ delete: deleteFn, select })
    rpc.mockResolvedValue({ error: null })

    await quitarPreguntaDelRecorrido('n-1', 'd-1')

    expect(eqDelete1).toHaveBeenCalledWith('nivel_id', 'n-1')
    expect(eqDelete2).toHaveBeenCalledWith('desafio_id', 'd-1')
    expect(rpc).toHaveBeenCalledWith('reordenar_preguntas_nivel', {
      p_nivel_id: 'n-1',
      ids_en_orden: ['d-2', 'd-3'],
    })
  })

  it('no llama a la RPC si no quedan preguntas asignadas', async () => {
    from.mockReturnValue({
      delete: () => ({ eq: () => ({ eq: () => Promise.resolve({ error: null }) }) }),
      select: () => ({ eq: () => ({ order: () => Promise.resolve({ data: [], error: null }) }) }),
    })

    await quitarPreguntaDelRecorrido('n-1', 'd-1')

    expect(rpc).not.toHaveBeenCalled()
  })

  it('propaga el error si el borrado falla', async () => {
    from.mockReturnValue({
      delete: () => ({
        eq: () => ({ eq: () => Promise.resolve({ error: { message: 'rechazado' } }) }),
      }),
    })

    await expect(quitarPreguntaDelRecorrido('n-1', 'd-1')).rejects.toThrow('rechazado')
  })
})
