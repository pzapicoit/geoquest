import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { MapaVistaPrevia } from './MapaVistaPrevia'

describe('MapaVistaPrevia', () => {
  it('muestra "Coordenadas incompletas" y ningún pin cuando lat/lng son nulos', () => {
    const { container } = render(<MapaVistaPrevia lat={null} lng={null} />)

    expect(screen.getByText('Coordenadas incompletas')).toBeInTheDocument()
    expect(container.querySelector('svg g')).not.toBeInTheDocument()
  })

  it('muestra las coordenadas formateadas y un pin cuando lat/lng son válidos', () => {
    const { container } = render(<MapaVistaPrevia lat={48.8584} lng={2.2945} />)

    expect(screen.getByText('48.8584, 2.2945')).toBeInTheDocument()
    expect(container.querySelector('svg g')).toBeInTheDocument()
  })

  it('reposiciona el pin cuando cambian lat/lng', () => {
    const { container, rerender } = render(<MapaVistaPrevia lat={48.8584} lng={2.2945} />)
    const transformInicial = container.querySelector('svg g')?.getAttribute('transform')

    rerender(<MapaVistaPrevia lat={-33.8688} lng={151.2093} />)

    expect(screen.getByText('-33.8688, 151.2093')).toBeInTheDocument()
    expect(container.querySelector('svg g')?.getAttribute('transform')).not.toBe(transformInicial)
  })
})
