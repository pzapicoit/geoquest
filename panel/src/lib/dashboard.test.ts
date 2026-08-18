import { describe, it, expect, vi, beforeEach } from 'vitest'
import { fetchActividadReciente, fetchAlertasContenido, fetchMetricasHome } from './dashboard'

const rpc = vi.fn()
const from = vi.fn()

vi.mock('./supabaseClient', () => ({
  supabase: {
    rpc: (...args: unknown[]) => rpc(...args),
    from: (...args: unknown[]) => from(...args),
  },
}))

function mockTables(responses: Record<string, { data: unknown[] | null; error: unknown }>) {
  from.mockImplementation((table: string) => ({
    select: () => ({
      in: () => Promise.resolve(responses[table] ?? { data: [], error: null }),
    }),
  }))
}

beforeEach(() => {
  rpc.mockReset()
  from.mockReset()
})

describe('fetchMetricasHome', () => {
  it('mapea la fila de metricas_home a camelCase', async () => {
    rpc.mockResolvedValue({
      data: [
        {
          jugadores_totales: 4907,
          jugadores_activos_7d: 1843,
          partidas_hoy: 1284,
          paradas_activas: 86,
        },
      ],
      error: null,
    })

    const metricas = await fetchMetricasHome()

    expect(rpc).toHaveBeenCalledWith('metricas_home')
    expect(metricas).toEqual({
      jugadoresTotales: 4907,
      jugadoresActivos7d: 1843,
      partidasHoy: 1284,
      paradasActivas: 86,
    })
  })

  it('lanza si metricas_home no devuelve ninguna fila', async () => {
    rpc.mockResolvedValue({ data: [], error: null })

    await expect(fetchMetricasHome()).rejects.toThrow()
  })

  it('propaga el error si la RPC falla', async () => {
    rpc.mockResolvedValue({ data: null, error: new Error('rechazado') })

    await expect(fetchMetricasHome()).rejects.toThrow('rechazado')
  })
})

describe('fetchAlertasContenido', () => {
  it('resuelve el nombre legible de paradas y desafíos con una consulta por tabla', async () => {
    rpc.mockResolvedValue({
      data: [
        {
          tipo: 'nivel_baja_tasa',
          referencia_id: 'camino-1',
          titulo: 'Parada con baja tasa de superacion',
          detalle: { tasa_superacion: 0.2, total_intentos: 10 },
        },
        {
          tipo: 'desafio_incompleto',
          referencia_id: 'desafio-1',
          titulo: 'Desafio con datos incompletos',
          detalle: { tipo: 'imagen', campo_faltante: 'imagen_url' },
        },
      ],
      error: null,
    })
    mockTables({
      camino: {
        data: [{ id: 'camino-1', dificultad: 'facil', tematica_id: 'tematica-1' }],
        error: null,
      },
      tematicas: { data: [{ id: 'tematica-1', nombre: 'Fiordos de Noruega' }], error: null },
      desafios: {
        data: [{ id: 'desafio-1', tipo: 'imagen', nombre_lugar: 'Coliseo' }],
        error: null,
      },
    })

    const alertas = await fetchAlertasContenido()

    expect(alertas).toEqual([
      expect.objectContaining({
        referenciaId: 'camino-1',
        etiqueta: 'Fiordos de Noruega · Fácil',
      }),
      expect.objectContaining({ referenciaId: 'desafio-1', etiqueta: 'Coliseo (imagen)' }),
    ])
    // camino, tematicas y desafios: una llamada cada una, no una por alerta.
    expect(from).toHaveBeenCalledTimes(3)
  })

  it('usa el titulo generico como fallback si no hay nombre resuelto', async () => {
    rpc.mockResolvedValue({
      data: [
        {
          tipo: 'nivel_baja_tasa',
          referencia_id: 'camino-huerfano',
          titulo: 'Parada con baja tasa de superacion',
          detalle: {},
        },
      ],
      error: null,
    })
    mockTables({ camino: { data: [], error: null } })

    const alertas = await fetchAlertasContenido()

    expect(alertas[0].etiqueta).toBe('Parada con baja tasa de superacion')
  })

  it('sin alertas no consulta ninguna tabla auxiliar', async () => {
    rpc.mockResolvedValue({ data: [], error: null })

    const alertas = await fetchAlertasContenido()

    expect(alertas).toEqual([])
    expect(from).not.toHaveBeenCalled()
  })
})

describe('fetchActividadReciente', () => {
  it('resuelve el nombre de la parada solo para eventos nivel_superado', async () => {
    rpc.mockResolvedValue({
      data: [
        {
          tipo: 'nivel_superado',
          ocurrido_en: '2026-08-15T21:51:52.295314+00:00',
          texto: 'Jugador0925',
          detalle: { estrellas_obtenidas: 3, camino_id: 'camino-1', tematica_id: 'tematica-1' },
        },
        {
          tipo: 'nuevo_registro',
          ocurrido_en: '2026-08-15T21:51:16.588642+00:00',
          texto: 'Jugador0925',
          detalle: {},
        },
      ],
      error: null,
    })
    mockTables({
      camino: {
        data: [{ id: 'camino-1', dificultad: 'intermedio', tematica_id: 'tematica-1' }],
        error: null,
      },
      tematicas: { data: [{ id: 'tematica-1', nombre: 'Fiordos de Noruega' }], error: null },
    })

    const eventos = await fetchActividadReciente()

    expect(eventos[0]).toMatchObject({
      tipo: 'nivel_superado',
      etiqueta: 'Fiordos de Noruega · Intermedio',
    })
    expect(eventos[1]).toMatchObject({ tipo: 'nuevo_registro', etiqueta: null })
  })

  it('pasa p_limite a la RPC', async () => {
    rpc.mockResolvedValue({ data: [], error: null })

    await fetchActividadReciente(5)

    expect(rpc).toHaveBeenCalledWith('actividad_reciente', { p_limite: 5 })
  })
})
