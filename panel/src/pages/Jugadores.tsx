import { useEffect, useState, type ReactElement } from 'react'
import {
  eliminarJugador,
  fetchJugadores,
  reiniciarProgresoJugador,
  type Jugador,
} from '../lib/jugadores'

type AccionJugador = 'reiniciar' | 'eliminar'

type ModalState = { jugadorId: string; accion: AccionJugador }

const PAGE_SIZE = 8

type OrdenJugadores = 'puntos' | 'parada' | 'alias' | 'tasa'

const ORDEN_LABEL: Record<OrdenJugadores, string> = {
  puntos: 'Más puntos',
  parada: 'Parada más avanzada',
  alias: 'Alias A–Z',
  tasa: 'Mayor tasa de superación',
}

const COMPARADORES: Record<OrdenJugadores, (a: Jugador, b: Jugador) => number> = {
  puntos: (a, b) => b.puntosTotales - a.puntosTotales,
  parada: (a, b) => (b.paradaMaxima ?? -1) - (a.paradaMaxima ?? -1),
  alias: (a, b) => a.alias.localeCompare(b.alias),
  tasa: (a, b) => (b.tasaSuperacion ?? -1) - (a.tasaSuperacion ?? -1),
}

const AVATAR_GRADIENTES = [
  'linear-gradient(140deg, #2BC0A8, #1B6FA8)',
  'linear-gradient(140deg, #1B6FA8, #7C5CFF)',
  'linear-gradient(140deg, #FFC53D, #F08A24)',
  'linear-gradient(140deg, #FF5A5F, #B3282D)',
]

function colorAvatar(alias: string): string {
  let hash = 0
  for (let i = 0; i < alias.length; i++) hash = (hash * 31 + alias.charCodeAt(i)) % 997
  return AVATAR_GRADIENTES[hash % AVATAR_GRADIENTES.length]
}

function formatFecha(iso: string | null): string {
  if (!iso) return 'Nunca'
  return new Date(iso).toLocaleString('es-ES', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function formatTasa(tasa: number | null): string {
  if (tasa === null) return '—'
  return `${Math.round(tasa * 100)} %`
}

function IconoBuscar() {
  return (
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
  )
}

function IconoReiniciar() {
  return (
    <svg
      width="13"
      height="13"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M20 12a8 8 0 1 1-2.4-5.7" />
      <path d="M20 4v4h-4" />
    </svg>
  )
}

function IconoEliminar() {
  return (
    <svg
      width="13"
      height="13"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M5 7h14M9.5 7V5h5v2M7 7l.9 12.1A1.5 1.5 0 0 0 9.4 20h5.2a1.5 1.5 0 0 0 1.5-.9L17 7" />
    </svg>
  )
}

function EstadoVacioFiltros({ onLimpiar }: { onLimpiar: () => void }) {
  return (
    <div className="flex flex-col items-center gap-2 px-6 py-16 text-center">
      <h4 className="font-display text-xl font-extrabold text-brand-night">
        Ningún jugador coincide
      </h4>
      <p className="max-w-md text-sm text-brand-night/55">
        Prueba con el alias completo o quita el filtro de búsqueda.
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

const MODAL_COPY: Record<
  AccionJugador,
  {
    titulo: (alias: string) => string
    cuerpo: (alias: string) => string
    iconoBg: string
    iconoColor: string
    icono: () => ReactElement
    botonLabel: string
    botonLabelProcesando: string
    botonGradiente: string
  }
> = {
  reiniciar: {
    titulo: (alias) => `Reiniciar a ${alias}`,
    cuerpo: () =>
      'Este jugador volverá al nivel 1 con 0 puntos. Su cuenta, alias y acceso se mantienen. Esta acción no se puede deshacer.',
    iconoBg: 'bg-brand-gold/20',
    iconoColor: 'text-[#8A5B00]',
    icono: IconoReiniciar,
    botonLabel: 'Reiniciar progreso',
    botonLabelProcesando: 'Reiniciando…',
    botonGradiente: 'linear-gradient(140deg, #FF7A3D, #E0454A)',
  },
  eliminar: {
    titulo: (alias) => `Eliminar a ${alias}`,
    cuerpo: (alias) =>
      `Se borra la cuenta de ${alias} por completo: perfil, progreso y todo su historial de partidas. No podrá volver a entrar con este acceso. Esta acción no se puede deshacer.`,
    iconoBg: 'bg-brand-error/15',
    iconoColor: 'text-[#B3282D]',
    icono: IconoEliminar,
    botonLabel: 'Eliminar jugador',
    botonLabelProcesando: 'Eliminando…',
    botonGradiente: 'linear-gradient(140deg, #FF5A5F, #B3282D)',
  },
}

function ModalAccionJugador({
  jugador,
  accion,
  procesando,
  error,
  onCancelar,
  onConfirmar,
}: {
  jugador: Jugador
  accion: AccionJugador
  procesando: boolean
  error: string
  onCancelar: () => void
  onConfirmar: () => void
}) {
  const [textoConfirmacion, setTextoConfirmacion] = useState('')
  const coincide = textoConfirmacion === jugador.alias
  const copy = MODAL_COPY[accion]
  const Icono = copy.icono

  return (
    <div className="fixed inset-0 z-20 flex items-center justify-center bg-brand-night/50 p-6 backdrop-blur-sm">
      <div className="w-full max-w-md rounded-2xl bg-white shadow-2xl">
        <div className="flex gap-3.5 px-6 pt-6">
          <span
            className={`flex h-10 w-10 flex-none items-center justify-center rounded-xl ${copy.iconoBg} ${copy.iconoColor}`}
          >
            <span className="[&>svg]:h-5 [&>svg]:w-5">
              <Icono />
            </span>
          </span>
          <div className="min-w-0">
            <h3 className="font-display text-xl font-extrabold text-brand-night">
              {copy.titulo(jugador.alias)}
            </h3>
            <p className="mt-1.5 text-sm text-brand-night/58">{copy.cuerpo(jugador.alias)}</p>
          </div>
        </div>

        <div className="px-6 pt-4">
          <label
            htmlFor="confirmar-alias"
            className="block text-xs font-semibold text-brand-night/55"
          >
            Escribe <span className="font-bold text-brand-night">{jugador.alias}</span> para
            confirmar
          </label>
          <input
            id="confirmar-alias"
            type="text"
            value={textoConfirmacion}
            onChange={(e) => setTextoConfirmacion(e.target.value)}
            disabled={procesando}
            autoFocus
            className="mt-2 h-11 w-full rounded-xl border-[1.5px] border-brand-border px-3.5 text-sm text-brand-night outline-none focus:border-brand-teal disabled:opacity-60"
          />
          {error && <p className="mt-2 text-xs text-[#B3282D]">{error}</p>}
        </div>

        <div className="flex justify-end gap-2.5 px-6 py-5">
          <button
            type="button"
            onClick={onCancelar}
            disabled={procesando}
            className="rounded-xl border-[1.5px] border-brand-border px-4 py-2.5 text-sm font-semibold text-brand-night/70 hover:border-brand-night hover:text-brand-night disabled:cursor-not-allowed disabled:opacity-60"
          >
            Cancelar
          </button>
          <button
            type="button"
            disabled={!coincide || procesando}
            onClick={onConfirmar}
            style={coincide ? { background: copy.botonGradiente } : undefined}
            className="rounded-xl px-5 py-2.5 font-display text-sm font-extrabold text-white disabled:cursor-not-allowed disabled:bg-brand-base disabled:text-brand-night/35"
          >
            {procesando ? copy.botonLabelProcesando : copy.botonLabel}
          </button>
        </div>
      </div>
    </div>
  )
}

export function Jugadores() {
  const [jugadores, setJugadores] = useState<Jugador[] | null>(null)
  const [error, setError] = useState('')
  const [query, setQuery] = useState('')
  const [orden, setOrden] = useState<OrdenJugadores>('puntos')
  const [page, setPage] = useState(1)
  const [modal, setModal] = useState<ModalState | null>(null)
  const [procesando, setProcesando] = useState(false)
  const [errorAccion, setErrorAccion] = useState('')
  const [toast, setToast] = useState('')

  useEffect(() => {
    let isMounted = true

    fetchJugadores()
      .then((resultado) => {
        if (!isMounted) return
        setJugadores(resultado)
      })
      .catch((cargaError: unknown) => {
        if (!isMounted) return
        console.error('Error cargando el listado de jugadores:', cargaError)
        setError('No se ha podido cargar el listado de jugadores.')
      })

    return () => {
      isMounted = false
    }
  }, [])

  useEffect(() => {
    if (!toast) return
    const temporizador = setTimeout(() => setToast(''), 5000)
    return () => clearTimeout(temporizador)
  }, [toast])

  if (error) {
    return (
      <div className="rounded-2xl border border-brand-error/40 bg-brand-error/10 p-5 text-sm text-[#B3282D]">
        {error}
      </div>
    )
  }

  const total = jugadores?.length ?? 0

  const q = query.trim().toLowerCase()
  const filtrados = (jugadores ?? []).filter((j) => !q || j.alias.toLowerCase().includes(q))
  const ordenados = [...filtrados].sort(COMPARADORES[orden])

  const hasFilters = q.length > 0
  const pageCount = Math.max(1, Math.ceil(ordenados.length / PAGE_SIZE))
  const paginaActual = Math.min(page, pageCount)
  const inicio = (paginaActual - 1) * PAGE_SIZE
  const pagina = ordenados.slice(inicio, inicio + PAGE_SIZE)

  function limpiarFiltros() {
    setQuery('')
    setPage(1)
  }

  const kpis = [
    { label: 'Jugadores', valor: total },
    {
      label: 'Puntos totales',
      valor: (jugadores ?? []).reduce((acc, j) => acc + j.puntosTotales, 0).toLocaleString('es-ES'),
    },
    {
      label: 'Niveles superados (media)',
      valor:
        total > 0
          ? ((jugadores ?? []).reduce((acc, j) => acc + j.nivelesSuperados, 0) / total).toFixed(1)
          : '—',
    },
    {
      label: 'Sin ninguna partida',
      valor: (jugadores ?? []).filter((j) => j.ultimaPartida === null).length,
    },
  ]

  const jugadorModal = modal ? (jugadores ?? []).find((j) => j.id === modal.jugadorId) : undefined

  function abrirModal(jugadorId: string, accion: AccionJugador) {
    setModal({ jugadorId, accion })
    setErrorAccion('')
  }

  function cerrarModal() {
    if (procesando) return
    setModal(null)
    setErrorAccion('')
  }

  async function confirmarAccion() {
    if (!jugadorModal || !modal) return
    setProcesando(true)
    setErrorAccion('')

    try {
      if (modal.accion === 'reiniciar') {
        await reiniciarProgresoJugador(jugadorModal.id)
        setJugadores(
          (actual) =>
            actual?.map((j) =>
              j.id === jugadorModal.id
                ? {
                    ...j,
                    nivelesSuperados: 0,
                    paradaMaxima: null,
                    puntosTotales: 0,
                    tasaSuperacion: null,
                    ultimaPartida: null,
                  }
                : j,
            ) ?? actual,
        )
        setToast(`Progreso de ${jugadorModal.alias} reiniciado.`)
      } else {
        await eliminarJugador(jugadorModal.id)
        setJugadores((actual) => actual?.filter((j) => j.id !== jugadorModal.id) ?? actual)
        setToast(`${jugadorModal.alias} eliminado.`)
      }
      setModal(null)
    } catch (accionError) {
      setErrorAccion(
        accionError instanceof Error
          ? accionError.message
          : modal.accion === 'reiniciar'
            ? 'No se ha podido reiniciar el progreso.'
            : 'No se ha podido eliminar al jugador.',
      )
    } finally {
      setProcesando(false)
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="font-display text-3xl font-extrabold tracking-tight text-brand-night">
          Jugadores
        </h1>
        <p className="mt-1.5 text-sm text-brand-night/55">
          {total} {total === 1 ? 'jugador registrado' : 'jugadores registrados'}
        </p>
      </div>

      <section className="grid grid-cols-4 gap-4">
        {kpis.map((kpi) => (
          <div key={kpi.label} className="rounded-2xl border border-brand-border bg-white p-5">
            <div className="text-[11px] font-semibold tracking-wider text-brand-night/50 uppercase">
              {kpi.label}
            </div>
            <div className="mt-3 font-display text-3xl font-extrabold text-brand-night">
              {jugadores ? kpi.valor : '—'}
            </div>
          </div>
        ))}
      </section>

      <div className="overflow-hidden rounded-2xl border border-brand-border bg-white">
        <div className="flex flex-wrap items-center gap-2.5 border-b border-brand-base p-4">
          <label className="flex h-10 max-w-96 min-w-[240px] flex-1 items-center gap-2 rounded-xl border-[1.5px] border-brand-border bg-brand-base/60 px-3.5 focus-within:border-brand-teal">
            <IconoBuscar />
            <input
              type="search"
              value={query}
              onChange={(e) => {
                setQuery(e.target.value)
                setPage(1)
              }}
              placeholder="Buscar por alias"
              className="min-w-0 flex-1 border-0 bg-transparent text-sm text-brand-night outline-none placeholder:text-brand-night/40"
            />
          </label>

          <select
            aria-label="Ordenar jugadores"
            value={orden}
            onChange={(e) => {
              setOrden(e.target.value as OrdenJugadores)
              setPage(1)
            }}
            className="h-10 rounded-xl border-[1.5px] border-brand-border bg-white px-3 text-sm font-medium text-brand-night/75"
          >
            {(Object.keys(ORDEN_LABEL) as OrdenJugadores[]).map((clave) => (
              <option key={clave} value={clave}>
                {ORDEN_LABEL[clave]}
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

          <span className="ml-auto text-xs text-brand-night/50">
            {ordenados.length} {ordenados.length === 1 ? 'jugador filtrado' : 'jugadores filtrados'}
          </span>
        </div>

        {jugadores !== null && ordenados.length === 0 ? (
          <EstadoVacioFiltros onLimpiar={limpiarFiltros} />
        ) : (
          <>
            <table className="w-full border-collapse text-left">
              <thead>
                <tr className="border-b border-brand-border bg-brand-base/60 text-[11px] font-semibold tracking-wider text-brand-night/45 uppercase">
                  <th className="px-5 py-3 font-semibold">Jugador</th>
                  <th className="px-5 py-3 font-semibold">Parada</th>
                  <th className="px-5 py-3 text-right font-semibold">Puntos</th>
                  <th className="px-5 py-3 text-right font-semibold">Tasa de superación</th>
                  <th className="px-5 py-3 font-semibold">Última partida</th>
                  <th className="px-5 py-3 text-right font-semibold">Acciones</th>
                </tr>
              </thead>
              <tbody>
                {pagina.map((jugador) => (
                  <tr
                    key={jugador.id}
                    className="border-b border-brand-base last:border-0 hover:bg-brand-base/40"
                  >
                    <td className="px-5 py-3">
                      <div className="flex items-center gap-3">
                        <span
                          className="flex h-9 w-9 flex-none items-center justify-center rounded-xl font-display text-xs font-extrabold text-white"
                          style={{ background: colorAvatar(jugador.alias) }}
                        >
                          {jugador.alias.slice(0, 2).toUpperCase()}
                        </span>
                        <span className="truncate text-sm font-semibold text-brand-night">
                          {jugador.alias}
                        </span>
                      </div>
                    </td>
                    <td className="px-5 py-3 text-sm text-brand-night/70">
                      {jugador.paradaMaxima === null
                        ? 'Sin avanzar'
                        : `Parada ${jugador.paradaMaxima}`}
                    </td>
                    <td className="px-5 py-3 text-right text-sm font-semibold tabular-nums text-brand-night">
                      {jugador.puntosTotales.toLocaleString('es-ES')}
                    </td>
                    <td className="px-5 py-3 text-right text-sm tabular-nums text-brand-night/70">
                      {formatTasa(jugador.tasaSuperacion)}
                    </td>
                    <td className="px-5 py-3 text-sm text-brand-night/55">
                      {formatFecha(jugador.ultimaPartida)}
                    </td>
                    <td className="px-5 py-3">
                      <div className="flex justify-end gap-2">
                        <button
                          type="button"
                          onClick={() => abrirModal(jugador.id, 'reiniciar')}
                          aria-label={`Reiniciar progreso de ${jugador.alias}`}
                          title="Reiniciar progreso"
                          className="inline-flex h-8 items-center gap-1.5 rounded-lg border-[1.5px] border-brand-border px-3 text-xs font-semibold text-brand-night/60 hover:border-brand-gold hover:text-[#8A5B00]"
                        >
                          <IconoReiniciar />
                          Reiniciar progreso
                        </button>
                        <button
                          type="button"
                          onClick={() => abrirModal(jugador.id, 'eliminar')}
                          aria-label={`Eliminar a ${jugador.alias}`}
                          title="Eliminar jugador"
                          className="inline-flex h-8 items-center gap-1.5 rounded-lg border-[1.5px] border-brand-border px-3 text-xs font-semibold text-brand-night/60 hover:border-brand-error hover:text-brand-error"
                        >
                          <IconoEliminar />
                          Eliminar
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>

            <Paginacion
              total={ordenados.length}
              inicio={inicio}
              cantidad={pagina.length}
              pagina={paginaActual}
              pageCount={pageCount}
              onCambiarPagina={setPage}
            />
          </>
        )}
      </div>

      {jugadorModal && modal && (
        <ModalAccionJugador
          jugador={jugadorModal}
          accion={modal.accion}
          procesando={procesando}
          error={errorAccion}
          onCancelar={cerrarModal}
          onConfirmar={confirmarAccion}
        />
      )}

      {toast && (
        <div className="fixed bottom-6 left-1/2 z-30 flex -translate-x-1/2 items-center gap-2.5 rounded-xl bg-brand-night px-4 py-3.5 text-white shadow-2xl">
          <span className="flex h-5 w-5 flex-none items-center justify-center rounded-full bg-brand-teal text-xs font-bold text-brand-night">
            ✓
          </span>
          <span className="text-sm font-medium">{toast}</span>
        </div>
      )}
    </div>
  )
}
