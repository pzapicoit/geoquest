import { useEffect, useMemo, useState, type ChangeEvent, type DragEvent } from 'react'
import {
  actualizarActivoTematica,
  eliminarTematica,
  fetchTematicas,
  guardarTematica,
  reordenarTematicas,
  validarImagenPortada,
  type Tematica,
} from '../lib/tematicas'

const BOTON_FONDO = {
  background: 'linear-gradient(140deg, #2BC0A8, #1B6FA8)',
}

const CAMPO_BASE =
  'h-11 rounded-xl border-[1.5px] border-brand-border bg-white px-3.5 text-sm text-brand-night outline-none placeholder:text-brand-night/40 focus:border-brand-teal focus:ring-4 focus:ring-brand-teal/15'
const CAMPO_ERROR = 'border-[#E0454A] bg-[#FFF8F8] focus:border-[#E0454A] focus:ring-[#E0454A]/15'

function useObjectUrl(file: File | null): string | null {
  const url = useMemo(() => (file ? URL.createObjectURL(file) : null), [file])

  useEffect(() => {
    return () => {
      if (url) URL.revokeObjectURL(url)
    }
  }, [url])

  return url
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

function IconoTematica() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M3 18l5.5-8 3.5 5 2.5-3.5L21 18z" />
      <circle cx="7.5" cy="7" r="2" />
    </svg>
  )
}

function IconoEditar() {
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
      <path d="M4 20h4L19.5 8.5a2 2 0 0 0 0-2.8l-1.2-1.2a2 2 0 0 0-2.8 0L4 16z" />
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

function Portada({ tematica }: { tematica: Tematica }) {
  const [rota, setRota] = useState(false)
  const mostrarImagen = Boolean(tematica.imagenPortada) && !rota

  return (
    <div className="flex h-10 w-14 flex-none items-center justify-center overflow-hidden rounded-lg bg-brand-blue/10 text-brand-blue">
      {mostrarImagen ? (
        <img
          src={tematica.imagenPortada}
          alt=""
          onError={() => setRota(true)}
          className="h-full w-full object-cover"
        />
      ) : (
        <IconoTematica />
      )}
    </div>
  )
}

function FilaTematica({
  tematica,
  index,
  total,
  error,
  eliminando,
  guardandoActivo,
  arrastrando,
  onDragStart,
  onDragOver,
  onDrop,
  onMover,
  onEditar,
  onEliminar,
  onCambiarActivo,
}: {
  tematica: Tematica
  index: number
  total: number
  error?: string
  eliminando: boolean
  guardandoActivo: boolean
  arrastrando: boolean
  onDragStart: () => void
  onDragOver: (e: DragEvent<HTMLTableRowElement>) => void
  onDrop: () => void
  onMover: (delta: number) => void
  onEditar: () => void
  onEliminar: () => void
  onCambiarActivo: (activo: boolean) => void
}) {
  return (
    <tr
      draggable
      onDragStart={onDragStart}
      onDragOver={onDragOver}
      onDrop={onDrop}
      className={`border-b border-brand-base last:border-0 hover:bg-brand-base/40 ${arrastrando ? 'opacity-40' : ''}`}
    >
      <td className="w-10 px-3 py-3 text-center text-brand-night/30" aria-hidden="true">
        <IconoAsa />
      </td>
      <td className="px-2 py-3 text-sm font-semibold text-brand-night/50 tabular-nums">
        {index + 1}
      </td>
      <td className="px-3 py-3">
        <div className="flex items-center gap-3">
          <Portada tematica={tematica} />
          <div className="min-w-0">
            <span className="block truncate text-sm font-semibold text-brand-night">
              {tematica.nombre}
            </span>
          </div>
        </div>
      </td>
      <td className="px-3 py-3">
        <span className="inline-flex items-center rounded-lg bg-brand-base px-2.5 py-1 text-xs font-semibold text-brand-night/60 tabular-nums">
          {tematica.cantidadParadas} {tematica.cantidadParadas === 1 ? 'parada' : 'paradas'}
        </span>
      </td>
      <td className="px-3 py-3">
        <label className="flex cursor-pointer items-center gap-2">
          <input
            type="checkbox"
            aria-label={`Cambiar estado de "${tematica.nombre}"`}
            checked={tematica.activo}
            disabled={guardandoActivo}
            onChange={(e) => onCambiarActivo(e.target.checked)}
            className="peer sr-only"
          />
          <span className="relative h-5 w-9 flex-none rounded-full bg-brand-border transition-colors peer-checked:bg-brand-success peer-disabled:opacity-60">
            <span className="absolute top-0.5 left-0.5 h-4 w-4 rounded-full bg-white shadow transition-transform peer-checked:translate-x-4" />
          </span>
          <span
            className={`text-xs font-semibold ${tematica.activo ? 'text-brand-success' : 'text-brand-night/45'}`}
          >
            {tematica.activo ? 'Activa' : 'Inactiva'}
          </span>
        </label>
      </td>
      <td className="px-3 py-3">
        <div className="flex items-center justify-end gap-1.5">
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
          <button
            type="button"
            onClick={onEditar}
            aria-label="Editar temática"
            title="Editar temática"
            className="flex h-8 w-8 items-center justify-center rounded-lg border-[1.5px] border-brand-border text-brand-night/60 hover:border-brand-blue hover:text-brand-blue"
          >
            <IconoEditar />
          </button>
          <button
            type="button"
            onClick={onEliminar}
            disabled={eliminando}
            aria-label="Eliminar temática"
            title="Eliminar temática"
            className="flex h-8 w-8 items-center justify-center rounded-lg border-[1.5px] border-brand-border text-brand-night/60 hover:border-brand-error hover:text-brand-error disabled:cursor-not-allowed disabled:opacity-40"
          >
            <IconoEliminar />
          </button>
        </div>
        {error && <p className="mt-1.5 text-right text-[11px] text-[#B3282D]">{error}</p>}
      </td>
    </tr>
  )
}

function EstadoVacio({ onCrear }: { onCrear: () => void }) {
  return (
    <div className="flex flex-col items-center gap-2 px-6 py-16 text-center">
      <div className="mb-3 flex h-[78px] w-[78px] items-center justify-center rounded-[22px] bg-brand-teal/10 text-brand-blue">
        <IconoTematica />
      </div>
      <h4 className="font-display text-xl font-extrabold text-brand-night">Aún no hay temáticas</h4>
      <p className="max-w-md text-sm text-brand-night/55">
        Las temáticas son los mundos del juego: agrupan preguntas que el camino resuelve por
        dificultad. Crea la primera para empezar.
      </p>
      <button
        type="button"
        onClick={onCrear}
        className="mt-3 flex items-center gap-2 rounded-xl px-4 py-2.5 font-display text-sm font-extrabold text-white"
        style={BOTON_FONDO}
      >
        <span className="text-base leading-none">+</span>Crear la primera temática
      </button>
    </div>
  )
}

function CampoPortada({
  previewUrl,
  error,
  onChange,
}: {
  previewUrl: string | null
  error?: string
  onChange: (file: File) => void
}) {
  return (
    <div className="flex flex-col gap-2">
      <span className="text-sm font-semibold text-brand-night">
        Imagen de portada <span className="text-[#E0454A]">*</span>
      </span>
      <div className="grid grid-cols-1 items-stretch gap-4 sm:grid-cols-[1fr_132px]">
        <label className="flex cursor-pointer flex-col items-center justify-center gap-1.5 rounded-xl border-[1.5px] border-dashed border-[#CFDDE3] bg-[#F8FBFC] p-5 text-center hover:border-brand-teal hover:bg-brand-teal/5">
          <span className="text-sm font-semibold text-brand-night">
            Arrastra o <span className="text-brand-blue underline">busca el archivo</span>
          </span>
          <span className="text-xs text-brand-night/45">JPG o PNG · hasta 4 MB</span>
          <input
            type="file"
            accept="image/jpeg,image/png"
            className="sr-only"
            onChange={(e: ChangeEvent<HTMLInputElement>) => {
              const file = e.target.files?.[0]
              e.target.value = ''
              if (file) onChange(file)
            }}
          />
        </label>
        <div className="flex flex-col overflow-hidden rounded-xl border border-brand-border">
          <div className="flex min-h-[84px] flex-1 items-center justify-center bg-brand-blue/5">
            {previewUrl ? (
              <img src={previewUrl} alt="" className="h-full w-full object-cover" />
            ) : (
              <span className="text-xs font-medium text-brand-night/45">Sin imagen todavía</span>
            )}
          </div>
          <div className="border-t border-brand-border px-3 py-2 text-[11px] font-semibold tracking-wider text-brand-night/40 uppercase">
            Previsual.
          </div>
        </div>
      </div>
      <ErrorCampo mensaje={error} />
    </div>
  )
}

interface FormState {
  id: string | null
  nombre: string
  activo: boolean
  archivo: File | null
  imagenPortadaActual: string | null
  promptImagen: string
}

const FORM_VACIO: FormState = {
  id: null,
  nombre: '',
  activo: true,
  archivo: null,
  imagenPortadaActual: null,
  promptImagen: '',
}

function PanelTematica({
  form,
  errores,
  errorGuardado,
  guardando,
  onCambiar,
  onArchivoSeleccionado,
  onGuardar,
  onCancelar,
}: {
  form: FormState
  errores: Record<string, string>
  errorGuardado: string
  guardando: boolean
  onCambiar: (form: FormState) => void
  onArchivoSeleccionado: (file: File) => void
  onGuardar: () => void
  onCancelar: () => void
}) {
  const previewPortada = useObjectUrl(form.archivo) ?? form.imagenPortadaActual

  return (
    <div onClick={onCancelar} className="fixed inset-0 z-20 flex justify-end bg-brand-night/40">
      <div
        onClick={(e) => e.stopPropagation()}
        className="flex h-full w-full max-w-[460px] flex-col bg-white"
      >
        <div className="border-b border-brand-border px-6 py-5">
          <div className="text-[10.5px] font-semibold tracking-[0.14em] text-brand-night/40 uppercase">
            {form.id ? 'Editar temática' : 'Nueva temática'}
          </div>
          <h3 className="mt-2.5 font-display text-2xl font-extrabold text-brand-night">
            {form.id ? form.nombre : 'Nueva temática'}
          </h3>
        </div>

        <div className="flex flex-1 flex-col gap-5.5 overflow-auto px-6 py-5.5">
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-semibold text-brand-night">
              Nombre <span className="text-[#E0454A]">*</span>
            </span>
            <input
              type="text"
              value={form.nombre}
              onChange={(e) => onCambiar({ ...form, nombre: e.target.value })}
              placeholder="Ej. Paisajes de Europa"
              className={`${CAMPO_BASE} ${errores.nombre ? CAMPO_ERROR : ''}`}
            />
            <span className="text-xs text-brand-night/45">
              Se muestra como título del mundo en el mapa del jugador.
            </span>
            <ErrorCampo mensaje={errores.nombre} />
          </label>

          <CampoPortada
            previewUrl={previewPortada}
            error={errores.portada}
            onChange={onArchivoSeleccionado}
          />

          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-semibold text-brand-night">
              Prompt de imagen <span className="font-medium text-brand-night/40">· opcional</span>
            </span>
            <textarea
              rows={3}
              value={form.promptImagen}
              onChange={(e) => onCambiar({ ...form, promptImagen: e.target.value })}
              placeholder="Ej. la ilustración es la bandera del país sobre fondo neutro, sin escena alrededor."
              className={`${CAMPO_BASE} resize-y`}
            />
            <span className="text-xs text-brand-night/45">
              Se aplica a todas las imágenes que la IA genere para esta temática. Describe cómo debe
              verse la ilustración, no qué lugares proponer: eso lo deduce la IA de las preguntas
              que ya tiene la temática.
            </span>
          </label>

          <label className="flex cursor-pointer items-center gap-3.5 border-t border-brand-base pt-5">
            <input
              type="checkbox"
              aria-label="Cambiar estado de la temática"
              checked={form.activo}
              onChange={(e) => onCambiar({ ...form, activo: e.target.checked })}
              className="peer sr-only"
            />
            <span className="relative h-[26px] w-11 flex-none rounded-full bg-brand-border transition-colors peer-checked:bg-brand-teal">
              <span className="absolute top-[3px] left-[3px] h-5 w-5 rounded-full bg-white shadow transition-transform peer-checked:translate-x-[18px]" />
            </span>
            <span>
              <span className="block text-sm font-semibold text-brand-night">
                {form.activo ? 'Activa' : 'Inactiva'}
              </span>
              <span className="mt-1 block text-xs text-brand-night/45">
                {form.activo
                  ? 'Visible en el mapa del jugador.'
                  : 'Oculta para los jugadores; puedes seguir editando sus preguntas.'}
              </span>
            </span>
          </label>
        </div>

        <div className="flex items-center gap-2.5 border-t border-brand-border bg-brand-base/60 px-6 py-4">
          {errorGuardado && (
            <span className="text-xs font-medium text-[#B3282D]">{errorGuardado}</span>
          )}
          <button
            type="button"
            onClick={onCancelar}
            className="rounded-xl border-[1.5px] border-[#CFDDE3] bg-white px-4.5 py-3 text-sm font-semibold text-brand-night/70 hover:border-brand-error hover:text-brand-error"
          >
            Cancelar
          </button>
          <button
            type="button"
            onClick={onGuardar}
            disabled={guardando}
            className="ml-auto rounded-xl px-5 py-3.5 font-display text-sm font-extrabold text-white disabled:cursor-not-allowed disabled:opacity-60"
            style={BOTON_FONDO}
          >
            {guardando ? 'Guardando…' : 'Guardar'}
          </button>
        </div>
      </div>
    </div>
  )
}

export function Tematicas() {
  const [tematicas, setTematicas] = useState<Tematica[] | null>(null)
  const [error, setError] = useState('')
  const [rowErrors, setRowErrors] = useState<Record<string, string>>({})
  const [eliminandoIds, setEliminandoIds] = useState<Set<string>>(new Set())
  const [guardandoActivoIds, setGuardandoActivoIds] = useState<Set<string>>(new Set())
  const [errorOrden, setErrorOrden] = useState('')
  const [operandoOrden, setOperandoOrden] = useState(false)
  const [dragIndex, setDragIndex] = useState<number | null>(null)

  const [panelAbierto, setPanelAbierto] = useState(false)
  const [form, setForm] = useState<FormState>(FORM_VACIO)
  const [formErrores, setFormErrores] = useState<Record<string, string>>({})
  const [errorGuardado, setErrorGuardado] = useState('')
  const [guardando, setGuardando] = useState(false)

  function cargar() {
    fetchTematicas()
      .then((resultado) => setTematicas(resultado))
      .catch((cargaError: unknown) => {
        console.error('Error cargando el listado de temáticas:', cargaError)
        setError('No se ha podido cargar el listado de temáticas.')
      })
  }

  useEffect(() => {
    cargar()
  }, [])

  if (error) {
    return (
      <div className="rounded-2xl border border-brand-error/40 bg-brand-error/10 p-5 text-sm text-[#B3282D]">
        {error}
      </div>
    )
  }

  const lista = tematicas ?? []
  const total = lista.length
  const activas = lista.filter((t) => t.activo).length

  function abrirNueva() {
    setForm(FORM_VACIO)
    setFormErrores({})
    setErrorGuardado('')
    setPanelAbierto(true)
  }

  function abrirEditar(tematica: Tematica) {
    setForm({
      id: tematica.id,
      nombre: tematica.nombre,
      activo: tematica.activo,
      archivo: null,
      imagenPortadaActual: tematica.imagenPortada,
      promptImagen: tematica.promptImagen ?? '',
    })
    setFormErrores({})
    setErrorGuardado('')
    setPanelAbierto(true)
  }

  function cerrarPanel() {
    if (guardando) return
    setPanelAbierto(false)
  }

  function validarForm(): Record<string, string> {
    const erroresLocal: Record<string, string> = {}

    if (!form.nombre.trim()) {
      erroresLocal.nombre = 'El nombre es obligatorio.'
    }
    if (!form.archivo && !form.imagenPortadaActual) {
      erroresLocal.portada = 'Selecciona una imagen de portada.'
    }

    return erroresLocal
  }

  async function handleGuardar() {
    if (guardando) return

    const erroresValidacion = validarForm()
    if (Object.keys(erroresValidacion).length > 0) {
      setFormErrores(erroresValidacion)
      return
    }

    setFormErrores({})
    setErrorGuardado('')
    setGuardando(true)

    try {
      await guardarTematica({
        id: form.id,
        nombre: form.nombre.trim(),
        activo: form.activo,
        archivo: form.archivo,
        imagenPortadaActual: form.imagenPortadaActual,
        promptImagen: form.promptImagen,
      })
      setPanelAbierto(false)
      cargar()
    } catch (guardarError) {
      setErrorGuardado(
        guardarError instanceof Error
          ? guardarError.message
          : 'No se ha podido guardar la temática.',
      )
    } finally {
      setGuardando(false)
    }
  }

  async function handleCambiarActivo(tematica: Tematica, activo: boolean) {
    if (guardandoActivoIds.has(tematica.id)) return
    const anterior = tematica.activo

    setGuardandoActivoIds((actual) => new Set(actual).add(tematica.id))
    setTematicas(
      (actual) => actual?.map((t) => (t.id === tematica.id ? { ...t, activo } : t)) ?? actual,
    )

    try {
      await actualizarActivoTematica(tematica.id, activo)
      setRowErrors((actual) => {
        if (!(tematica.id in actual)) return actual
        const resto = { ...actual }
        delete resto[tematica.id]
        return resto
      })
    } catch (error) {
      setTematicas(
        (actual) =>
          actual?.map((t) => (t.id === tematica.id ? { ...t, activo: anterior } : t)) ?? actual,
      )
      setRowErrors((actual) => ({
        ...actual,
        [tematica.id]:
          error instanceof Error ? error.message : 'No se ha podido guardar el estado.',
      }))
    } finally {
      setGuardandoActivoIds((actual) => {
        const siguiente = new Set(actual)
        siguiente.delete(tematica.id)
        return siguiente
      })
    }
  }

  async function handleEliminar(tematica: Tematica) {
    if (eliminandoIds.has(tematica.id)) return

    const confirmado = window.confirm(
      `¿Eliminar "${tematica.nombre}"? Se eliminarán también sus ${tematica.cantidadParadas} ${
        tematica.cantidadParadas === 1 ? 'parada' : 'paradas'
      } en el camino y el progreso de los jugadores en ellas. El banco de preguntas no se ve afectado, pero si la temática tiene preguntas propias el borrado se rechazará hasta que las borres o reasignes.`,
    )
    if (!confirmado) return

    setEliminandoIds((actual) => new Set(actual).add(tematica.id))

    try {
      await eliminarTematica(tematica.id)
      setTematicas((actual) => actual?.filter((t) => t.id !== tematica.id) ?? actual)
      setRowErrors((actual) => {
        if (!(tematica.id in actual)) return actual
        const resto = { ...actual }
        delete resto[tematica.id]
        return resto
      })
    } catch (eliminarError) {
      setRowErrors((actual) => ({
        ...actual,
        [tematica.id]:
          eliminarError instanceof Error
            ? eliminarError.message
            : 'No se ha podido eliminar la temática.',
      }))
    } finally {
      setEliminandoIds((actual) => {
        const siguiente = new Set(actual)
        siguiente.delete(tematica.id)
        return siguiente
      })
    }
  }

  function persistirOrden(nuevoOrden: Tematica[]) {
    if (operandoOrden) return

    const anterior = lista
    const renumeradas = nuevoOrden.map((t, i) => ({ ...t, orden: i + 1 }))
    setTematicas(renumeradas)
    setErrorOrden('')
    setOperandoOrden(true)

    reordenarTematicas(renumeradas.map((t) => t.id))
      .catch((reordenarError: unknown) => {
        setTematicas(anterior)
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
    if (destino < 0 || destino >= lista.length) return
    const reordenadas = [...lista]
    const [item] = reordenadas.splice(index, 1)
    reordenadas.splice(destino, 0, item)
    persistirOrden(reordenadas)
  }

  function handleDrop(index: number) {
    if (dragIndex === null || dragIndex === index || operandoOrden) {
      setDragIndex(null)
      return
    }
    const reordenadas = [...lista]
    const [item] = reordenadas.splice(dragIndex, 1)
    reordenadas.splice(index, 0, item)
    persistirOrden(reordenadas)
    setDragIndex(null)
  }

  function handleArchivoPortada(archivo: File) {
    const errorArchivo = validarImagenPortada(archivo)
    if (errorArchivo) {
      setFormErrores((actual) => ({ ...actual, portada: errorArchivo }))
      return
    }
    setFormErrores((actual) => {
      if (!('portada' in actual)) return actual
      const resto = { ...actual }
      delete resto.portada
      return resto
    })
    setForm((actual) => ({ ...actual, archivo }))
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-display text-3xl font-extrabold tracking-tight text-brand-night">
            Temáticas
          </h1>
          <p className="mt-1.5 text-sm text-brand-night/55">
            {total === 0
              ? 'Ninguna temática creada todavía'
              : `${total} ${total === 1 ? 'temática' : 'temáticas'} · ${activas} activas · el orden define la progresión del jugador`}
          </p>
        </div>
        <button
          type="button"
          onClick={abrirNueva}
          className="flex items-center gap-2 rounded-xl px-6 py-4 font-display text-base font-extrabold text-white"
          style={BOTON_FONDO}
        >
          <span className="text-xl leading-none">+</span>Nueva temática
        </button>
      </div>

      <div className="overflow-hidden rounded-2xl border border-brand-border bg-white">
        {tematicas !== null && total === 0 ? (
          <EstadoVacio onCrear={abrirNueva} />
        ) : (
          <>
            {errorOrden && (
              <p className="border-b border-brand-base px-5 py-2.5 text-xs font-medium text-[#B3282D]">
                {errorOrden}
              </p>
            )}
            <table className="w-full border-collapse text-left">
              <thead>
                <tr className="border-b border-brand-border bg-brand-base/60 text-[11px] font-semibold tracking-wider text-brand-night/45 uppercase">
                  <th className="w-10 px-3 py-3" aria-hidden="true" />
                  <th className="px-2 py-3 font-semibold">#</th>
                  <th className="px-3 py-3 font-semibold">Temática</th>
                  <th className="px-3 py-3 font-semibold">Paradas en el camino</th>
                  <th className="px-3 py-3 font-semibold">Estado</th>
                  <th className="px-3 py-3 text-right font-semibold">Acciones</th>
                </tr>
              </thead>
              <tbody>
                {lista.map((tematica, index) => (
                  <FilaTematica
                    key={tematica.id}
                    tematica={tematica}
                    index={index}
                    total={lista.length}
                    error={rowErrors[tematica.id]}
                    eliminando={eliminandoIds.has(tematica.id)}
                    guardandoActivo={guardandoActivoIds.has(tematica.id)}
                    arrastrando={dragIndex === index}
                    onDragStart={() => setDragIndex(index)}
                    onDragOver={(e) => e.preventDefault()}
                    onDrop={() => handleDrop(index)}
                    onMover={(delta) => handleMover(index, delta)}
                    onEditar={() => abrirEditar(tematica)}
                    onEliminar={() => handleEliminar(tematica)}
                    onCambiarActivo={(activo) => handleCambiarActivo(tematica, activo)}
                  />
                ))}
              </tbody>
            </table>
          </>
        )}
      </div>

      {panelAbierto && (
        <PanelTematica
          form={form}
          errores={formErrores}
          errorGuardado={errorGuardado}
          guardando={guardando}
          onCambiar={setForm}
          onArchivoSeleccionado={handleArchivoPortada}
          onGuardar={handleGuardar}
          onCancelar={cerrarPanel}
        />
      )}
    </div>
  )
}
