import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Routes, Route } from 'react-router-dom'
import { PanelLayout } from './PanelLayout'
import { RequireAuth } from './RequireAuth'

const signOut = vi.fn()
const getSession = vi.fn()
const from = vi.fn()
const authCallbacks: Array<(event: string, session: unknown) => void> = []
const onAuthStateChange = vi.fn((callback: (event: string, session: unknown) => void) => {
  authCallbacks.push(callback)
  return { data: { subscription: { unsubscribe: vi.fn() } } }
})

vi.mock('../lib/supabaseClient', () => ({
  supabase: {
    auth: {
      signOut: (...args: unknown[]) => signOut(...args),
      getSession: (...args: unknown[]) => getSession(...args),
      onAuthStateChange: (...args: Parameters<typeof onAuthStateChange>) =>
        onAuthStateChange(...args),
    },
    from: (...args: unknown[]) => from(...args),
  },
}))

function mockProfileNombre(nombre: string) {
  from.mockReturnValue({
    select: () => ({
      eq: () => ({
        single: () => Promise.resolve({ data: { nombre }, error: null }),
      }),
    }),
  })
}

function renderLayout() {
  return render(
    <MemoryRouter>
      <PanelLayout>
        <div>Contenido de Home</div>
      </PanelLayout>
    </MemoryRouter>,
  )
}

beforeEach(() => {
  signOut.mockReset().mockResolvedValue({ error: null })
  getSession.mockReset().mockResolvedValue({ data: { session: { user: { id: 'admin-1' } } } })
  onAuthStateChange.mockClear()
  authCallbacks.length = 0
  from.mockReset()
  mockProfileNombre('Valoe Márquez')
})

describe('PanelLayout', () => {
  it('muestra la navegación con los 5 enlaces, solo Home, Jugadores, Temáticas y Preguntas/Desafíos navegables', () => {
    renderLayout()

    for (const label of ['Home', 'Jugadores', 'Ranking', 'Temáticas', 'Preguntas/Desafíos']) {
      expect(screen.getByText(label)).toBeInTheDocument()
    }
    expect(screen.queryByText('Niveles')).not.toBeInTheDocument()

    expect(screen.getByRole('link', { name: 'Home' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Jugadores' })).toHaveAttribute('href', '/jugadores')
    expect(screen.getByRole('link', { name: 'Temáticas' })).toHaveAttribute('href', '/tematicas')
    expect(screen.getByRole('link', { name: 'Preguntas/Desafíos' })).toHaveAttribute(
      'href',
      '/preguntas',
    )
    const ranking = screen.getByText('Ranking')
    expect(ranking.tagName).not.toBe('A')
    expect(ranking).toHaveAttribute('aria-disabled', 'true')
  })

  it('muestra el nombre del admin en el header', async () => {
    renderLayout()

    expect(await screen.findByText('Valoe Márquez')).toBeInTheDocument()
  })

  it('cierra sesión al hacer click y el panel redirige a login', async () => {
    const user = userEvent.setup()
    render(
      <MemoryRouter initialEntries={['/']}>
        <Routes>
          <Route
            path="/"
            element={
              <RequireAuth>
                <PanelLayout>
                  <div>Contenido de Home</div>
                </PanelLayout>
              </RequireAuth>
            }
          />
          <Route path="/login" element={<div>Pantalla de login</div>} />
        </Routes>
      </MemoryRouter>,
    )

    await screen.findByText('Contenido de Home')

    await user.click(screen.getByRole('button', { name: /cerrar sesión/i }))
    expect(signOut).toHaveBeenCalled()

    // Simula la notificación real de Supabase a los suscriptores tras el signOut.
    authCallbacks.forEach((callback) => callback('SIGNED_OUT', null))

    expect(await screen.findByText(/pantalla de login/i)).toBeInTheDocument()
  })
})
