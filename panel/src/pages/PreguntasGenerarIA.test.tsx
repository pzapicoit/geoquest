import { StrictMode } from 'react'
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import { PreguntasGenerarIA } from './PreguntasGenerarIA'
import { ErrorIa, type CandidatoIA } from '../lib/iaPreguntas'

const fetchTematicasParaPregunta = vi.fn()
const pedirCandidatosDeduplicados = vi.fn()
const generarImagenLugar = vi.fn()
const guardarLoteIA = vi.fn()

vi.mock('../lib/preguntaForm', async () => {
  const actual = await vi.importActual<typeof import('../lib/preguntaForm')>('../lib/preguntaForm')
  return {
    ...actual,
    fetchTematicasParaPregunta: (...args: unknown[]) => fetchTematicasParaPregunta(...args),
  }
})

vi.mock('../lib/iaPreguntas', async () => {
  const actual = await vi.importActual<typeof import('../lib/iaPreguntas')>('../lib/iaPreguntas')
  return {
    ...actual,
    pedirCandidatosDeduplicados: (...args: unknown[]) => pedirCandidatosDeduplicados(...args),
    generarImagenLugar: (...args: unknown[]) => generarImagenLugar(...args),
  }
})

vi.mock('../lib/loteIA', async () => {
  const actual = await vi.importActual<typeof import('../lib/loteIA')>('../lib/loteIA')
  return {
    ...actual,
    guardarLoteIA: (...args: unknown[]) => guardarLoteIA(...args),
  }
})

const TEMATICAS = [
  { id: 't-monumentos', nombre: 'Monumentos', promptImagen: null },
  {
    id: 't-banderas',
    nombre: 'Banderas',
    promptImagen: 'la bandera del país sobre fondo neutro, sin escena alrededor',
  },
]

function candidato(
  nombre: string,
  lat = 41.8902,
  lng = 12.4922,
  ciudad: string | null = 'Roma',
  pais: string | null = 'Italia',
): CandidatoIA {
  return {
    nombre,
    lat,
    lng,
    ciudad,
    pais,
    descripcion: `Se ve ${nombre.toLowerCase()} desde el aire`,
  }
}

const COLISEO = candidato('Coliseo, Roma')
const EIFFEL = candidato('Torre Eiffel', 48.8584, 2.2945)

// El panel monta con StrictMode (`src/main.tsx`), que en desarrollo monta,
// desmonta y remonta cada componente. Los tests hacen lo mismo a propósito: un
// ref de "sigo montado" que no se reafirme en el efecto se queda en false tras
// ese ciclo y congela la pantalla, y eso solo se ve montando así.
function renderPantalla() {
  return render(
    <StrictMode>
      <MemoryRouter>
        <PreguntasGenerarIA />
      </MemoryRouter>
    </StrictMode>,
  )
}

async function generarTanda(candidatos: CandidatoIA[], tandaCorta = false) {
  const user = userEvent.setup()
  pedirCandidatosDeduplicados.mockResolvedValue({ candidatos, tandaCorta })
  renderPantalla()
  await screen.findByRole('option', { name: 'Monumentos' })
  await user.click(screen.getByRole('button', { name: /Generar propuestas/ }))
  await screen.findByRole('button', { name: /Generar imágenes/ })
  return user
}

function imagenGenerada() {
  return new Blob(['webp'], { type: 'image/webp' })
}

beforeEach(() => {
  fetchTematicasParaPregunta.mockReset()
  pedirCandidatosDeduplicados.mockReset()
  generarImagenLugar.mockReset()
  guardarLoteIA.mockReset()

  fetchTematicasParaPregunta.mockResolvedValue(TEMATICAS)
  generarImagenLugar.mockResolvedValue(imagenGenerada())
  guardarLoteIA.mockImplementation(
    (lote: { candidatos: { nombre: string; imagen: Blob | null }[] }) =>
      Promise.resolve(
        lote.candidatos.map((c) => ({
          nombre: c.nombre,
          guardado: c.imagen !== null,
          motivo: c.imagen ? null : 'sin_imagen',
        })),
      ),
  )

  // jsdom no implementa las URL de objeto que usan las previsualizaciones.
  URL.createObjectURL = vi.fn(() => 'blob:previa')
  URL.revokeObjectURL = vi.fn()
})

afterEach(() => {
  vi.restoreAllMocks()
})

describe('paso 1 · configuración', () => {
  it('ofrece las cinco dificultades del catálogo y ninguna más', async () => {
    renderPantalla()
    await screen.findByRole('option', { name: 'Monumentos' })

    for (const etiqueta of ['Fácil', 'Normal', 'Intermedio', 'Difícil', 'Muy difícil']) {
      expect(screen.getByRole('button', { name: new RegExp(etiqueta) })).toBeInTheDocument()
    }
    expect(screen.queryByRole('button', { name: /Mixta/ })).not.toBeInTheDocument()
  })

  it('marca la dificultad elegida', async () => {
    const user = userEvent.setup()
    renderPantalla()
    await screen.findByRole('option', { name: 'Monumentos' })

    const dificil = screen.getByRole('button', { name: /Difícil/ })
    expect(screen.getByRole('button', { name: /Normal/ })).toHaveAttribute('aria-pressed', 'true')

    await user.click(dificil)

    expect(dificil).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByRole('button', { name: /Normal/ })).toHaveAttribute('aria-pressed', 'false')
  })

  it('no deja bajar de 3 ni pasar de 20 preguntas', async () => {
    const user = userEvent.setup()
    renderPantalla()
    await screen.findByRole('option', { name: 'Monumentos' })

    const cantidad = screen.getByTestId('cantidad')
    const menos = screen.getByRole('button', { name: 'Quitar una pregunta' })
    const mas = screen.getByRole('button', { name: 'Añadir una pregunta' })

    expect(cantidad).toHaveTextContent('8')

    for (let i = 0; i < 8; i += 1) await user.click(menos)
    expect(cantidad).toHaveTextContent('3')

    for (let i = 0; i < 20; i += 1) await user.click(mas)
    expect(cantidad).toHaveTextContent('20')
  })

  it('no permite generar si no hay ninguna temática', async () => {
    fetchTematicasParaPregunta.mockResolvedValue([])
    renderPantalla()

    await waitFor(() =>
      expect(screen.getByRole('button', { name: /Generar propuestas/ })).toBeDisabled(),
    )
    expect(pedirCandidatosDeduplicados).not.toHaveBeenCalled()
  })

  it('pide la tanda con la temática, dificultad, cantidad e indicaciones elegidas', async () => {
    const user = userEvent.setup()
    pedirCandidatosDeduplicados.mockResolvedValue({ candidatos: [COLISEO], tandaCorta: false })
    renderPantalla()
    await screen.findByRole('option', { name: 'Monumentos' })

    await user.click(screen.getByRole('button', { name: /Intermedio/ }))
    await user.click(screen.getByRole('button', { name: 'Quitar una pregunta' }))
    await user.type(screen.getByRole('textbox'), 'solo hemisferio sur')
    await user.click(screen.getByRole('button', { name: /Generar propuestas/ }))

    await waitFor(() =>
      expect(pedirCandidatosDeduplicados).toHaveBeenCalledWith({
        tematicaId: 't-monumentos',
        tematicaNombre: 'Monumentos',
        dificultad: 'intermedio',
        cantidad: 7,
        indicaciones: 'solo hemisferio sur',
      }),
    )
  })
})

describe('indicador de pasos', () => {
  it('empieza con el paso 1 en curso y los otros dos pendientes', async () => {
    renderPantalla()
    await screen.findByRole('option', { name: 'Monumentos' })

    expect(screen.getByText('1. Configurar (en curso)')).toBeInTheDocument()
    expect(screen.getByText('2. Revisar propuestas (pendiente)')).toBeInTheDocument()
    expect(screen.getByText('3. Ilustrar y guardar (pendiente)')).toBeInTheDocument()
  })

  it('avanza a medida que avanza el wizard', async () => {
    const user = await generarTanda([COLISEO])

    expect(screen.getByText('1. Configurar (completado)')).toBeInTheDocument()
    expect(screen.getByText('2. Revisar propuestas (en curso)')).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: /Generar imágenes \(1\)/ }))
    await screen.findByText('1 / 1 listas')

    expect(screen.getByText('2. Revisar propuestas (completado)')).toBeInTheDocument()
    expect(screen.getByText('3. Ilustrar y guardar (en curso)')).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Guardar 1 pregunta' }))

    expect(await screen.findByText('3. Ilustrar y guardar (completado)')).toBeInTheDocument()
  })

  it('mientras pide las propuestas lo dice y no deja lanzar otra tanda', async () => {
    const user = userEvent.setup()
    let entregar: (tanda: { candidatos: CandidatoIA[]; tandaCorta: boolean }) => void = () => {}
    pedirCandidatosDeduplicados.mockReturnValue(
      new Promise((resolve) => {
        entregar = resolve
      }),
    )
    renderPantalla()
    await screen.findByRole('option', { name: 'Monumentos' })

    await user.click(screen.getByRole('button', { name: /Generar propuestas/ }))

    expect(await screen.findByText(/Redactando 8 preguntas de «Monumentos»/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /Regenerar propuestas/ })).toBeDisabled()

    entregar({ candidatos: [COLISEO], tandaCorta: false })

    expect(await screen.findByRole('button', { name: /Generar imágenes \(1\)/ })).toBeEnabled()
    expect(pedirCandidatosDeduplicados).toHaveBeenCalledTimes(1)
  })
})

describe('paso 2 · revisión de propuestas', () => {
  it('muestra un candidato por fila, todos marcados', async () => {
    await generarTanda([COLISEO, EIFFEL])

    const filaColiseo = screen.getByText('Coliseo, Roma').closest('tr') as HTMLElement
    expect(within(filaColiseo).getByRole('checkbox')).toBeChecked()
    expect(within(filaColiseo).getByText('41.8902, 12.4922')).toBeInTheDocument()
    expect(within(filaColiseo).getByText(/Se ve coliseo/)).toBeInTheDocument()
    expect(within(filaColiseo).getByText('Roma')).toBeInTheDocument()
    expect(within(filaColiseo).getByText('Italia')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /Generar imágenes \(2\)/ })).toBeEnabled()
  })

  it('un candidato sin ciudad se marca como tal y sigue seleccionable', async () => {
    // La ciudad se revisa antes de ilustrar (INT-122, D11), pero no bloquea:
    // hay objetivos que no están dentro de ninguna localidad.
    const stonehenge = candidato('Stonehenge', 51.1789, -1.8262, null, 'Reino Unido')
    await generarTanda([stonehenge])

    const fila = screen.getByText('Stonehenge').closest('tr') as HTMLElement
    expect(within(fila).getByText('sin ciudad')).toBeInTheDocument()
    expect(within(fila).getByText('Reino Unido')).toBeInTheDocument()
    expect(within(fila).getByRole('checkbox')).toBeChecked()
    expect(screen.getByRole('button', { name: /Generar imágenes \(1\)/ })).toBeEnabled()
  })

  it('descartar un candidato lo saca de la cuenta', async () => {
    const user = await generarTanda([COLISEO, EIFFEL])

    await user.click(screen.getByRole('checkbox', { name: 'Conservar Coliseo, Roma' }))

    expect(screen.getByRole('button', { name: /Generar imágenes \(1\)/ })).toBeEnabled()
  })

  it('sin ningún candidato marcado no se puede continuar', async () => {
    const user = await generarTanda([COLISEO, EIFFEL])

    await user.click(screen.getByRole('button', { name: 'Desmarcar todas' }))

    expect(screen.getByRole('button', { name: /Generar imágenes \(0\)/ })).toBeDisabled()
    expect(screen.getByText('Marca al menos una pregunta para continuar.')).toBeInTheDocument()
  })

  it('avisa del coste aproximado antes de ilustrar', async () => {
    await generarTanda([COLISEO, EIFFEL])

    expect(screen.getByText(/se generarán 2 imágenes, coste aproximado/)).toBeInTheDocument()
  })

  it('avisa cuando la tanda queda corta por duplicados', async () => {
    await generarTanda([COLISEO], true)

    expect(screen.getByText(/solo ha encontrado 1 lugares nuevos/)).toBeInTheDocument()
  })

  it('descartar la tanda vuelve al paso 1 sin candidatos', async () => {
    const user = await generarTanda([COLISEO, EIFFEL])

    await user.click(screen.getByRole('button', { name: 'Descartar tanda' }))

    expect(screen.queryByText('Coliseo, Roma')).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /Generar imágenes/ })).not.toBeInTheDocument()
    expect(guardarLoteIA).not.toHaveBeenCalled()
  })
})

describe('paso 3 · ilustraciones', () => {
  it('genera una imagen por candidato y muestra el progreso', async () => {
    const user = await generarTanda([COLISEO, EIFFEL])

    await user.click(screen.getByRole('button', { name: /Generar imágenes \(2\)/ }))

    expect(await screen.findByText('2 / 2 listas')).toBeInTheDocument()
    expect(generarImagenLugar).toHaveBeenCalledTimes(2)
    expect(generarImagenLugar).toHaveBeenCalledWith({
      nombre: 'Coliseo, Roma',
      descripcion: COLISEO.descripcion,
      estiloTematica: null,
      indicaciones: null,
    })
    expect(screen.getAllByAltText(/Ilustración de/)).toHaveLength(4) // tabla + tarjetas
  })

  it('una imagen fallida no bloquea el resto del lote', async () => {
    const user = await generarTanda([COLISEO, EIFFEL])
    generarImagenLugar.mockRejectedValueOnce(new ErrorIa('openai_error'))

    await user.click(screen.getByRole('button', { name: /Generar imágenes \(2\)/ }))

    expect(await screen.findByText('1 / 2 listas')).toBeInTheDocument()
    expect(screen.getByText('No se pudo generar')).toBeInTheDocument()
    expect(screen.getByRole('alert')).toHaveTextContent('La IA no ha respondido')
  })

  it('permite reintentar la imagen fallida sin tocar las demás', async () => {
    const user = await generarTanda([COLISEO, EIFFEL])
    generarImagenLugar.mockRejectedValueOnce(new ErrorIa('openai_error'))

    await user.click(screen.getByRole('button', { name: /Generar imágenes \(2\)/ }))
    await screen.findByText('1 / 2 listas')

    await user.click(screen.getByRole('button', { name: /Reintentar Coliseo, Roma/ }))

    expect(await screen.findByText('2 / 2 listas')).toBeInTheDocument()
    expect(generarImagenLugar).toHaveBeenCalledTimes(3)
  })

  it('permite rehacer una imagen ya generada', async () => {
    const user = await generarTanda([COLISEO])

    await user.click(screen.getByRole('button', { name: /Generar imágenes \(1\)/ }))
    await screen.findByText('1 / 1 listas')

    await user.click(screen.getByRole('button', { name: /Rehacer Coliseo, Roma/ }))

    await waitFor(() => expect(generarImagenLugar).toHaveBeenCalledTimes(2))
    expect(await screen.findByText('1 / 1 listas')).toBeInTheDocument()
  })
})

describe('tanda descartada con ilustraciones en vuelo', () => {
  it('no crea previsualizaciones ni reaparece el candidato cuando la imagen llega tarde', async () => {
    const user = await generarTanda([COLISEO])
    let terminar: (imagen: Blob) => void = () => {}
    generarImagenLugar.mockReturnValueOnce(
      new Promise<Blob>((resolve) => {
        terminar = resolve
      }),
    )

    await user.click(screen.getByRole('button', { name: /Generar imágenes \(1\)/ }))
    await screen.findByText('0 / 1 listas')

    await user.click(screen.getByRole('button', { name: 'Descartar tanda' }))
    terminar(imagenGenerada())

    await waitFor(() => expect(screen.queryByText('Coliseo, Roma')).not.toBeInTheDocument())
    expect(URL.createObjectURL).not.toHaveBeenCalled()
  })

  it('no muestra el error de una tanda ya descartada', async () => {
    const user = await generarTanda([COLISEO])
    let romper: (fallo: Error) => void = () => {}
    generarImagenLugar.mockReturnValueOnce(
      new Promise<Blob>((_, reject) => {
        romper = reject
      }),
    )

    await user.click(screen.getByRole('button', { name: /Generar imágenes \(1\)/ }))
    await screen.findByText('0 / 1 listas')

    await user.click(screen.getByRole('button', { name: 'Descartar tanda' }))
    romper(new ErrorIa('openai_error'))

    await waitFor(() =>
      expect(screen.getByRole('button', { name: /Generar propuestas/ })).toBeInTheDocument(),
    )
    expect(screen.queryByRole('alert')).not.toBeInTheDocument()
  })
})

describe('las indicaciones extra llegan también a la ilustración', () => {
  it('la imagen se pide con las indicaciones que produjeron la tanda', async () => {
    const user = userEvent.setup()
    pedirCandidatosDeduplicados.mockResolvedValue({ candidatos: [COLISEO], tandaCorta: false })
    renderPantalla()
    await screen.findByRole('option', { name: 'Monumentos' })

    await user.type(screen.getByRole('textbox'), 'Capitales del mundo y sus banderas')
    await user.click(screen.getByRole('button', { name: /Generar propuestas/ }))
    await screen.findByRole('button', { name: /Generar imágenes \(1\)/ })

    // Editar el textarea después no debe cambiar la tanda que ya está en curso.
    await user.clear(screen.getByRole('textbox'))
    await user.click(screen.getByRole('button', { name: /Generar imágenes \(1\)/ }))
    await screen.findByText('1 / 1 listas')

    expect(generarImagenLugar).toHaveBeenCalledWith({
      nombre: COLISEO.nombre,
      descripcion: COLISEO.descripcion,
      estiloTematica: null,
      indicaciones: 'Capitales del mundo y sus banderas',
    })
  })
})

describe('estilo de ilustración de la temática', () => {
  it('el paso 1 muestra el estilo de la temática elegida', async () => {
    const user = userEvent.setup()
    renderPantalla()
    await screen.findByRole('option', { name: 'Banderas' })

    await user.selectOptions(screen.getByRole('combobox'), 't-banderas')

    expect(
      screen.getByText('la bandera del país sobre fondo neutro, sin escena alrededor'),
    ).toBeInTheDocument()
  })

  it('si la temática no tiene estilo, lo dice y enlaza a Temáticas', async () => {
    renderPantalla()
    await screen.findByRole('option', { name: 'Monumentos' })

    expect(screen.getByText(/no tiene estilo propio/)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Temáticas' })).toHaveAttribute('href', '/tematicas')
  })

  it('cada ilustración se pide con el estilo de la temática', async () => {
    const user = userEvent.setup()
    pedirCandidatosDeduplicados.mockResolvedValue({ candidatos: [COLISEO], tandaCorta: false })
    renderPantalla()
    await screen.findByRole('option', { name: 'Banderas' })

    await user.selectOptions(screen.getByRole('combobox'), 't-banderas')
    await user.click(screen.getByRole('button', { name: /Generar propuestas/ }))
    await screen.findByRole('button', { name: /Generar imágenes \(1\)/ })
    await user.click(screen.getByRole('button', { name: /Generar imágenes \(1\)/ }))
    await screen.findByText('1 / 1 listas')

    expect(generarImagenLugar).toHaveBeenCalledWith(
      expect.objectContaining({
        estiloTematica: 'la bandera del país sobre fondo neutro, sin escena alrededor',
      }),
    )
  })

  it('el estilo de la temática y las indicaciones de la tanda llegan juntos', async () => {
    const user = userEvent.setup()
    pedirCandidatosDeduplicados.mockResolvedValue({ candidatos: [COLISEO], tandaCorta: false })
    renderPantalla()
    await screen.findByRole('option', { name: 'Banderas' })

    await user.selectOptions(screen.getByRole('combobox'), 't-banderas')
    await user.type(screen.getByRole('textbox'), 'solo hemisferio sur')
    await user.click(screen.getByRole('button', { name: /Generar propuestas/ }))
    await screen.findByRole('button', { name: /Generar imágenes \(1\)/ })
    await user.click(screen.getByRole('button', { name: /Generar imágenes \(1\)/ }))
    await screen.findByText('1 / 1 listas')

    // Las dos cosas viajan a la vez y por separado: el estilo gobierna el motivo,
    // las indicaciones lo matizan.
    expect(generarImagenLugar).toHaveBeenCalledWith({
      nombre: COLISEO.nombre,
      descripcion: COLISEO.descripcion,
      estiloTematica: 'la bandera del país sobre fondo neutro, sin escena alrededor',
      indicaciones: 'solo hemisferio sur',
    })
  })

  it('sin estilo en la temática, la ilustración se pide sin él', async () => {
    const user = await generarTanda([COLISEO])

    await user.click(screen.getByRole('button', { name: /Generar imágenes \(1\)/ }))
    await screen.findByText('1 / 1 listas')

    expect(generarImagenLugar).toHaveBeenCalledWith(
      expect.objectContaining({ estiloTematica: null }),
    )
  })

  it('cambiar de temática después de lanzar no altera el estilo de la tanda en curso', async () => {
    const user = userEvent.setup()
    pedirCandidatosDeduplicados.mockResolvedValue({ candidatos: [COLISEO], tandaCorta: false })
    renderPantalla()
    await screen.findByRole('option', { name: 'Banderas' })

    await user.selectOptions(screen.getByRole('combobox'), 't-banderas')
    await user.click(screen.getByRole('button', { name: /Generar propuestas/ }))
    await screen.findByRole('button', { name: /Generar imágenes \(1\)/ })

    // Cambiar de temática descarta la tanda, así que se vuelve a lanzar con la
    // nueva: el estilo que llega a la imagen es el de la temática vigente.
    await user.selectOptions(screen.getByRole('combobox'), 't-monumentos')
    await user.click(screen.getByRole('button', { name: /Generar propuestas/ }))
    await screen.findByRole('button', { name: /Generar imágenes \(1\)/ })
    await user.click(screen.getByRole('button', { name: /Generar imágenes \(1\)/ }))
    await screen.findByText('1 / 1 listas')

    expect(generarImagenLugar).toHaveBeenLastCalledWith(
      expect.objectContaining({ estiloTematica: null }),
    )
  })
})

describe('guardado del lote', () => {
  it('guarda las preguntas listas como activas por defecto', async () => {
    const user = await generarTanda([COLISEO, EIFFEL])

    await user.click(screen.getByRole('button', { name: /Generar imágenes \(2\)/ }))
    await screen.findByText('2 / 2 listas')

    await user.click(screen.getByRole('button', { name: 'Guardar 2 preguntas' }))

    await waitFor(() => expect(guardarLoteIA).toHaveBeenCalledTimes(1))
    expect(guardarLoteIA).toHaveBeenCalledWith(
      expect.objectContaining({ tematicaId: 't-monumentos', dificultad: 'normal', activo: true }),
    )
    const candidatosGuardados = (
      guardarLoteIA.mock.calls[0][0] as { candidatos: { ciudad: string | null }[] }
    ).candidatos
    expect(candidatosGuardados.map((c) => c.ciudad)).toEqual(['Roma', 'Roma'])
    expect(await screen.findByText('2 preguntas guardadas en el banco')).toBeInTheDocument()
    expect(screen.getByText(/activas y listas para el camino/)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Ver en el banco' })).toHaveAttribute(
      'href',
      '/preguntas',
    )
  })

  it('guarda como inactivas si se apaga "Publicar activas"', async () => {
    const user = await generarTanda([COLISEO])

    await user.click(screen.getByRole('button', { name: /Generar imágenes \(1\)/ }))
    await screen.findByText('1 / 1 listas')
    await user.click(screen.getByRole('checkbox', { name: 'Publicar activas' }))
    await user.click(screen.getByRole('button', { name: 'Guardar 1 pregunta' }))

    await waitFor(() =>
      expect(guardarLoteIA).toHaveBeenCalledWith(expect.objectContaining({ activo: false })),
    )
    expect(await screen.findByText(/guardadas como inactivas/)).toBeInTheDocument()
  })

  it('no manda al banco el candidato cuya imagen falló', async () => {
    const user = await generarTanda([COLISEO, EIFFEL])
    generarImagenLugar.mockRejectedValueOnce(new ErrorIa('openai_error'))

    await user.click(screen.getByRole('button', { name: /Generar imágenes \(2\)/ }))
    await screen.findByText('1 / 2 listas')

    await user.click(screen.getByRole('button', { name: 'Guardar 1 pregunta' }))

    await waitFor(() => expect(guardarLoteIA).toHaveBeenCalledTimes(1))
    const lote = guardarLoteIA.mock.calls[0][0] as {
      candidatos: { nombre: string; imagen: Blob | null }[]
    }
    expect(lote.candidatos.find((c) => c.nombre === 'Coliseo, Roma')?.imagen).toBeNull()
    expect(lote.candidatos.find((c) => c.nombre === 'Torre Eiffel')?.imagen).not.toBeNull()
    expect(await screen.findByText('1 pregunta guardada en el banco')).toBeInTheDocument()
    expect(screen.getByText(/No se han podido guardar 1: Coliseo, Roma/)).toBeInTheDocument()
  })

  it('no deja guardar mientras queda alguna ilustración en curso', async () => {
    const user = await generarTanda([COLISEO, EIFFEL])
    let terminar: (imagen: Blob) => void = () => {}
    generarImagenLugar.mockResolvedValueOnce(imagenGenerada()).mockReturnValueOnce(
      new Promise<Blob>((resolve) => {
        terminar = resolve
      }),
    )

    await user.click(screen.getByRole('button', { name: /Generar imágenes \(2\)/ }))

    expect(await screen.findByText('1 / 2 listas')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Generando…' })).toBeDisabled()
    expect(screen.getByText(/Espera a que terminen las 2 ilustraciones/)).toBeInTheDocument()

    terminar(imagenGenerada())

    expect(await screen.findByRole('button', { name: 'Guardar 2 preguntas' })).toBeEnabled()
  })
})

describe('errores traducidos', () => {
  it('explica que falta el secreto de OpenAI sin volcar el error crudo', async () => {
    const user = userEvent.setup()
    pedirCandidatosDeduplicados.mockRejectedValue(new ErrorIa('secreto_no_configurado'))
    renderPantalla()
    await screen.findByRole('option', { name: 'Monumentos' })

    await user.click(screen.getByRole('button', { name: /Generar propuestas/ }))

    const aviso = await screen.findByRole('alert')
    expect(aviso).toHaveTextContent('La clave de OpenAI no está configurada')
    expect(aviso).not.toHaveTextContent('OpenAI API')
    expect(screen.queryByRole('button', { name: /Generar imágenes/ })).not.toBeInTheDocument()
  })

  it('traduce un fallo desconocido del generador', async () => {
    const user = userEvent.setup()
    pedirCandidatosDeduplicados.mockRejectedValue(new Error('kaboom'))
    renderPantalla()
    await screen.findByRole('option', { name: 'Monumentos' })

    await user.click(screen.getByRole('button', { name: /Generar propuestas/ }))

    expect(await screen.findByRole('alert')).toHaveTextContent('No se ha podido contactar')
  })

  it('avisa si no se pueden cargar las temáticas', async () => {
    fetchTematicasParaPregunta.mockRejectedValue(new Error('sin red'))
    renderPantalla()

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'No se han podido cargar las temáticas.',
    )
  })

  it('cuenta como tanda vacía cuando la IA no encuentra nada nuevo', async () => {
    const user = userEvent.setup()
    pedirCandidatosDeduplicados.mockResolvedValue({ candidatos: [], tandaCorta: true })
    renderPantalla()
    await screen.findByRole('option', { name: 'Monumentos' })

    await user.click(screen.getByRole('button', { name: /Generar propuestas/ }))

    expect(
      await screen.findByText(/La IA no ha encontrado lugares nuevos para esta temática/),
    ).toBeInTheDocument()
  })
})
