import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  ErrorIa,
  MAX_RONDAS_EXTRA,
  ejecutarConLimite,
  fetchLugaresExistentes,
  generarImagenLugar,
  mensajeDeError,
  pedirCandidatosDeduplicados,
  proponerLugares,
  type CandidatoIA,
} from './iaPreguntas'

const invoke = vi.fn()
const select = vi.fn()
const eq = vi.fn()

vi.mock('./supabaseClient', () => ({
  supabase: {
    functions: { invoke: (...args: unknown[]) => invoke(...args) },
    from: () => ({ select: (...args: unknown[]) => select(...args) }),
  },
}))

function errorConCodigo(codigo: string) {
  return { context: { json: () => Promise.resolve({ codigo }) } }
}

function lugar(
  nombre: string,
  lat: number,
  lng: number,
  ciudad: string | null = `ciudad de ${nombre}`,
  pais: string | null = 'País de prueba',
): CandidatoIA {
  return { nombre, lat, lng, ciudad, pais, descripcion: `descripción de ${nombre}` }
}

beforeEach(() => {
  invoke.mockReset()
  select.mockReset()
  eq.mockReset()
  select.mockReturnValue({ eq: (...args: unknown[]) => eq(...args) })
})

describe('proponerLugares', () => {
  it('invoca la función con la petición y devuelve los candidatos', async () => {
    invoke.mockResolvedValue({
      data: { lugares: [lugar('Coliseo, Roma', 41.8902, 12.4922)] },
      error: null,
    })

    const candidatos = await proponerLugares({
      tematica: 'Monumentos',
      dificultad: 'normal',
      cantidad: 5,
      existentes: [{ nombre: 'Torre Eiffel', lat: 48.8584, lng: 2.2945 }],
      indicaciones: null,
    })

    expect(invoke).toHaveBeenCalledWith('proponer-lugares', {
      body: {
        tematica: 'Monumentos',
        dificultad: 'normal',
        cantidad: 5,
        existentes: [{ nombre: 'Torre Eiffel', lat: 48.8584, lng: 2.2945 }],
        indicaciones: null,
      },
    })
    expect(candidatos).toEqual([lugar('Coliseo, Roma', 41.8902, 12.4922)])
  })

  it('arrastra la ciudad y el país de cada candidato', async () => {
    invoke.mockResolvedValue({
      data: { lugares: [lugar('Coliseo, Roma', 41.8902, 12.4922, 'Roma', 'Italia')] },
      error: null,
    })

    const candidatos = await proponerLugares({
      tematica: 'Monumentos',
      dificultad: 'normal',
      cantidad: 1,
      existentes: [],
      indicaciones: null,
    })

    expect(candidatos[0]).toMatchObject({ ciudad: 'Roma', pais: 'Italia' })
  })

  it('una función anterior a INT-122 deja la ciudad y el país en null', async () => {
    // No manda esas claves. No es una respuesta inválida: es exactamente el
    // comportamiento que había antes de este cambio.
    invoke.mockResolvedValue({
      data: {
        lugares: [
          { nombre: 'Coliseo, Roma', lat: 41.8902, lng: 12.4922, descripcion: 'anfiteatro' },
        ],
      },
      error: null,
    })

    const candidatos = await proponerLugares({
      tematica: 'Monumentos',
      dificultad: 'normal',
      cantidad: 1,
      existentes: [],
      indicaciones: null,
    })

    expect(candidatos[0]).toMatchObject({ ciudad: null, pais: null })
  })

  it('devuelve lista vacía si la función no trae lugares', async () => {
    invoke.mockResolvedValue({ data: {}, error: null })

    expect(
      await proponerLugares({
        tematica: 'Monumentos',
        dificultad: 'facil',
        cantidad: 3,
        existentes: [],
        indicaciones: null,
      }),
    ).toEqual([])
  })
})

describe('traducción de errores', () => {
  const casos: [string, string][] = [
    ['secreto_no_configurado', 'clave de OpenAI no está configurada'],
    ['no_autorizado', 'permisos de administrador'],
    ['peticion_invalida', 'configuración de la tanda no es válida'],
    ['respuesta_invalida', 'formato que no se entiende'],
    ['openai_error', 'La IA no ha respondido'],
  ]

  it.each(casos)('el código %s tiene su mensaje propio', async (codigo, fragmento) => {
    invoke.mockResolvedValue({ data: null, error: errorConCodigo(codigo) })

    const fallo = await proponerLugares({
      tematica: 'Monumentos',
      dificultad: 'normal',
      cantidad: 5,
      existentes: [],
      indicaciones: null,
    }).catch((error: unknown) => error)

    expect(fallo).toBeInstanceOf(ErrorIa)
    expect((fallo as ErrorIa).codigo).toBe(codigo)
    expect((fallo as ErrorIa).message).toContain(fragmento)
    expect((fallo as ErrorIa).message).not.toContain('OpenAI error')
  })

  it('un fallo de red sin cuerpo legible queda como fallo desconocido', async () => {
    invoke.mockResolvedValue({ data: null, error: new TypeError('Failed to fetch') })

    const fallo = await generarImagenLugar({
      nombre: 'Coliseo',
      descripcion: null,
      estiloTematica: null,
      indicaciones: null,
    }).catch((error: unknown) => error)

    expect((fallo as ErrorIa).codigo).toBe('fallo_desconocido')
    expect((fallo as ErrorIa).message).toContain('Revisa la conexión')
  })

  it('un código que no reconocemos también queda como fallo desconocido', async () => {
    invoke.mockResolvedValue({ data: null, error: errorConCodigo('algo_raro') })

    const fallo = await generarImagenLugar({
      nombre: 'Coliseo',
      descripcion: null,
      estiloTematica: null,
      indicaciones: null,
    }).catch((error: unknown) => error)

    expect((fallo as ErrorIa).codigo).toBe('fallo_desconocido')
  })

  it('mensajeDeError traduce cualquier cosa que no sea ErrorIa', () => {
    expect(mensajeDeError(new Error('boom'))).toContain('No se ha podido contactar')
    expect(mensajeDeError(new ErrorIa('openai_error'))).toContain('La IA no ha respondido')
  })
})

describe('generarImagenLugar', () => {
  it('convierte el base64 de la función en un Blob con su tipo', async () => {
    // "hola" en base64.
    invoke.mockResolvedValue({
      data: { imagenBase64: 'aG9sYQ==', mime: 'image/webp' },
      error: null,
    })

    const blob = await generarImagenLugar({
      nombre: 'Coliseo',
      descripcion: 'anfiteatro',
      estiloTematica: 'fondo neutro',
      indicaciones: 'solo Italia',
    })

    expect(invoke).toHaveBeenCalledWith('generar-imagen-lugar', {
      body: {
        nombre: 'Coliseo',
        descripcion: 'anfiteatro',
        estiloTematica: 'fondo neutro',
        indicaciones: 'solo Italia',
      },
    })
    expect(blob.type).toBe('image/webp')
    expect(blob.size).toBe(4)
  })

  it('falla como respuesta inválida si no llega imagen', async () => {
    invoke.mockResolvedValue({ data: { mime: 'image/webp' }, error: null })

    const fallo = await generarImagenLugar({
      nombre: 'Coliseo',
      descripcion: null,
      estiloTematica: null,
      indicaciones: null,
    }).catch((error: unknown) => error)

    expect((fallo as ErrorIa).codigo).toBe('respuesta_invalida')
  })
})

describe('fetchLugaresExistentes', () => {
  it('pide solo los desafíos de esa temática y los mapea a lugares comparables', async () => {
    eq.mockResolvedValue({
      data: [{ nombre_lugar: 'Coliseo', lat_real: 41.8902, lng_real: 12.4922 }],
      error: null,
    })

    const lugares = await fetchLugaresExistentes('tematica-1')

    expect(select).toHaveBeenCalledWith('nombre_lugar, lat_real, lng_real')
    expect(eq).toHaveBeenCalledWith('tematica_id', 'tematica-1')
    expect(lugares).toEqual([{ nombre: 'Coliseo', lat: 41.8902, lng: 12.4922 }])
  })

  it('propaga el error de la consulta', async () => {
    eq.mockResolvedValue({ data: null, error: { message: 'permiso denegado' } })

    await expect(fetchLugaresExistentes('tematica-1')).rejects.toThrow('permiso denegado')
  })
})

describe('pedirCandidatosDeduplicados', () => {
  const entrada = {
    tematicaId: 'tematica-1',
    tematicaNombre: 'Monumentos',
    dificultad: 'normal' as const,
    cantidad: 3,
    indicaciones: null,
  }

  it('descarta los duplicados del banco y pide una ronda extra para completar', async () => {
    eq.mockResolvedValue({
      data: [{ nombre_lugar: 'Coliseo', lat_real: 41.8902, lng_real: 12.4922 }],
      error: null,
    })
    invoke
      .mockResolvedValueOnce({
        data: {
          lugares: [
            lugar('Coliseo, Roma', 41.8902, 12.4922),
            lugar('Torre Eiffel', 48.8584, 2.2945),
            lugar('Machu Picchu', -13.1631, -72.545),
          ],
        },
        error: null,
      })
      .mockResolvedValueOnce({
        data: { lugares: [lugar('Angkor Wat', 13.4125, 103.867)] },
        error: null,
      })

    const { candidatos, tandaCorta } = await pedirCandidatosDeduplicados(entrada)

    expect(candidatos.map((c) => c.nombre)).toEqual(['Torre Eiffel', 'Machu Picchu', 'Angkor Wat'])
    expect(tandaCorta).toBe(false)
    expect(invoke).toHaveBeenCalledTimes(2)
    // La segunda ronda pide solo lo que falta y excluye lo ya visto, aceptado o
    // rechazado.
    expect(invoke.mock.calls[1][1].body.cantidad).toBe(1)
    const conocidos = invoke.mock.calls[1][1].body.existentes as { nombre: string }[]
    expect(conocidos.map((l) => l.nombre)).toContain('Coliseo, Roma')
    expect(conocidos.map((l) => l.nombre)).toContain('Torre Eiffel')
    // Van con coordenadas: son a la vez exclusiones y ejemplos del tipo de
    // respuesta que espera la temática.
    expect(conocidos.every((l) => typeof (l as { lat?: number }).lat === 'number')).toBe(true)
  })

  it('marca la tanda como corta cuando se agotan las rondas extra', async () => {
    eq.mockResolvedValue({ data: [], error: null })
    invoke.mockResolvedValue({
      data: { lugares: [lugar('Torre Eiffel', 48.8584, 2.2945)] },
      error: null,
    })

    const { candidatos, tandaCorta } = await pedirCandidatosDeduplicados(entrada)

    expect(candidatos).toHaveLength(1)
    expect(tandaCorta).toBe(true)
    expect(invoke).toHaveBeenCalledTimes(MAX_RONDAS_EXTRA + 1)
  })

  it('para en seco si una ronda no devuelve nada', async () => {
    eq.mockResolvedValue({ data: [], error: null })
    invoke
      .mockResolvedValueOnce({
        data: { lugares: [lugar('Torre Eiffel', 48.8584, 2.2945)] },
        error: null,
      })
      .mockResolvedValueOnce({ data: { lugares: [] }, error: null })

    const { candidatos, tandaCorta } = await pedirCandidatosDeduplicados(entrada)

    expect(candidatos).toHaveLength(1)
    expect(tandaCorta).toBe(true)
    expect(invoke).toHaveBeenCalledTimes(2)
  })

  it('no pide rondas extra si la primera ya completa la tanda', async () => {
    eq.mockResolvedValue({ data: [], error: null })
    invoke.mockResolvedValue({
      data: {
        lugares: [
          lugar('Torre Eiffel', 48.8584, 2.2945),
          lugar('Machu Picchu', -13.1631, -72.545),
          lugar('Angkor Wat', 13.4125, 103.867),
        ],
      },
      error: null,
    })

    const { tandaCorta } = await pedirCandidatosDeduplicados(entrada)

    expect(tandaCorta).toBe(false)
    expect(invoke).toHaveBeenCalledTimes(1)
  })
})

describe('ejecutarConLimite', () => {
  it('nunca mantiene más tareas en vuelo que el límite y las ejecuta todas', async () => {
    const items = [1, 2, 3, 4, 5, 6, 7]
    let enVuelo = 0
    let maximo = 0
    const hechas: number[] = []

    await ejecutarConLimite(items, 3, async (item) => {
      enVuelo += 1
      maximo = Math.max(maximo, enVuelo)
      await Promise.resolve()
      hechas.push(item)
      enVuelo -= 1
    })

    expect(hechas.sort((a, b) => a - b)).toEqual(items)
    expect(maximo).toBeLessThanOrEqual(3)
  })

  it('no falla con una lista vacía', async () => {
    const tarea = vi.fn()
    await ejecutarConLimite([], 3, tarea)
    expect(tarea).not.toHaveBeenCalled()
  })
})
