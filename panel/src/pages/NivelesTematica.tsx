import { useEffect, useState, type ChangeEvent, type DragEvent } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import {
  crearNivel,
  eliminarNivel,
  fetchNivelesTematica,
  reordenarNiveles,
  type NivelListado,
  type NivelesTematica as NivelesTematicaData,
} from '../lib/niveles'

const BOTON_FONDO = {
  background: 'linear-gradient(140deg, #2BC0A8, #1B6FA8)',
}

const CAMPO_BASE =
  'h-11 rounded-xl border-[1.5px] border-brand-border bg-white px-3.5 text-sm text-brand-night outline-none placeholder:text-brand-night/40 focus:border-brand-teal focus:ring-4 focus:ring-brand-teal/15'
const CAMPO_ERROR = 'border-[#E0454A] bg-[#FFF8F8] focus:border-[#E0454A] focus:ring-[#E0454A]/15'

function nombreNivel(nivel: Pick<NivelListado, 'nombre' | 'orden'>): string {
  const nombre = nivel.nombre?.trim()
  return nombre ? nombre : `Nivel ${nivel.orden}`
}

function formatearPosicion(index: number): string {
  return String(index + 1).padStart(2, '0')
}

function fraseDesbloqueo(index: number): string {
  return index === 0 ? 'Primer nivel de la temática' : `Se desbloquea al superar el nivel ${index}`
}

function etiquetaPreguntas(cantidad: number): string {
  return cantidad === 1 ? '1 pregunta' : `${cantidad} preguntas`
}

function ErrorCampo({ mensaje }: { mensaje?: string }) {
  if (!mensaje) return null
  return <p className="text-xs font-medium text-[#B3282D]">{mensaje}</p>
}

function IconoAsa() {
  return (
    <svg width="12" height="18" viewBox="0 0 12 18" fill="currentColor" aria-hidden="true">
      <circle cx="3" cy="3" r="1.5" />
      <circle cx="9" cy="3" r="1.5" />
      <circle cx="3" cy="9" r="1.5" />
      <circle cx="9" cy="9" r="1.5" />
      <circle cx="3" cy="15" r="1.5" />
      <circle cx="9" cy="15" r="1.5" />
    </svg>
  )
}

function IconoEliminar() {
  return (
    <svg
      width="14"
      height="14"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.9"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M5 7h14M9.5 7V5h5v2M7 7l.9 12.1A1.5 1.5 0 0 0 9.4 20h5.2a1.5 1.5 0 0 0 1.5-.9L17 7" />
    </svg>
  )
}

function IconoNivel() {
  return (
    <svg
      width="34"
      height="34"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M5 19h4M11 19h4M17 19h2" />
      <path d="M6 15V9M12 15V6M18 15v-3" />
    </svg>
  )
}

function IconoAviso() {
  return (
    <svg
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="#E0454A"
      strokeWidth="1.9"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M12 4.4 21 19.6H3z" />
      <path d="M12 10v4.2M12 17h.01" />
    </svg>
  )
}

function FilaNivel({
  nivel,
  index,
  total,
  arrastrando,
  onDragStart,
  onDragOver,
  onDrop,
  onMover,
  onEliminarClick,
}: {
  nivel: NivelListado
  index: number
  total: number
  arrastrando: boolean
  onDragStart: () => void
  onDragOver: (e: DragEvent<HTMLDivElement>) => void
  onDrop: () => void
  onMover: (delta: number) => void
  onEliminarClick: () => void
}) {
  const pocasPreguntas = nivel.cantidadPreguntas < 3

  return (
    <div
      draggable
      onDragStart={onDragStart}
      onDragOver={onDragOver}
      onDrop={onDrop}
      className={`flex items-center gap-3 border-b border-brand-base px-4 py-3 last:border-0 hover:bg-brand-base/40 ${arrastrando ? 'opacity-40' : ''}`}
    >
      <span
        title="Arrastrar para reordenar"
        className="flex flex-none cursor-grab items-center justify-center text-brand-night/30 hover:text-brand-blue"
      >
        <IconoAsa />
      </span>
      <span className="flex h-8 w-8 flex-none items-center justify-center rounded-lg bg-brand-blue/10 text-xs font-extrabold text-brand-blue tabular-nums">
        {formatearPosicion(index)}
      </span>
      <div className="min-w-0 flex-1">
        <Link
          to={`/niveles/${nivel.id}`}
          className="block truncate text-sm font-semibold text-brand-night hover:text-brand-blue hover:underline"
        >
          {nombreNivel(nivel)}
        </Link>
        <div className="mt-0.5 flex items-center gap-1.5 text-xs text-brand-night/50">
          <span className="flex-none font-semibold text-brand-night/60">
            Mínimo {nivel.puntajeMinimoSuperar.toLocaleString('es-ES')} pts
          </span>
          <span className="text-brand-night/30">·</span>
          <span className="min-w-0 truncate">{fraseDesbloqueo(index)}</span>
        </div>
      </div>
      <span
        className={`flex-none rounded-lg px-2.5 py-1 text-xs font-semibold tabular-nums whitespace-nowrap ${
          pocasPreguntas ? 'bg-brand-gold/20 text-[#996100]' : 'bg-brand-base text-brand-night/60'
        }`}
      >
        {etiquetaPreguntas(nivel.cantidadPreguntas)}
      </span>
      <span
        className={`flex-none items-center gap-1.5 text-xs font-semibold whitespace-nowrap ${
          nivel.activo ? 'text-brand-success' : 'text-brand-night/45'
        } flex`}
      >
        <span
          className={`h-1.5 w-1.5 rounded-full ${nivel.activo ? 'bg-brand-success' : 'bg-brand-border'}`}
        />
        {nivel.activo ? 'Activo' : 'Inactivo'}
      </span>
      <div className="flex flex-none items-center gap-1.5">
        <button
          type="button"
          onClick={() => onMover(-1)}
          disabled={index === 0}
          aria-label="Subir posición"
          title="Subir posición"
          className="flex h-8 w-8 items-center justify-center rounded-lg border-[1.5px] border-brand-border text-brand-night/60 hover:border-brand-blue hover:text-brand-blue disabled:cursor-not-allowed disabled:opacity-30"
        >
          ↑
        </button>
        <button
          type="button"
          onClick={() => onMover(1)}
          disabled={index === total - 1}
          aria-label="Bajar posición"
          title="Bajar posición"
          className="flex h-8 w-8 items-center justify-center rounded-lg border-[1.5px] border-brand-border text-brand-night/60 hover:border-brand-blue hover:text-brand-blue disabled:cursor-not-allowed disabled:opacity-30"
        >
          ↓
        </button>
        <Link
          to={`/niveles/${nivel.id}`}
          className="rounded-lg border-[1.5px] border-brand-border px-3 py-2 text-xs font-semibold whitespace-nowrap text-brand-night hover:border-brand-teal hover:text-brand-blue"
        >
          Recorrido →
        </Link>
        <button
          type="button"
          onClick={onEliminarClick}
          aria-label="Eliminar nivel"
          title="Eliminar nivel"
          className="flex h-8 w-8 items-center justify-center rounded-lg border-[1.5px] border-brand-border text-brand-night/60 hover:border-brand-error hover:text-brand-error"
        >
          <IconoEliminar />
        </button>
      </div>
    </div>
  )
}

function EstadoVacio({ onCrear }: { onCrear: () => void }) {
  return (
    <div className="flex flex-col items-center gap-2 px-6 py-16 text-center">
      <div className="mb-3 flex h-[78px] w-[78px] items-center justify-center rounded-[22px] bg-brand-teal/10 text-brand-blue">
        <IconoNivel />
      </div>
      <h4 className="font-display text-xl font-extrabold text-brand-night">
        Esta temática aún no tiene niveles
      </h4>
      <p className="max-w-md text-sm text-brand-night/55">
        Crea el primer nivel del recorrido. Después podrás añadirle preguntas y ajustar sus puntajes
        en su pantalla de recorrido.
      </p>
      <button
        type="button"
        onClick={onCrear}
        className="mt-3 flex items-center gap-2 rounded-xl px-4 py-2.5 font-display text-sm font-extrabold text-white"
        style={BOTON_FONDO}
      >
        <span className="text-base leading-none">+</span>Crear el primer nivel
      </button>
    </div>
  )
}

function ModalNuevoNivel({
  tematicaNombre,
  posicion,
  nombre,
  error,
  guardando,
  onCambiarNombre,
  onGuardar,
  onCancelar,
}: {
  tematicaNombre: string
  posicion: string
  nombre: string
  error: string
  guardando: boolean
  onCambiarNombre: (nombre: string) => void
  onGuardar: () => void
  onCancelar: () => void
}) {
  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Nuevo nivel"
      onClick={onCancelar}
      className="fixed inset-0 z-20 flex items-start justify-center bg-brand-night/45 px-5 py-[120px]"
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className="w-full max-w-[460px] overflow-hidden rounded-2xl bg-white shadow-2xl"
      >
        <div className="px-6 pt-5.5">
          <h3 className="font-display text-xl font-extrabold text-brand-night">Nuevo nivel</h3>
          <p className="mt-2 text-sm text-brand-night/55">
            Se añadirá al final del recorrido de «{tematicaNombre}». Al guardar irás a su recorrido
            para añadir preguntas y puntajes.
          </p>
        </div>
        <div className="flex flex-col gap-1.5 px-6 py-5">
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-semibold text-brand-night">
              Nombre del nivel <span className="text-[#E0454A]">*</span>
            </span>
            <input
              type="text"
              value={nombre}
              onChange={(e: ChangeEvent<HTMLInputElement>) => onCambiarNombre(e.target.value)}
              placeholder="Ej. Nivel 10 · Islas del norte"
              className={`${CAMPO_BASE} ${error ? CAMPO_ERROR : ''}`}
            />
            <span className="text-xs text-brand-night/45">
              Se muestra al jugador en el mapa del mundo.
            </span>
            <ErrorCampo mensaje={error} />
          </label>
        </div>
        <div className="flex items-center gap-2.5 border-t border-brand-border bg-brand-base/60 px-6 py-4">
          <span className="text-xs text-brand-night/45">Posición {posicion} del recorrido</span>
          <button
            type="button"
            onClick={onCancelar}
            className="ml-auto rounded-xl border-[1.5px] border-[#CFDDE3] bg-white px-4.5 py-3 text-sm font-semibold text-brand-night/70 hover:border-brand-error hover:text-brand-error"
          >
            Cancelar
          </button>
          <button
            type="button"
            onClick={onGuardar}
            disabled={guardando}
            className="rounded-xl px-5 py-3.5 font-display text-sm font-extrabold text-white disabled:cursor-not-allowed disabled:opacity-60"
            style={BOTON_FONDO}
          >
            {guardando ? 'Guardando…' : 'Guardar y configurar'}
          </button>
        </div>
      </div>
    </div>
  )
}

function ModalConfirmarEliminar({
  nivel,
  error,
  eliminando,
  onConfirmar,
  onCancelar,
}: {
  nivel: NivelListado
  error: string
  eliminando: boolean
  onConfirmar: () => void
  onCancelar: () => void
}) {
  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={`Eliminar ${nombreNivel(nivel)}`}
      onClick={onCancelar}
      className="fixed inset-0 z-30 flex items-center justify-center bg-brand-night/50 p-6"
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className="w-full max-w-[520px] overflow-hidden rounded-2xl bg-white shadow-2xl"
      >
        <div className="flex gap-4 px-6.5 pt-6 pb-5">
          <div className="flex h-12 w-12 flex-none items-center justify-center rounded-2xl bg-brand-error/10">
            <IconoAviso />
          </div>
          <div className="min-w-0">
            <h3 className="font-display text-lg font-extrabold text-brand-night">
              ¿Eliminar «{nombreNivel(nivel)}»?
            </h3>
            <p className="mt-2 text-sm leading-relaxed text-brand-night/65">
              Se perderá su{' '}
              <strong className="font-semibold">
                recorrido de {etiquetaPreguntas(nivel.cantidadPreguntas)} asignadas
              </strong>{' '}
              y sus puntajes. Los niveles siguientes se recolocan en el recorrido de la temática.
            </p>
            <div className="mt-3.5 flex items-start gap-2.5 rounded-xl bg-brand-success/10 p-3">
              <span className="mt-1.5 h-1.5 w-1.5 flex-none rounded-full bg-brand-success" />
              <span className="text-xs leading-relaxed text-brand-night">
                Las preguntas <strong className="font-semibold">no se borran del banco</strong>:
                solo dejan de estar asignadas a este nivel.
              </span>
            </div>
            <ErrorCampo mensaje={error} />
          </div>
        </div>
        <div className="flex items-center gap-2.5 border-t border-brand-border bg-brand-base/60 px-6.5 py-4">
          <span className="text-xs text-brand-night/45">Esta acción no se puede deshacer.</span>
          <button
            type="button"
            onClick={onCancelar}
            className="ml-auto rounded-xl border-[1.5px] border-[#CFDDE3] bg-white px-4.5 py-3 text-sm font-semibold text-brand-night/70 hover:border-brand-blue hover:text-brand-blue"
          >
            Cancelar
          </button>
          <button
            type="button"
            onClick={onConfirmar}
            disabled={eliminando}
            className="rounded-xl bg-[#E0454A] px-5 py-3.5 font-display text-sm font-extrabold text-white disabled:cursor-not-allowed disabled:opacity-60"
          >
            {eliminando ? 'Eliminando…' : 'Eliminar nivel'}
          </button>
        </div>
      </div>
    </div>
  )
}

export function NivelesTematica() {
  const { id } = useParams<{ id: string }>()
  const tematicaId = id ?? ''
  const navigate = useNavigate()

  const [datos, setDatos] = useState<NivelesTematicaData | null>(null)
  const [cargando, setCargando] = useState(true)
  const [errorCarga, setErrorCarga] = useState('')

  const [errorOrden, setErrorOrden] = useState('')
  const [operandoOrden, setOperandoOrden] = useState(false)
  const [dragIndex, setDragIndex] = useState<number | null>(null)

  const [modalNuevoAbierto, setModalNuevoAbierto] = useState(false)
  const [nombreNuevo, setNombreNuevo] = useState('')
  const [errorNuevo, setErrorNuevo] = useState('')
  const [creando, setCreando] = useState(false)

  const [nivelAEliminar, setNivelAEliminar] = useState<NivelListado | null>(null)
  const [errorEliminar, setErrorEliminar] = useState('')
  const [eliminando, setEliminando] = useState(false)

  useEffect(() => {
    let isMounted = true

    fetchNivelesTematica(tematicaId)
      .then((resultado) => {
        if (!isMounted) return
        setDatos(resultado)
      })
      .catch((error: unknown) => {
        if (!isMounted) return
        console.error('Error cargando el listado de niveles:', error)
        setErrorCarga('No se ha podido cargar el listado de niveles.')
      })
      .finally(() => {
        if (isMounted) setCargando(false)
      })

    return () => {
      isMounted = false
    }
  }, [tematicaId])

  if (cargando) {
    return <div className="p-8 text-sm text-brand-night/55">Cargando…</div>
  }

  if (errorCarga || !datos) {
    return (
      <div className="rounded-2xl border border-brand-error/40 bg-brand-error/10 p-5 text-sm text-[#B3282D]">
        {errorCarga || 'No se ha podido cargar el listado de niveles.'}
      </div>
    )
  }

  const niveles = datos.niveles
  const total = niveles.length
  const activos = niveles.filter((n) => n.activo).length
  const preguntasTotal = niveles.reduce((acc, n) => acc + n.cantidadPreguntas, 0)

  const subtitulo =
    total > 0
      ? `${total} ${total === 1 ? 'nivel' : 'niveles'} · ${activos} activos · ${preguntasTotal} ${preguntasTotal === 1 ? 'pregunta asignada' : 'preguntas asignadas'} en total`
      : 'Sin niveles todavía'

  function abrirNuevo() {
    setNombreNuevo('')
    setErrorNuevo('')
    setModalNuevoAbierto(true)
  }

  function cerrarNuevo() {
    if (creando) return
    setModalNuevoAbierto(false)
  }

  async function handleGuardarNuevo() {
    if (creando) return

    const nombreLimpio = nombreNuevo.trim()
    if (!nombreLimpio) {
      setErrorNuevo('El nombre del nivel es obligatorio.')
      return
    }

    setErrorNuevo('')
    setCreando(true)
    try {
      const { id: nuevoId } = await crearNivel(tematicaId, nombreLimpio)
      navigate(`/niveles/${nuevoId}`)
    } catch (crearError) {
      setErrorNuevo(
        crearError instanceof Error ? crearError.message : 'No se ha podido crear el nivel.',
      )
    } finally {
      setCreando(false)
    }
  }

  function persistirOrden(nuevoOrden: NivelListado[]) {
    if (operandoOrden) return

    const anterior = niveles
    const renumerados = nuevoOrden.map((nivel, i) => ({ ...nivel, orden: i + 1 }))
    setDatos((actual) => (actual ? { ...actual, niveles: renumerados } : actual))
    setErrorOrden('')
    setOperandoOrden(true)

    reordenarNiveles(
      tematicaId,
      renumerados.map((nivel) => nivel.id),
    )
      .catch((reordenarError: unknown) => {
        setDatos((actual) => (actual ? { ...actual, niveles: anterior } : actual))
        setErrorOrden(
          reordenarError instanceof Error
            ? reordenarError.message
            : 'No se ha podido reordenar el recorrido.',
        )
      })
      .finally(() => setOperandoOrden(false))
  }

  function handleMover(index: number, delta: number) {
    if (operandoOrden) return
    const destino = index + delta
    if (destino < 0 || destino >= niveles.length) return
    const reordenados = [...niveles]
    const [item] = reordenados.splice(index, 1)
    reordenados.splice(destino, 0, item)
    persistirOrden(reordenados)
  }

  function handleDrop(index: number) {
    if (dragIndex === null || dragIndex === index || operandoOrden) {
      setDragIndex(null)
      return
    }
    const reordenados = [...niveles]
    const [item] = reordenados.splice(dragIndex, 1)
    reordenados.splice(index, 0, item)
    persistirOrden(reordenados)
    setDragIndex(null)
  }

  async function handleConfirmarEliminar() {
    if (!nivelAEliminar || eliminando) return

    const nivelId = nivelAEliminar.id
    setEliminando(true)
    setErrorEliminar('')
    try {
      await eliminarNivel(tematicaId, nivelId)
      setDatos((actual) =>
        actual ? { ...actual, niveles: actual.niveles.filter((n) => n.id !== nivelId) } : actual,
      )
      setNivelAEliminar(null)
    } catch (eliminarError) {
      setErrorEliminar(
        eliminarError instanceof Error
          ? eliminarError.message
          : 'No se ha podido eliminar el nivel.',
      )
    } finally {
      setEliminando(false)
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <nav aria-label="Miga de pan" className="text-sm text-brand-night/50">
        <Link to="/tematicas" className="text-brand-blue hover:underline">
          Temáticas
        </Link>{' '}
        <span className="mx-1.5">›</span>{' '}
        <span className="font-semibold text-brand-night">{datos.tematicaNombre}</span>
      </nav>

      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-display text-3xl font-extrabold tracking-tight text-brand-night">
            Niveles de «{datos.tematicaNombre}»
          </h1>
          <p className="mt-1.5 text-sm text-brand-night/55">{subtitulo}</p>
        </div>
        <button
          type="button"
          onClick={abrirNuevo}
          className="flex items-center gap-2 rounded-xl px-6 py-4 font-display text-base font-extrabold text-white"
          style={BOTON_FONDO}
        >
          <span className="text-xl leading-none">+</span>Nuevo nivel
        </button>
      </div>

      <div className="overflow-hidden rounded-2xl border border-brand-border bg-white">
        {total === 0 ? (
          <EstadoVacio onCrear={abrirNuevo} />
        ) : (
          <>
            <div className="flex items-center gap-2.5 border-b border-brand-border bg-brand-base/60 px-4 py-2.5 text-xs text-brand-night/50">
              Arrastra por el asa para cambiar el orden del recorrido. Haz clic en un nivel para
              configurar su recorrido de preguntas.
            </div>
            {errorOrden && (
              <p className="border-b border-brand-base px-4 py-2.5 text-xs font-medium text-[#B3282D]">
                {errorOrden}
              </p>
            )}
            {niveles.map((nivel, index) => (
              <FilaNivel
                key={nivel.id}
                nivel={nivel}
                index={index}
                total={niveles.length}
                arrastrando={dragIndex === index}
                onDragStart={() => setDragIndex(index)}
                onDragOver={(e) => e.preventDefault()}
                onDrop={() => handleDrop(index)}
                onMover={(delta) => handleMover(index, delta)}
                onEliminarClick={() => {
                  setErrorEliminar('')
                  setNivelAEliminar(nivel)
                }}
              />
            ))}
            <div className="px-4 py-3.5 text-xs text-brand-night/45">
              El puntaje mínimo, los umbrales de estrellas y las preguntas de cada nivel se editan
              dentro de su recorrido.
            </div>
          </>
        )}
      </div>

      {modalNuevoAbierto && (
        <ModalNuevoNivel
          tematicaNombre={datos.tematicaNombre}
          posicion={formatearPosicion(niveles.length)}
          nombre={nombreNuevo}
          error={errorNuevo}
          guardando={creando}
          onCambiarNombre={setNombreNuevo}
          onGuardar={handleGuardarNuevo}
          onCancelar={cerrarNuevo}
        />
      )}

      {nivelAEliminar && (
        <ModalConfirmarEliminar
          nivel={nivelAEliminar}
          error={errorEliminar}
          eliminando={eliminando}
          onConfirmar={handleConfirmarEliminar}
          onCancelar={() => {
            if (eliminando) return
            setNivelAEliminar(null)
          }}
        />
      )}
    </div>
  )
}
