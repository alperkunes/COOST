import { NavLink, Outlet } from 'react-router-dom'
import {
  BadgeDollarSign,
  Building2,
  CheckCircle2,
  ChevronDown,
  Landmark,
  LayoutDashboard,
  LogOut,
  MessageCircle,
  PackageOpen,
  ReceiptText,
  ShoppingCart,
  Sparkles,
  UsersRound,
  type LucideIcon,
} from 'lucide-react'
import { appNavigation } from '../../core/navigation/appNavigation'
import { useAuth } from '../../shared/auth/useAuth'
import { useTenant } from '../../shared/tenant/useTenant'

const navigationIcons: Record<string, LucideIcon> = {
  '/': LayoutDashboard,
  '/assistant': MessageCircle,
  '/finance': Landmark,
  '/suppliers': Building2,
  '/checks': ReceiptText,
  '/inventory': PackageOpen,
  '/purchasing': ShoppingCart,
  '/staff': UsersRound,
}

export function AppShell() {
  const { signOut } = useAuth()
  const { tenantName } = useTenant()

  const handleSignOut = () => {
    void signOut().catch((error) => {
      console.error('Failed to sign out:', error)
    })
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand-block">
          <div className="brand-mark">C</div>

          <div className="brand-copy">
            <strong>COOST</strong>
            <span>İşletme Yönetim Asistanı</span>
          </div>
        </div>

        <nav className="sidebar-nav" aria-label="Ana navigasyon">
          {appNavigation.map((section) => (
            <div className="nav-section" key={section.label}>
              <span className="nav-section-title">{section.label}</span>

              {section.items.map((item) => {
                const Icon =
                  navigationIcons[item.path] ?? BadgeDollarSign

                return (
                  <NavLink
                    className={({ isActive }) =>
                      `nav-item${isActive ? ' active' : ''}`
                    }
                    end={item.path === '/'}
                    key={item.path}
                    to={item.path}
                  >
                    <Icon size={19} strokeWidth={1.8} />
                    <span>{item.label}</span>
                  </NavLink>
                )
              })}
            </div>
          ))}
        </nav>

        <div className="sidebar-footer">
          <Sparkles size={14} />
          <span>COOST v1 Foundation</span>
        </div>
      </aside>

      <div className="workspace">
        <header className="topbar">
          <button className="workspace-selector" type="button">
            <span>
              <small>AKTİF İŞLETME</small>
              <strong>{tenantName ?? 'İşletme'}</strong>
            </span>

            <ChevronDown size={17} />
          </button>

          <div className="topbar-actions">
            <div className="topbar-status">
              <CheckCircle2 size={16} />
              <span>Sistem hazır</span>
            </div>

            <button
              className="sign-out-button"
              onClick={handleSignOut}
              type="button"
            >
              <LogOut size={16} />
              <span>Çıkış</span>
            </button>
          </div>
        </header>

        <main className="content">
          <Outlet />
        </main>
      </div>
    </div>
  )
}