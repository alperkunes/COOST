import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { AppShell } from './layout/AppShell'
import { DashboardPage } from '../modules/dashboard/pages/DashboardPage'
import { FinancePage } from '../modules/finance/pages/FinancePage'
import { SupplierPage } from '../modules/suppliers/pages/SupplierPage'
import { RequireAccess } from '../shared/access/RequireAccess'
import { PlaceholderPage } from '../shared/ui/PlaceholderPage'

export function AppRouter() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<AppShell />}>
          <Route index element={<DashboardPage />} />

          <Route
            path="assistant"
            element={
              <RequireAccess
                requiredModule="assistant"
                requiredPermission="assistant.read"
              >
                <PlaceholderPage />
              </RequireAccess>
            }
          />

          <Route
            path="finance"
            element={
              <RequireAccess
                requiredModule="finance"
                requiredPermission="finance.read"
              >
                <FinancePage />
              </RequireAccess>
            }
          />

          <Route
            path="suppliers"
            element={
              <RequireAccess
                requiredModule="suppliers"
                requiredPermission="suppliers.read"
              >
                <SupplierPage />
              </RequireAccess>
            }
          />

          <Route
            path="checks"
            element={
              <RequireAccess
                requiredModule="checks"
                requiredPermission="checks.read"
              >
                <PlaceholderPage />
              </RequireAccess>
            }
          />

          <Route
            path="inventory"
            element={
              <RequireAccess
                requiredModule="inventory"
                requiredPermission="inventory.read"
              >
                <PlaceholderPage />
              </RequireAccess>
            }
          />

          <Route
            path="purchasing"
            element={
              <RequireAccess
                requiredModule="purchasing"
                requiredPermission="purchasing.read"
              >
                <PlaceholderPage />
              </RequireAccess>
            }
          />

          <Route
            path="staff"
            element={
              <RequireAccess
                requiredModule="staff"
                requiredPermission="staff.read"
              >
                <PlaceholderPage />
              </RequireAccess>
            }
          />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
