import { useEffect, useState } from 'react'
import { DIFICULTAD_LABEL } from '../lib/dificultad'
import {
  fetchDificultadDefaults,
  fetchUmbralesParada,
  guardarDificultadDefault,
  type DificultadDefault,
  type UmbralesParada,
} from '../lib/dificultadDefaults'

const CAMPO_BASE =
  'h-10 w-24 rounded-lg border-[1.5px] border-brand-border bg-white px-2.5 text-sm text-brand-night outline-none tabular-nums focus:border-brand-teal focus:ring-4 focus:ring-brand-teal/15'
const CAMPO_ERROR = 'border-[#E0454A] bg-[#FFF8F8] focus:border-[#E0454A] focus:ring-[#E0454A]/15'

interface FormFila {
  preguntasPorPartida: string
  segundosPorDesafio: string
}

function aForm(fila: DificultadDefault): FormFila {
  return {
    preguntasPorPartida: String(fila.preguntasPorPartida),
    segundosPorDesafio: String(fila.segundosPorDesafio),
  }
}

function CampoNumero({
  label,
  valor,
  onChange,
  error,
}: {
  label: string
  valor: string
  onChange: (valor: string) => void
  error?: boolean
}) {
  return (
    <label className="flex flex-col gap-1">
      <span className="text-[11px] font-semibold tracking-wide text-brand-night/50 uppercase">
        {label}
      </span>
      <input
        type="number"
        min={1}
        step={1}
        value={valor}
        onChange={(e) => onChange(e.target.value)}
        className={`${CAMPO_BASE} ${error ? CAMPO_ERROR : ''}`}
      />
    </label>
  )
}

function BloqueUmbrales({ umbrales }: { umbrales: UmbralesParada | null }) {
  if (!umbrales) {
    return <p className="text-xs text-brand-night/40">Calculando…</p>
  }
  const pct = (valor: number) => Math.round((valor / umbrales.maximo) * 100)
  return (
    <dl className="grid grid-cols-2 gap-x-3 gap-y-0.5 text-xs tabular-nums text-brand-night/70">
      <dt className="text-brand-night/45">Máximo</dt>
      <dd className="text-right font-semibold">{umbrales.maximo.toLocaleString('es-ES')}</dd>
      <dt className="text-brand-night/45">★1 · superar</dt>
      <dd className="text-right">
        {umbrales.minimo.toLocaleString('es-ES')} · {pct(umbrales.minimo)}%
      </dd>
      <dt className="text-brand-night/45">★2</dt>
      <dd className="text-right">
        {umbrales.umbralEstrella2.toLocaleString('es-ES')} · {pct(umbrales.umbralEstrella2)}%
      </dd>
      <dt className="text-brand-night/45">★3</dt>
      <dd className="text-right">
        {umbrales.umbralEstrella3.toLocaleString('es-ES')} · {pct(umbrales.umbralEstrella3)}%
      </dd>
    </dl>
  )
}

function FilaDificultad({
  fila,
  form,
  error,
  guardando,
  onChange,
  onGuardar,
}: {
  fila: DificultadDefault
  form: FormFila
  error?: string
  guardando: boolean
  onChange: (form: FormFila) => void
  onGuardar: () => void
}) {
  const [umbrales, setUmbrales] = useState<UmbralesParada | null>(null)

  useEffect(() => {
    const preguntas = Number(form.preguntasPorPartida)
    if (!Number.isInteger(preguntas) || preguntas <= 0) {
      setUmbrales(null)
      return
    }

    let cancelado = false
    const timeout = setTimeout(() => {
      fetchUmbralesParada(fila.dificultad, preguntas)
        .then((resultado) => {
          if (!cancelado) setUmbrales(resultado)
        })
        .catch((umbralesError: unknown) => {
          console.error('Error calculando los umbrales derivados:', umbralesError)
        })
    }, 250)

    return () => {
      cancelado = true
      clearTimeout(timeout)
    }
  }, [fila.dificultad, form.preguntasPorPartida])

  return (
    <tr className="border-b border-brand-base last:border-0">
      <td className="px-4 py-3.5 align-top">
        <span className="text-sm font-semibold text-brand-night">
          {DIFICULTAD_LABEL[fila.dificultad]}
        </span>
      </td>
      <td className="px-4 py-3.5 align-top">
        <CampoNumero
          label="Preguntas/partida"
          valor={form.preguntasPorPartida}
          onChange={(v) => onChange({ ...form, preguntasPorPartida: v })}
        />
      </td>
      <td className="px-4 py-3.5 align-top">
        <CampoNumero
          label="Segundos/pregunta"
          valor={form.segundosPorDesafio}
          onChange={(v) => onChange({ ...form, segundosPorDesafio: v })}
        />
      </td>
      <td className="px-4 py-3.5 align-top">
        <BloqueUmbrales umbrales={umbrales} />
      </td>
      <td className="px-4 py-3.5 align-top">
        <button
          type="button"
          onClick={onGuardar}
          disabled={guardando}
          className="h-10 rounded-lg border-[1.5px] border-brand-border px-4 text-sm font-semibold text-brand-blue hover:border-brand-blue disabled:cursor-not-allowed disabled:opacity-50"
        >
          {guardando ? 'Guardando…' : 'Guardar'}
        </button>
        {error && <p className="mt-1.5 max-w-[220px] text-[11px] text-[#B3282D]">{error}</p>}
      </td>
    </tr>
  )
}

export function DificultadDefaults() {
  const [filas, setFilas] = useState<DificultadDefault[] | null>(null)
  const [error, setError] = useState('')
  const [formPorDificultad, setFormPorDificultad] = useState<Record<string, FormFila>>({})
  const [erroresPorDificultad, setErroresPorDificultad] = useState<Record<string, string>>({})
  const [guardandoDificultad, setGuardandoDificultad] = useState<string | null>(null)

  useEffect(() => {
    fetchDificultadDefaults()
      .then((resultado) => {
        setFilas(resultado)
        setFormPorDificultad(
          Object.fromEntries(resultado.map((fila) => [fila.dificultad, aForm(fila)])),
        )
      })
      .catch((cargaError: unknown) => {
        console.error('Error cargando los valores por defecto de dificultad:', cargaError)
        setError('No se han podido cargar los valores por defecto.')
      })
  }, [])

  if (error) {
    return (
      <div className="rounded-2xl border border-brand-error/40 bg-brand-error/10 p-5 text-sm text-[#B3282D]">
        {error}
      </div>
    )
  }

  async function handleGuardar(fila: DificultadDefault) {
    const form = formPorDificultad[fila.dificultad]
    const numeros = {
      preguntasPorPartida: Number(form.preguntasPorPartida),
      segundosPorDesafio: Number(form.segundosPorDesafio),
    }

    setGuardandoDificultad(fila.dificultad)
    try {
      await guardarDificultadDefault({ dificultad: fila.dificultad, ...numeros })
      setFilas(
        (actual) =>
          actual?.map((f) => (f.dificultad === fila.dificultad ? { ...f, ...numeros } : f)) ??
          actual,
      )
      setErroresPorDificultad((actual) => {
        if (!(fila.dificultad in actual)) return actual
        const resto = { ...actual }
        delete resto[fila.dificultad]
        return resto
      })
    } catch (guardarError) {
      setErroresPorDificultad((actual) => ({
        ...actual,
        [fila.dificultad]:
          guardarError instanceof Error ? guardarError.message : 'No se ha podido guardar.',
      }))
    } finally {
      setGuardandoDificultad(null)
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="font-display text-3xl font-extrabold tracking-tight text-brand-night">
          Valores por defecto de dificultad
        </h1>
        <p className="mt-1.5 text-sm text-brand-night/55">
          Se aplican a toda parada del camino que no tenga un override propio en ese campo. Los
          umbrales de estrellas se derivan de estos valores y no son editables.
        </p>
      </div>

      <div className="overflow-auto rounded-2xl border border-brand-border bg-white">
        <table className="w-full border-collapse text-left">
          <thead>
            <tr className="border-b border-brand-border bg-brand-base/60 text-[11px] font-semibold tracking-wider text-brand-night/45 uppercase">
              <th className="px-4 py-3 font-semibold">Dificultad</th>
              <th className="px-4 py-3 font-semibold">Preguntas/partida</th>
              <th className="px-4 py-3 font-semibold">Segundos/pregunta</th>
              <th className="px-4 py-3 font-semibold">Umbrales derivados</th>
              <th className="px-4 py-3 font-semibold" />
            </tr>
          </thead>
          <tbody>
            {(filas ?? []).map((fila) => (
              <FilaDificultad
                key={fila.dificultad}
                fila={fila}
                form={formPorDificultad[fila.dificultad] ?? aForm(fila)}
                error={erroresPorDificultad[fila.dificultad]}
                guardando={guardandoDificultad === fila.dificultad}
                onChange={(form) =>
                  setFormPorDificultad((actual) => ({ ...actual, [fila.dificultad]: form }))
                }
                onGuardar={() => handleGuardar(fila)}
              />
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
