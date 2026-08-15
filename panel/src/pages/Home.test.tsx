import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import { Home } from './Home'

const fetchMetricasHome = vi.fn()
const fetchAlertasContenido = vi.fn()
const fetchActividadReciente = vi.fn()

vi.mock('../lib/dashboard', () => ({
  fetchMetricasHome: (...args: unknown[]) => fetchMetricasHome(...args),
  fetchAlertasContenido: (...args: unknown[]) => fetchAlertasContenido(...args),
  fetchActividadReciente: (...args: unknown[]) => fetchActividadReciente(...args),
}))

const METRICAS = {
  jugadoresTotales: 4907,
  jugadoresActivos7d: 1843,
  partidasHoy: 1284,
  nivelesActivos: 86,
}

beforeEach(() => {
  fetchMetricasHome.mockReset().mockResolvedValue(METRICAS)
  fetchAlertasContenido.mockReset().mockResolvedValue([])
  fetchActividadReciente.mockReset().mockResolvedValue([])
})

describe('Home', () => {
  it('muestra las 4 tarjetas de métricas de metricas_home', async () => {
    render(<Home />)

    expect(await screen.findByText('4907')).toBeInTheDocument()
    expect(screen.getByText('1843')).toBeInTheDocument()
    expect(screen.getByText('1284')).toBeInTheDocument()
    expect(screen.getByText('86')).toBeInTheDocument()
    expect(screen.getByText(/jugadores totales/i)).toBeInTheDocument()
    expect(screen.getByText(/activos 7 días/i)).toBeInTheDocument()
    expect(screen.getByText(/partidas hoy/i)).toBeInTheDocument()
    expect(screen.getByText(/niveles publicados/i)).toBeInTheDocument()
  })

  it('muestra los 3 accesos rápidos deshabilitados', async () => {
    render(<Home />)
    await screen.findByText('4907')

    const nuevaTematica = screen.getByText(/nueva temática/i)
    const nuevoNivel = screen.getByText(/nuevo nivel/i)
    const nuevoDesafio = screen.getByText(/nuevo desafío/i)

    for (const accion of [nuevaTematica, nuevoNivel, nuevoDesafio]) {
      expect(accion).toHaveAttribute('aria-disabled', 'true')
    }
    expect(screen.queryByRole('link', { name: /nueva temática/i })).not.toBeInTheDocument()
  })

  it('muestra la actividad reciente con datos', async () => {
    fetchActividadReciente.mockResolvedValue([
      {
        tipo: 'nuevo_registro',
        ocurridoEn: '2026-08-15T21:51:16.588642+00:00',
        texto: 'Jugador0925',
        detalle: {},
        etiqueta: null,
      },
      {
        tipo: 'nivel_superado',
        ocurridoEn: '2026-08-15T21:51:52.295314+00:00',
        texto: 'Jugador0925',
        detalle: { estrellas_obtenidas: 3 },
        etiqueta: 'Fiordos de Noruega · Nivel 4',
      },
    ])

    render(<Home />)

    expect(await screen.findByText(/nuevo registro: jugador0925/i)).toBeInTheDocument()
    expect(screen.getByText(/superó fiordos de noruega · nivel 4/i)).toBeInTheDocument()
  })

  it('muestra un estado vacío explícito cuando no hay actividad reciente', async () => {
    render(<Home />)

    expect(await screen.findByText(/todavía no hay actividad que mostrar/i)).toBeInTheDocument()
  })

  it('muestra las alertas de contenido con datos', async () => {
    fetchAlertasContenido.mockResolvedValue([
      {
        tipo: 'nivel_baja_tasa',
        referenciaId: 'nivel-1',
        titulo: 'Nivel con baja tasa de superacion',
        detalle: {},
        etiqueta: 'Fiordos de Noruega · Nivel 9',
      },
    ])

    render(<Home />)

    expect(await screen.findByText('Fiordos de Noruega · Nivel 9')).toBeInTheDocument()
    expect(screen.getByText('1')).toBeInTheDocument()
  })

  it('muestra un estado vacío explícito cuando no hay alertas de contenido', async () => {
    render(<Home />)

    expect(await screen.findByText(/sin alertas de contenido por ahora/i)).toBeInTheDocument()
  })

  it('muestra un error si falla la carga del resumen', async () => {
    fetchMetricasHome.mockRejectedValue(new Error('network down'))

    render(<Home />)

    expect(
      await screen.findByText(/no se ha podido cargar el resumen del panel/i),
    ).toBeInTheDocument()
  })
})
