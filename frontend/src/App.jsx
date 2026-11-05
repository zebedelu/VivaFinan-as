import { Link, Route, Routes } from 'react-router-dom'
import AppShell from './components/AppShell'
import ProtectedRoute from './components/ProtectedRoute'
import Dashboard from './pages/Dashboard'
import Individual from './pages/Individual'
import Invite from './pages/Invite'
import JevAI from './pages/JevAI'
import Banking from './pages/Banking'
import Forecast from './pages/Forecast'
import Goals from './pages/Goals'
import Login from './pages/Login'
import Onboarding from './pages/Onboarding'
import Recurring from './pages/Recurring'
import ResetPassword from './pages/ResetPassword'
import Settings from './pages/Settings'
import Transactions from './pages/Transactions'

function NotFound() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-areia px-6">
      <div className="text-center">
        <p className="font-display text-5xl text-verde-texto">404</p>
        <h1 className="mt-2 font-display text-2xl">Essa página não existe</h1>
        <p className="mt-2 text-sm text-muted">Talvez o endereço tenha mudado. Volte para o painel.</p>
        <Link to="/" className="btn-primary mt-5 no-underline">
          Ir para o painel
        </Link>
      </div>
    </main>
  )
}

export default function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/reset-password" element={<ResetPassword />} />
      <Route path="/invite/:token" element={<Invite />} />
      <Route element={<ProtectedRoute />}>
        <Route path="/onboarding" element={<Onboarding />} />
        <Route element={<AppShell />}>
          <Route index element={<Dashboard />} />
          <Route path="/individual" element={<Individual />} />
          <Route path="/transactions" element={<Transactions />} />
          <Route path="/recurring" element={<Recurring />} />
          <Route path="/goals" element={<Goals />} />
          <Route path="/forecast" element={<Forecast />} />
          <Route path="/ai" element={<JevAI />} />
          <Route path="/banking" element={<Banking />} />
          <Route path="/settings" element={<Settings />} />
        </Route>
      </Route>
      <Route path="*" element={<NotFound />} />
    </Routes>
  )
}
