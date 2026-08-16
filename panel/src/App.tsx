import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { RequireAuth } from './components/RequireAuth'
import { PanelLayout } from './components/PanelLayout'
import { Login } from './pages/Login'
import { Home } from './pages/Home'
import { Preguntas } from './pages/Preguntas'

export function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route
          path="/"
          element={
            <RequireAuth>
              <PanelLayout>
                <Home />
              </PanelLayout>
            </RequireAuth>
          }
        />
        <Route
          path="/preguntas"
          element={
            <RequireAuth>
              <PanelLayout>
                <Preguntas />
              </PanelLayout>
            </RequireAuth>
          }
        />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}
