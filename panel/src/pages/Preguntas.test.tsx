import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Preguntas } from './Preguntas'
import type { Pregunta } from '../lib/preguntas'

const fetchPreguntas = vi.fn()
const eliminarPregunta = vi.fn()

vi.mock('../lib/preguntas', async () => {
  const actual = await vi.importActual<typeof import('../lib/preguntas')>('../lib/preguntas')
  return {
    ...actual,
    fetchPreguntas: (...args: unknown[]) => fetchPreguntas(...args),
    eliminarPregunta: (...args: unknown[]) => eliminarPregunta(...args),
  }
})

function pregunta(overrides: Partial<Pregunta> & { id: string }): Pregunta {
  return {
    tipo: 'imagen',
    nombreLugar: 'Lugar de prueba',
    textoPregunta: null,
    imagenUrl: null,
    activo: true,
    usos: [],
    ...overrides,
  }
}

const TORRE_EIFFEL = pregunta({
  id: 'd-eiffel',
  nombreLugar: 'Torre Eiffel',
  tipo: 'imagen',
  usos: [
    { nivelId: 'n-1', tematicaNombre: 'Capitales', nivelOrden: 1 },
    { nivelId: 'n-2', tematicaNombre: 'Paisajes', nivelOrden: 3 },
  ],
})

const MACHU_PICCHU = pregunta({
  id: 'd-machu',
  nombreLugar: 'Machu Picchu',
  tipo: 'pregunta_texto',
  textoPregunta: 'Ciudadela inca a 2 430 m de altitud',
  activo: true,
  usos: [{ nivelId: 'n-3', tematicaNombre: 'Patrimonio', nivelOrden: 2 }],
})

const DESAFIO_SUELTO = pregunta({
  id: 'd-suelto',
  nombreLugar: 'Desafío suelto',
  tipo: 'video',
  activo: false,
  usos: [],
})

beforeEach(() => {
  fetchPreguntas.mockReset()
  eliminarPregunta.mockReset()
  vi.spyOn(window, 'confirm').mockReturnValue(true)
})

describe('Preguntas', () => {
  it('muestra una fila por desafío, no por asignación, con el indicador de uso', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL, MACHU_PICCHU, DESAFIO_SUELTO])

    render(<Preguntas />)

    expect(await screen.findByText('Torre Eiffel')).toBeInTheDocument()
    expect(screen.getAllByText('Torre Eiffel')).toHaveLength(1)
    expect(screen.getByText('Usado en 2 niveles')).toBeInTheDocument()
    expect(screen.getByText('Usado en 1 nivel')).toBeInTheDocument()
    expect(screen.getByText('Sin asignar')).toBeInTheDocument()
  })

  it('el detalle del indicador de uso lista cada temática y nivel al abrirlo', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL])
    const user = userEvent.setup()

    render(<Preguntas />)

    const resumen = await screen.findByText('Usado en 2 niveles')
    const detalle = resumen.closest('details') as HTMLElement
    expect(detalle).not.toHaveAttribute('open')

    await user.click(resumen)

    expect(detalle).toHaveAttribute('open')

    expect(within(detalle).getByText('Capitales · Nivel 1')).toBeInTheDocument()
    expect(within(detalle).getByText('Paisajes · Nivel 3')).toBeInTheDocument()
  })

  it('busca por nombre de lugar o texto de la pregunta', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL, MACHU_PICCHU])
    const user = userEvent.setup()

    render(<Preguntas />)
    await screen.findByText('Torre Eiffel')

    await user.type(screen.getByPlaceholderText(/buscar por lugar/i), 'ciudadela')

    expect(screen.queryByText('Torre Eiffel')).not.toBeInTheDocument()
    expect(screen.getByText('Machu Picchu')).toBeInTheDocument()
  })

  it('combina el filtro de tipo y estado', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL, MACHU_PICCHU, DESAFIO_SUELTO])
    const user = userEvent.setup()

    render(<Preguntas />)
    await screen.findByText('Torre Eiffel')

    await user.selectOptions(screen.getByLabelText(/filtrar por tipo/i), 'video')
    expect(screen.queryByText('Torre Eiffel')).not.toBeInTheDocument()
    expect(screen.getByText('Desafío suelto')).toBeInTheDocument()

    await user.selectOptions(screen.getByLabelText(/filtrar por estado/i), 'activo')
    expect(screen.queryByText('Desafío suelto')).not.toBeInTheDocument()
  })

  it('filtra por temática y por nivel', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL, MACHU_PICCHU])
    const user = userEvent.setup()

    render(<Preguntas />)
    await screen.findByText('Torre Eiffel')

    await user.selectOptions(screen.getByLabelText(/filtrar por temática/i), 'Patrimonio')
    expect(screen.queryByText('Torre Eiffel')).not.toBeInTheDocument()
    expect(screen.getByText('Machu Picchu')).toBeInTheDocument()
  })

  it('filtra por "sin asignar a ningún nivel"', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL, DESAFIO_SUELTO])
    const user = userEvent.setup()

    render(<Preguntas />)
    await screen.findByText('Torre Eiffel')

    await user.click(screen.getByLabelText(/sin asignar a ningún nivel/i))

    expect(screen.queryByText('Torre Eiffel')).not.toBeInTheDocument()
    expect(screen.getByText('Desafío suelto')).toBeInTheDocument()
  })

  it('pagina los resultados y reinicia a la primera página al cambiar un filtro', async () => {
    const muchas = Array.from({ length: 12 }, (_, i) =>
      pregunta({ id: `d-${i}`, nombreLugar: `Lugar ${String(i).padStart(2, '0')}` }),
    )
    fetchPreguntas.mockResolvedValue(muchas)
    const user = userEvent.setup()

    render(<Preguntas />)
    await screen.findByText('Lugar 00')

    expect(screen.getByText(/mostrando 1–10 de 12/i)).toBeInTheDocument()
    expect(screen.queryByText('Lugar 10')).not.toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: '2' }))
    expect(await screen.findByText('Lugar 10')).toBeInTheDocument()
    expect(screen.queryByText('Lugar 00')).not.toBeInTheDocument()

    await user.type(screen.getByPlaceholderText(/buscar por lugar/i), 'Lugar 0')
    expect(await screen.findByText('Lugar 00')).toBeInTheDocument()
  })

  it('muestra un estado vacío con CTA cuando los filtros no coinciden con nada', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL])
    const user = userEvent.setup()

    render(<Preguntas />)
    await screen.findByText('Torre Eiffel')

    await user.type(screen.getByPlaceholderText(/buscar por lugar/i), 'no-existe-nada')

    expect(await screen.findByText(/ninguna pregunta coincide/i)).toBeInTheDocument()
    const [limpiar] = screen.getAllByRole('button', { name: /limpiar filtros/i })

    await user.click(limpiar)
    expect(await screen.findByText('Torre Eiffel')).toBeInTheDocument()
  })

  it('muestra un estado vacío distinto cuando el banco no tiene ninguna pregunta', async () => {
    fetchPreguntas.mockResolvedValue([])

    render(<Preguntas />)

    expect(await screen.findByText(/todavía no hay preguntas/i)).toBeInTheDocument()
    const cta = screen.getByText(/crear la primera pregunta/i)
    expect(cta).toHaveAttribute('aria-disabled', 'true')
  })

  it('"Nueva pregunta" y "Editar" están deshabilitados', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL])

    render(<Preguntas />)
    await screen.findByText('Torre Eiffel')

    const nuevaPregunta = screen.getByText('Nueva pregunta')
    expect(nuevaPregunta).toHaveAttribute('aria-disabled', 'true')
    expect(nuevaPregunta.closest('a')).toBeNull()

    const fila = screen.getByText('Torre Eiffel').closest('tr') as HTMLElement
    const accionEditar = within(fila).getByLabelText('Editar')
    expect(accionEditar).toHaveAttribute('aria-disabled', 'true')
    expect(accionEditar.tagName).not.toBe('A')
    expect(within(fila).queryByRole('link')).not.toBeInTheDocument()
  })

  it('elimina un desafío con éxito y lo quita del listado', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL, MACHU_PICCHU])
    eliminarPregunta.mockResolvedValue(undefined)
    const user = userEvent.setup()

    render(<Preguntas />)
    await screen.findByText('Torre Eiffel')

    const filaEiffel = screen.getByText('Torre Eiffel').closest('tr') as HTMLElement
    await user.click(within(filaEiffel).getByTitle('Eliminar'))

    expect(eliminarPregunta).toHaveBeenCalledWith('d-eiffel')
    expect(await screen.findByText('Machu Picchu')).toBeInTheDocument()
    expect(screen.queryByText('Torre Eiffel')).not.toBeInTheDocument()
  })

  it('muestra el mensaje de error y conserva la fila si el desafío está en uso', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL])
    eliminarPregunta.mockRejectedValue(
      new Error(
        'No se puede eliminar: esta pregunta está en uso o tiene respuestas registradas de jugadores.',
      ),
    )
    const user = userEvent.setup()

    render(<Preguntas />)
    await screen.findByText('Torre Eiffel')

    const fila = screen.getByText('Torre Eiffel').closest('tr') as HTMLElement
    await user.click(within(fila).getByTitle('Eliminar'))

    expect(await screen.findByText(/no se puede eliminar/i)).toBeInTheDocument()
    expect(screen.getByText('Torre Eiffel')).toBeInTheDocument()
  })

  it('no elimina si el admin cancela la confirmación', async () => {
    vi.spyOn(window, 'confirm').mockReturnValue(false)
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL])
    const user = userEvent.setup()

    render(<Preguntas />)
    const fila = (await screen.findByText('Torre Eiffel')).closest('tr') as HTMLElement
    await user.click(within(fila).getByTitle('Eliminar'))

    expect(eliminarPregunta).not.toHaveBeenCalled()
    expect(screen.getByText('Torre Eiffel')).toBeInTheDocument()
  })

  it('muestra un error si falla la carga del listado', async () => {
    fetchPreguntas.mockRejectedValue(new Error('network down'))

    render(<Preguntas />)

    expect(
      await screen.findByText(/no se ha podido cargar el listado de preguntas/i),
    ).toBeInTheDocument()
  })
})
