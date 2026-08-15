import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import { PanelLayout } from './PanelLayout'

const signOut = vi.fn()

vi.mock('../lib/supabaseClient', () => ({
  supabase: {
    auth: {
      signOut: (...args: unknown[]) => signOut(...args),
    },
  },
}))

vi.mock('../lib/useAdminProfile', () => ({
  useAdminProfile: () => ({ nombre: 'Valoe Márquez', loading: false }),
}))

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
})

describe('PanelLayout', () => {
  it('muestra la navegación con los 6 enlaces, solo Home navegable', () => {
    renderLayout()

    for (const label of [
      'Home',
      'Jugadores',
      'Ranking',
      'Temáticas',
      'Niveles',
      'Preguntas/Desafíos',
    ]) {
      expect(screen.getByText(label)).toBeInTheDocument()
    }

    expect(screen.getByRole('link', { name: 'Home' })).toBeInTheDocument()
    for (const label of ['Jugadores', 'Ranking', 'Temáticas', 'Niveles', 'Preguntas/Desafíos']) {
      const item = screen.getByText(label)
      expect(item.tagName).not.toBe('A')
      expect(item).toHaveAttribute('aria-disabled', 'true')
    }
  })

  it('muestra el nombre del admin en el header', () => {
    renderLayout()

    expect(screen.getByText('Valoe Márquez')).toBeInTheDocument()
  })

  it('cierra sesión al hacer click en "Cerrar sesión"', async () => {
    const user = userEvent.setup()
    renderLayout()

    await user.click(screen.getByRole('button', { name: /cerrar sesión/i }))

    expect(signOut).toHaveBeenCalled()
  })
})
