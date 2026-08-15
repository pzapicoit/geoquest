import { useEffect, useState, type FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'
import { useSession } from '../lib/useSession'

export function Login() {
  const navigate = useNavigate()
  const { session } = useSession()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (session) {
      navigate('/', { replace: true })
    }
  }, [session, navigate])

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()

    if (!email.trim() || !password.trim()) {
      setError('Introduce email y contraseña.')
      return
    }

    setLoading(true)
    setError('')

    try {
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      })

      if (signInError) {
        setError('Email o contraseña incorrectos.')
        return
      }

      navigate('/', { replace: true })
    } catch {
      setError('No se ha podido conectar. Inténtalo de nuevo.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="grid min-h-screen bg-brand-night lg:grid-cols-[1.05fr_1fr]">
      <div className="relative hidden overflow-hidden lg:block">
        <div
          className="absolute inset-0"
          style={{
            background:
              'radial-gradient(circle at 20% 20%, rgba(43,192,168,.18), transparent 55%), radial-gradient(circle at 80% 75%, rgba(27,111,168,.28), transparent 50%), #0E1620',
          }}
        />
        <div className="relative flex h-full flex-col justify-between p-11">
          <div className="flex items-center gap-2.5">
            <span className="font-display text-2xl font-extrabold tracking-tight text-white">
              Geo<span className="text-brand-teal">Quest</span>
            </span>
            <span className="ml-2 rounded-lg border border-white/20 bg-white/10 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.16em] text-white/70">
              Admin
            </span>
          </div>
          <div className="max-w-[430px]">
            <p className="text-balance font-display text-4xl font-extrabold leading-tight tracking-tight text-white">
              Panel de gestión del juego
            </p>
            <p className="mt-3.5 text-balance text-[15.5px] leading-relaxed text-white/60">
              Rutas, paradas, preguntas y jugadores. Todo el contenido de GeoQuest desde un solo
              sitio.
            </p>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-center bg-brand-base px-10 py-14">
        <div className="w-full max-w-[392px]">
          <p className="text-[10px] font-semibold uppercase tracking-[0.2em] text-brand-night/40">
            Acceso restringido
          </p>
          <h1 className="mt-4 font-display text-4xl font-extrabold tracking-tight text-brand-night">
            Iniciar sesión
          </h1>
          <p className="mt-2 mb-7 text-[15px] text-brand-night/55">
            Introduce tus credenciales de administrador.
          </p>

          <form onSubmit={handleSubmit} noValidate className="flex flex-col gap-[18px]">
            <label className="flex flex-col gap-2">
              <span className="text-xs font-semibold uppercase tracking-[0.08em] text-brand-night/60">
                Correo electrónico
              </span>
              <input
                type="email"
                value={email}
                onChange={(event) => {
                  setEmail(event.target.value)
                  setError('')
                }}
                autoComplete="username"
                placeholder="nombre.apellido@geoquest.app"
                className="w-full rounded-2xl border-[1.5px] border-brand-border bg-white px-[17px] py-[15px] text-base text-brand-night outline-none transition focus:border-brand-teal focus:ring-4 focus:ring-brand-teal/15"
              />
            </label>

            <label className="flex flex-col gap-2">
              <span className="text-xs font-semibold uppercase tracking-[0.08em] text-brand-night/60">
                Contraseña
              </span>
              <span className="relative block">
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(event) => {
                    setPassword(event.target.value)
                    setError('')
                  }}
                  autoComplete="current-password"
                  placeholder="••••••••"
                  className="w-full rounded-2xl border-[1.5px] border-brand-border bg-white py-[15px] pr-[62px] pl-[17px] text-base text-brand-night outline-none transition focus:border-brand-teal focus:ring-4 focus:ring-brand-teal/15"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((value) => !value)}
                  className="absolute top-1/2 right-2 -translate-y-1/2 rounded-lg px-2.5 py-2 text-[11px] font-semibold uppercase tracking-[0.1em] text-brand-blue hover:bg-brand-blue/10"
                >
                  {showPassword ? 'Ocultar' : 'Ver'}
                </button>
              </span>
            </label>

            {error && (
              <div className="flex items-center gap-2.5 rounded-xl border-[1.5px] border-brand-error/40 bg-brand-error/10 px-3.5 py-3 text-[13.5px] font-medium text-[#B3282D]">
                <span className="grid h-[18px] w-[18px] flex-none place-items-center rounded-full bg-brand-error text-xs font-bold text-white">
                  !
                </span>
                <span>{error}</span>
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="mt-2 rounded-2xl bg-gradient-to-r from-brand-teal to-brand-blue py-[17px] font-display text-lg font-extrabold text-white shadow-[0_5px_0_rgba(11,66,102,.45)] transition active:translate-y-[5px] active:shadow-none disabled:cursor-not-allowed disabled:opacity-70"
            >
              {loading ? 'Entrando…' : 'Entrar al panel'}
            </button>
          </form>

          <div className="mt-8 border-t border-brand-border pt-5">
            <p className="text-balance text-[12.5px] text-brand-night/45">
              ¿Problemas de acceso? Escribe a{' '}
              <a
                href="mailto:soporte@geoquest.app"
                className="text-brand-blue hover:text-brand-teal"
              >
                soporte@geoquest.app
              </a>
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
