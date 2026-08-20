import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, within, waitFor, fireEvent } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import { Preguntas } from './Preguntas'
import type { Pregunta } from '../lib/preguntas'

function renderPreguntas() {
  return render(
    <MemoryRouter>
      <Preguntas />
    </MemoryRouter>,
  )
}

const fetchPreguntas = vi.fn()
const eliminarPregunta = vi.fn()
const actualizarDificultadPregunta = vi.fn()
const actualizarActivoPregunta = vi.fn()

vi.mock('../lib/preguntas', async () => {
  const actual = await vi.importActual<typeof import('../lib/preguntas')>('../lib/preguntas')
  return {
    ...actual,
    fetchPreguntas: (...args: unknown[]) => fetchPreguntas(...args),
    eliminarPregunta: (...args: unknown[]) => eliminarPregunta(...args),
    actualizarDificultadPregunta: (...args: unknown[]) => actualizarDificultadPregunta(...args),
    actualizarActivoPregunta: (...args: unknown[]) => actualizarActivoPregunta(...args),
  }
})

function pregunta(overrides: Partial<Pregunta> & { id: string }): Pregunta {
  return {
    nombre: 'Nombre de prueba',
    tipo: 'imagen',
    nombreLugar: 'Lugar de prueba',
    textoPregunta: null,
    imagenUrl: null,
    activo: true,
    dificultad: 'normal',
    tematicaId: 't-1',
    tematicaNombre: 'Temática de prueba',
    ...overrides,
  }
}

const TORRE_EIFFEL = pregunta({
  id: 'd-eiffel',
  nombre: 'Torre Eiffel',
  nombreLugar: 'Torre Eiffel, París',
  tipo: 'imagen',
  dificultad: 'dificil',
  tematicaId: 't-patrimonio',
  tematicaNombre: 'Patrimonio',
})

const MACHU_PICCHU = pregunta({
  id: 'd-machu',
  nombre: 'Machu Picchu',
  nombreLugar: 'Machu Picchu, Perú',
  tipo: 'pregunta_texto',
  textoPregunta: 'Ciudadela inca a 2 430 m de altitud',
  activo: true,
  dificultad: 'muy_dificil',
  tematicaId: 't-paisajes',
  tematicaNombre: 'Paisajes',
})

const DESAFIO_SUELTO = pregunta({
  id: 'd-suelto',
  nombre: 'Desafío suelto',
  nombreLugar: 'Desafío suelto',
  tipo: 'video',
  activo: false,
  dificultad: 'facil',
})

beforeEach(() => {
  fetchPreguntas.mockReset()
  eliminarPregunta.mockReset()
  actualizarDificultadPregunta.mockReset()
  actualizarActivoPregunta.mockReset()
  vi.spyOn(window, 'confirm').mockReturnValue(true)
  sessionStorage.clear()
})

describe('Preguntas', () => {
  it('muestra una fila por desafío con su temática y badge de dificultad', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL, MACHU_PICCHU, DESAFIO_SUELTO])

    renderPreguntas()

    const filaEiffel = (await screen.findByText('Torre Eiffel')).closest('tr') as HTMLElement
    expect(screen.getAllByText('Torre Eiffel')).toHaveLength(1)
    expect(within(filaEiffel).getByText('Patrimonio')).toBeInTheDocument()
    expect(within(filaEiffel).getByText('Difícil')).toBeInTheDocument()

    const filaMachu = screen.getByText('Machu Picchu').closest('tr') as HTMLElement
    expect(within(filaMachu).getByText('Muy difícil')).toBeInTheDocument()

    const filaSuelto = screen.getByText('Desafío suelto').closest('tr') as HTMLElement
    expect(within(filaSuelto).getByText('Fácil')).toBeInTheDocument()
  })

  it('cae a un ícono si la miniatura de imagen falla al cargar', async () => {
    fetchPreguntas.mockResolvedValue([
      pregunta({
        id: 'd-rota',
        nombre: 'Imagen rota',
        nombreLugar: 'Imagen rota',
        tipo: 'imagen',
        imagenUrl: 'https://example.test/no-existe.jpg',
      }),
    ])

    renderPreguntas()
    await screen.findByText('Imagen rota')

    const img = screen.getByAltText('')
    fireEvent.error(img)

    await waitFor(() => expect(screen.queryByAltText('')).not.toBeInTheDocument())
  })

  it('busca por nombre de la pregunta', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL, MACHU_PICCHU])
    const user = userEvent.setup()

    renderPreguntas()
    await screen.findByText('Torre Eiffel')

    await user.type(screen.getByPlaceholderText(/buscar por nombre/i), 'machu')

    expect(screen.queryByText('Torre Eiffel')).not.toBeInTheDocument()
    expect(screen.getByText('Machu Picchu')).toBeInTheDocument()
  })

  it('busca por el lugar real revelado aunque no coincida con el nombre', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL, MACHU_PICCHU])
    const user = userEvent.setup()

    renderPreguntas()
    await screen.findByText('Torre Eiffel')

    await user.type(screen.getByPlaceholderText(/buscar por nombre/i), 'perú')

    expect(screen.queryByText('Torre Eiffel')).not.toBeInTheDocument()
    expect(screen.getByText('Machu Picchu')).toBeInTheDocument()
  })

  it('combina el filtro de tipo y estado', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL, MACHU_PICCHU, DESAFIO_SUELTO])
    const user = userEvent.setup()

    renderPreguntas()
    await screen.findByText('Torre Eiffel')

    const grupoTipo = screen.getByRole('group', { name: /filtrar por tipo/i })
    await user.click(within(grupoTipo).getByRole('button', { name: 'Vídeo' }))
    expect(screen.queryByText('Torre Eiffel')).not.toBeInTheDocument()
    expect(screen.getByText('Desafío suelto')).toBeInTheDocument()

    const grupoEstado = screen.getByRole('group', { name: /filtrar por estado/i })
    await user.click(within(grupoEstado).getByRole('button', { name: 'Activo' }))
    expect(screen.queryByText('Desafío suelto')).not.toBeInTheDocument()
  })

  it('filtra por temática', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL, MACHU_PICCHU])
    const user = userEvent.setup()

    renderPreguntas()
    await screen.findByText('Torre Eiffel')

    await user.selectOptions(screen.getByLabelText(/filtrar por temática/i), 'Paisajes')
    expect(screen.queryByText('Torre Eiffel')).not.toBeInTheDocument()
    expect(screen.getByText('Machu Picchu')).toBeInTheDocument()
  })

  it('filtra por dificultad', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL, MACHU_PICCHU])
    const user = userEvent.setup()

    renderPreguntas()
    await screen.findByText('Torre Eiffel')

    const grupoDificultad = screen.getByRole('group', { name: /filtrar por dificultad/i })
    await user.click(within(grupoDificultad).getByRole('button', { name: 'Muy difícil' }))
    expect(screen.queryByText('Torre Eiffel')).not.toBeInTheDocument()
    expect(screen.getByText('Machu Picchu')).toBeInTheDocument()
  })

  it('marca como activo (aria-pressed) el chip del filtro seleccionado', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL, MACHU_PICCHU, DESAFIO_SUELTO])
    const user = userEvent.setup()

    renderPreguntas()
    await screen.findByText('Torre Eiffel')

    const grupoTipo = screen.getByRole('group', { name: /filtrar por tipo/i })
    const chipTodos = within(grupoTipo).getByRole('button', { name: 'Todos' })
    const chipVideo = within(grupoTipo).getByRole('button', { name: 'Vídeo' })

    expect(chipTodos).toHaveAttribute('aria-pressed', 'true')
    expect(chipVideo).toHaveAttribute('aria-pressed', 'false')

    await user.click(chipVideo)

    expect(chipTodos).toHaveAttribute('aria-pressed', 'false')
    expect(chipVideo).toHaveAttribute('aria-pressed', 'true')
  })

  it('recuerda el último filtro aplicado al volver a montar el listado (p.ej. tras crear una pregunta)', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL, MACHU_PICCHU, DESAFIO_SUELTO])
    const user = userEvent.setup()

    const { unmount } = renderPreguntas()
    await screen.findByText('Torre Eiffel')

    const grupoTipo = screen.getByRole('group', { name: /filtrar por tipo/i })
    await user.click(within(grupoTipo).getByRole('button', { name: 'Vídeo' }))
    expect(screen.getByText('Desafío suelto')).toBeInTheDocument()

    unmount()

    renderPreguntas()
    await screen.findByText('Desafío suelto')
    expect(screen.queryByText('Torre Eiffel')).not.toBeInTheDocument()

    const grupoTipoTrasRemontar = screen.getByRole('group', { name: /filtrar por tipo/i })
    expect(within(grupoTipoTrasRemontar).getByRole('button', { name: 'Vídeo' })).toHaveAttribute(
      'aria-pressed',
      'true',
    )
  })

  it('pagina los resultados y reinicia a la primera página al cambiar un filtro', async () => {
    const muchas = Array.from({ length: 12 }, (_, i) =>
      pregunta({
        id: `d-${i}`,
        nombre: `Lugar ${String(i).padStart(2, '0')}`,
        nombreLugar: `Lugar ${String(i).padStart(2, '0')}`,
      }),
    )
    fetchPreguntas.mockResolvedValue(muchas)
    const user = userEvent.setup()

    renderPreguntas()
    await screen.findByText('Lugar 00')

    expect(screen.getByText(/mostrando 1–10 de 12/i)).toBeInTheDocument()
    expect(screen.queryByText('Lugar 10')).not.toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: '2' }))
    expect(await screen.findByText('Lugar 10')).toBeInTheDocument()
    expect(screen.queryByText('Lugar 00')).not.toBeInTheDocument()

    await user.type(screen.getByPlaceholderText(/buscar por nombre/i), 'Lugar 0')
    expect(await screen.findByText('Lugar 00')).toBeInTheDocument()
  })

  it('muestra un estado vacío con CTA cuando los filtros no coinciden con nada', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL])
    const user = userEvent.setup()

    renderPreguntas()
    await screen.findByText('Torre Eiffel')

    await user.type(screen.getByPlaceholderText(/buscar por nombre/i), 'no-existe-nada')

    expect(await screen.findByText(/ninguna pregunta coincide/i)).toBeInTheDocument()
    const [limpiar] = screen.getAllByRole('button', { name: /limpiar filtros/i })

    await user.click(limpiar)
    expect(await screen.findByText('Torre Eiffel')).toBeInTheDocument()
  })

  it('muestra un estado vacío distinto cuando el banco no tiene ninguna pregunta', async () => {
    fetchPreguntas.mockResolvedValue([])

    renderPreguntas()

    expect(await screen.findByText(/todavía no hay preguntas/i)).toBeInTheDocument()
    const cta = screen.getByText(/crear la primera pregunta/i)
    expect(cta.closest('a')).toHaveAttribute('href', '/preguntas/nueva')
  })

  it('"Nueva pregunta" navega a /preguntas/nueva y "Editar" a /preguntas/{id}/editar', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL])

    renderPreguntas()
    await screen.findByText('Torre Eiffel')

    const nuevaPregunta = screen.getByText('Nueva pregunta')
    expect(nuevaPregunta.closest('a')).toHaveAttribute('href', '/preguntas/nueva')

    const fila = screen.getByText('Torre Eiffel').closest('tr') as HTMLElement
    const accionEditar = within(fila).getByLabelText('Editar')
    expect(accionEditar).toHaveAttribute('href', '/preguntas/d-eiffel/editar')
  })

  it('"Generar con IA" navega a /preguntas/generar-ia', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL])

    renderPreguntas()
    await screen.findByText('Torre Eiffel')

    const generarConIa = screen.getByText('Generar con IA')
    expect(generarConIa.closest('a')).toHaveAttribute('href', '/preguntas/generar-ia')
  })

  it('elimina un desafío con éxito y lo quita del listado', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL, MACHU_PICCHU])
    eliminarPregunta.mockResolvedValue(undefined)
    const user = userEvent.setup()

    renderPreguntas()
    await screen.findByText('Torre Eiffel')

    const filaEiffel = screen.getByText('Torre Eiffel').closest('tr') as HTMLElement
    await user.click(within(filaEiffel).getByTitle('Eliminar'))

    expect(eliminarPregunta).toHaveBeenCalledWith('d-eiffel')
    expect(await screen.findByText('Machu Picchu')).toBeInTheDocument()
    expect(screen.queryByText('Torre Eiffel')).not.toBeInTheDocument()
  })

  it('no reenvía un segundo borrado mientras el primero está en curso', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL])
    let resolverBorrado: () => void = () => {}
    eliminarPregunta.mockImplementation(
      () =>
        new Promise<void>((resolve) => {
          resolverBorrado = resolve
        }),
    )
    const user = userEvent.setup()

    renderPreguntas()
    const fila = (await screen.findByText('Torre Eiffel')).closest('tr') as HTMLElement
    const botonEliminar = within(fila).getByTitle('Eliminar')

    await user.click(botonEliminar)
    expect(botonEliminar).toBeDisabled()

    await user.click(botonEliminar)
    expect(eliminarPregunta).toHaveBeenCalledTimes(1)

    resolverBorrado()
    await waitFor(() => expect(screen.queryByText('Torre Eiffel')).not.toBeInTheDocument())
  })

  it('muestra el mensaje de error y conserva la fila si el desafío está en uso', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL])
    eliminarPregunta.mockRejectedValue(
      new Error('No se puede eliminar: esta pregunta tiene respuestas registradas de jugadores.'),
    )
    const user = userEvent.setup()

    renderPreguntas()
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

    renderPreguntas()
    const fila = (await screen.findByText('Torre Eiffel')).closest('tr') as HTMLElement
    await user.click(within(fila).getByTitle('Eliminar'))

    expect(eliminarPregunta).not.toHaveBeenCalled()
    expect(screen.getByText('Torre Eiffel')).toBeInTheDocument()
  })

  it('cambia la dificultad desde el listado sin navegar', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL])
    actualizarDificultadPregunta.mockResolvedValue(undefined)
    const user = userEvent.setup()

    renderPreguntas()
    const fila = (await screen.findByText('Torre Eiffel')).closest('tr') as HTMLElement

    await user.selectOptions(within(fila).getByLabelText('Dificultad de "Torre Eiffel"'), 'facil')

    expect(actualizarDificultadPregunta).toHaveBeenCalledWith('d-eiffel', 'facil')
    expect(screen.getByText('Torre Eiffel')).toBeInTheDocument()
  })

  it('cambia el estado activo/inactivo desde el listado', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL])
    actualizarActivoPregunta.mockResolvedValue(undefined)
    const user = userEvent.setup()

    renderPreguntas()
    const fila = (await screen.findByText('Torre Eiffel')).closest('tr') as HTMLElement

    await user.click(within(fila).getByLabelText('Cambiar estado de "Torre Eiffel"'))

    expect(actualizarActivoPregunta).toHaveBeenCalledWith('d-eiffel', false)
    expect(within(fila).getByText('Inactivo')).toBeInTheDocument()
  })

  it('revierte el cambio y muestra un error si el guardado inline falla', async () => {
    fetchPreguntas.mockResolvedValue([TORRE_EIFFEL])
    actualizarActivoPregunta.mockRejectedValue(new Error('No se ha podido guardar.'))
    const user = userEvent.setup()

    renderPreguntas()
    const fila = (await screen.findByText('Torre Eiffel')).closest('tr') as HTMLElement

    await user.click(within(fila).getByLabelText('Cambiar estado de "Torre Eiffel"'))

    expect(await within(fila).findByText('No se ha podido guardar.')).toBeInTheDocument()
    expect(within(fila).getByText('Activo')).toBeInTheDocument()
  })

  it('muestra un error si falla la carga del listado', async () => {
    fetchPreguntas.mockRejectedValue(new Error('network down'))

    renderPreguntas()

    expect(
      await screen.findByText(/no se ha podido cargar el listado de preguntas/i),
    ).toBeInTheDocument()
  })
})
