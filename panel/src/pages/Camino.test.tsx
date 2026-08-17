import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor, fireEvent } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import { Camino } from './Camino'
import type { NivelDisponible, PosicionCamino } from '../lib/camino'

const fetchCamino = vi.fn()
const fetchNivelesNoAsignados = vi.fn()
const agregarNivelAlCamino = vi.fn()
const reordenarCamino = vi.fn()
const actualizarEstrellasRequeridas = vi.fn()
const quitarDelCamino = vi.fn()

vi.mock('../lib/camino', async () => {
  const actual = await vi.importActual<typeof import('../lib/camino')>('../lib/camino')
  return {
    ...actual,
    fetchCamino: (...args: unknown[]) => fetchCamino(...args),
    fetchNivelesNoAsignados: (...args: unknown[]) => fetchNivelesNoAsignados(...args),
    agregarNivelAlCamino: (...args: unknown[]) => agregarNivelAlCamino(...args),
    reordenarCamino: (...args: unknown[]) => reordenarCamino(...args),
    actualizarEstrellasRequeridas: (...args: unknown[]) => actualizarEstrellasRequeridas(...args),
    quitarDelCamino: (...args: unknown[]) => quitarDelCamino(...args),
  }
})

function renderCamino() {
  return render(
    <MemoryRouter>
      <Camino />
    </MemoryRouter>,
  )
}

const CAMINO: PosicionCamino[] = [
  {
    id: 'c-1',
    orden: 1,
    nivelId: 'n-1',
    nivelNombre: 'Nivel 1',
    tematicaNombre: 'Monumentos',
    estrellasRequeridas: 0,
  },
  {
    id: 'c-2',
    orden: 2,
    nivelId: 'n-2',
    nivelNombre: 'Nivel 1',
    tematicaNombre: 'Banderas',
    estrellasRequeridas: 3,
  },
]

beforeEach(() => {
  fetchCamino.mockReset()
  fetchNivelesNoAsignados.mockReset()
  agregarNivelAlCamino.mockReset()
  reordenarCamino.mockReset()
  actualizarEstrellasRequeridas.mockReset()
  quitarDelCamino.mockReset()
  vi.spyOn(window, 'confirm').mockReturnValue(true)
})

describe('Camino — listado', () => {
  it('muestra una fila por posición con temática, nivel y estrellas requeridas', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    renderCamino()

    await screen.findByText('Monumentos')
    expect(screen.getByText('Banderas')).toBeInTheDocument()
    expect(screen.getAllByText('Nivel 1')).toHaveLength(2)
    expect(screen.getByDisplayValue('0')).toBeInTheDocument()
    expect(screen.getByDisplayValue('3')).toBeInTheDocument()
  })

  it('muestra el estado vacío cuando el camino no tiene posiciones', async () => {
    fetchCamino.mockResolvedValue([])
    renderCamino()

    expect(await screen.findByText('El camino está vacío')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /añadir nivel al camino/i })).toBeInTheDocument()
  })

  it('muestra un error si falla la carga del camino', async () => {
    fetchCamino.mockRejectedValue(new Error('sin conexión'))
    renderCamino()

    expect(await screen.findByText('No se ha podido cargar el camino.')).toBeInTheDocument()
  })
})

describe('Camino — añadir nivel', () => {
  it('añade un nivel existente desde el selector', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    const disponibles: NivelDisponible[] = [
      { id: 'n-9', nombre: 'Nivel 3', tematicaNombre: 'Paisajes' },
    ]
    fetchNivelesNoAsignados.mockResolvedValue(disponibles)
    agregarNivelAlCamino.mockResolvedValue({ id: 'c-9' })
    const user = userEvent.setup()
    renderCamino()

    await screen.findByText('Monumentos')
    await user.click(screen.getByRole('button', { name: /añadir nivel al camino/i }))

    await screen.findByText('Nivel 3')
    await user.click(screen.getByText('Añadir'))

    await waitFor(() => expect(agregarNivelAlCamino).toHaveBeenCalledWith('n-9'))
    expect(
      await screen.findByText('3 posiciones · el orden define la secuencia de juego'),
    ).toBeInTheDocument()
  })

  it('el selector no ofrece niveles ya presentes en el camino', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    fetchNivelesNoAsignados.mockResolvedValue([])
    const user = userEvent.setup()
    renderCamino()

    await screen.findByText('Monumentos')
    await user.click(screen.getByRole('button', { name: /añadir nivel al camino/i }))

    expect(await screen.findByText('Todos los niveles ya están en el camino.')).toBeInTheDocument()
  })
})

describe('Camino — reorden', () => {
  it('sube la posición de una fila y persiste el nuevo orden', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    reordenarCamino.mockResolvedValue(undefined)
    const user = userEvent.setup()
    renderCamino()

    await screen.findByText('Monumentos')
    await user.click(screen.getAllByLabelText('Subir posición')[1])

    await waitFor(() => expect(reordenarCamino).toHaveBeenCalledWith(['c-2', 'c-1']))
  })

  it('arrastra una fila a otra posición y persiste el nuevo orden', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    reordenarCamino.mockResolvedValue(undefined)
    renderCamino()

    await screen.findByText('Monumentos')
    const filaMonumentos = screen.getByText('Monumentos').closest('tr') as HTMLElement
    const filaBanderas = screen.getByText('Banderas').closest('tr') as HTMLElement

    fireEvent.dragStart(filaBanderas)
    fireEvent.dragOver(filaMonumentos)
    fireEvent.drop(filaMonumentos)

    await waitFor(() => expect(reordenarCamino).toHaveBeenCalledWith(['c-2', 'c-1']))
  })

  it('revierte el orden local si la persistencia del reorden falla', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    reordenarCamino.mockRejectedValue(new Error('conflicto de orden'))
    const user = userEvent.setup()
    renderCamino()

    await screen.findByText('Monumentos')
    await user.click(screen.getAllByLabelText('Subir posición')[1])

    expect(await screen.findByText('conflicto de orden')).toBeInTheDocument()
    const nombres = screen.getAllByText(/^(Monumentos|Banderas)$/).map((el) => el.textContent)
    expect(nombres).toEqual(['Monumentos', 'Banderas'])
  })
})

describe('Camino — editar estrellas requeridas', () => {
  it('guarda un umbral válido al perder el foco', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    actualizarEstrellasRequeridas.mockResolvedValue(undefined)
    const user = userEvent.setup()
    renderCamino()

    await screen.findByText('Monumentos')
    const input = screen.getByDisplayValue('0')
    await user.clear(input)
    await user.type(input, '5')
    await user.tab()

    await waitFor(() => expect(actualizarEstrellasRequeridas).toHaveBeenCalledWith('c-1', 5))
  })

  it('bloquea un valor negativo sin llamar a supabase', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    const user = userEvent.setup()
    renderCamino()

    await screen.findByText('Monumentos')
    const input = screen.getByDisplayValue('0')
    await user.clear(input)
    await user.type(input, '-1')
    await user.tab()

    expect(
      await screen.findByText('Debe ser un número entero igual o mayor a 0.'),
    ).toBeInTheDocument()
    expect(actualizarEstrellasRequeridas).not.toHaveBeenCalled()
  })
})

describe('Camino — quitar posición', () => {
  it('quita una posición del camino tras confirmar', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    quitarDelCamino.mockResolvedValue(undefined)
    const user = userEvent.setup()
    renderCamino()

    await screen.findByText('Monumentos')
    await user.click(screen.getAllByText('Quitar del camino')[0])

    await waitFor(() => expect(quitarDelCamino).toHaveBeenCalledWith('c-1'))
    expect(screen.queryByText('Monumentos')).not.toBeInTheDocument()
  })

  it('no quita nada si se cancela la confirmación', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    vi.spyOn(window, 'confirm').mockReturnValue(false)
    const user = userEvent.setup()
    renderCamino()

    await screen.findByText('Monumentos')
    await user.click(screen.getAllByText('Quitar del camino')[0])

    expect(quitarDelCamino).not.toHaveBeenCalled()
  })
})
