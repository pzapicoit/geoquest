import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor, fireEvent } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { NivelRecorrido } from './NivelRecorrido'
import type { NivelRecorrido as NivelRecorridoData, PreguntaBanco } from '../lib/nivelRecorrido'

const fetchNivelRecorrido = vi.fn()
const guardarConfiguracionNivel = vi.fn()
const fetchPreguntasNoAsignadas = vi.fn()
const agregarPreguntaAlRecorrido = vi.fn()
const quitarPreguntaDelRecorrido = vi.fn()
const reordenarRecorrido = vi.fn()

vi.mock('../lib/nivelRecorrido', async () => {
  const actual =
    await vi.importActual<typeof import('../lib/nivelRecorrido')>('../lib/nivelRecorrido')
  return {
    ...actual,
    fetchNivelRecorrido: (...args: unknown[]) => fetchNivelRecorrido(...args),
    guardarConfiguracionNivel: (...args: unknown[]) => guardarConfiguracionNivel(...args),
    fetchPreguntasNoAsignadas: (...args: unknown[]) => fetchPreguntasNoAsignadas(...args),
    agregarPreguntaAlRecorrido: (...args: unknown[]) => agregarPreguntaAlRecorrido(...args),
    quitarPreguntaDelRecorrido: (...args: unknown[]) => quitarPreguntaDelRecorrido(...args),
    reordenarRecorrido: (...args: unknown[]) => reordenarRecorrido(...args),
  }
})

// preguntasPorPartida: null y 2 preguntas asignadas → N efectivo = 2,
// máximo del nivel = 2 × 5000 = 10000. umbralEstrella2/3 elegidos como
// porcentajes redondos de ese máximo (30% y 60%) para que las aserciones de
// UI sean números limpios.
const NIVEL: NivelRecorridoData = {
  id: 'n-1',
  nombre: null,
  orden: 3,
  tematicaNombre: 'Paisajes',
  puntajeMinimoSuperar: 1000,
  umbralEstrella2: 3000,
  umbralEstrella3: 6000,
  preguntasPorPartida: null,
  preguntas: [
    { desafioId: 'd-1', orden: 1, tipo: 'imagen', nombreLugar: 'Torre Eiffel', imagenUrl: null },
    { desafioId: 'd-2', orden: 2, tipo: 'video', nombreLugar: 'Coliseo', imagenUrl: null },
  ],
}

function renderNivel(id = 'n-1') {
  return render(
    <MemoryRouter initialEntries={[`/niveles/${id}`]}>
      <Routes>
        <Route path="/niveles/:id" element={<NivelRecorrido />} />
        <Route path="/preguntas/nueva" element={<div>Formulario nueva pregunta</div>} />
      </Routes>
    </MemoryRouter>,
  )
}

beforeEach(() => {
  fetchNivelRecorrido.mockReset()
  guardarConfiguracionNivel.mockReset()
  fetchPreguntasNoAsignadas.mockReset()
  agregarPreguntaAlRecorrido.mockReset()
  quitarPreguntaDelRecorrido.mockReset()
  reordenarRecorrido.mockReset()
  vi.spyOn(window, 'confirm').mockReturnValue(true)
})

describe('NivelRecorrido — carga y configuración', () => {
  it('muestra el breadcrumb y precarga la configuración del nivel', async () => {
    fetchNivelRecorrido.mockResolvedValue(NIVEL)
    renderNivel()

    await screen.findByText('2 preguntas en este recorrido')

    const breadcrumb = screen.getByLabelText('Miga de pan')
    expect(breadcrumb.textContent).toContain('Temáticas')
    expect(breadcrumb.textContent).toContain('Paisajes')
    expect(breadcrumb.textContent).toContain('Nivel 3')

    expect(screen.getByDisplayValue('1000')).toBeInTheDocument()
    expect(screen.getByDisplayValue('30')).toBeInTheDocument()
    expect(screen.getByDisplayValue('60')).toBeInTheDocument()
  })

  it('muestra el absoluto y la distancia media derivados de cada umbral', async () => {
    fetchNivelRecorrido.mockResolvedValue(NIVEL)
    renderNivel()

    await screen.findByText('2 preguntas en este recorrido')

    // umbral 2 estrellas: 30% de 10000 = 3000 pts, con su distancia media
    expect(await screen.findByText(/3000 pts.*km/)).toBeInTheDocument()
    // umbral 3 estrellas: 60% de 10000 = 6000 pts, con su distancia media
    expect(await screen.findByText(/6000 pts.*km/)).toBeInTheDocument()
    // puntaje mínimo: también muestra distancia media (varios "km" en pantalla)
    expect(screen.getAllByText(/km/).length).toBeGreaterThanOrEqual(3)
  })

  it('precarga el nombre del nivel cuando ya tiene uno asignado', async () => {
    fetchNivelRecorrido.mockResolvedValue({ ...NIVEL, nombre: 'Costas del Mediterráneo' })
    renderNivel()

    expect(await screen.findByDisplayValue('Costas del Mediterráneo')).toBeInTheDocument()
    const breadcrumb = screen.getByLabelText('Miga de pan')
    expect(breadcrumb.textContent).toContain('Costas del Mediterráneo')
  })

  it('muestra un error si falla la carga del nivel', async () => {
    fetchNivelRecorrido.mockRejectedValue(new Error('no encontrado'))
    renderNivel()

    expect(await screen.findByText('No se ha podido cargar el nivel.')).toBeInTheDocument()
  })

  it('guarda una configuración válida', async () => {
    fetchNivelRecorrido.mockResolvedValue(NIVEL)
    guardarConfiguracionNivel.mockResolvedValue(undefined)
    const user = userEvent.setup()
    renderNivel()

    await screen.findByText('2 preguntas en este recorrido')
    await user.type(screen.getByPlaceholderText('Nivel 3'), 'Costas')
    await user.click(screen.getByRole('button', { name: /guardar cambios/i }))

    await waitFor(() =>
      expect(guardarConfiguracionNivel).toHaveBeenCalledWith(
        'n-1',
        expect.objectContaining({
          nombre: 'Costas',
          puntajeMinimoSuperar: 1000,
          umbralEstrella2: 3000,
          umbralEstrella3: 6000,
          preguntasPorPartida: null,
        }),
        2,
      ),
    )
    expect(await screen.findByText('Configuración guardada.')).toBeInTheDocument()
  })

  it('recalcula el absoluto al editar el puntaje mínimo y el umbral de 3 estrellas', async () => {
    fetchNivelRecorrido.mockResolvedValue(NIVEL)
    guardarConfiguracionNivel.mockResolvedValue(undefined)
    const user = userEvent.setup()
    renderNivel()

    await screen.findByText('2 preguntas en este recorrido')

    const inputPuntajeMinimo = screen.getByDisplayValue('1000')
    await user.clear(inputPuntajeMinimo)
    await user.type(inputPuntajeMinimo, '1200')

    const inputUmbral3 = screen.getByDisplayValue('60')
    await user.clear(inputUmbral3)
    await user.type(inputUmbral3, '70')

    await user.click(screen.getByRole('button', { name: /guardar cambios/i }))

    await waitFor(() =>
      expect(guardarConfiguracionNivel).toHaveBeenCalledWith(
        'n-1',
        expect.objectContaining({ puntajeMinimoSuperar: 1200, umbralEstrella3: 7000 }),
        2,
      ),
    )
  })

  it('guarda preguntas_por_partida cuando es un valor válido dentro del pool', async () => {
    fetchNivelRecorrido.mockResolvedValue(NIVEL)
    guardarConfiguracionNivel.mockResolvedValue(undefined)
    const user = userEvent.setup()
    renderNivel()

    await screen.findByText('2 preguntas en este recorrido')
    await user.type(screen.getByPlaceholderText('Todas'), '2')
    await user.click(screen.getByRole('button', { name: /guardar cambios/i }))

    await waitFor(() =>
      expect(guardarConfiguracionNivel).toHaveBeenCalledWith(
        'n-1',
        expect.objectContaining({ preguntasPorPartida: 2 }),
        2,
      ),
    )
    expect(await screen.findByText('Configuración guardada.')).toBeInTheDocument()
  })

  it('bloquea el guardado si preguntas_por_partida supera el pool del recorrido', async () => {
    fetchNivelRecorrido.mockResolvedValue(NIVEL)
    const user = userEvent.setup()
    renderNivel()

    await screen.findByText('2 preguntas en este recorrido')
    await user.type(screen.getByPlaceholderText('Todas'), '5')
    await user.click(screen.getByRole('button', { name: /guardar cambios/i }))

    expect(await screen.findByText(/no pueden superar/i)).toBeInTheDocument()
    expect(guardarConfiguracionNivel).not.toHaveBeenCalled()
  })

  it('guarda preguntas_por_partida vacío como null (se juegan todas)', async () => {
    fetchNivelRecorrido.mockResolvedValue({ ...NIVEL, preguntasPorPartida: 2 })
    guardarConfiguracionNivel.mockResolvedValue(undefined)
    const user = userEvent.setup()
    renderNivel()

    const inputPreguntas = await screen.findByDisplayValue('2')
    await user.clear(inputPreguntas)
    await user.click(screen.getByRole('button', { name: /guardar cambios/i }))

    await waitFor(() =>
      expect(guardarConfiguracionNivel).toHaveBeenCalledWith(
        'n-1',
        expect.objectContaining({ preguntasPorPartida: null }),
        2,
      ),
    )
  })

  it('bloquea el guardado si los umbrales no son ascendentes', async () => {
    fetchNivelRecorrido.mockResolvedValue(NIVEL)
    const user = userEvent.setup()
    renderNivel()

    await screen.findByText('2 preguntas en este recorrido')
    const inputUmbral2 = screen.getByDisplayValue('30')
    await user.clear(inputUmbral2)
    await user.type(inputUmbral2, '5')
    await user.click(screen.getByRole('button', { name: /guardar cambios/i }))

    expect(await screen.findByText(/ascendentes/i)).toBeInTheDocument()
    expect(guardarConfiguracionNivel).not.toHaveBeenCalled()
  })
})

describe('NivelRecorrido — recorrido de preguntas', () => {
  it('quita una pregunta del recorrido tras confirmar', async () => {
    fetchNivelRecorrido.mockResolvedValue(NIVEL)
    quitarPreguntaDelRecorrido.mockResolvedValue(undefined)
    const user = userEvent.setup()
    renderNivel()

    await screen.findByText('Torre Eiffel')
    await user.click(screen.getAllByText('Quitar del recorrido')[0])

    await waitFor(() => expect(quitarPreguntaDelRecorrido).toHaveBeenCalledWith('n-1', 'd-1'))
    await waitFor(() => expect(screen.queryByText('Torre Eiffel')).not.toBeInTheDocument())
    expect(screen.getByText('1 pregunta en este recorrido')).toBeInTheDocument()
  })

  it('no quita nada si se cancela la confirmación', async () => {
    fetchNivelRecorrido.mockResolvedValue(NIVEL)
    vi.spyOn(window, 'confirm').mockReturnValue(false)
    const user = userEvent.setup()
    renderNivel()

    await screen.findByText('Torre Eiffel')
    await user.click(screen.getAllByText('Quitar del recorrido')[0])

    expect(quitarPreguntaDelRecorrido).not.toHaveBeenCalled()
    expect(screen.getByText('Torre Eiffel')).toBeInTheDocument()
  })

  it('sube la posición de una pregunta y persiste el nuevo orden', async () => {
    fetchNivelRecorrido.mockResolvedValue(NIVEL)
    reordenarRecorrido.mockResolvedValue(undefined)
    const user = userEvent.setup()
    renderNivel()

    await screen.findByText('Torre Eiffel')
    await user.click(screen.getAllByLabelText('Subir posición')[1])

    await waitFor(() => expect(reordenarRecorrido).toHaveBeenCalledWith('n-1', ['d-2', 'd-1']))
  })

  it('arrastra una pregunta a otra posición y persiste el nuevo orden', async () => {
    fetchNivelRecorrido.mockResolvedValue(NIVEL)
    reordenarRecorrido.mockResolvedValue(undefined)
    renderNivel()

    await screen.findByText('Torre Eiffel')
    const filaEiffel = screen.getByText('Torre Eiffel').closest('tr') as HTMLElement
    const filaColiseo = screen.getByText('Coliseo').closest('tr') as HTMLElement

    fireEvent.dragStart(filaColiseo)
    fireEvent.dragOver(filaEiffel)
    fireEvent.drop(filaEiffel)

    await waitFor(() => expect(reordenarRecorrido).toHaveBeenCalledWith('n-1', ['d-2', 'd-1']))
  })

  it('revierte el orden local si la persistencia del reorden falla', async () => {
    fetchNivelRecorrido.mockResolvedValue(NIVEL)
    reordenarRecorrido.mockRejectedValue(new Error('conflicto de orden'))
    const user = userEvent.setup()
    renderNivel()

    await screen.findByText('Torre Eiffel')
    await user.click(screen.getAllByLabelText('Subir posición')[1])

    expect(await screen.findByText('conflicto de orden')).toBeInTheDocument()
    const nombres = screen.getAllByText(/^(Torre Eiffel|Coliseo)$/).map((el) => el.textContent)
    expect(nombres).toEqual(['Torre Eiffel', 'Coliseo'])
  })

  it('bloquea quitar/añadir mientras hay un reorden en curso, y los desbloquea al terminar', async () => {
    fetchNivelRecorrido.mockResolvedValue(NIVEL)
    let resolverReorden: () => void = () => {}
    reordenarRecorrido.mockReturnValue(
      new Promise<void>((resolve) => {
        resolverReorden = resolve
      }),
    )
    const user = userEvent.setup()
    renderNivel()

    await screen.findByText('Torre Eiffel')
    await user.click(screen.getAllByLabelText('Subir posición')[1])

    const botonQuitar = screen.getAllByText('Quitar del recorrido')[0]
    expect(botonQuitar).toBeDisabled()

    await user.click(botonQuitar)
    expect(quitarPreguntaDelRecorrido).not.toHaveBeenCalled()

    resolverReorden()
    await waitFor(() => expect(botonQuitar).not.toBeDisabled())
  })

  it('añade una pregunta existente desde el selector', async () => {
    fetchNivelRecorrido.mockResolvedValue(NIVEL)
    const banco: PreguntaBanco[] = [
      { id: 'd-9', tipo: 'imagen', nombreLugar: 'Machu Picchu', imagenUrl: null },
    ]
    fetchPreguntasNoAsignadas.mockResolvedValue(banco)
    agregarPreguntaAlRecorrido.mockResolvedValue(undefined)
    const user = userEvent.setup()
    renderNivel()

    await screen.findByText('Torre Eiffel')
    await user.click(screen.getByRole('button', { name: /añadir pregunta existente/i }))

    await screen.findByText('Machu Picchu')
    await user.click(screen.getByText('Añadir'))

    await waitFor(() => expect(agregarPreguntaAlRecorrido).toHaveBeenCalledWith('n-1', 'd-9'))
    expect(await screen.findByText('3 preguntas en este recorrido')).toBeInTheDocument()
  })

  it('muestra el estado vacío con ambas llamadas a la acción', async () => {
    fetchNivelRecorrido.mockResolvedValue({ ...NIVEL, preguntas: [] })
    renderNivel()

    expect(await screen.findByText('Este nivel todavía no tiene preguntas')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /añadir pregunta existente/i })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /crear pregunta nueva/i })).toBeInTheDocument()
  })

  it('el botón "Crear pregunta nueva" navega al formulario de nueva pregunta', async () => {
    fetchNivelRecorrido.mockResolvedValue(NIVEL)
    const user = userEvent.setup()
    renderNivel()

    await screen.findByText('Torre Eiffel')
    await user.click(screen.getByRole('link', { name: /crear pregunta nueva/i }))

    expect(await screen.findByText('Formulario nueva pregunta')).toBeInTheDocument()
  })
})
