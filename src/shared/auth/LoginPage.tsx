import {
  useState,
  type FormEvent,
} from 'react'
import { LogIn } from 'lucide-react'
import { supabase } from '../supabase/client'

export function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(
    event: FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault()

    if (!email.trim() || !password) {
      setError('E-posta ve şifre zorunludur.')
      return
    }

    setSubmitting(true)
    setError(null)

    const { error: signInError } =
      await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      })

    if (signInError) {
      setError(
        'Giriş yapılamadı. E-posta ve şifrenizi kontrol edin.',
      )
      setSubmitting(false)
      return
    }

    setSubmitting(false)
  }

  return (
    <main className="auth-screen">
      <section
        className="auth-card"
        aria-labelledby="login-title"
      >
        <div className="auth-brand">
          <div className="brand-mark">C</div>

          <div>
            <strong>COOST</strong>
            <span>İşletme Yönetim Asistanı</span>
          </div>
        </div>

        <div className="auth-heading">
          <span className="eyebrow">GÜVENLİ GİRİŞ</span>
          <h1 id="login-title">Hesabınıza giriş yapın</h1>
          <p>
            COOST yönetim paneline erişmek için
            yetkili kullanıcı bilgilerinizle giriş yapın.
          </p>
        </div>

        <form
          className="auth-form"
          onSubmit={handleSubmit}
        >
          <label>
            <span>E-posta</span>
            <input
              autoComplete="email"
              disabled={submitting}
              onChange={(event) =>
                setEmail(event.target.value)
              }
              placeholder="ornek@firma.com"
              type="email"
              value={email}
            />
          </label>

          <label>
            <span>Şifre</span>
            <input
              autoComplete="current-password"
              disabled={submitting}
              onChange={(event) =>
                setPassword(event.target.value)
              }
              type="password"
              value={password}
            />
          </label>

          {error ? (
            <div
              className="auth-error"
              role="alert"
            >
              {error}
            </div>
          ) : null}

          <button
            className="auth-submit"
            disabled={submitting}
            type="submit"
          >
            <LogIn size={18} />
            <span>
              {submitting
                ? 'Giriş yapılıyor...'
                : 'Giriş yap'}
            </span>
          </button>
        </form>

        <p className="auth-security-note">
          Yetkisiz erişim engellenir ve işletme verileri
          kullanıcı yetkilerine göre izole edilir.
        </p>
      </section>
    </main>
  )
}