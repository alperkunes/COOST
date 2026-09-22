import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { AppShell } from './layout/AppShell'
import { DashboardPage } from '../modules/dashboard/pages/DashboardPage'
import { PlaceholderPage } from '../shared/ui/PlaceholderPage'

export function AppRouter() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<AppShell />}>
          <Route index element={<DashboardPage />} />
          <Route path="assistant" element={<PlaceholderPage />} />
          <Route path="finance" element={<PlaceholderPage />} />
          <Route path="suppliers" element={<PlaceholderPage />} />
          <Route path="checks" element={<PlaceholderPage />} />
          <Route path="inventory" element={<PlaceholderPage />} />
          <Route path="purchasing" element={<PlaceholderPage />} />
          <Route path="staff" element={<PlaceholderPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}