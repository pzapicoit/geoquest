import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  absolutoDesdePorcentaje,
  agregarPreguntaAlRecorrido,
  distanciaMediaKm,
  fetchNivelRecorrido,
  fetchPreguntasNoAsignadas,
  guardarConfiguracionNivel,
  MAX_PUNTOS_DESAFIO,
  MAX_PUNTOS_DISTANCIA,
  porcentajeDesdeAbsoluto,
  preguntasEfectivasPorPartida,
  puntajeMaximoNivel,
  quitarPreguntaDelRecorrido,
  reordenarRecorrido,
  validarConfiguracionNivel,
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
  umbral_estrella_2: 30,
  umbral_estrella_3: 40,
  segundos_por_desafio: 45,
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
    expect(nivel.segundosPorDesafio).toBe(45)
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
      validarConfiguracionNivel(
        {
          nombre: null,
          puntajeMinimoSuperar: 10,
          umbralEstrella2: 30,
          umbralEstrella3: 40,
          preguntasPorPartida: null,
          segundosPorDesafio: 60,
        },
        5,
      ),
    ).toBeNull()
  })

  it('rechaza umbrales no ascendentes', () => {
    expect(
      validarConfiguracionNivel(
        {
          nombre: null,
          puntajeMinimoSuperar: 10,
          umbralEstrella2: 40,
          umbralEstrella3: 30,
          preguntasPorPartida: null,
          segundosPorDesafio: 60,
        },
        5,
      ),
    ).toMatch(/ascendentes/)
  })

  it('acepta preguntasPorPartida sin definir (se juegan todas)', () => {
    expect(
      validarConfiguracionNivel(
        {
          nombre: null,
          puntajeMinimoSuperar: 10,
          umbralEstrella2: 30,
          umbralEstrella3: 40,
          preguntasPorPartida: null,
          segundosPorDesafio: 60,
        },
        0,
      ),
    ).toBeNull()
  })

  it('acepta preguntasPorPartida dentro del pool asignado', () => {
    expect(
      validarConfiguracionNivel(
        {
          nombre: null,
          puntajeMinimoSuperar: 10,
          umbralEstrella2: 30,
          umbralEstrella3: 40,
          preguntasPorPartida: 5,
          segundosPorDesafio: 60,
        },
        8,
      ),
    ).toBeNull()
  })

  it('rechaza preguntasPorPartida por encima del pool asignado', () => {
    expect(
      validarConfiguracionNivel(
        {
          nombre: null,
          puntajeMinimoSuperar: 10,
          umbralEstrella2: 30,
          umbralEstrella3: 40,
          preguntasPorPartida: 8,
          segundosPorDesafio: 60,
        },
        5,
      ),
    ).toMatch(/no pueden superar/)
  })
})

describe('guardarConfiguracionNivel', () => {
  it('actualiza la fila de niveles cuando la configuración es válida', async () => {
    const eq = vi.fn().mockResolvedValue({ error: null })
    const update = vi.fn().mockReturnValue({ eq })
    from.mockReturnValue({ update })

    await guardarConfiguracionNivel(
      'n-1',
      {
        nombre: 'Costas',
        puntajeMinimoSuperar: 10,
        umbralEstrella2: 30,
        umbralEstrella3: 40,
        preguntasPorPartida: 5,
        segundosPorDesafio: 90,
      },
      8,
    )

    expect(from).toHaveBeenCalledWith('niveles')
    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({
        nombre: 'Costas',
        puntaje_minimo_superar: 10,
        umbral_estrella_2: 30,
        umbral_estrella_3: 40,
        preguntas_por_partida: 5,
        segundos_por_desafio: 90,
      }),
    )
    expect(eq).toHaveBeenCalledWith('id', 'n-1')
  })

  it('fija umbral_estrella_1 = puntaje_minimo_superar sin leerlo de la config', async () => {
    const eq = vi.fn().mockResolvedValue({ error: null })
    const update = vi.fn().mockReturnValue({ eq })
    from.mockReturnValue({ update })

    await guardarConfiguracionNivel(
      'n-1',
      {
        nombre: null,
        puntajeMinimoSuperar: 1200,
        umbralEstrella2: 3000,
        umbralEstrella3: 4500,
        preguntasPorPartida: null,
        segundosPorDesafio: 60,
      },
      5,
    )

    expect(update).toHaveBeenCalledWith(expect.objectContaining({ umbral_estrella_1: 1200 }))
  })

  it('rechaza sin llamar a supabase si los umbrales no son ascendentes', async () => {
    await expect(
      guardarConfiguracionNivel(
        'n-1',
        {
          nombre: null,
          puntajeMinimoSuperar: 10,
          umbralEstrella2: 40,
          umbralEstrella3: 30,
          preguntasPorPartida: null,
          segundosPorDesafio: 60,
        },
        0,
      ),
    ).rejects.toThrow(/ascendentes/)
    expect(from).not.toHaveBeenCalled()
  })

  it('rechaza sin llamar a supabase si preguntasPorPartida supera el pool', async () => {
    await expect(
      guardarConfiguracionNivel(
        'n-1',
        {
          nombre: null,
          puntajeMinimoSuperar: 10,
          umbralEstrella2: 30,
          umbralEstrella3: 40,
          preguntasPorPartida: 8,
          segundosPorDesafio: 60,
        },
        5,
      ),
    ).rejects.toThrow(/no pueden superar/)
    expect(from).not.toHaveBeenCalled()
  })

  it('propaga el error si la base de datos rechaza la actualización', async () => {
    const eq = vi.fn().mockResolvedValue({ error: { message: 'no autorizado' } })
    from.mockReturnValue({ update: () => ({ eq }) })

    await expect(
      guardarConfiguracionNivel(
        'n-1',
        {
          nombre: null,
          puntajeMinimoSuperar: 10,
          umbralEstrella2: 30,
          umbralEstrella3: 40,
          preguntasPorPartida: null,
          segundosPorDesafio: 60,
        },
        0,
      ),
    ).rejects.toThrow('no autorizado')
  })
})

describe('preguntasEfectivasPorPartida / puntajeMaximoNivel', () => {
  it('usa preguntasPorPartida cuando está definido', () => {
    expect(preguntasEfectivasPorPartida(5, 8)).toBe(5)
    // 5 desafíos × MAX_PUNTOS_DESAFIO (5500, con bonus por rapidez)
    expect(puntajeMaximoNivel(5, 8)).toBe(27500)
  })

  it('usa el tamaño del pool cuando preguntasPorPartida es null', () => {
    expect(preguntasEfectivasPorPartida(null, 8)).toBe(8)
    // 8 desafíos × MAX_PUNTOS_DESAFIO (5500, con bonus por rapidez)
    expect(puntajeMaximoNivel(null, 8)).toBe(44000)
  })
})

describe('MAX_PUNTOS_DESAFIO / MAX_PUNTOS_DISTANCIA', () => {
  it('MAX_PUNTOS_DESAFIO (5500) incluye el bonus por rapidez sobre MAX_PUNTOS_DISTANCIA (5000)', () => {
    expect(MAX_PUNTOS_DESAFIO).toBe(5500)
    expect(MAX_PUNTOS_DISTANCIA).toBe(5000)
    expect(MAX_PUNTOS_DESAFIO).toBe(MAX_PUNTOS_DISTANCIA + 500)
  })
})

describe('absolutoDesdePorcentaje / porcentajeDesdeAbsoluto', () => {
  it('convierte porcentaje a absoluto redondeando', () => {
    expect(absolutoDesdePorcentaje(40, 10000)).toBe(4000)
    expect(absolutoDesdePorcentaje(33.33, 10000)).toBe(3333)
  })

  it('es la inversa de porcentajeDesdeAbsoluto', () => {
    expect(porcentajeDesdeAbsoluto(4000, 10000)).toBe(40)
  })

  it('devuelve 0 si el máximo del nivel es 0', () => {
    expect(porcentajeDesdeAbsoluto(100, 0)).toBe(0)
  })
})

describe('distanciaMediaKm', () => {
  it('d=0 → MAX_PUNTOS_DISTANCIA (1 desafío), no MAX_PUNTOS_DESAFIO (D12: peor caso, sin bonus)', () => {
    // Si distanciaMediaKm invirtiera la curva sobre MAX_PUNTOS_DESAFIO (5500,
    // con bonus) en vez de MAX_PUNTOS_DISTANCIA (5000, solo distancia), este
    // puntaje ya no estaría en el máximo de la curva y devolvería una
    // distancia > 0 en vez de 0.
    expect(distanciaMediaKm(MAX_PUNTOS_DISTANCIA, 1)).toBeCloseTo(0, 5)
    expect(distanciaMediaKm(5000, 1)).toBeCloseTo(0, 5)
  })

  it('reproduce la tabla de la propuesta (1 desafío)', () => {
    expect(distanciaMediaKm(4838, 1)).toBeCloseTo(50, 0)
    expect(distanciaMediaKm(4382, 1)).toBeCloseTo(200, 0)
    expect(distanciaMediaKm(3597, 1)).toBeCloseTo(500, 0)
    expect(distanciaMediaKm(2591, 1)).toBeCloseTo(1000, 0)
    expect(distanciaMediaKm(1355, 1)).toBeCloseTo(2000, -1)
  })

  it('divide entre el número de desafíos para obtener el promedio', () => {
    // 10000 pts en 2 desafíos = 5000 pts/desafío = distancia 0
    expect(distanciaMediaKm(10000, 2)).toBeCloseTo(0, 5)
  })

  it('devuelve null si el puntaje está en el suelo o por debajo', () => {
    expect(distanciaMediaKm(50, 1)).toBeNull()
    expect(distanciaMediaKm(0, 1)).toBeNull()
  })

  it('devuelve null si no hay desafíos', () => {
    expect(distanciaMediaKm(1000, 0)).toBeNull()
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
