import { useEffect, useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import {
  actualizarActivoPregunta,
  actualizarDificultadPregunta,
  eliminarPregunta,
  fetchPreguntas,
  type Pregunta,
  type TipoDesafio,
} from '../lib/preguntas'
import { DIFICULTADES, type Dificultad } from '../lib/dificultad'

const PAGE_SIZE = 10
const TODAS_TEMATICAS = 'Todas las temáticas'
const FILTROS_STORAGE_KEY = 'panel:preguntas:filtros'

type FiltroTipo = 'todos' | TipoDesafio
type FiltroEstado = 'todos' | 'activo' | 'inactivo'
type FiltroDificultad = 'todas' | Dificultad

const TIPO_LABEL: Record<TipoDesafio, string> = {
  imagen: 'Imagen',
  video: 'Vídeo',
  pregunta_texto: 'Pregunta de texto',
}

const TIPO_BADGE: Record<TipoDesafio, string> = {
  imagen: 'bg-brand-blue/10 text-brand-blue',
  video: 'bg-brand-special/10 text-brand-special',
  pregunta_texto: 'bg-brand-gold/25 text-[#996100]',
}

const DIFICULTAD_BADGE: Record<Dificultad, string> = {
  facil: 'bg-brand-teal/10 text-brand-teal',
  normal: 'bg-brand-blue/10 text-brand-blue',
  intermedio: 'bg-brand-gold/25 text-[#996100]',
  dificil: 'bg-brand-special/10 text-brand-special',
  muy_dificil: 'bg-[#E0454A]/10 text-[#B3282D]',
}

// Mismos colores que las badges de la tabla, para que el filtro activo se
// reconozca de un vistazo con la fila que produce.
const DIFICULTAD_CHIP_ACTIVA: Record<Dificultad, string> = {
  facil: 'border-brand-teal bg-brand-teal/10 text-brand-teal',
  normal: 'border-brand-blue bg-brand-blue/10 text-brand-blue',
  intermedio: 'border-brand-gold bg-brand-gold/25 text-[#996100]',
  dificil: 'border-brand-special bg-brand-special/10 text-brand-special',
  muy_dificil: 'border-[#E0454A] bg-[#E0454A]/10 text-[#B3282D]',
}

const TIPO_CHIP_ACTIVA: Record<TipoDesafio, string> = {
  imagen: 'border-brand-blue bg-brand-blue/10 text-brand-blue',
  video: 'border-brand-special bg-brand-special/10 text-brand-special',
  pregunta_texto: 'border-brand-gold bg-brand-gold/25 text-[#996100]',
}

const ESTADO_CHIP_ACTIVA: Record<'activo' | 'inactivo', string> = {
  activo: 'border-brand-success bg-brand-success/10 text-brand-success',
  inactivo: 'border-brand-night/35 bg-brand-night/5 text-brand-night/70',
}

const CHIP_TODOS_ACTIVA = 'border-brand-night/70 bg-brand-base text-brand-night'

const BOTON_FONDO = {
  background: 'linear-gradient(140deg, #2BC0A8, #1B6FA8)',
}

const BOTON_IA_FONDO = {
  background: 'linear-gradient(140deg, #7C5CFF, #5B3FD1)',
}

function IconoTipo({ tipo, size = 18 }: { tipo: TipoDesafio; size?: number }) {
  if (tipo === 'imagen') {
    return (
      <svg
        width={size}
        height={size}
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <rect x="3" y="5" width="18" height="14" rx="2.5" />
        <path d="M3 16l5-4.5 4 3.5 3-2.5 6 5" />
        <circle cx="15.5" cy="9.5" r="1.4" />
      </svg>
    )
  }
  if (tipo === 'video') {
    return (
      <svg
        width={size}
        height={size}
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <rect x="2.5" y="5.5" width="13" height="13" rx="2.5" />
        <path d="M15.5 11l5-3v8l-5-3z" />
      </svg>
    )
  }
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M5 6h14M5 11h14M5 16h8" />
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

function Miniatura({ pregunta }: { pregunta: Pregunta }) {
  const [rota, setRota] = useState(false)
  const mostrarImagen = pregunta.tipo === 'imagen' && pregunta.imagenUrl && !rota

  return (
    <div
      className={`flex h-10 w-14 flex-none items-center justify-center overflow-hidden rounded-lg ${TIPO_BADGE[pregunta.tipo]}`}
    >
      {mostrarImagen ? (
        <img
          src={pregunta.imagenUrl ?? undefined}
          alt=""
          onError={() => setRota(true)}
          className="h-full w-full object-cover"
        />
      ) : (
        <IconoTipo tipo={pregunta.tipo} />
      )}
    </div>
  )
}

function FilaPregunta({
  pregunta,
  error,
  eliminando,
  guardandoDificultad,
  guardandoActivo,
  onEliminar,
  onCambiarDificultad,
  onCambiarActivo,
}: {
  pregunta: Pregunta
  error?: string
  eliminando: boolean
  guardandoDificultad: boolean
  guardandoActivo: boolean
  onEliminar: () => void
  onCambiarDificultad: (dificultad: Dificultad) => void
  onCambiarActivo: (activo: boolean) => void
}) {
  return (
    <tr className="border-b border-brand-base last:border-0 hover:bg-brand-base/40">
      <td className="px-5 py-3">
        <div className="flex items-center gap-3">
          <Miniatura pregunta={pregunta} />
          <div className="min-w-0">
            <div className="truncate text-sm font-semibold text-brand-night">{pregunta.nombre}</div>
            {pregunta.tipo === 'pregunta_texto' && pregunta.textoPregunta && (
              <div className="truncate text-xs text-brand-night/50">{pregunta.textoPregunta}</div>
            )}
          </div>
        </div>
      </td>
      <td className="px-5 py-3">
        <span className="text-sm text-brand-night/70">{pregunta.tematicaNombre}</span>
      </td>
      <td className="px-5 py-3">
        <span
          className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ${TIPO_BADGE[pregunta.tipo]}`}
        >
          {TIPO_LABEL[pregunta.tipo]}
        </span>
      </td>
      <td className="px-5 py-3">
        <select
          aria-label={`Dificultad de "${pregunta.nombre}"`}
          value={pregunta.dificultad}
          disabled={guardandoDificultad}
          onChange={(e) => onCambiarDificultad(e.target.value as Dificultad)}
          className={`rounded-full border-0 px-2.5 py-1 text-xs font-semibold outline-none disabled:cursor-not-allowed disabled:opacity-60 ${DIFICULTAD_BADGE[pregunta.dificultad]}`}
        >
          {DIFICULTADES.map((d) => (
            <option key={d.valor} value={d.valor}>
              {d.label}
            </option>
          ))}
        </select>
      </td>
      <td className="px-5 py-3">
        <label className="flex cursor-pointer items-center gap-2">
          <input
            type="checkbox"
            aria-label={`Cambiar estado de "${pregunta.nombre}"`}
            checked={pregunta.activo}
            disabled={guardandoActivo}
            onChange={(e) => onCambiarActivo(e.target.checked)}
            className="peer sr-only"
          />
          <span className="relative h-5 w-9 flex-none rounded-full bg-brand-border transition-colors peer-checked:bg-brand-success peer-disabled:opacity-60">
            <span className="absolute top-0.5 left-0.5 h-4 w-4 rounded-full bg-white shadow transition-transform peer-checked:translate-x-4" />
          </span>
          <span
            className={`text-xs font-semibold ${pregunta.activo ? 'text-brand-success' : 'text-brand-night/45'}`}
          >
            {pregunta.activo ? 'Activo' : 'Inactivo'}
          </span>
        </label>
      </td>
      <td className="px-5 py-3">
        <div className="flex justify-end gap-2">
          <Link
            to={`/preguntas/${pregunta.id}/editar`}
            aria-label="Editar"
            title="Editar"
            className="flex h-8 w-8 items-center justify-center rounded-lg border-[1.5px] border-brand-border text-brand-night/60 hover:border-brand-blue hover:text-brand-blue"
          >
            <IconoEditar />
          </Link>
          <button
            type="button"
            onClick={onEliminar}
            disabled={eliminando}
            title="Eliminar"
            className="flex h-8 w-8 items-center justify-center rounded-lg border-[1.5px] border-brand-border text-brand-night/60 hover:border-brand-error hover:text-brand-error disabled:cursor-not-allowed disabled:opacity-40"
          >
            <IconoEliminar />
          </button>
        </div>
        {error && (
          <p className="mt-1.5 max-w-[220px] text-right text-[11px] text-[#B3282D]">{error}</p>
        )}
      </td>
    </tr>
  )
}

function Paginacion({
  total,
  inicio,
  cantidad,
  pagina,
  pageCount,
  onCambiarPagina,
}: {
  total: number
  inicio: number
  cantidad: number
  pagina: number
  pageCount: number
  onCambiarPagina: (pagina: number) => void
}) {
  return (
    <div className="flex flex-wrap items-center gap-3.5 p-4">
      <span className="text-xs text-brand-night/50">
        Mostrando {cantidad === 0 ? 0 : inicio + 1}–{inicio + cantidad} de {total}
      </span>
      <div className="ml-auto flex items-center gap-1.5">
        <button
          type="button"
          disabled={pagina <= 1}
          onClick={() => onCambiarPagina(Math.max(1, pagina - 1))}
          className="h-8 rounded-lg border-[1.5px] border-brand-border px-3 text-xs font-semibold text-brand-night/70 disabled:cursor-not-allowed disabled:opacity-40"
        >
          Anterior
        </button>
        {Array.from({ length: pageCount }, (_, i) => i + 1).map((p) => (
          <button
            key={p}
            type="button"
            onClick={() => onCambiarPagina(p)}
            aria-current={p === pagina ? 'page' : undefined}
            className={`h-8 min-w-8 rounded-lg border-[1.5px] px-2 text-xs font-semibold ${
              p === pagina
                ? 'border-brand-blue bg-brand-blue text-white'
                : 'border-brand-border text-brand-night/70'
            }`}
          >
            {p}
          </button>
        ))}
        <button
          type="button"
          disabled={pagina >= pageCount}
          onClick={() => onCambiarPagina(Math.min(pageCount, pagina + 1))}
          className="h-8 rounded-lg border-[1.5px] border-brand-border px-3 text-xs font-semibold text-brand-night/70 disabled:cursor-not-allowed disabled:opacity-40"
        >
          Siguiente
        </button>
      </div>
    </div>
  )
}

function EstadoVacioFiltros({ onLimpiar }: { onLimpiar: () => void }) {
  return (
    <div className="flex flex-col items-center gap-2 px-6 py-16 text-center">
      <h4 className="font-display text-xl font-extrabold text-brand-night">
        Ninguna pregunta coincide
      </h4>
      <p className="max-w-md text-sm text-brand-night/55">
        Prueba a quitar algún filtro o a buscar solo por el nombre.
      </p>
      <button
        type="button"
        onClick={onLimpiar}
        className="mt-3 rounded-xl border-[1.5px] border-brand-border px-4 py-2.5 text-sm font-semibold text-brand-blue"
      >
        Limpiar filtros
      </button>
    </div>
  )
}

function EstadoVacioBanco() {
  return (
    <div className="flex flex-col items-center gap-2 px-6 py-16 text-center">
      <h4 className="font-display text-xl font-extrabold text-brand-night">
        Todavía no hay preguntas
      </h4>
      <p className="max-w-md text-sm text-brand-night/55">
        Crea la primera pregunta del banco para empezar a construir el camino.
      </p>
      <Link
        to="/preguntas/nueva"
        className="mt-3 flex items-center gap-2 rounded-xl px-4 py-2.5 font-display text-sm font-extrabold text-white"
        style={BOTON_FONDO}
      >
        <span className="text-base leading-none">+</span>Crear la primera pregunta
      </Link>
    </div>
  )
}

function ChipFiltro({
  activo,
  claseActiva,
  onClick,
  children,
}: {
  activo: boolean
  claseActiva: string
  onClick: () => void
  children: ReactNode
}) {
  return (
    <button
      type="button"
      aria-pressed={activo}
      onClick={onClick}
      className={`inline-flex items-center gap-1.5 rounded-full border-[1.5px] px-3 py-1.5 text-xs font-semibold whitespace-nowrap transition-colors ${
        activo ? claseActiva : 'border-brand-border text-brand-night/55 hover:border-brand-night/30'
      }`}
    >
      {children}
    </button>
  )
}

type FiltrosGuardados = {
  query?: string
  topic?: string
  dificultad?: FiltroDificultad
  tipo?: FiltroTipo
  estado?: FiltroEstado
}

function leerFiltrosGuardados(): FiltrosGuardados {
  try {
    const raw = sessionStorage.getItem(FILTROS_STORAGE_KEY)
    return raw ? (JSON.parse(raw) as FiltrosGuardados) : {}
  } catch {
    return {}
  }
}

export function Preguntas() {
  const [preguntas, setPreguntas] = useState<Pregunta[] | null>(null)
  const [error, setError] = useState('')
  const [rowErrors, setRowErrors] = useState<Record<string, string>>({})
  const [eliminandoIds, setEliminandoIds] = useState<Set<string>>(new Set())
  const [guardandoCampos, setGuardandoCampos] = useState<Set<string>>(new Set())

  const filtrosGuardados = leerFiltrosGuardados()
  const [query, setQuery] = useState(filtrosGuardados.query ?? '')
  const [topic, setTopic] = useState(filtrosGuardados.topic ?? TODAS_TEMATICAS)
  const [dificultad, setDificultad] = useState<FiltroDificultad>(
    filtrosGuardados.dificultad ?? 'todas',
  )
  const [tipo, setTipo] = useState<FiltroTipo>(filtrosGuardados.tipo ?? 'todos')
  const [estado, setEstado] = useState<FiltroEstado>(filtrosGuardados.estado ?? 'todos')
  const [page, setPage] = useState(1)

  // Recuerda el último filtro aplicado (p.ej. al volver de "Nueva pregunta").
  useEffect(() => {
    try {
      sessionStorage.setItem(
        FILTROS_STORAGE_KEY,
        JSON.stringify({ query, topic, dificultad, tipo, estado }),
      )
    } catch {
      // sessionStorage puede no estar disponible (modo privado); no persistir en ese caso.
    }
  }, [query, topic, dificultad, tipo, estado])

  useEffect(() => {
    let isMounted = true

    fetchPreguntas()
      .then((resultado) => {
        if (!isMounted) return
        setPreguntas(resultado)
      })
      .catch((cargaError: unknown) => {
        if (!isMounted) return
        console.error('Error cargando el listado de preguntas:', cargaError)
        setError('No se ha podido cargar el listado de preguntas.')
      })

    return () => {
      isMounted = false
    }
  }, [])

  if (error) {
    return (
      <div className="rounded-2xl border border-brand-error/40 bg-brand-error/10 p-5 text-sm text-[#B3282D]">
        {error}
      </div>
    )
  }

  async function handleEliminar(pregunta: Pregunta) {
    if (eliminandoIds.has(pregunta.id)) return

    const confirmado = window.confirm(
      `¿Eliminar "${pregunta.nombre}"? Esta acción no se puede deshacer.`,
    )
    if (!confirmado) return

    setEliminandoIds((actual) => new Set(actual).add(pregunta.id))

    try {
      await eliminarPregunta(pregunta.id)
      setPreguntas((actual) => actual?.filter((p) => p.id !== pregunta.id) ?? actual)
      setRowErrors((actual) => {
        if (!(pregunta.id in actual)) return actual
        const resto = { ...actual }
        delete resto[pregunta.id]
        return resto
      })
    } catch (eliminarError) {
      setRowErrors((actual) => ({
        ...actual,
        [pregunta.id]:
          eliminarError instanceof Error
            ? eliminarError.message
            : 'No se ha podido eliminar la pregunta.',
      }))
    } finally {
      setEliminandoIds((actual) => {
        const siguiente = new Set(actual)
        siguiente.delete(pregunta.id)
        return siguiente
      })
    }
  }

  async function handleCambiarDificultad(pregunta: Pregunta, dificultad: Dificultad) {
    const clave = `${pregunta.id}:dificultad`
    if (guardandoCampos.has(clave)) return
    const anterior = pregunta.dificultad

    setGuardandoCampos((actual) => new Set(actual).add(clave))
    setPreguntas(
      (actual) => actual?.map((p) => (p.id === pregunta.id ? { ...p, dificultad } : p)) ?? actual,
    )

    try {
      await actualizarDificultadPregunta(pregunta.id, dificultad)
      setRowErrors((actual) => {
        if (!(pregunta.id in actual)) return actual
        const resto = { ...actual }
        delete resto[pregunta.id]
        return resto
      })
    } catch (error) {
      setPreguntas(
        (actual) =>
          actual?.map((p) => (p.id === pregunta.id ? { ...p, dificultad: anterior } : p)) ?? actual,
      )
      setRowErrors((actual) => ({
        ...actual,
        [pregunta.id]:
          error instanceof Error ? error.message : 'No se ha podido guardar la dificultad.',
      }))
    } finally {
      setGuardandoCampos((actual) => {
        const siguiente = new Set(actual)
        siguiente.delete(clave)
        return siguiente
      })
    }
  }

  async function handleCambiarActivo(pregunta: Pregunta, activo: boolean) {
    const clave = `${pregunta.id}:activo`
    if (guardandoCampos.has(clave)) return
    const anterior = pregunta.activo

    setGuardandoCampos((actual) => new Set(actual).add(clave))
    setPreguntas(
      (actual) => actual?.map((p) => (p.id === pregunta.id ? { ...p, activo } : p)) ?? actual,
    )

    try {
      await actualizarActivoPregunta(pregunta.id, activo)
      setRowErrors((actual) => {
        if (!(pregunta.id in actual)) return actual
        const resto = { ...actual }
        delete resto[pregunta.id]
        return resto
      })
    } catch (error) {
      setPreguntas(
        (actual) =>
          actual?.map((p) => (p.id === pregunta.id ? { ...p, activo: anterior } : p)) ?? actual,
      )
      setRowErrors((actual) => ({
        ...actual,
        [pregunta.id]:
          error instanceof Error ? error.message : 'No se ha podido guardar el estado.',
      }))
    } finally {
      setGuardandoCampos((actual) => {
        const siguiente = new Set(actual)
        siguiente.delete(clave)
        return siguiente
      })
    }
  }

  const total = preguntas?.length ?? 0
  const bancoVacio = preguntas !== null && total === 0

  const topicOptions = [TODAS_TEMATICAS, ...new Set((preguntas ?? []).map((p) => p.tematicaNombre))]

  const q = query.trim().toLowerCase()
  const filtradas = (preguntas ?? []).filter((p) => {
    const matchQuery =
      !q || p.nombre.toLowerCase().includes(q) || p.nombreLugar.toLowerCase().includes(q)
    const matchTopic = topic === TODAS_TEMATICAS || p.tematicaNombre === topic
    const matchDificultad = dificultad === 'todas' || p.dificultad === dificultad
    const matchTipo = tipo === 'todos' || p.tipo === tipo
    const matchEstado = estado === 'todos' || (estado === 'activo') === p.activo
    return matchQuery && matchTopic && matchDificultad && matchTipo && matchEstado
  })

  const hasFilters =
    q.length > 0 ||
    topic !== TODAS_TEMATICAS ||
    dificultad !== 'todas' ||
    tipo !== 'todos' ||
    estado !== 'todos'

  const pageCount = Math.max(1, Math.ceil(filtradas.length / PAGE_SIZE))
  const paginaActual = Math.min(page, pageCount)
  const inicio = (paginaActual - 1) * PAGE_SIZE
  const pagina = filtradas.slice(inicio, inicio + PAGE_SIZE)

  // Cambiar de filtros vuelve a la página 1 y descarta errores de fila de
  // desafíos que puedan haber quedado ocultos por el filtro anterior.
  function alCambiarFiltro() {
    setPage(1)
    setRowErrors({})
  }

  function limpiarFiltros() {
    setQuery('')
    setTopic(TODAS_TEMATICAS)
    setDificultad('todas')
    setTipo('todos')
    setEstado('todos')
    alCambiarFiltro()
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-display text-3xl font-extrabold tracking-tight text-brand-night">
            Preguntas / Desafíos
          </h1>
          <p className="mt-1.5 text-sm text-brand-night/55">
            {total} {total === 1 ? 'pregunta' : 'preguntas'} en el banco
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2.5">
          <Link
            to="/preguntas/generar-ia"
            className="flex items-center gap-2 rounded-xl px-5 py-4 font-display text-base font-extrabold text-white"
            style={BOTON_IA_FONDO}
          >
            <span className="leading-none">✦</span>Generar con IA
          </Link>
          <Link
            to="/preguntas/nueva"
            className="flex items-center gap-2 rounded-xl px-6 py-4 font-display text-base font-extrabold text-white"
            style={BOTON_FONDO}
          >
            <span className="text-xl leading-none">+</span>Nueva pregunta
          </Link>
        </div>
      </div>

      <div className="overflow-hidden rounded-2xl border border-brand-border bg-white">
        <div className="flex flex-col gap-3 border-b border-brand-base p-4">
          <div className="flex flex-wrap items-center gap-2.5">
            <label className="flex h-10 max-w-96 min-w-[240px] flex-1 items-center gap-2 rounded-xl border-[1.5px] border-brand-border bg-brand-base/60 px-3.5 focus-within:border-brand-teal">
              <svg
                width="15"
                height="15"
                viewBox="0 0 20 20"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                className="text-brand-night/40"
              >
                <circle cx="8.5" cy="8.5" r="5.5" />
                <path d="M12.5 12.5 17 17" />
              </svg>
              <input
                type="search"
                value={query}
                onChange={(e) => {
                  setQuery(e.target.value)
                  alCambiarFiltro()
                }}
                placeholder="Buscar por nombre o lugar"
                className="min-w-0 flex-1 border-0 bg-transparent text-sm text-brand-night outline-none placeholder:text-brand-night/40"
              />
            </label>

            <select
              aria-label="Filtrar por temática"
              value={topic}
              onChange={(e) => {
                setTopic(e.target.value)
                alCambiarFiltro()
              }}
              className="h-10 rounded-xl border-[1.5px] border-brand-border bg-white px-3 text-sm font-medium text-brand-night/75"
            >
              {topicOptions.map((o) => (
                <option key={o} value={o}>
                  {o}
                </option>
              ))}
            </select>

            {hasFilters && (
              <button
                type="button"
                onClick={limpiarFiltros}
                className="text-xs font-semibold text-brand-blue underline underline-offset-2"
              >
                Limpiar filtros
              </button>
            )}
          </div>

          <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
            <div
              role="group"
              aria-label="Filtrar por tipo"
              className="flex flex-wrap items-center gap-1.5"
            >
              <span className="text-[10px] font-bold tracking-wide text-brand-night/35 uppercase">
                Tipo
              </span>
              <ChipFiltro
                activo={tipo === 'todos'}
                claseActiva={CHIP_TODOS_ACTIVA}
                onClick={() => {
                  setTipo('todos')
                  alCambiarFiltro()
                }}
              >
                Todos
              </ChipFiltro>
              {(['imagen', 'video', 'pregunta_texto'] as TipoDesafio[]).map((t) => (
                <ChipFiltro
                  key={t}
                  activo={tipo === t}
                  claseActiva={TIPO_CHIP_ACTIVA[t]}
                  onClick={() => {
                    setTipo(t)
                    alCambiarFiltro()
                  }}
                >
                  <IconoTipo tipo={t} size={13} />
                  {TIPO_LABEL[t]}
                </ChipFiltro>
              ))}
            </div>

            <div className="hidden h-6 w-px bg-brand-border sm:block" />

            <div
              role="group"
              aria-label="Filtrar por dificultad"
              className="flex flex-wrap items-center gap-1.5"
            >
              <span className="text-[10px] font-bold tracking-wide text-brand-night/35 uppercase">
                Dificultad
              </span>
              <ChipFiltro
                activo={dificultad === 'todas'}
                claseActiva={CHIP_TODOS_ACTIVA}
                onClick={() => {
                  setDificultad('todas')
                  alCambiarFiltro()
                }}
              >
                Todas
              </ChipFiltro>
              {DIFICULTADES.map((d) => (
                <ChipFiltro
                  key={d.valor}
                  activo={dificultad === d.valor}
                  claseActiva={DIFICULTAD_CHIP_ACTIVA[d.valor]}
                  onClick={() => {
                    setDificultad(d.valor)
                    alCambiarFiltro()
                  }}
                >
                  {d.label}
                </ChipFiltro>
              ))}
            </div>

            <div className="hidden h-6 w-px bg-brand-border sm:block" />

            <div
              role="group"
              aria-label="Filtrar por estado"
              className="flex flex-wrap items-center gap-1.5"
            >
              <span className="text-[10px] font-bold tracking-wide text-brand-night/35 uppercase">
                Estado
              </span>
              <ChipFiltro
                activo={estado === 'todos'}
                claseActiva={CHIP_TODOS_ACTIVA}
                onClick={() => {
                  setEstado('todos')
                  alCambiarFiltro()
                }}
              >
                Todos
              </ChipFiltro>
              <ChipFiltro
                activo={estado === 'activo'}
                claseActiva={ESTADO_CHIP_ACTIVA.activo}
                onClick={() => {
                  setEstado('activo')
                  alCambiarFiltro()
                }}
              >
                Activo
              </ChipFiltro>
              <ChipFiltro
                activo={estado === 'inactivo'}
                claseActiva={ESTADO_CHIP_ACTIVA.inactivo}
                onClick={() => {
                  setEstado('inactivo')
                  alCambiarFiltro()
                }}
              >
                Inactivo
              </ChipFiltro>
            </div>
          </div>
        </div>

        {bancoVacio ? (
          <EstadoVacioBanco />
        ) : filtradas.length === 0 ? (
          <EstadoVacioFiltros onLimpiar={limpiarFiltros} />
        ) : (
          <>
            <table className="w-full border-collapse text-left">
              <thead>
                <tr className="border-b border-brand-border bg-brand-base/60 text-[11px] font-semibold tracking-wider text-brand-night/45 uppercase">
                  <th className="px-5 py-3 font-semibold">Pregunta</th>
                  <th className="px-5 py-3 font-semibold">Temática</th>
                  <th className="px-5 py-3 font-semibold">Tipo</th>
                  <th className="px-5 py-3 font-semibold">Dificultad</th>
                  <th className="px-5 py-3 font-semibold">Estado</th>
                  <th className="px-5 py-3 text-right font-semibold">Acciones</th>
                </tr>
              </thead>
              <tbody>
                {pagina.map((p) => (
                  <FilaPregunta
                    key={p.id}
                    pregunta={p}
                    error={rowErrors[p.id]}
                    eliminando={eliminandoIds.has(p.id)}
                    guardandoDificultad={guardandoCampos.has(`${p.id}:dificultad`)}
                    guardandoActivo={guardandoCampos.has(`${p.id}:activo`)}
                    onEliminar={() => handleEliminar(p)}
                    onCambiarDificultad={(dificultad) => handleCambiarDificultad(p, dificultad)}
                    onCambiarActivo={(activo) => handleCambiarActivo(p, activo)}
                  />
                ))}
              </tbody>
            </table>

            <Paginacion
              total={filtradas.length}
              inicio={inicio}
              cantidad={pagina.length}
              pagina={paginaActual}
              pageCount={pageCount}
              onCambiarPagina={setPage}
            />
          </>
        )}
      </div>
    </div>
  )
}
