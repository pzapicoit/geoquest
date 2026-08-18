import { Fragment, useEffect, useState, type DragEvent } from 'react'
import {
  actualizarEstrellasRequeridas,
  actualizarOverridesParada,
  agregarParadaAlCamino,
  fetchCamino,
  fetchTematicasParaCamino,
  nombreParada,
  quitarDelCamino,
  reordenarCamino,
  validarOverrides,
  type OverridesParada,
  type PosicionCamino,
  type TematicaOpcion,
} from '../lib/camino'
import { fetchDificultadDefaults, type DificultadDefault } from '../lib/dificultadDefaults'
import { DIFICULTADES, DIFICULTAD_LABEL, type Dificultad } from '../lib/dificultad'

const BOTON_FONDO = {
  background: 'linear-gradient(140deg, #2BC0A8, #1B6FA8)',
}

const CAMPO_BASE =
  'h-10 rounded-lg border-[1.5px] border-brand-border bg-white px-3 text-sm text-brand-night outline-none focus:border-brand-teal focus:ring-4 focus:ring-brand-teal/15'

type OverridesFormTexto = Record<keyof OverridesParada, string>

function overridesAForm(posicion: PosicionCamino): OverridesFormTexto {
  return {
    preguntasPorPartida:
      posicion.preguntasPorPartida === null ? '' : String(posicion.preguntasPorPartida),
    segundosPorDesafio:
      posicion.segundosPorDesafio === null ? '' : String(posicion.segundosPorDesafio),
    puntajeMinimoSuperar:
      posicion.puntajeMinimoSuperar === null ? '' : String(posicion.puntajeMinimoSuperar),
    umbralEstrella2: posicion.umbralEstrella2 === null ? '' : String(posicion.umbralEstrella2),
    umbralEstrella3: posicion.umbralEstrella3 === null ? '' : String(posicion.umbralEstrella3),
  }
}

function formAOverrides(form: OverridesFormTexto): OverridesParada {
  const aNumeroONull = (valor: string): number | null =>
    valor.trim() === '' ? null : Number(valor)
  return {
    preguntasPorPartida: aNumeroONull(form.preguntasPorPartida),
    segundosPorDesafio: aNumeroONull(form.segundosPorDesafio),
    puntajeMinimoSuperar: aNumeroONull(form.puntajeMinimoSuperar),
    umbralEstrella2: aNumeroONull(form.umbralEstrella2),
    umbralEstrella3: aNumeroONull(form.umbralEstrella3),
  }
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

function IconoCamino() {
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
      <circle cx="5" cy="19" r="2" />
      <circle cx="12" cy="10" r="2" />
      <circle cx="19" cy="5" r="2" />
      <path d="M6.4 17.6 10.6 11.6M13.4 8.4 17.6 6.4" />
    </svg>
  )
}

function EstadoVacio({ onAnadir }: { onAnadir: () => void }) {
  return (
    <div className="flex flex-col items-center gap-2 px-6 py-16 text-center">
      <div className="mb-3 flex h-[78px] w-[78px] items-center justify-center rounded-[22px] bg-brand-teal/10 text-brand-blue">
        <IconoCamino />
      </div>
      <h4 className="font-display text-xl font-extrabold text-brand-night">El camino está vacío</h4>
      <p className="max-w-md text-sm text-brand-night/55">
        El camino define en qué orden juega el jugador cada parada de temática y dificultad,
        pudiendo intercalar temáticas y repetir combinaciones libremente. Añade la primera parada
        para empezar.
      </p>
      <button
        type="button"
        onClick={onAnadir}
        className="mt-3 flex items-center gap-2 rounded-xl px-4 py-2.5 font-display text-sm font-extrabold text-white"
        style={BOTON_FONDO}
      >
        <span className="text-base leading-none">+</span>Añadir parada al camino
      </button>
    </div>
  )
}

function SelectorParada({
  tematicas,
  error,
  agregando,
  onAgregar,
}: {
  tematicas: TematicaOpcion[] | null
  error: string
  agregando: boolean
  onAgregar: (tematicaId: string, dificultad: Dificultad) => void
}) {
  const [tematicaId, setTematicaId] = useState('')
  const [dificultad, setDificultad] = useState<Dificultad | ''>('')

  return (
    <div className="flex flex-col gap-3.5 rounded-2xl border-[1.5px] border-dashed border-[#CFDDE3] bg-brand-teal/5 p-6">
      <h2 className="font-display text-lg font-extrabold text-brand-night">
        Añadir parada al camino
      </h2>
      {error && <p className="text-sm text-[#B3282D]">{error}</p>}
      <div className="flex flex-wrap items-end gap-3">
        <label className="flex flex-col gap-1.5">
          <span className="text-xs font-medium text-brand-night/60">Temática</span>
          <select
            value={tematicaId}
            onChange={(e) => setTematicaId(e.target.value)}
            disabled={tematicas === null}
            className={`${CAMPO_BASE} min-w-[220px]`}
          >
            <option value="">{tematicas === null ? 'Cargando…' : 'Selecciona una temática'}</option>
            {(tematicas ?? []).map((t) => (
              <option key={t.id} value={t.id}>
                {t.nombre}
              </option>
            ))}
          </select>
        </label>
        <label className="flex flex-col gap-1.5">
          <span className="text-xs font-medium text-brand-night/60">Dificultad</span>
          <select
            value={dificultad}
            onChange={(e) => setDificultad(e.target.value as Dificultad)}
            className={`${CAMPO_BASE} min-w-[160px]`}
          >
            <option value="">Selecciona una dificultad</option>
            {DIFICULTADES.map((d) => (
              <option key={d.valor} value={d.valor}>
                {d.label}
              </option>
            ))}
          </select>
        </label>
        <button
          type="button"
          disabled={!tematicaId || !dificultad || agregando}
          onClick={() => {
            if (tematicaId && dificultad) onAgregar(tematicaId, dificultad)
          }}
          className="h-10 rounded-lg px-4 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
          style={BOTON_FONDO}
        >
          {agregando ? 'Añadiendo…' : 'Añadir'}
        </button>
      </div>
    </div>
  )
}

function PanelOverrides({
  form,
  defaults,
  error,
  guardando,
  onChange,
  onGuardar,
  onCancelar,
}: {
  form: OverridesFormTexto
  defaults: DificultadDefault
  error?: string
  guardando: boolean
  onChange: (form: OverridesFormTexto) => void
  onGuardar: () => void
  onCancelar: () => void
}) {
  const campos: { clave: keyof OverridesFormTexto; label: string; defecto: number }[] = [
    {
      clave: 'preguntasPorPartida',
      label: 'Preguntas/partida',
      defecto: defaults.preguntasPorPartida,
    },
    {
      clave: 'segundosPorDesafio',
      label: 'Segundos/pregunta',
      defecto: defaults.segundosPorDesafio,
    },
    {
      clave: 'puntajeMinimoSuperar',
      label: 'Mínimo para superar',
      defecto: defaults.puntajeMinimoSuperar,
    },
    { clave: 'umbralEstrella2', label: 'Umbral 2 estrellas', defecto: defaults.umbralEstrella2 },
    { clave: 'umbralEstrella3', label: 'Umbral 3 estrellas', defecto: defaults.umbralEstrella3 },
  ]

  return (
    <tr>
      <td colSpan={5} className="bg-brand-base/40 px-4 py-4">
        <div className="flex flex-col gap-3">
          <p className="text-xs text-brand-night/55">
            Deja un campo vacío para usar el valor por defecto de esta dificultad (mostrado entre
            paréntesis).
          </p>
          <div className="flex flex-wrap gap-3">
            {campos.map((campo) => (
              <label key={campo.clave} className="flex flex-col gap-1">
                <span className="text-[11px] font-semibold text-brand-night/50">
                  {campo.label} <span className="text-brand-night/35">({campo.defecto})</span>
                </span>
                <input
                  type="number"
                  min={1}
                  step={1}
                  placeholder={String(campo.defecto)}
                  value={form[campo.clave]}
                  onChange={(e) => onChange({ ...form, [campo.clave]: e.target.value })}
                  className={`${CAMPO_BASE} w-36 tabular-nums`}
                />
              </label>
            ))}
          </div>
          {error && <p className="text-xs font-medium text-[#B3282D]">{error}</p>}
          <div className="flex gap-2">
            <button
              type="button"
              onClick={onGuardar}
              disabled={guardando}
              className="rounded-lg px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
              style={BOTON_FONDO}
            >
              {guardando ? 'Guardando…' : 'Guardar overrides'}
            </button>
            <button
              type="button"
              onClick={onCancelar}
              className="rounded-lg border-[1.5px] border-brand-border px-4 py-2 text-sm font-semibold text-brand-night/70 hover:border-brand-error hover:text-brand-error"
            >
              Cancelar
            </button>
          </div>
        </div>
      </td>
    </tr>
  )
}

export function Camino() {
  const [camino, setCamino] = useState<PosicionCamino[] | null>(null)
  const [error, setError] = useState('')
  const [rowErrors, setRowErrors] = useState<Record<string, string>>({})
  const [quitandoIds, setQuitandoIds] = useState<Set<string>>(new Set())
  const [errorOrden, setErrorOrden] = useState('')
  const [dragIndex, setDragIndex] = useState<number | null>(null)
  const [operandoCamino, setOperandoCamino] = useState(false)

  const [mostrarSelector, setMostrarSelector] = useState(false)
  const [tematicas, setTematicas] = useState<TematicaOpcion[] | null>(null)
  const [errorSelector, setErrorSelector] = useState('')
  const [agregando, setAgregando] = useState(false)

  const [defaults, setDefaults] = useState<Record<Dificultad, DificultadDefault> | null>(null)

  const [estrellasEditando, setEstrellasEditando] = useState<Record<string, string>>({})
  const [guardandoEstrellasIds, setGuardandoEstrellasIds] = useState<Set<string>>(new Set())

  const [overridesAbiertoId, setOverridesAbiertoId] = useState<string | null>(null)
  const [overridesForm, setOverridesForm] = useState<OverridesFormTexto | null>(null)
  const [overridesError, setOverridesError] = useState('')
  const [guardandoOverrides, setGuardandoOverrides] = useState(false)

  function cargar() {
    fetchCamino()
      .then((resultado) => setCamino(resultado))
      .catch((cargaError: unknown) => {
        console.error('Error cargando el camino:', cargaError)
        setError('No se ha podido cargar el camino.')
      })
  }

  useEffect(() => {
    cargar()
    fetchDificultadDefaults()
      .then((resultado) => {
        setDefaults(
          Object.fromEntries(resultado.map((f) => [f.dificultad, f])) as Record<
            Dificultad,
            DificultadDefault
          >,
        )
      })
      .catch((cargaError: unknown) => {
        console.error('Error cargando los valores por defecto de dificultad:', cargaError)
      })
  }, [])

  if (error) {
    return (
      <div className="rounded-2xl border border-brand-error/40 bg-brand-error/10 p-5 text-sm text-[#B3282D]">
        {error}
      </div>
    )
  }

  const lista = camino ?? []
  const total = lista.length

  function abrirSelector() {
    setMostrarSelector(true)
    if (tematicas !== null) return

    fetchTematicasParaCamino()
      .then((resultado) => setTematicas(resultado))
      .catch((tematicasError: unknown) => {
        console.error('Error cargando las temáticas:', tematicasError)
        setErrorSelector('No se han podido cargar las temáticas.')
      })
  }

  async function handleAgregar(tematicaId: string, dificultad: Dificultad) {
    if (agregando || operandoCamino) return

    setAgregando(true)
    setOperandoCamino(true)
    try {
      const { id } = await agregarParadaAlCamino(tematicaId, dificultad)
      const tematicaNombre = tematicas?.find((t) => t.id === tematicaId)?.nombre ?? '—'
      setCamino((actual) => [
        ...(actual ?? []),
        {
          id,
          orden: (actual?.length ?? 0) + 1,
          tematicaId,
          tematicaNombre,
          dificultad,
          nombre: null,
          estrellasRequeridas: 0,
          preguntasPorPartida: null,
          segundosPorDesafio: null,
          puntajeMinimoSuperar: null,
          umbralEstrella2: null,
          umbralEstrella3: null,
        },
      ])
    } catch (agregarError) {
      setErrorSelector(
        agregarError instanceof Error ? agregarError.message : 'No se ha podido añadir la parada.',
      )
    } finally {
      setAgregando(false)
      setOperandoCamino(false)
    }
  }

  function persistirOrden(nuevoOrden: PosicionCamino[]) {
    if (operandoCamino) return

    const anterior = lista
    const renumeradas = nuevoOrden.map((p, i) => ({ ...p, orden: i + 1 }))
    setCamino(renumeradas)
    setErrorOrden('')
    setOperandoCamino(true)

    reordenarCamino(renumeradas.map((p) => p.id))
      .catch((reordenarError: unknown) => {
        setCamino(anterior)
        setErrorOrden(
          reordenarError instanceof Error
            ? reordenarError.message
            : 'No se ha podido reordenar el camino.',
        )
      })
      .finally(() => setOperandoCamino(false))
  }

  function handleMover(index: number, delta: number) {
    if (operandoCamino) return
    const destino = index + delta
    if (destino < 0 || destino >= lista.length) return
    const reordenadas = [...lista]
    const [item] = reordenadas.splice(index, 1)
    reordenadas.splice(destino, 0, item)
    persistirOrden(reordenadas)
  }

  function handleDrop(index: number) {
    if (dragIndex === null || dragIndex === index || operandoCamino) {
      setDragIndex(null)
      return
    }
    const reordenadas = [...lista]
    const [item] = reordenadas.splice(dragIndex, 1)
    reordenadas.splice(index, 0, item)
    persistirOrden(reordenadas)
    setDragIndex(null)
  }

  async function handleEstrellasBlur(posicion: PosicionCamino) {
    const valorTexto = estrellasEditando[posicion.id] ?? String(posicion.estrellasRequeridas)
    const valor = Number(valorTexto)

    if (valorTexto.trim() === '' || !Number.isInteger(valor) || valor < 0) {
      setRowErrors((actual) => ({
        ...actual,
        [posicion.id]: 'Debe ser un número entero igual o mayor a 0.',
      }))
      return
    }

    if (valor === posicion.estrellasRequeridas) return

    setGuardandoEstrellasIds((actual) => new Set(actual).add(posicion.id))
    try {
      await actualizarEstrellasRequeridas(posicion.id, valor)
      setCamino(
        (actual) =>
          actual?.map((p) => (p.id === posicion.id ? { ...p, estrellasRequeridas: valor } : p)) ??
          actual,
      )
      setRowErrors((actual) => {
        if (!(posicion.id in actual)) return actual
        const resto = { ...actual }
        delete resto[posicion.id]
        return resto
      })
    } catch (guardarError) {
      setRowErrors((actual) => ({
        ...actual,
        [posicion.id]:
          guardarError instanceof Error ? guardarError.message : 'No se ha podido guardar.',
      }))
    } finally {
      setGuardandoEstrellasIds((actual) => {
        const siguiente = new Set(actual)
        siguiente.delete(posicion.id)
        return siguiente
      })
    }
  }

  async function handleQuitar(posicion: PosicionCamino) {
    if (quitandoIds.has(posicion.id) || operandoCamino) return

    const confirmado = window.confirm(
      `¿Quitar "${nombreParada(posicion)}" del camino? La temática y sus preguntas seguirán intactas.`,
    )
    if (!confirmado) return

    setQuitandoIds((actual) => new Set(actual).add(posicion.id))
    setOperandoCamino(true)
    try {
      await quitarDelCamino(posicion.id)
      setCamino((actual) =>
        (actual ?? []).filter((p) => p.id !== posicion.id).map((p, i) => ({ ...p, orden: i + 1 })),
      )
      setRowErrors((actual) => {
        if (!(posicion.id in actual)) return actual
        const resto = { ...actual }
        delete resto[posicion.id]
        return resto
      })
    } catch (quitarError) {
      setRowErrors((actual) => ({
        ...actual,
        [posicion.id]:
          quitarError instanceof Error ? quitarError.message : 'No se ha podido quitar del camino.',
      }))
    } finally {
      setQuitandoIds((actual) => {
        const siguiente = new Set(actual)
        siguiente.delete(posicion.id)
        return siguiente
      })
      setOperandoCamino(false)
    }
  }

  function abrirOverrides(posicion: PosicionCamino) {
    setOverridesAbiertoId(posicion.id)
    setOverridesForm(overridesAForm(posicion))
    setOverridesError('')
  }

  function cerrarOverrides() {
    setOverridesAbiertoId(null)
    setOverridesForm(null)
    setOverridesError('')
  }

  async function handleGuardarOverrides(posicion: PosicionCamino) {
    if (!overridesForm || !defaults) return

    const overrides = formAOverrides(overridesForm)
    const erroresConversion = Object.values(overridesForm).some(
      (v) => v.trim() !== '' && Number.isNaN(Number(v)),
    )
    if (erroresConversion) {
      setOverridesError('Cada override debe ser un número.')
      return
    }

    const errorValidacion = validarOverrides(overrides, defaults[posicion.dificultad])
    if (errorValidacion) {
      setOverridesError(errorValidacion)
      return
    }

    setGuardandoOverrides(true)
    try {
      await actualizarOverridesParada(posicion.id, overrides)
      setCamino(
        (actual) =>
          actual?.map((p) => (p.id === posicion.id ? { ...p, ...overrides } : p)) ?? actual,
      )
      cerrarOverrides()
    } catch (guardarError) {
      setOverridesError(
        guardarError instanceof Error ? guardarError.message : 'No se ha podido guardar.',
      )
    } finally {
      setGuardandoOverrides(false)
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-display text-3xl font-extrabold tracking-tight text-brand-night">
            Camino
          </h1>
          <p className="mt-1.5 text-sm text-brand-night/55">
            {total === 0
              ? 'Ninguna posición definida todavía'
              : `${total} ${total === 1 ? 'posición' : 'posiciones'} · el orden define la secuencia de juego`}
          </p>
        </div>
        {total > 0 && (
          <button
            type="button"
            onClick={abrirSelector}
            className="flex items-center gap-2 rounded-xl px-6 py-4 font-display text-base font-extrabold text-white"
            style={BOTON_FONDO}
          >
            <span className="text-xl leading-none">+</span>Añadir parada al camino
          </button>
        )}
      </div>

      {mostrarSelector && (
        <SelectorParada
          tematicas={tematicas}
          error={errorSelector}
          agregando={agregando}
          onAgregar={handleAgregar}
        />
      )}

      <div className="overflow-hidden rounded-2xl border border-brand-border bg-white">
        {camino !== null && total === 0 ? (
          <EstadoVacio onAnadir={abrirSelector} />
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
                  <th className="px-3 py-3 font-semibold">Parada</th>
                  <th className="px-3 py-3 font-semibold">Estrellas para desbloquear</th>
                  <th className="px-3 py-3 text-right font-semibold">Acciones</th>
                </tr>
              </thead>
              <tbody>
                {lista.map((posicion, index) => (
                  <Fragment key={posicion.id}>
                    <tr
                      draggable={!operandoCamino}
                      onDragStart={() => setDragIndex(index)}
                      onDragOver={(e: DragEvent<HTMLTableRowElement>) => e.preventDefault()}
                      onDrop={() => handleDrop(index)}
                      className={`border-b border-brand-base last:border-0 hover:bg-brand-base/40 ${
                        dragIndex === index ? 'opacity-40' : ''
                      }`}
                    >
                      <td
                        className="w-10 px-3 py-3 text-center text-brand-night/30"
                        aria-hidden="true"
                      >
                        <IconoAsa />
                      </td>
                      <td className="px-2 py-3 text-sm font-semibold text-brand-night/50 tabular-nums">
                        {index + 1}
                      </td>
                      <td className="px-3 py-3">
                        <div className="min-w-0">
                          <div className="truncate text-sm font-semibold text-brand-night">
                            {nombreParada(posicion)}
                          </div>
                          {posicion.nombre?.trim() && (
                            <div className="truncate text-xs text-brand-night/50">
                              {posicion.tematicaNombre} · {DIFICULTAD_LABEL[posicion.dificultad]}
                            </div>
                          )}
                        </div>
                      </td>
                      <td className="px-3 py-3">
                        <div className="flex items-center gap-1.5">
                          <span className="text-brand-gold">★</span>
                          <input
                            type="number"
                            min={0}
                            step={1}
                            value={
                              estrellasEditando[posicion.id] ?? String(posicion.estrellasRequeridas)
                            }
                            disabled={guardandoEstrellasIds.has(posicion.id)}
                            onChange={(e) =>
                              setEstrellasEditando((actual) => ({
                                ...actual,
                                [posicion.id]: e.target.value,
                              }))
                            }
                            onBlur={() => handleEstrellasBlur(posicion)}
                            className={`${CAMPO_BASE} w-20 tabular-nums`}
                          />
                        </div>
                        {rowErrors[posicion.id] && (
                          <p className="mt-1.5 text-[11px] text-[#B3282D]">
                            {rowErrors[posicion.id]}
                          </p>
                        )}
                      </td>
                      <td className="px-3 py-3">
                        <div className="flex items-center justify-end gap-1.5">
                          <button
                            type="button"
                            onClick={() => handleMover(index, -1)}
                            disabled={index === 0 || operandoCamino}
                            aria-label="Subir posición"
                            title="Subir posición"
                            className="flex h-8 w-8 items-center justify-center rounded-lg border-[1.5px] border-brand-border text-brand-night/60 hover:border-brand-blue hover:text-brand-blue disabled:cursor-not-allowed disabled:opacity-30"
                          >
                            ↑
                          </button>
                          <button
                            type="button"
                            onClick={() => handleMover(index, 1)}
                            disabled={index === lista.length - 1 || operandoCamino}
                            aria-label="Bajar posición"
                            title="Bajar posición"
                            className="flex h-8 w-8 items-center justify-center rounded-lg border-[1.5px] border-brand-border text-brand-night/60 hover:border-brand-blue hover:text-brand-blue disabled:cursor-not-allowed disabled:opacity-30"
                          >
                            ↓
                          </button>
                          <button
                            type="button"
                            onClick={() =>
                              overridesAbiertoId === posicion.id
                                ? cerrarOverrides()
                                : abrirOverrides(posicion)
                            }
                            className="rounded-lg border-[1.5px] border-brand-border px-3 py-2 text-xs font-semibold text-brand-night/60 hover:border-brand-blue hover:text-brand-blue"
                          >
                            {overridesAbiertoId === posicion.id ? 'Cerrar overrides' : 'Overrides'}
                          </button>
                          <button
                            type="button"
                            onClick={() => handleQuitar(posicion)}
                            disabled={quitandoIds.has(posicion.id) || operandoCamino}
                            title="Quitar del camino"
                            className="rounded-lg border-[1.5px] border-brand-border px-3 py-2 text-xs font-semibold text-brand-night/60 hover:border-brand-error hover:text-brand-error disabled:cursor-not-allowed disabled:opacity-40"
                          >
                            Quitar
                          </button>
                        </div>
                      </td>
                    </tr>
                    {overridesAbiertoId === posicion.id && overridesForm && defaults && (
                      <PanelOverrides
                        key={`${posicion.id}-overrides`}
                        form={overridesForm}
                        defaults={defaults[posicion.dificultad]}
                        error={overridesError}
                        guardando={guardandoOverrides}
                        onChange={setOverridesForm}
                        onGuardar={() => handleGuardarOverrides(posicion)}
                        onCancelar={cerrarOverrides}
                      />
                    )}
                  </Fragment>
                ))}
              </tbody>
            </table>
          </>
        )}
      </div>
    </div>
  )
}
