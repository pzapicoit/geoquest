import { describe, it, expect, vi, beforeEach } from 'vitest'
import { fetchPreguntas, eliminarPregunta } from './preguntas'

const from = vi.fn()

vi.mock('./supabaseClient', () => ({
  supabase: {
    from: (...args: unknown[]) => from(...args),
  },
}))

function selectable(data: unknown[] | null, error: unknown = null) {
  const result = { data, error }
  return Object.assign(Promise.resolve(result), {
    in: () => Promise.resolve(result),
  })
}

const DESAFIOS = [
  {
    id: 'd-eiffel',
    tipo: 'imagen',
    nombre_lugar: 'Torre Eiffel',
    texto_pregunta: null,
    imagen_url: 'https://example.test/eiffel.jpg',
    activo: true,
  },
  {
    id: 'd-suelto',
    tipo: 'pregunta_texto',
    nombre_lugar: 'Desafío suelto',
    texto_pregunta: '¿Pregunta sin asignar?',
    imagen_url: null,
    activo: true,
  },
]

const ASIGNACIONES = [
  { desafio_id: 'd-eiffel', nivel_id: 'n-1' },
  { desafio_id: 'd-eiffel', nivel_id: 'n-2' },
]

const NIVELES = [
  { id: 'n-1', orden: 3, tematica_id: 't-paisajes' },
  { id: 'n-2', orden: 2, tematica_id: 't-patrimonio' },
]

const TEMATICAS = [
  { id: 't-paisajes', nombre: 'Paisajes' },
  { id: 't-patrimonio', nombre: 'Patrimonio' },
]

function mockTables(overrides: Partial<Record<string, unknown[] | null>> = {}) {
  from.mockImplementation((table: string) => ({
    select: () => {
      if (table === 'desafios') return selectable(overrides.desafios ?? DESAFIOS)
      if (table === 'nivel_desafios') return selectable(overrides.nivel_desafios ?? ASIGNACIONES)
      if (table === 'niveles') return selectable(overrides.niveles ?? NIVELES)
      if (table === 'tematicas') return selectable(overrides.tematicas ?? TEMATICAS)
      throw new Error(`tabla inesperada: ${table}`)
    },
  }))
}

beforeEach(() => {
  from.mockReset()
})

describe('fetchPreguntas', () => {
  it('devuelve una fila por desafío, con sus usos resueltos a temática·nivel', async () => {
    mockTables()

    const preguntas = await fetchPreguntas()

    expect(preguntas).toHaveLength(2)

    const eiffel = preguntas.find((p) => p.id === 'd-eiffel')
    expect(eiffel).toMatchObject({
      tipo: 'imagen',
      nombreLugar: 'Torre Eiffel',
      imagenUrl: 'https://example.test/eiffel.jpg',
      activo: true,
    })
    expect(eiffel?.usos).toEqual(
      expect.arrayContaining([
        { nivelId: 'n-1', tematicaNombre: 'Paisajes', nivelOrden: 3 },
        { nivelId: 'n-2', tematicaNombre: 'Patrimonio', nivelOrden: 2 },
      ]),
    )
    expect(eiffel?.usos).toHaveLength(2)
  })

  it('un desafío sin asignaciones tiene usos vacío', async () => {
    mockTables()

    const preguntas = await fetchPreguntas()

    const suelto = preguntas.find((p) => p.id === 'd-suelto')
    expect(suelto?.usos).toEqual([])
  })

  it('no consulta niveles/temáticas si no hay asignaciones', async () => {
    mockTables({ nivel_desafios: [] })

    await fetchPreguntas()

    expect(from).not.toHaveBeenCalledWith('niveles')
    expect(from).not.toHaveBeenCalledWith('tematicas')
  })

  it('propaga el error si falla la consulta de desafíos', async () => {
    from.mockImplementation((table: string) => ({
      select: () =>
        table === 'desafios'
          ? selectable(null, new Error('rechazado'))
          : selectable(table === 'nivel_desafios' ? [] : []),
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

    await expect(eliminarPregunta('d-eiffel')).rejects.toThrow(/está en uso o tiene respuestas/i)
  })

  it('propaga cualquier otro error de la base de datos', async () => {
    const eq = vi.fn().mockResolvedValue({ error: { code: '42501', message: 'no autorizado' } })
    from.mockReturnValue({ delete: () => ({ eq }) })

    await expect(eliminarPregunta('d-eiffel')).rejects.toMatchObject({ code: '42501' })
  })
})
