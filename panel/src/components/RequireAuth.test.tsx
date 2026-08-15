import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import { MemoryRouter, Routes, Route } from 'react-router-dom'
import { RequireAuth } from './RequireAuth'

const getSession = vi.fn()
const onAuthStateChange = vi.fn()

vi.mock('../lib/supabaseClient', () => ({
  supabase: {
    auth: {
      getSession: (...args: unknown[]) => getSession(...args),
      onAuthStateChange: (...args: unknown[]) => onAuthStateChange(...args),
    },
  },
}))

function renderProtected() {
  return render(
    <MemoryRouter initialEntries={['/']}>
      <Routes>
        <Route
          path="/"
          element={
            <RequireAuth>
              <div>Contenido protegido</div>
            </RequireAuth>
          }
        />
        <Route path="/login" element={<div>Pantalla de login</div>} />
      </Routes>
    </MemoryRouter>,
  )
}

describe('RequireAuth', () => {
  it('redirige a /login cuando no hay sesión', async () => {
    getSession.mockResolvedValue({ data: { session: null } })
    onAuthStateChange.mockReturnValue({ data: { subscription: { unsubscribe: vi.fn() } } })

    renderProtected()

    expect(await screen.findByText(/pantalla de login/i)).toBeInTheDocument()
  })

  it('muestra el contenido protegido cuando hay sesión', async () => {
    getSession.mockResolvedValue({ data: { session: { user: { id: '1' } } } })
    onAuthStateChange.mockReturnValue({ data: { subscription: { unsubscribe: vi.fn() } } })

    renderProtected()

    expect(await screen.findByText(/contenido protegido/i)).toBeInTheDocument()
  })
})
