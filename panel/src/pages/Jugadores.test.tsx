import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, within, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Jugadores } from './Jugadores'
import type { Jugador } from '../lib/jugadores'

const fetchJugadores = vi.fn()
const reiniciarProgresoJugador = vi.fn()
const eliminarJugador = vi.fn()

vi.mock('../lib/jugadores', async () => {
  const actual = await vi.importActual<typeof import('../lib/jugadores')>('../lib/jugadores')
  return {
    ...actual,
    fetchJugadores: (...args: unknown[]) => fetchJugadores(...args),
    reiniciarProgresoJugador: (...args: unknown[]) => reiniciarProgresoJugador(...args),
    eliminarJugador: (...args: unknown[]) => eliminarJugador(...args),
  }
})

function jugador(overrides: Partial<Jugador> & { id: string; alias: string }): Jugador {
  return {
    nivelesSuperados: 0,
    paradaMaxima: null,
    puntosTotales: 0,
    tasaSuperacion: null,
    ultimaPartida: null,
    ...overrides,
  }
}

const MAPACHE = jugador({
  id: 'j-mapache',
  alias: 'mapachedeluxe',
  nivelesSuperados: 2,
  paradaMaxima: 3,
  puntosTotales: 18420,
  tasaSuperacion: 0.6667,
  ultimaPartida: '2026-08-18T18:12:28.769947+00:00',
})

const SIN_PARTIDAS = jugador({ id: 'j-nuevo', alias: 'reciennacido' })

beforeEach(() => {
  fetchJugadores.mockReset()
  reiniciarProgresoJugador.mockReset()
  eliminarJugador.mockReset()
})

describe('Jugadores', () => {
  it('muestra una fila por jugador con sus datos agregados', async () => {
    fetchJugadores.mockResolvedValue([MAPACHE, SIN_PARTIDAS])

    render(<Jugadores />)

    const filaMapache = (await screen.findByText('mapachedeluxe')).closest('tr') as HTMLElement
    expect(within(filaMapache).getByText('Parada 3')).toBeInTheDocument()
    expect(within(filaMapache).getByText('18.420')).toBeInTheDocument()
    expect(within(filaMapache).getByText('67 %')).toBeInTheDocument()

    const filaNueva = screen.getByText('reciennacido').closest('tr') as HTMLElement
    expect(within(filaNueva).getByText('Sin avanzar')).toBeInTheDocument()
    expect(within(filaNueva).getByText('Nunca')).toBeInTheDocument()
  })

  it('filtra por alias', async () => {
    const user = userEvent.setup()
    fetchJugadores.mockResolvedValue([MAPACHE, SIN_PARTIDAS])

    render(<Jugadores />)
    await screen.findByText('mapachedeluxe')

    await user.type(screen.getByPlaceholderText('Buscar por alias'), 'mapache')

    expect(screen.getByText('mapachedeluxe')).toBeInTheDocument()
    expect(screen.queryByText('reciennacido')).not.toBeInTheDocument()
  })

  it('muestra un estado vacío cuando ningún jugador coincide con el filtro', async () => {
    const user = userEvent.setup()
    fetchJugadores.mockResolvedValue([MAPACHE])

    render(<Jugadores />)
    await screen.findByText('mapachedeluxe')

    await user.type(screen.getByPlaceholderText('Buscar por alias'), 'no-existe')

    expect(await screen.findByText('Ningún jugador coincide')).toBeInTheDocument()

    const [botonLimpiar] = screen.getAllByRole('button', { name: 'Limpiar filtros' })
    await user.click(botonLimpiar)
    expect(await screen.findByText('mapachedeluxe')).toBeInTheDocument()
  })

  it('ordena por alias A-Z', async () => {
    const user = userEvent.setup()
    fetchJugadores.mockResolvedValue([MAPACHE, SIN_PARTIDAS])

    render(<Jugadores />)
    await screen.findByText('mapachedeluxe')

    await user.selectOptions(screen.getByLabelText('Ordenar jugadores'), 'Alias A–Z')

    const alias = screen.getAllByText(/mapachedeluxe|reciennacido/).map((el) => el.textContent)
    expect(alias).toEqual(['mapachedeluxe', 'reciennacido'])
  })

  it('pagina el listado en cliente', async () => {
    const user = userEvent.setup()
    const jugadores = Array.from({ length: 9 }, (_, i) =>
      jugador({ id: `j-${i}`, alias: `jugador${i}`, puntosTotales: 100 - i }),
    )
    fetchJugadores.mockResolvedValue(jugadores)

    render(<Jugadores />)
    await screen.findByText('jugador0')

    expect(screen.queryByText('jugador8')).not.toBeInTheDocument()
    expect(screen.getByText('Mostrando 1–8 de 9')).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Siguiente' }))

    expect(await screen.findByText('jugador8')).toBeInTheDocument()
  })

  describe('reinicio de progreso', () => {
    async function abrirModal() {
      const user = userEvent.setup()
      fetchJugadores.mockResolvedValue([MAPACHE])

      render(<Jugadores />)
      await screen.findByText('mapachedeluxe')

      await user.click(screen.getByRole('button', { name: 'Reiniciar progreso de mapachedeluxe' }))
      await screen.findByText('Reiniciar a mapachedeluxe')

      return user
    }

    it('mantiene el botón de confirmar deshabilitado hasta que el alias coincide exactamente', async () => {
      const user = await abrirModal()
      const input = screen.getByLabelText(/escribe/i)
      const confirmar = screen.getByRole('button', { name: 'Reiniciar progreso' })

      expect(confirmar).toBeDisabled()

      await user.type(input, 'mapache')
      expect(confirmar).toBeDisabled()

      await user.type(input, 'deluxe')
      expect(confirmar).toBeEnabled()
    })

    it('reinicia el progreso, actualiza la fila y muestra confirmación', async () => {
      const user = await abrirModal()
      reiniciarProgresoJugador.mockResolvedValue(undefined)

      await user.type(screen.getByLabelText(/escribe/i), 'mapachedeluxe')
      await user.click(screen.getByRole('button', { name: 'Reiniciar progreso' }))

      expect(reiniciarProgresoJugador).toHaveBeenCalledWith('j-mapache')
      await waitFor(() =>
        expect(screen.queryByText('Reiniciar a mapachedeluxe')).not.toBeInTheDocument(),
      )

      expect(await screen.findByText('Progreso de mapachedeluxe reiniciado.')).toBeInTheDocument()

      const fila = screen.getByText('mapachedeluxe').closest('tr') as HTMLElement
      expect(within(fila).getByText('Sin avanzar')).toBeInTheDocument()
      expect(within(fila).getByText('0')).toBeInTheDocument()
      expect(within(fila).getByText('Nunca')).toBeInTheDocument()
    })

    it('muestra el error de la RPC y mantiene el modal abierto', async () => {
      const user = await abrirModal()
      reiniciarProgresoJugador.mockRejectedValue(new Error('Solo un admin puede reiniciar'))

      await user.type(screen.getByLabelText(/escribe/i), 'mapachedeluxe')
      await user.click(screen.getByRole('button', { name: 'Reiniciar progreso' }))

      expect(await screen.findByText('Solo un admin puede reiniciar')).toBeInTheDocument()
      expect(screen.getByText('Reiniciar a mapachedeluxe')).toBeInTheDocument()
    })

    it('cancelar cierra el modal sin llamar a la RPC', async () => {
      const user = await abrirModal()

      await user.click(screen.getByRole('button', { name: 'Cancelar' }))

      expect(reiniciarProgresoJugador).not.toHaveBeenCalled()
      expect(screen.queryByText('Reiniciar a mapachedeluxe')).not.toBeInTheDocument()
    })
  })

  describe('eliminación de jugador', () => {
    async function abrirModal() {
      const user = userEvent.setup()
      fetchJugadores.mockResolvedValue([MAPACHE])

      render(<Jugadores />)
      await screen.findByText('mapachedeluxe')

      await user.click(screen.getByRole('button', { name: 'Eliminar a mapachedeluxe' }))
      await screen.findByText('Eliminar a mapachedeluxe')

      return user
    }

    it('mantiene el botón de confirmar deshabilitado hasta que el alias coincide exactamente', async () => {
      const user = await abrirModal()
      const input = screen.getByLabelText(/escribe/i)
      const confirmar = screen.getByRole('button', { name: 'Eliminar jugador' })

      expect(confirmar).toBeDisabled()

      await user.type(input, 'mapache')
      expect(confirmar).toBeDisabled()

      await user.type(input, 'deluxe')
      expect(confirmar).toBeEnabled()
    })

    it('elimina al jugador, lo quita de la tabla y muestra confirmación', async () => {
      const user = await abrirModal()
      eliminarJugador.mockResolvedValue(undefined)

      await user.type(screen.getByLabelText(/escribe/i), 'mapachedeluxe')
      await user.click(screen.getByRole('button', { name: 'Eliminar jugador' }))

      expect(eliminarJugador).toHaveBeenCalledWith('j-mapache')
      await waitFor(() =>
        expect(screen.queryByText('Eliminar a mapachedeluxe')).not.toBeInTheDocument(),
      )

      expect(await screen.findByText('mapachedeluxe eliminado.')).toBeInTheDocument()
      expect(screen.queryByText('mapachedeluxe')).not.toBeInTheDocument()
    })

    it('muestra el error de la RPC y mantiene el modal abierto', async () => {
      const user = await abrirModal()
      eliminarJugador.mockRejectedValue(new Error('Solo un admin puede eliminar un jugador'))

      await user.type(screen.getByLabelText(/escribe/i), 'mapachedeluxe')
      await user.click(screen.getByRole('button', { name: 'Eliminar jugador' }))

      expect(await screen.findByText('Solo un admin puede eliminar un jugador')).toBeInTheDocument()
      expect(screen.getByText('Eliminar a mapachedeluxe')).toBeInTheDocument()
      expect(within(screen.getByRole('table')).getByText('mapachedeluxe')).toBeInTheDocument()
    })

    it('cancelar cierra el modal sin llamar a la RPC', async () => {
      const user = await abrirModal()

      await user.click(screen.getByRole('button', { name: 'Cancelar' }))

      expect(eliminarJugador).not.toHaveBeenCalled()
      expect(screen.queryByText('Eliminar a mapachedeluxe')).not.toBeInTheDocument()
    })
  })
})
