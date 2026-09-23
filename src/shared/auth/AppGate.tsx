import type { ReactNode } from 'react'
import { useAuth } from './useAuth'
import { LoginPage } from './LoginPage'
import { useTenant } from '../tenant/useTenant'

type AppGateProps = {
  children: ReactNode
}

export function AppGate({
  children,
}: AppGateProps) {
  const {
    user,
    loading: authLoading,
  } = useAuth()

  const {
    tenantIds,
    context,
    loading: tenantLoading,
    error: tenantError,
  } = useTenant()

  if (authLoading) {
    return (
      <StatusScreen message="Oturum kontrol ediliyor..." />
    )
  }

  if (!user) {
    return <LoginPage />
  }

  if (tenantLoading) {
    return (
      <StatusScreen message="İşletme yetkileri yükleniyor..." />
    )
  }

  if (tenantError) {
    return (
      <StatusScreen
        message="İşletme yetkileri yüklenemedi."
        detail={tenantError}
      />
    )
  }

  if (tenantIds.length === 0) {
    return (
      <StatusScreen
        message="Bu hesaba aktif bir işletme atanmamış."
        detail="Sistem yöneticinizden işletme üyeliğinizi kontrol etmesini isteyin."
      />
    )
  }

  if (!context) {
    return (
      <StatusScreen message="İşletme erişimi doğrulanamadı." />
    )
  }

  return children
}

type StatusScreenProps = {
  message: string
  detail?: string
}

function StatusScreen({
  message,
  detail,
}: StatusScreenProps) {
  return (
    <main className="auth-screen">
      <section className="auth-card auth-status-card">
        <div className="auth-brand">
          <div className="brand-mark">C</div>

          <div>
            <strong>COOST</strong>
            <span>İşletme Yönetim Asistanı</span>
          </div>
        </div>

        <div className="auth-heading">
          <span className="eyebrow">COOST</span>
          <h1>{message}</h1>

          {detail ? <p>{detail}</p> : null}
        </div>
      </section>
    </main>
  )
}