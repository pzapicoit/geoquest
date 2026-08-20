import { describe, it, expect, vi, beforeEach } from 'vitest'
import { fetchPreguntas, eliminarPregunta } from './preguntas'

const from = vi.fn()

vi.mock('./supabaseClient', () => ({
  supabase: {
    from: (...args: unknown[]) => from(...args),
  },
}))

function selectable(data: unknown[] | null, error: unknown = null) {
  return Promise.resolve({ data, error })
}

const DESAFIOS = [
  {
    id: 'd-eiffel',
    nombre: 'Torre Eiffel',
    tipo: 'imagen',
    nombre_lugar: 'Torre Eiffel, París',
    texto_pregunta: null,
    imagen_url: 'https://example.test/eiffel.jpg',
    activo: true,
    dificultad: 'dificil',
    tematica_id: 't-patrimonio',
  },
  {
    id: 'd-texto',
    nombre: 'Machu Picchu',
    tipo: 'pregunta_texto',
    nombre_lugar: 'Machu Picchu, Perú',
    texto_pregunta: '¿Ciudadela inca?',
    imagen_url: null,
    activo: true,
    dificultad: 'normal',
    tematica_id: 't-paisajes',
  },
]

const TEMATICAS = [
  { id: 't-paisajes', nombre: 'Paisajes' },
  { id: 't-patrimonio', nombre: 'Patrimonio' },
]

function mockTables(overrides: Partial<Record<string, unknown[] | null>> = {}) {
  from.mockImplementation((table: string) => ({
    select: () => {
      if (table === 'desafios') return selectable(overrides.desafios ?? DESAFIOS)
      if (table === 'tematicas') return selectable(overrides.tematicas ?? TEMATICAS)
      throw new Error(`tabla inesperada: ${table}`)
    },
  }))
}

beforeEach(() => {
  from.mockReset()
})

describe('fetchPreguntas', () => {
  it('devuelve una fila por desafío con dificultad y nombre de temática resuelto', async () => {
    mockTables()

    const preguntas = await fetchPreguntas()

    expect(preguntas).toHaveLength(2)

    const eiffel = preguntas.find((p) => p.id === 'd-eiffel')
    expect(eiffel).toMatchObject({
      nombre: 'Torre Eiffel',
      tipo: 'imagen',
      nombreLugar: 'Torre Eiffel, París',
      imagenUrl: 'https://example.test/eiffel.jpg',
      activo: true,
      dificultad: 'dificil',
      tematicaId: 't-patrimonio',
      tematicaNombre: 'Patrimonio',
    })

    const texto = preguntas.find((p) => p.id === 'd-texto')
    expect(texto).toMatchObject({ dificultad: 'normal', tematicaNombre: 'Paisajes' })
  })

  it('usa "Temática desconocida" si la temática referenciada ya no existe', async () => {
    mockTables({ tematicas: [] })

    const preguntas = await fetchPreguntas()

    expect(preguntas.every((p) => p.tematicaNombre === 'Temática desconocida')).toBe(true)
  })

  it('propaga el error si falla la consulta de desafíos', async () => {
    from.mockImplementation((table: string) => ({
      select: () =>
        table === 'desafios' ? selectable(null, new Error('rechazado')) : selectable([]),
    }))

    await expect(fetchPreguntas()).rejects.toThrow('rechazado')
  })

  it('propaga el error si falla la consulta de temáticas', async () => {
    from.mockImplementation((table: string) => ({
      select: () =>
        table === 'tematicas' ? selectable(null, new Error('rechazado')) : selectable(DESAFIOS),
    }))

    await expect(fetchPreguntas()).rejects.toThrow('rechazado')
  })
})

describe('eliminarPregunta', () => {
  it('borra el desafío cuando la base de datos lo permite', async () => {
    const eq = vi.fn().mockResolvedValue({ error: null })
    from.mockReturnValue({ delete: () => ({ eq }) })

    await expect(eliminarPregunta('d-eiffel')).resolves.toBeUndefined()
    expect(from).toHaveBeenCalledWith('desafios')
    expect(eq).toHaveBeenCalledWith('id', 'd-eiffel')
  })

  it('da un mensaje amigable cuando el borrado se rechaza por estar en uso (23503)', async () => {
    const eq = vi
      .fn()
      .mockResolvedValue({ error: { code: '23503', message: 'foreign key violation' } })
    from.mockReturnValue({ delete: () => ({ eq }) })

    await expect(eliminarPregunta('d-eiffel')).rejects.toThrow(/respuestas registradas/i)
  })

  it('propaga cualquier otro error de la base de datos como Error con su mensaje', async () => {
    const eq = vi.fn().mockResolvedValue({ error: { code: '42501', message: 'no autorizado' } })
    from.mockReturnValue({ delete: () => ({ eq }) })

    await expect(eliminarPregunta('d-eiffel')).rejects.toThrow('no autorizado')
    await expect(eliminarPregunta('d-eiffel')).rejects.toBeInstanceOf(Error)
  })
})
