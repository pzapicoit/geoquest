import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor, fireEvent, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes, useParams } from 'react-router-dom'
import { NivelesTematica } from './NivelesTematica'
import type { NivelesTematica as NivelesTematicaData } from '../lib/niveles'

const fetchNivelesTematica = vi.fn()
const crearNivel = vi.fn()
const eliminarNivel = vi.fn()
const reordenarNiveles = vi.fn()

vi.mock('../lib/niveles', async () => {
  const actual = await vi.importActual<typeof import('../lib/niveles')>('../lib/niveles')
  return {
    ...actual,
    fetchNivelesTematica: (...args: unknown[]) => fetchNivelesTematica(...args),
    crearNivel: (...args: unknown[]) => crearNivel(...args),
    eliminarNivel: (...args: unknown[]) => eliminarNivel(...args),
    reordenarNiveles: (...args: unknown[]) => reordenarNiveles(...args),
  }
})

function RecorridoStub() {
  const { id } = useParams<{ id: string }>()
  return <div>Recorrido de {id}</div>
}

function renderNiveles(tematicaId = 't-1') {
  return render(
    <MemoryRouter initialEntries={[`/tematicas/${tematicaId}/niveles`]}>
      <Routes>
        <Route path="/tematicas/:id/niveles" element={<NivelesTematica />} />
        <Route path="/tematicas" element={<div>Listado de temáticas</div>} />
        <Route path="/niveles/:id" element={<RecorridoStub />} />
      </Routes>
    </MemoryRouter>,
  )
}

const DATOS: NivelesTematicaData = {
  tematicaId: 't-1',
  tematicaNombre: 'Paisajes de Europa',
  tematicaOrden: 2,
  niveles: [
    {
      id: 'n-1',
      nombre: 'Costas del sur',
      orden: 1,
      puntajeMinimoSuperar: 900,
      activo: true,
      cantidadPreguntas: 8,
    },
    {
      id: 'n-2',
      nombre: null,
      orden: 2,
      puntajeMinimoSuperar: 1000,
      activo: false,
      cantidadPreguntas: 2,
    },
  ],
}

beforeEach(() => {
  fetchNivelesTematica.mockReset()
  crearNivel.mockReset()
  eliminarNivel.mockReset()
  reordenarNiveles.mockReset()
})

describe('NivelesTematica — listado', () => {
  it('muestra el breadcrumb, el título y una fila por nivel', async () => {
    fetchNivelesTematica.mockResolvedValue(DATOS)
    renderNiveles()

    await screen.findByText('Costas del sur')

    const breadcrumb = screen.getByLabelText('Miga de pan')
    expect(breadcrumb.textContent).toContain('Temáticas')
    expect(breadcrumb.textContent).toContain('Paisajes de Europa')

    expect(screen.getByText('Niveles de «Paisajes de Europa»')).toBeInTheDocument()
    expect(
      screen.getByText('2 niveles · 1 activos · 10 preguntas asignadas en total'),
    ).toBeInTheDocument()
  })

  it('usa "Nivel N" cuando el nivel no tiene nombre asignado', async () => {
    fetchNivelesTematica.mockResolvedValue(DATOS)
    renderNiveles()

    expect(await screen.findByText('Nivel 2')).toBeInTheDocument()
  })

  it('resalta el badge de preguntas cuando hay menos de 3 asignadas', async () => {
    fetchNivelesTematica.mockResolvedValue(DATOS)
    renderNiveles()

    await screen.findByText('Costas del sur')

    expect(screen.getByText('8 preguntas').className).not.toContain('996100')
    expect(screen.getByText('2 preguntas').className).toContain('996100')
  })

  it('estado vacío sin niveles, sin referencia a estrellas ni a otra temática', async () => {
    fetchNivelesTematica.mockResolvedValue({ ...DATOS, niveles: [] })
    renderNiveles()

    expect(await screen.findByText('Esta temática aún no tiene niveles')).toBeInTheDocument()
    expect(screen.getByText('Sin niveles todavía')).toBeInTheDocument()
  })

  it('muestra un error si falla la carga del listado', async () => {
    fetchNivelesTematica.mockRejectedValue(new Error('sin conexión'))
    renderNiveles()

    expect(
      await screen.findByText('No se ha podido cargar el listado de niveles.'),
    ).toBeInTheDocument()
  })
})

describe('NivelesTematica — navegación al Recorrido', () => {
  it('el nombre de un nivel navega a su Recorrido', async () => {
    fetchNivelesTematica.mockResolvedValue(DATOS)
    const user = userEvent.setup()
    renderNiveles()

    await user.click(await screen.findByText('Costas del sur'))

    expect(await screen.findByText('Recorrido de n-1')).toBeInTheDocument()
  })

  it('el botón "Recorrido →" navega también', async () => {
    fetchNivelesTematica.mockResolvedValue(DATOS)
    const user = userEvent.setup()
    renderNiveles()

    await screen.findByText('Costas del sur')
    await user.click(screen.getAllByText('Recorrido →')[0])

    expect(await screen.findByText('Recorrido de n-1')).toBeInTheDocument()
  })

  it('hacer click en el estado de la fila no navega', async () => {
    fetchNivelesTematica.mockResolvedValue(DATOS)
    const user = userEvent.setup()
    renderNiveles()

    await screen.findByText('Costas del sur')
    await user.click(screen.getByText('Activo'))

    expect(screen.getByText('Niveles de «Paisajes de Europa»')).toBeInTheDocument()
  })
})

describe('NivelesTematica — alta de un nivel', () => {
  it('crea un nivel nuevo y navega a su Recorrido', async () => {
    fetchNivelesTematica.mockResolvedValue(DATOS)
    crearNivel.mockResolvedValue({ id: 'n-9' })
    const user = userEvent.setup()
    renderNiveles()

    await screen.findByText('Costas del sur')
    await user.click(screen.getByRole('button', { name: /nuevo nivel/i }))

    const dialog = screen.getByRole('dialog', { name: 'Nuevo nivel' })
    expect(within(dialog).getByText(/Paisajes de Europa/)).toBeInTheDocument()
    expect(within(dialog).getByText('Posición 03 del recorrido')).toBeInTheDocument()

    await user.type(within(dialog).getByLabelText(/nombre del nivel/i), 'Islas del norte')
    await user.click(within(dialog).getByRole('button', { name: /guardar y configurar/i }))

    await waitFor(() => expect(crearNivel).toHaveBeenCalledWith('t-1', 'Islas del norte'))
    expect(await screen.findByText('Recorrido de n-9')).toBeInTheDocument()
  })

  it('bloquea el guardado sin nombre', async () => {
    fetchNivelesTematica.mockResolvedValue(DATOS)
    const user = userEvent.setup()
    renderNiveles()

    await screen.findByText('Costas del sur')
    await user.click(screen.getByRole('button', { name: /nuevo nivel/i }))
    await user.click(screen.getByRole('button', { name: /guardar y configurar/i }))

    expect(screen.getByText('El nombre del nivel es obligatorio.')).toBeInTheDocument()
    expect(crearNivel).not.toHaveBeenCalled()
  })

  it('muestra un error si la creación falla', async () => {
    fetchNivelesTematica.mockResolvedValue(DATOS)
    crearNivel.mockRejectedValue(new Error('límite alcanzado'))
    const user = userEvent.setup()
    renderNiveles()

    await screen.findByText('Costas del sur')
    await user.click(screen.getByRole('button', { name: /nuevo nivel/i }))
    await user.type(screen.getByLabelText(/nombre del nivel/i), 'Nivel X')
    await user.click(screen.getByRole('button', { name: /guardar y configurar/i }))

    expect(await screen.findByText('límite alcanzado')).toBeInTheDocument()
  })

  it('cancelar cierra el modal sin crear', async () => {
    fetchNivelesTematica.mockResolvedValue(DATOS)
    const user = userEvent.setup()
    renderNiveles()

    await screen.findByText('Costas del sur')
    await user.click(screen.getByRole('button', { name: /nuevo nivel/i }))
    await user.click(screen.getByRole('button', { name: /cancelar/i }))

    expect(crearNivel).not.toHaveBeenCalled()
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })
})

describe('NivelesTematica — reorden', () => {
  it('arrastra una fila a otra posición y persiste el nuevo orden', async () => {
    fetchNivelesTematica.mockResolvedValue(DATOS)
    reordenarNiveles.mockResolvedValue(undefined)
    renderNiveles()

    await screen.findByText('Costas del sur')
    const filaOrigen = screen.getByText('Nivel 2').closest('[draggable="true"]') as HTMLElement
    const filaDestino = screen
      .getByText('Costas del sur')
      .closest('[draggable="true"]') as HTMLElement

    fireEvent.dragStart(filaOrigen)
    fireEvent.dragOver(filaDestino)
    fireEvent.drop(filaDestino)

    await waitFor(() => expect(reordenarNiveles).toHaveBeenCalledWith('t-1', ['n-2', 'n-1']))
  })

  it('sube de posición con el botón y revierte si falla la persistencia', async () => {
    fetchNivelesTematica.mockResolvedValue(DATOS)
    reordenarNiveles.mockRejectedValue(new Error('conflicto de orden'))
    const user = userEvent.setup()
    renderNiveles()

    await screen.findByText('Costas del sur')
    await user.click(screen.getAllByLabelText('Subir posición')[1])

    expect(await screen.findByText('conflicto de orden')).toBeInTheDocument()
    const nombres = screen.getAllByText(/^(Costas del sur|Nivel 2)$/).map((el) => el.textContent)
    expect(nombres).toEqual(['Costas del sur', 'Nivel 2'])
  })
})

describe('NivelesTematica — eliminación', () => {
  it('abre la confirmación con el recuento de preguntas y elimina al confirmar', async () => {
    fetchNivelesTematica.mockResolvedValue(DATOS)
    eliminarNivel.mockResolvedValue(undefined)
    const user = userEvent.setup()
    renderNiveles()

    await screen.findByText('Costas del sur')
    await user.click(screen.getAllByLabelText('Eliminar nivel')[0])

    const dialog = screen.getByRole('dialog', { name: 'Eliminar Costas del sur' })
    expect(within(dialog).getByText(/recorrido de 8 preguntas asignadas/)).toBeInTheDocument()

    await user.click(within(dialog).getByRole('button', { name: 'Eliminar nivel' }))

    await waitFor(() => expect(eliminarNivel).toHaveBeenCalledWith('t-1', 'n-1'))
    await waitFor(() => expect(screen.queryByText('Costas del sur')).not.toBeInTheDocument())
  })

  it('cancelar no elimina', async () => {
    fetchNivelesTematica.mockResolvedValue(DATOS)
    const user = userEvent.setup()
    renderNiveles()

    await screen.findByText('Costas del sur')
    await user.click(screen.getAllByLabelText('Eliminar nivel')[0])
    await user.click(screen.getByRole('button', { name: /cancelar/i }))

    expect(eliminarNivel).not.toHaveBeenCalled()
    expect(screen.getByText('Costas del sur')).toBeInTheDocument()
  })

  it('muestra un error dentro del modal si la eliminación falla', async () => {
    fetchNivelesTematica.mockResolvedValue(DATOS)
    eliminarNivel.mockRejectedValue(new Error('no autorizado'))
    const user = userEvent.setup()
    renderNiveles()

    await screen.findByText('Costas del sur')
    await user.click(screen.getAllByLabelText('Eliminar nivel')[0])
    const dialog = screen.getByRole('dialog', { name: 'Eliminar Costas del sur' })
    await user.click(within(dialog).getByRole('button', { name: 'Eliminar nivel' }))

    expect(await within(dialog).findByText('no autorizado')).toBeInTheDocument()
    expect(screen.getByText('Costas del sur')).toBeInTheDocument()
  })
})
