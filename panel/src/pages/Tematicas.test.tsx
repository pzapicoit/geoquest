import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor, fireEvent } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import { Tematicas } from './Tematicas'
import type { Tematica } from '../lib/tematicas'

function renderTematicas() {
  return render(
    <MemoryRouter>
      <Tematicas />
    </MemoryRouter>,
  )
}

const fetchTematicas = vi.fn()
const guardarTematica = vi.fn()
const eliminarTematica = vi.fn()
const reordenarTematicas = vi.fn()

vi.mock('../lib/tematicas', async () => {
  const actual = await vi.importActual<typeof import('../lib/tematicas')>('../lib/tematicas')
  return {
    ...actual,
    fetchTematicas: (...args: unknown[]) => fetchTematicas(...args),
    guardarTematica: (...args: unknown[]) => guardarTematica(...args),
    eliminarTematica: (...args: unknown[]) => eliminarTematica(...args),
    reordenarTematicas: (...args: unknown[]) => reordenarTematicas(...args),
  }
})

function tematica(overrides: Partial<Tematica> & { id: string }): Tematica {
  return {
    nombre: 'Temática de prueba',
    imagenPortada: 'https://example.test/portada.jpg',
    orden: 1,
    activo: true,
    cantidadNiveles: 0,
    ...overrides,
  }
}

const CAPITALES = tematica({
  id: 't-1',
  nombre: 'Capitales del mundo',
  orden: 1,
  cantidadNiveles: 12,
})

const PAISAJES = tematica({
  id: 't-2',
  nombre: 'Paisajes de Europa',
  orden: 2,
  cantidadNiveles: 9,
})

function archivo(nombre: string, tipo: string, bytes = 1024) {
  return new File([new Uint8Array(bytes)], nombre, { type: tipo })
}

beforeEach(() => {
  fetchTematicas.mockReset()
  guardarTematica.mockReset()
  eliminarTematica.mockReset()
  reordenarTematicas.mockReset()
  vi.spyOn(window, 'confirm').mockReturnValue(true)
})

describe('Tematicas — listado', () => {
  it('muestra una fila por temática con nombre, niveles y estado', async () => {
    fetchTematicas.mockResolvedValue([CAPITALES, PAISAJES])

    renderTematicas()

    expect(await screen.findByText('Capitales del mundo')).toBeInTheDocument()
    expect(screen.getByText('12 niveles')).toBeInTheDocument()
    expect(screen.getByText('Paisajes de Europa')).toBeInTheDocument()
    expect(screen.getByText('9 niveles')).toBeInTheDocument()
    expect(screen.getAllByText('Activa')).toHaveLength(2)
  })

  it('el nombre de la temática enlaza al listado de niveles de esa temática', async () => {
    fetchTematicas.mockResolvedValue([CAPITALES])
    renderTematicas()

    const nombre = await screen.findByText('Capitales del mundo')
    expect(nombre.closest('a')).toHaveAttribute('href', '/tematicas/t-1/niveles')
  })

  it('muestra el estado vacío cuando no hay ninguna temática', async () => {
    fetchTematicas.mockResolvedValue([])
    renderTematicas()

    expect(await screen.findByText('Aún no hay temáticas')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /crear la primera temática/i })).toBeInTheDocument()
  })
})

describe('Tematicas — reorden por arrastre', () => {
  it('arrastra una temática a otra posición y persiste el nuevo orden', async () => {
    fetchTematicas.mockResolvedValue([CAPITALES, PAISAJES])
    reordenarTematicas.mockResolvedValue(undefined)
    renderTematicas()

    await screen.findByText('Capitales del mundo')
    const filaCapitales = screen.getByText('Capitales del mundo').closest('tr') as HTMLElement
    const filaPaisajes = screen.getByText('Paisajes de Europa').closest('tr') as HTMLElement

    fireEvent.dragStart(filaPaisajes)
    fireEvent.dragOver(filaCapitales)
    fireEvent.drop(filaCapitales)

    await waitFor(() => expect(reordenarTematicas).toHaveBeenCalledWith(['t-2', 't-1']))
  })

  it('sube de posición con el botón y revierte si falla la persistencia', async () => {
    fetchTematicas.mockResolvedValue([CAPITALES, PAISAJES])
    reordenarTematicas.mockRejectedValue(new Error('conflicto de orden'))
    const user = userEvent.setup()
    renderTematicas()

    await screen.findByText('Capitales del mundo')
    await user.click(screen.getAllByLabelText('Subir posición')[1])

    expect(await screen.findByText('conflicto de orden')).toBeInTheDocument()
    const nombres = screen
      .getAllByText(/^(Capitales del mundo|Paisajes de Europa)$/)
      .map((el) => el.textContent)
    expect(nombres).toEqual(['Capitales del mundo', 'Paisajes de Europa'])
  })
})

describe('Tematicas — eliminación', () => {
  it('elimina tras confirmar', async () => {
    fetchTematicas.mockResolvedValue([CAPITALES])
    eliminarTematica.mockResolvedValue(undefined)
    const user = userEvent.setup()
    renderTematicas()

    await screen.findByText('Capitales del mundo')
    await user.click(screen.getByLabelText('Eliminar temática'))

    expect(window.confirm).toHaveBeenCalledWith(expect.stringContaining('12 niveles'))
    await waitFor(() => expect(eliminarTematica).toHaveBeenCalledWith('t-1'))
    await waitFor(() => expect(screen.queryByText('Capitales del mundo')).not.toBeInTheDocument())
  })

  it('no elimina si se cancela la confirmación', async () => {
    fetchTematicas.mockResolvedValue([CAPITALES])
    vi.spyOn(window, 'confirm').mockReturnValue(false)
    const user = userEvent.setup()
    renderTematicas()

    await screen.findByText('Capitales del mundo')
    await user.click(screen.getByLabelText('Eliminar temática'))

    expect(eliminarTematica).not.toHaveBeenCalled()
    expect(screen.getByText('Capitales del mundo')).toBeInTheDocument()
  })

  it('muestra un error de fila si la eliminación falla', async () => {
    fetchTematicas.mockResolvedValue([CAPITALES])
    eliminarTematica.mockRejectedValue(new Error('en uso por niveles activos'))
    const user = userEvent.setup()
    renderTematicas()

    await screen.findByText('Capitales del mundo')
    await user.click(screen.getByLabelText('Eliminar temática'))

    expect(await screen.findByText('en uso por niveles activos')).toBeInTheDocument()
    expect(screen.getByText('Capitales del mundo')).toBeInTheDocument()
  })
})

describe('Tematicas — carga', () => {
  it('muestra un error si falla la carga del listado', async () => {
    fetchTematicas.mockRejectedValue(new Error('sin conexión'))
    renderTematicas()

    expect(
      await screen.findByText('No se ha podido cargar el listado de temáticas.'),
    ).toBeInTheDocument()
  })
})

describe('Tematicas — panel de alta/edición', () => {
  it('editar una temática precarga sus datos', async () => {
    fetchTematicas.mockResolvedValue([CAPITALES, PAISAJES])
    const user = userEvent.setup()
    renderTematicas()

    await screen.findByText('Paisajes de Europa')
    await user.click(screen.getAllByLabelText('Editar temática')[1])

    expect(screen.getByDisplayValue('Paisajes de Europa')).toBeInTheDocument()
  })

  it('bloquea el guardado sin nombre ni portada', async () => {
    fetchTematicas.mockResolvedValue([])
    const user = userEvent.setup()
    renderTematicas()

    await screen.findByText('Aún no hay temáticas')
    await user.click(screen.getByRole('button', { name: /crear la primera temática/i }))
    await user.click(screen.getByRole('button', { name: /^guardar$/i }))

    expect(screen.getByText('El nombre es obligatorio.')).toBeInTheDocument()
    expect(screen.getByText('Selecciona una imagen de portada.')).toBeInTheDocument()
    expect(guardarTematica).not.toHaveBeenCalled()
  })

  it('crea una temática con portada válida y cierra el panel al guardar', async () => {
    fetchTematicas.mockResolvedValueOnce([]).mockResolvedValueOnce([CAPITALES])
    guardarTematica.mockResolvedValue({ id: 't-1' })
    const user = userEvent.setup()
    renderTematicas()

    await screen.findByText('Aún no hay temáticas')
    await user.click(screen.getByRole('button', { name: /crear la primera temática/i }))

    await user.type(screen.getByLabelText(/^nombre/i), 'Capitales del mundo')
    await user.upload(screen.getByLabelText(/arrastra o/i), archivo('portada.jpg', 'image/jpeg'))
    await user.click(screen.getByRole('button', { name: /^guardar$/i }))

    await waitFor(() =>
      expect(guardarTematica).toHaveBeenCalledWith(
        expect.objectContaining({ nombre: 'Capitales del mundo' }),
      ),
    )
    await waitFor(() =>
      expect(screen.queryByRole('button', { name: /^guardar$/i })).not.toBeInTheDocument(),
    )
    expect(fetchTematicas).toHaveBeenCalledTimes(2)
  })

  it('edita el estado (activo) de una temática existente', async () => {
    fetchTematicas.mockResolvedValueOnce([CAPITALES, PAISAJES]).mockResolvedValueOnce([CAPITALES])
    guardarTematica.mockResolvedValue({ id: 't-2' })
    const user = userEvent.setup()
    renderTematicas()

    await screen.findByText('Paisajes de Europa')
    await user.click(screen.getAllByLabelText('Editar temática')[1])

    await user.click(screen.getByRole('checkbox'))
    await user.click(screen.getByRole('button', { name: /^guardar$/i }))

    await waitFor(() =>
      expect(guardarTematica).toHaveBeenCalledWith(
        expect.objectContaining({ id: 't-2', activo: false }),
      ),
    )
  })

  it('muestra un error y mantiene el panel abierto si el guardado falla', async () => {
    fetchTematicas.mockResolvedValue([])
    guardarTematica.mockRejectedValue(new Error('nombre duplicado'))
    const user = userEvent.setup()
    renderTematicas()

    await screen.findByText('Aún no hay temáticas')
    await user.click(screen.getByRole('button', { name: /crear la primera temática/i }))

    await user.type(screen.getByLabelText(/^nombre/i), 'Capitales del mundo')
    await user.upload(screen.getByLabelText(/arrastra o/i), archivo('portada.jpg', 'image/jpeg'))
    await user.click(screen.getByRole('button', { name: /^guardar$/i }))

    expect(await screen.findByText('nombre duplicado')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /^guardar$/i })).toBeInTheDocument()
  })

  it('rechaza un archivo de portada de tipo no permitido soltado sobre la zona de arrastre', async () => {
    // userEvent.upload valida el `accept` del input y no dispara el evento
    // para un tipo no permitido, pero soltar un archivo arrastrado sí puede
    // saltarse ese filtro — de ahí que la validación deba ocurrir en
    // handleArchivoPortada y no solo confiar en `accept`.
    fetchTematicas.mockResolvedValue([])
    const user = userEvent.setup()
    renderTematicas()

    await screen.findByText('Aún no hay temáticas')
    await user.click(screen.getByRole('button', { name: /crear la primera temática/i }))

    const input = screen.getByLabelText(/arrastra o/i) as HTMLInputElement
    const file = archivo('portada.webp', 'image/webp')
    fireEvent.change(input, { target: { files: [file] } })

    expect(await screen.findByText('La portada debe ser JPG o PNG.')).toBeInTheDocument()
  })

  it('cancelar cierra el panel sin guardar', async () => {
    fetchTematicas.mockResolvedValue([CAPITALES])
    const user = userEvent.setup()
    renderTematicas()

    await screen.findByText('Capitales del mundo')
    await user.click(screen.getAllByLabelText('Editar temática')[0])
    await user.click(screen.getByRole('button', { name: /cancelar/i }))

    expect(guardarTematica).not.toHaveBeenCalled()
    expect(screen.queryByRole('button', { name: /^guardar$/i })).not.toBeInTheDocument()
  })
})
