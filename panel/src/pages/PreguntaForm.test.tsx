import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { PreguntaForm } from './PreguntaForm'
import type { NivelParaAsignar, PreguntaDetalle } from '../lib/preguntaForm'

const fetchPregunta = vi.fn()
const fetchNivelesParaAsignar = vi.fn()
const guardarPregunta = vi.fn()
const asignarPreguntaANiveles = vi.fn()

vi.mock('../lib/preguntaForm', async () => {
  const actual = await vi.importActual<typeof import('../lib/preguntaForm')>('../lib/preguntaForm')
  return {
    ...actual,
    fetchPregunta: (...args: unknown[]) => fetchPregunta(...args),
    fetchNivelesParaAsignar: (...args: unknown[]) => fetchNivelesParaAsignar(...args),
    guardarPregunta: (...args: unknown[]) => guardarPregunta(...args),
    asignarPreguntaANiveles: (...args: unknown[]) => asignarPreguntaANiveles(...args),
  }
})

const NIVELES: NivelParaAsignar[] = [
  { id: 'n-1', tematicaNombre: 'Capitales', nivelOrden: 1, cantidadPreguntas: 4 },
  { id: 'n-2', tematicaNombre: 'Paisajes', nivelOrden: 3, cantidadPreguntas: 2 },
]

const PREGUNTA_EXISTENTE: PreguntaDetalle = {
  id: 'd-eiffel',
  tipo: 'imagen',
  nombreLugar: 'Torre Eiffel',
  textoPregunta: null,
  imagenUrl: 'https://cdn.test/imagen/d-eiffel.jpg',
  videoUrl: null,
  latReal: 48.8584,
  lngReal: 2.2945,
  activo: true,
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
  fetchNivelesParaAsignar.mockReset()
  guardarPregunta.mockReset()
  asignarPreguntaANiveles.mockReset()
  fetchNivelesParaAsignar.mockResolvedValue(NIVELES)
})

async function rellenarCamposComunes(user: ReturnType<typeof userEvent.setup>) {
  await user.type(screen.getByPlaceholderText(/torre eiffel, parís/i), 'Machu Picchu')
  await user.type(screen.getByPlaceholderText('-90 a 90'), '-13.1631')
  await user.type(screen.getByPlaceholderText('-180 a 180'), '-72.545')
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

  it('busca niveles por temática y quita una selección con la pill', async () => {
    const user = userEvent.setup()
    renderNueva()

    await screen.findByText('4 preguntas')
    await user.click(screen.getByText('Capitales · Nivel 1'))
    expect(await screen.findByText('1 nivel seleccionado')).toBeInTheDocument()

    await user.type(screen.getByPlaceholderText(/buscar nivel o temática/i), 'paisajes')
    expect(screen.queryByText('4 preguntas')).not.toBeInTheDocument()
    expect(screen.getByText('2 preguntas')).toBeInTheDocument()

    await user.click(screen.getByTitle('Quitar'))
    expect(await screen.findByText('Ningún nivel seleccionado')).toBeInTheDocument()
  })

  it('muestra un aviso si no se pueden cargar los niveles disponibles', async () => {
    fetchNivelesParaAsignar.mockRejectedValue(new Error('network down'))
    renderNueva()

    expect(
      await screen.findByText('No se han podido cargar los niveles disponibles.'),
    ).toBeInTheDocument()
  })

  it('bloquea el guardado y muestra error si el tipo imagen no tiene archivo', async () => {
    const user = userEvent.setup()
    renderNueva()

    await rellenarCamposComunes(user)
    await user.click(screen.getByRole('button', { name: /guardar pregunta/i }))

    expect(await screen.findByText('Selecciona una imagen.')).toBeInTheDocument()
    expect(guardarPregunta).not.toHaveBeenCalled()
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

  it('crea una pregunta de tipo texto y vuelve al listado', async () => {
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
        tipo: 'pregunta_texto',
        nombreLugar: 'Machu Picchu',
        textoPregunta: '¿Ciudadela inca?',
        latReal: -13.1631,
        lngReal: -72.545,
        activo: true,
      }),
    )
    expect(asignarPreguntaANiveles).not.toHaveBeenCalled()
    expect(await screen.findByText('Listado de preguntas')).toBeInTheDocument()
  })

  it('al crear y seleccionar un nivel, asigna la pregunta a ese nivel', async () => {
    guardarPregunta.mockResolvedValue({ id: 'd-nueva' })
    asignarPreguntaANiveles.mockResolvedValue([{ nivelId: 'n-1', error: null }])
    const user = userEvent.setup()
    renderNueva()

    await user.click(screen.getByText('Pregunta de texto'))
    await user.type(screen.getByPlaceholderText(/ciudadela inca/i), '¿Ciudadela inca?')
    await rellenarCamposComunes(user)

    await screen.findByText('Capitales · Nivel 1')
    await user.click(screen.getByText('Capitales · Nivel 1'))
    await user.click(screen.getByRole('button', { name: /guardar pregunta/i }))

    await waitFor(() => expect(asignarPreguntaANiveles).toHaveBeenCalledWith('d-nueva', ['n-1']))
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
  it('precarga los datos existentes y no muestra la sección de asignar niveles', async () => {
    fetchPregunta.mockResolvedValue(PREGUNTA_EXISTENTE)
    renderEditar('d-eiffel')

    expect(await screen.findByText('Editar pregunta')).toBeInTheDocument()
    expect(screen.getByDisplayValue('Torre Eiffel')).toBeInTheDocument()
    expect(screen.getByDisplayValue('48.8584')).toBeInTheDocument()
    expect(screen.getByDisplayValue('2.2945')).toBeInTheDocument()
    expect(screen.queryByText('Asignar a nivel(es) ahora')).not.toBeInTheDocument()
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
      }),
    )
    expect(fetchNivelesParaAsignar).not.toHaveBeenCalled()
  })

  it('muestra un error de carga si la pregunta no existe', async () => {
    fetchPregunta.mockRejectedValue(new Error('no encontrada'))
    renderEditar('d-x')

    expect(await screen.findByText('No se ha podido cargar la pregunta.')).toBeInTheDocument()
  })
})
