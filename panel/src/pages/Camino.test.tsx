import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor, fireEvent, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import { Camino } from './Camino'
import type { PosicionCamino, TematicaOpcion } from '../lib/camino'
import type { DificultadDefault, UmbralesParada } from '../lib/dificultadDefaults'

const fetchCamino = vi.fn()
const fetchTematicasParaCamino = vi.fn()
const agregarParadaAlCamino = vi.fn()
const reordenarCamino = vi.fn()
const quitarDelCamino = vi.fn()
const actualizarOverridesParada = vi.fn()

vi.mock('../lib/camino', async () => {
  const actual = await vi.importActual<typeof import('../lib/camino')>('../lib/camino')
  return {
    ...actual,
    fetchCamino: (...args: unknown[]) => fetchCamino(...args),
    fetchTematicasParaCamino: (...args: unknown[]) => fetchTematicasParaCamino(...args),
    agregarParadaAlCamino: (...args: unknown[]) => agregarParadaAlCamino(...args),
    reordenarCamino: (...args: unknown[]) => reordenarCamino(...args),
    quitarDelCamino: (...args: unknown[]) => quitarDelCamino(...args),
    actualizarOverridesParada: (...args: unknown[]) => actualizarOverridesParada(...args),
  }
})

const fetchDificultadDefaults = vi.fn()
const fetchUmbralesParada = vi.fn()
vi.mock('../lib/dificultadDefaults', async () => {
  const actual = await vi.importActual<typeof import('../lib/dificultadDefaults')>(
    '../lib/dificultadDefaults',
  )
  return {
    ...actual,
    fetchDificultadDefaults: (...args: unknown[]) => fetchDificultadDefaults(...args),
    fetchUmbralesParada: (...args: unknown[]) => fetchUmbralesParada(...args),
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
    tematicaId: 't-1',
    tematicaNombre: 'Monumentos',
    dificultad: 'facil',
    nombre: null,
    preguntasPorPartida: null,
    segundosPorDesafio: null,
  },
  {
    id: 'c-2',
    orden: 2,
    tematicaId: 't-2',
    tematicaNombre: 'Banderas',
    dificultad: 'dificil',
    nombre: null,
    preguntasPorPartida: null,
    segundosPorDesafio: null,
  },
]

const DEFAULTS: DificultadDefault[] = [
  { dificultad: 'facil', preguntasPorPartida: 8, segundosPorDesafio: 90 },
  { dificultad: 'normal', preguntasPorPartida: 8, segundosPorDesafio: 75 },
  { dificultad: 'intermedio', preguntasPorPartida: 6, segundosPorDesafio: 60 },
  { dificultad: 'dificil', preguntasPorPartida: 6, segundosPorDesafio: 45 },
  { dificultad: 'muy_dificil', preguntasPorPartida: 5, segundosPorDesafio: 30 },
]

const UMBRALES_FACIL: UmbralesParada = {
  maximo: 44000,
  minimo: 19800,
  umbralEstrella2: 28600,
  umbralEstrella3: 36080,
}

beforeEach(() => {
  fetchCamino.mockReset()
  fetchTematicasParaCamino.mockReset()
  agregarParadaAlCamino.mockReset()
  reordenarCamino.mockReset()
  quitarDelCamino.mockReset()
  actualizarOverridesParada.mockReset()
  fetchDificultadDefaults.mockReset()
  fetchUmbralesParada.mockReset()
  fetchDificultadDefaults.mockResolvedValue(DEFAULTS)
  fetchUmbralesParada.mockResolvedValue(UMBRALES_FACIL)
  vi.spyOn(window, 'confirm').mockReturnValue(true)
})

describe('Camino — listado', () => {
  it('muestra una fila por posición con temática, dificultad y estrellas requeridas derivadas', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    renderCamino()

    await screen.findByText('Monumentos · Fácil')
    expect(screen.getByText('Banderas · Difícil')).toBeInTheDocument()
    // orden 1 -> 0 estrellas, orden 2 -> 1 estrella (floor((2-1) * 1.8)); se
    // busca dentro de cada fila para no confundirse con la columna "#".
    const filaMonumentos = screen.getByText('Monumentos · Fácil').closest('tr') as HTMLElement
    const filaBanderas = screen.getByText('Banderas · Difícil').closest('tr') as HTMLElement
    expect(within(filaMonumentos).getByText('0')).toBeInTheDocument()
    expect(within(filaBanderas).getByText('1')).toBeInTheDocument()
  })

  it('muestra el estado vacío cuando el camino no tiene posiciones', async () => {
    fetchCamino.mockResolvedValue([])
    renderCamino()

    expect(await screen.findByText('El camino está vacío')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /añadir parada al camino/i })).toBeInTheDocument()
  })

  it('muestra un error si falla la carga del camino', async () => {
    fetchCamino.mockRejectedValue(new Error('sin conexión'))
    renderCamino()

    expect(await screen.findByText('No se ha podido cargar el camino.')).toBeInTheDocument()
  })
})

describe('Camino — añadir parada', () => {
  it('añade una parada nueva desde el selector de temática y dificultad', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    const tematicas: TematicaOpcion[] = [{ id: 't-9', nombre: 'Paisajes' }]
    fetchTematicasParaCamino.mockResolvedValue(tematicas)
    agregarParadaAlCamino.mockResolvedValue({ id: 'c-9' })
    const user = userEvent.setup()
    renderCamino()

    await screen.findByText('Monumentos · Fácil')
    await user.click(screen.getByRole('button', { name: /añadir parada al camino/i }))

    await screen.findByText('Paisajes')
    await user.selectOptions(screen.getByLabelText('Temática'), 't-9')
    await user.selectOptions(screen.getByLabelText('Dificultad'), 'muy_dificil')
    await user.click(screen.getByRole('button', { name: 'Añadir' }))

    await waitFor(() => expect(agregarParadaAlCamino).toHaveBeenCalledWith('t-9', 'muy_dificil'))
    expect(
      await screen.findByText('3 posiciones · el orden define la secuencia de juego'),
    ).toBeInTheDocument()
  })

  it('el botón de añadir queda deshabilitado hasta elegir temática y dificultad', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    fetchTematicasParaCamino.mockResolvedValue([{ id: 't-9', nombre: 'Paisajes' }])
    const user = userEvent.setup()
    renderCamino()

    await screen.findByText('Monumentos · Fácil')
    await user.click(screen.getByRole('button', { name: /añadir parada al camino/i }))

    await screen.findByText('Paisajes')
    expect(screen.getByRole('button', { name: 'Añadir' })).toBeDisabled()
  })
})

describe('Camino — reorden', () => {
  it('sube la posición de una fila y persiste el nuevo orden', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    reordenarCamino.mockResolvedValue(undefined)
    const user = userEvent.setup()
    renderCamino()

    await screen.findByText('Monumentos · Fácil')
    await user.click(screen.getAllByLabelText('Subir posición')[1])

    await waitFor(() => expect(reordenarCamino).toHaveBeenCalledWith(['c-2', 'c-1']))
  })

  it('arrastra una fila a otra posición y persiste el nuevo orden', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    reordenarCamino.mockResolvedValue(undefined)
    renderCamino()

    await screen.findByText('Monumentos · Fácil')
    const filaMonumentos = screen.getByText('Monumentos · Fácil').closest('tr') as HTMLElement
    const filaBanderas = screen.getByText('Banderas · Difícil').closest('tr') as HTMLElement

    fireEvent.dragStart(filaBanderas)
    fireEvent.dragOver(filaMonumentos)
    fireEvent.drop(filaMonumentos)

    await waitFor(() => expect(reordenarCamino).toHaveBeenCalledWith(['c-2', 'c-1']))
  })
})

describe('Camino — quitar posición', () => {
  it('quita una posición del camino tras confirmar', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    quitarDelCamino.mockResolvedValue(undefined)
    const user = userEvent.setup()
    renderCamino()

    await screen.findByText('Monumentos · Fácil')
    await user.click(screen.getAllByText('Quitar')[0])

    await waitFor(() => expect(quitarDelCamino).toHaveBeenCalledWith('c-1'))
    expect(screen.queryByText('Monumentos · Fácil')).not.toBeInTheDocument()
  })

  it('no quita nada si se cancela la confirmación', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    vi.spyOn(window, 'confirm').mockReturnValue(false)
    const user = userEvent.setup()
    renderCamino()

    await screen.findByText('Monumentos · Fácil')
    await user.click(screen.getAllByText('Quitar')[0])

    expect(quitarDelCamino).not.toHaveBeenCalled()
  })
})

describe('Camino — overrides por posición', () => {
  it('guarda un override válido', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    actualizarOverridesParada.mockResolvedValue(undefined)
    const user = userEvent.setup()
    renderCamino()

    await screen.findByText('Monumentos · Fácil')
    await user.click(screen.getAllByRole('button', { name: 'Overrides' })[0])

    const campo = await screen.findByPlaceholderText('8')
    await user.type(campo, '5')
    await user.click(screen.getByRole('button', { name: 'Guardar overrides' }))

    await waitFor(() =>
      expect(actualizarOverridesParada).toHaveBeenCalledWith(
        'c-1',
        expect.objectContaining({ preguntasPorPartida: 5 }),
      ),
    )
  })

  it('rechaza un override no entero o no positivo', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    const user = userEvent.setup()
    renderCamino()

    await screen.findByText('Monumentos · Fácil')
    await user.click(screen.getAllByRole('button', { name: 'Overrides' })[0])

    const campo = await screen.findByPlaceholderText('8')
    await user.clear(campo)
    await user.type(campo, '0')
    await user.click(screen.getByRole('button', { name: 'Guardar overrides' }))

    expect(await screen.findByText(/entero positivo/)).toBeInTheDocument()
    expect(actualizarOverridesParada).not.toHaveBeenCalled()
  })

  it('muestra el bloque de umbrales derivados y lo recalcula al cambiar preguntas por partida', async () => {
    fetchCamino.mockResolvedValue(CAMINO)
    const user = userEvent.setup()
    renderCamino()

    await screen.findByText('Monumentos · Fácil')
    await user.click(screen.getAllByRole('button', { name: 'Overrides' })[0])

    await waitFor(() =>
      expect(fetchUmbralesParada).toHaveBeenCalledWith('facil', 8),
    )
    expect(await screen.findByText(/Se desbloquea con/)).toBeInTheDocument()
    expect(await screen.findByText(/posición 1 de 2/)).toBeInTheDocument()

    fetchUmbralesParada.mockClear()
    const campo = await screen.findByPlaceholderText('8')
    await user.clear(campo)
    await user.type(campo, '5')

    await waitFor(() => expect(fetchUmbralesParada).toHaveBeenCalledWith('facil', 5), {
      timeout: 1000,
    })
  })
})
