import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import { Login } from './Login'

const signInWithPassword = vi.fn()
const getSession = vi.fn()
const onAuthStateChange = vi.fn()
const navigate = vi.fn()

vi.mock('../lib/supabaseClient', () => ({
  supabase: {
    auth: {
      signInWithPassword: (...args: unknown[]) => signInWithPassword(...args),
      getSession: (...args: unknown[]) => getSession(...args),
      onAuthStateChange: (...args: unknown[]) => onAuthStateChange(...args),
    },
  },
}))

vi.mock('react-router-dom', async (importOriginal) => {
  const actual = await importOriginal<typeof import('react-router-dom')>()
  return {
    ...actual,
    useNavigate: () => navigate,
  }
})

function renderLogin() {
  return render(
    <MemoryRouter>
      <Login />
    </MemoryRouter>,
  )
}

describe('Login', () => {
  beforeEach(() => {
    signInWithPassword.mockReset()
    navigate.mockReset()
    getSession.mockReset().mockResolvedValue({ data: { session: null } })
    onAuthStateChange.mockReset().mockReturnValue({
      data: { subscription: { unsubscribe: vi.fn() } },
    })
  })

  it('muestra el formulario con email y contraseña, sin opción de registro', () => {
    renderLogin()

    expect(screen.getByLabelText(/correo electrónico/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/contraseña/i)).toBeInTheDocument()
    expect(screen.queryByText(/regístrate|crear cuenta/i)).not.toBeInTheDocument()
  })

  it('valida que email y contraseña no estén vacíos sin llamar a Supabase Auth', async () => {
    const user = userEvent.setup()
    renderLogin()

    await user.click(screen.getByRole('button', { name: /entrar al panel/i }))

    expect(await screen.findByText(/introduce email y contraseña/i)).toBeInTheDocument()
    expect(signInWithPassword).not.toHaveBeenCalled()
  })

  it('rechaza una contraseña compuesta solo por espacios en blanco', async () => {
    const user = userEvent.setup()
    renderLogin()

    await user.type(screen.getByLabelText(/correo electrónico/i), 'admin@geoquest.app')
    await user.type(screen.getByLabelText(/contraseña/i), '   ')
    await user.click(screen.getByRole('button', { name: /entrar al panel/i }))

    expect(await screen.findByText(/introduce email y contraseña/i)).toBeInTheDocument()
    expect(signInWithPassword).not.toHaveBeenCalled()
  })

  it('muestra un error explícito en credenciales inválidas y no navega', async () => {
    signInWithPassword.mockResolvedValue({ error: { message: 'Invalid login credentials' } })
    const user = userEvent.setup()
    renderLogin()

    await user.type(screen.getByLabelText(/correo electrónico/i), 'admin@geoquest.app')
    await user.type(screen.getByLabelText(/contraseña/i), 'wrong-password')
    await user.click(screen.getByRole('button', { name: /entrar al panel/i }))

    expect(await screen.findByText(/incorrectos/i)).toBeInTheDocument()
    expect(navigate).not.toHaveBeenCalled()
  })

  it('muestra un error genérico si la llamada a Supabase falla inesperadamente', async () => {
    signInWithPassword.mockRejectedValue(new Error('network down'))
    const user = userEvent.setup()
    renderLogin()

    await user.type(screen.getByLabelText(/correo electrónico/i), 'admin@geoquest.app')
    await user.type(screen.getByLabelText(/contraseña/i), 'correct-password')
    await user.click(screen.getByRole('button', { name: /entrar al panel/i }))

    expect(await screen.findByText(/no se ha podido conectar/i)).toBeInTheDocument()
    expect(navigate).not.toHaveBeenCalled()
  })

  it('redirige a Home tras un login correcto', async () => {
    signInWithPassword.mockResolvedValue({ error: null })
    const user = userEvent.setup()
    renderLogin()

    await user.type(screen.getByLabelText(/correo electrónico/i), 'admin@geoquest.app')
    await user.type(screen.getByLabelText(/contraseña/i), 'correct-password')
    await user.click(screen.getByRole('button', { name: /entrar al panel/i }))

    await waitFor(() => expect(navigate).toHaveBeenCalledWith('/', { replace: true }))
  })

  it('redirige a Home si ya hay una sesión activa', async () => {
    getSession.mockResolvedValue({ data: { session: { user: { id: '1' } } } })
    renderLogin()

    await waitFor(() => expect(navigate).toHaveBeenCalledWith('/', { replace: true }))
  })
})
