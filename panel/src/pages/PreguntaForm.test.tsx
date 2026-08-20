import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { PreguntaForm } from './PreguntaForm'
import type { PreguntaDetalle, TematicaOpcion } from '../lib/preguntaForm'

const fetchPregunta = vi.fn()
const fetchTematicasParaPregunta = vi.fn()
const guardarPregunta = vi.fn()

vi.mock('../lib/preguntaForm', async () => {
  const actual = await vi.importActual<typeof import('../lib/preguntaForm')>('../lib/preguntaForm')
  return {
    ...actual,
    fetchPregunta: (...args: unknown[]) => fetchPregunta(...args),
    fetchTematicasParaPregunta: (...args: unknown[]) => fetchTematicasParaPregunta(...args),
    guardarPregunta: (...args: unknown[]) => guardarPregunta(...args),
  }
})

const TEMATICAS: TematicaOpcion[] = [
  { id: 't-1', nombre: 'Capitales', promptImagen: null },
  { id: 't-2', nombre: 'Paisajes', promptImagen: null },
]

const PREGUNTA_EXISTENTE: PreguntaDetalle = {
  id: 'd-eiffel',
  nombre: 'Torre Eiffel',
  tipo: 'imagen',
  nombreLugar: 'Torre Eiffel, París',
  pista: null,
  textoPregunta: null,
  imagenUrl: 'https://cdn.test/imagen/d-eiffel.jpg',
  videoUrl: null,
  latReal: 48.8584,
  lngReal: 2.2945,
  activo: true,
  tematicaId: 't-1',
  dificultad: 'normal',
}

function renderNueva() {
  return render(
    <MemoryRouter initialEntries={['/preguntas/nueva']}>
      <Routes>
        <Route path="/preguntas/nueva" element={<PreguntaForm />} />
        <Route path="/preguntas/:id/editar" element={<PreguntaForm />} />
        <Route path="/preguntas" element={<div>Listado de preguntas</div>} />
      </Routes>
    </MemoryRouter>,
  )
}

function renderEditar(id: string) {
  return render(
    <MemoryRouter initialEntries={[`/preguntas/${id}/editar`]}>
      <Routes>
        <Route path="/preguntas/nueva" element={<PreguntaForm />} />
        <Route path="/preguntas/:id/editar" element={<PreguntaForm />} />
        <Route path="/preguntas" element={<div>Listado de preguntas</div>} />
      </Routes>
    </MemoryRouter>,
  )
}

beforeEach(() => {
  fetchPregunta.mockReset()
  fetchTematicasParaPregunta.mockReset()
  guardarPregunta.mockReset()
  fetchTematicasParaPregunta.mockResolvedValue(TEMATICAS)
})

async function rellenarCamposComunes(user: ReturnType<typeof userEvent.setup>) {
  await user.type(screen.getByPlaceholderText('Ej. Torre Eiffel'), 'Machu Picchu')
  await user.type(screen.getByPlaceholderText(/torre eiffel, parís/i), 'Machu Picchu, Perú')
  await user.type(screen.getByPlaceholderText('-90 a 90'), '-13.1631')
  await user.type(screen.getByPlaceholderText('-180 a 180'), '-72.545')
  await user.selectOptions(screen.getByLabelText(/^temática/i), 't-1')
  await user.selectOptions(screen.getByLabelText(/^dificultad/i), 'normal')
}

function archivo(nombre: string, tipo: string, bytes = 1024) {
  return new File([new Uint8Array(bytes)], nombre, { type: tipo })
}

describe('PreguntaForm — creación', () => {
  it('cambiar de tipo oculta el campo anterior y muestra el del nuevo tipo', async () => {
    const user = userEvent.setup()
    renderNueva()

    expect(screen.getByText('Imagen de la pregunta')).toBeInTheDocument()

    await user.click(screen.getByText('Pregunta de texto'))

    expect(screen.queryByText('Imagen de la pregunta')).not.toBeInTheDocument()
    expect(screen.getByText('Texto de la pregunta')).toBeInTheDocument()
  })

  it('selecciona una imagen válida y muestra su previsualización', async () => {
    const user = userEvent.setup()
    renderNueva()

    await user.upload(
      screen.getByLabelText(/arrastra la imagen/i),
      archivo('foto.png', 'image/png'),
    )

    expect(await screen.findByAltText('')).toBeInTheDocument()
    expect(screen.queryByText('Sin imagen todavía')).not.toBeInTheDocument()
  })

  it('rechaza un archivo de imagen con tipo MIME no permitido, sin mostrar previsualización', async () => {
    const user = userEvent.setup()
    renderNueva()

    await user.upload(
      screen.getByLabelText(/arrastra la imagen/i),
      archivo('doc.pdf', 'application/pdf'),
    )

    expect(await screen.findByText(/JPG, PNG o WEBP/)).toBeInTheDocument()
    expect(screen.queryByAltText('')).not.toBeInTheDocument()
  })

  it('selecciona un vídeo válido y muestra su previsualización', async () => {
    const user = userEvent.setup()
    renderNueva()

    await user.click(screen.getByText('Vídeo'))
    await user.upload(screen.getByLabelText(/arrastra el vídeo/i), archivo('clip.mp4', 'video/mp4'))

    expect(await screen.findByText('Previsualización')).toBeInTheDocument()
    expect(screen.queryByText('Sin vídeo todavía')).not.toBeInTheDocument()
  })

  it('ofrece las temáticas cargadas en el selector', async () => {
    renderNueva()

    await screen.findByText('Paisajes')
    expect(screen.getByText('Capitales')).toBeInTheDocument()
  })

  it('muestra un aviso si no se pueden cargar las temáticas', async () => {
    fetchTematicasParaPregunta.mockRejectedValue(new Error('network down'))
    renderNueva()

    expect(await screen.findByText('No se han podido cargar las temáticas.')).toBeInTheDocument()
  })

  it('bloquea el guardado y muestra error si el tipo imagen no tiene archivo', async () => {
    const user = userEvent.setup()
    renderNueva()

    await rellenarCamposComunes(user)
    await user.click(screen.getByRole('button', { name: /guardar pregunta/i }))

    expect(await screen.findByText('Selecciona una imagen.')).toBeInTheDocument()
    expect(guardarPregunta).not.toHaveBeenCalled()
  })

  it('bloquea el guardado sin elegir temática ni dificultad', async () => {
    const user = userEvent.setup()
    renderNueva()

    await user.click(screen.getByText('Pregunta de texto'))
    await user.type(screen.getByPlaceholderText(/ciudadela inca/i), '¿Dónde está esto?')
    await user.type(screen.getByPlaceholderText(/torre eiffel, parís/i), 'Lugar')
    await user.type(screen.getByPlaceholderText('-90 a 90'), '1')
    await user.type(screen.getByPlaceholderText('-180 a 180'), '2')

    await user.click(screen.getByRole('button', { name: /guardar pregunta/i }))

    expect(await screen.findByText('Selecciona una temática.')).toBeInTheDocument()
    expect(screen.getByText('Selecciona una dificultad.')).toBeInTheDocument()
    expect(guardarPregunta).not.toHaveBeenCalled()
  })

  it('bloquea el guardado sin nombre', async () => {
    const user = userEvent.setup()
    renderNueva()

    await user.click(screen.getByText('Pregunta de texto'))
    await user.type(screen.getByPlaceholderText(/ciudadela inca/i), '¿Dónde está esto?')
    await user.type(screen.getByPlaceholderText(/torre eiffel, parís/i), 'Lugar')
    await user.type(screen.getByPlaceholderText('-90 a 90'), '1')
    await user.type(screen.getByPlaceholderText('-180 a 180'), '2')
    await user.selectOptions(screen.getByLabelText(/^temática/i), 't-1')
    await user.selectOptions(screen.getByLabelText(/^dificultad/i), 'normal')

    await user.click(screen.getByRole('button', { name: /guardar pregunta/i }))

    expect(await screen.findByText('El nombre es obligatorio.')).toBeInTheDocument()
    expect(guardarPregunta).not.toHaveBeenCalled()
  })

  it('guarda una pista opcional', async () => {
    guardarPregunta.mockResolvedValue({ id: 'd-nueva' })
    const user = userEvent.setup()
    renderNueva()

    await user.click(screen.getByText('Pregunta de texto'))
    await user.type(screen.getByPlaceholderText(/ciudadela inca/i), '¿Ciudadela inca?')
    await rellenarCamposComunes(user)
    await user.type(
      screen.getByPlaceholderText(/pista adicional/i),
      'Está a más de 2000 m de altitud',
    )

    await user.click(screen.getByRole('button', { name: /guardar pregunta/i }))

    await waitFor(() => expect(guardarPregunta).toHaveBeenCalledTimes(1))
    expect(guardarPregunta).toHaveBeenCalledWith(
      expect.objectContaining({ pista: 'Está a más de 2000 m de altitud' }),
    )
  })

  it('bloquea el guardado con una latitud fuera de rango', async () => {
    const user = userEvent.setup()
    renderNueva()

    await user.click(screen.getByText('Pregunta de texto'))
    await user.type(screen.getByPlaceholderText(/ciudadela inca/i), '¿Dónde está esto?')
    await user.type(screen.getByPlaceholderText(/torre eiffel, parís/i), 'Lugar')
    await user.type(screen.getByPlaceholderText('-90 a 90'), '120')
    await user.type(screen.getByPlaceholderText('-180 a 180'), '2')

    await user.click(screen.getByRole('button', { name: /guardar pregunta/i }))

    expect(
      await screen.findByText('La latitud debe ser un número entre -90 y 90.'),
    ).toBeInTheDocument()
    expect(guardarPregunta).not.toHaveBeenCalled()
  })

  it('crea una pregunta de tipo texto con temática y dificultad, y vuelve al listado', async () => {
    guardarPregunta.mockResolvedValue({ id: 'd-nueva' })
    const user = userEvent.setup()
    renderNueva()

    await user.click(screen.getByText('Pregunta de texto'))
    await user.type(screen.getByPlaceholderText(/ciudadela inca/i), '¿Ciudadela inca?')
    await rellenarCamposComunes(user)

    await user.click(screen.getByRole('button', { name: /guardar pregunta/i }))

    await waitFor(() => expect(guardarPregunta).toHaveBeenCalledTimes(1))
    expect(guardarPregunta).toHaveBeenCalledWith(
      expect.objectContaining({
        id: null,
        nombre: 'Machu Picchu',
        tipo: 'pregunta_texto',
        nombreLugar: 'Machu Picchu, Perú',
        pista: null,
        textoPregunta: '¿Ciudadela inca?',
        latReal: -13.1631,
        lngReal: -72.545,
        activo: true,
        tematicaId: 't-1',
        dificultad: 'normal',
      }),
    )
    expect(await screen.findByText('Listado de preguntas')).toBeInTheDocument()
  })

  it('muestra un error y no navega si el guardado falla', async () => {
    guardarPregunta.mockRejectedValue(new Error('restricción violada'))
    const user = userEvent.setup()
    renderNueva()

    await user.click(screen.getByText('Pregunta de texto'))
    await user.type(screen.getByPlaceholderText(/ciudadela inca/i), '¿Ciudadela inca?')
    await rellenarCamposComunes(user)

    await user.click(screen.getByRole('button', { name: /guardar pregunta/i }))

    expect(await screen.findByText('restricción violada')).toBeInTheDocument()
    expect(screen.queryByText('Listado de preguntas')).not.toBeInTheDocument()
  })

  it('cancelar vuelve al listado sin guardar', async () => {
    const user = userEvent.setup()
    renderNueva()

    await user.click(screen.getByRole('button', { name: /cancelar/i }))

    expect(guardarPregunta).not.toHaveBeenCalled()
    expect(await screen.findByText('Listado de preguntas')).toBeInTheDocument()
  })
})

describe('PreguntaForm — edición', () => {
  it('precarga los datos existentes, incluida temática y dificultad', async () => {
    fetchPregunta.mockResolvedValue(PREGUNTA_EXISTENTE)
    renderEditar('d-eiffel')

    expect(await screen.findByText('Editar pregunta')).toBeInTheDocument()
    expect(screen.getByDisplayValue('Torre Eiffel')).toBeInTheDocument()
    expect(screen.getByDisplayValue('Torre Eiffel, París')).toBeInTheDocument()
    expect(screen.getByDisplayValue('48.8584')).toBeInTheDocument()
    expect(screen.getByDisplayValue('2.2945')).toBeInTheDocument()
    expect(screen.getByLabelText(/^temática/i)).toHaveValue('t-1')
    expect(screen.getByLabelText(/^dificultad/i)).toHaveValue('normal')
  })

  it('guarda una edición conservando la media existente si no se sube un archivo nuevo', async () => {
    fetchPregunta.mockResolvedValue(PREGUNTA_EXISTENTE)
    guardarPregunta.mockResolvedValue({ id: 'd-eiffel' })
    const user = userEvent.setup()
    renderEditar('d-eiffel')

    await screen.findByText('Editar pregunta')
    await user.click(screen.getByRole('button', { name: /guardar pregunta/i }))

    await waitFor(() => expect(guardarPregunta).toHaveBeenCalledTimes(1))
    expect(guardarPregunta).toHaveBeenCalledWith(
      expect.objectContaining({
        id: 'd-eiffel',
        imagenUrlActual: 'https://cdn.test/imagen/d-eiffel.jpg',
        archivo: null,
        tematicaId: 't-1',
        dificultad: 'normal',
      }),
    )
  })

  it('muestra un error de carga si la pregunta no existe', async () => {
    fetchPregunta.mockRejectedValue(new Error('no encontrada'))
    renderEditar('d-x')

    expect(await screen.findByText('No se ha podido cargar la pregunta.')).toBeInTheDocument()
  })
})
