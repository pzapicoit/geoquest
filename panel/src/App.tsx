import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { RequireAuth } from './components/RequireAuth'
import { PanelLayout } from './components/PanelLayout'
import { Login } from './pages/Login'
import { Home } from './pages/Home'
import { Preguntas } from './pages/Preguntas'
import { PreguntaForm } from './pages/PreguntaForm'
import { NivelRecorrido } from './pages/NivelRecorrido'
import { Tematicas } from './pages/Tematicas'
import { NivelesTematica } from './pages/NivelesTematica'
import { Camino } from './pages/Camino'

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
          path="/tematicas"
          element={
            <RequireAuth>
              <PanelLayout>
                <Tematicas />
              </PanelLayout>
            </RequireAuth>
          }
        />
        <Route
          path="/tematicas/:id/niveles"
          element={
            <RequireAuth>
              <PanelLayout>
                <NivelesTematica />
              </PanelLayout>
            </RequireAuth>
          }
        />
        <Route
          path="/camino"
          element={
            <RequireAuth>
              <PanelLayout>
                <Camino />
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
        <Route
          path="/preguntas/nueva"
          element={
            <RequireAuth>
              <PanelLayout>
                <PreguntaForm />
              </PanelLayout>
            </RequireAuth>
          }
        />
        <Route
          path="/preguntas/:id/editar"
          element={
            <RequireAuth>
              <PanelLayout>
                <PreguntaForm />
              </PanelLayout>
            </RequireAuth>
          }
        />
        <Route
          path="/niveles/:id"
          element={
            <RequireAuth>
              <PanelLayout>
                <NivelRecorrido />
              </PanelLayout>
            </RequireAuth>
          }
        />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}
