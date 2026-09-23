import {
  ArrowRight,
  LayoutDashboard,
  ShieldCheck,
  Sparkles,
} from 'lucide-react'

export function DashboardPage() {
  return (
    <section className="dashboard-page">
      <div className="page-heading">
        <span className="eyebrow">COOST</span>
        <h1>İşletme Özeti</h1>
        <p>
          Finans, operasyon ve yönetim sinyalleri burada tek bir noktada
          birleşecek.
        </p>
      </div>

      <div className="dashboard-grid">
        <article className="dashboard-card">
          <div className="card-icon card-icon-blue">
            <LayoutDashboard size={23} />
          </div>

          <div className="card-content">
            <span>BUGÜN</span>
            <strong>Foundation aktif</strong>
            <p>COOST uygulama kabuğu çalışıyor.</p>
          </div>

          <button
            className="card-action"
            type="button"
            aria-label="Detaya git"
          >
            <ArrowRight size={18} />
          </button>
        </article>

        <article className="dashboard-card">
          <div className="card-icon card-icon-purple">
            <Sparkles size={23} />
          </div>

          <div className="card-content">
            <span>ASİSTAN</span>
            <strong>Hazırlanıyor</strong>
            <p>
              Karar ve aksiyon motorları sonraki aşamalarda bağlanacak.
            </p>
          </div>

          <button
            className="card-action"
            type="button"
            aria-label="Detaya git"
          >
            <ArrowRight size={18} />
          </button>
        </article>

        <article className="dashboard-card">
          <div className="card-icon card-icon-green">
            <ShieldCheck size={23} />
          </div>

          <div className="card-content">
            <span>SİSTEM</span>
            <strong>Güvenlik altyapısı aktif</strong>
            <p>
              Tenant izolasyonu, RLS ve kullanıcı yetkilendirmesi
              staging ortamında doğrulandı.
            </p>
          </div>

          <button
            className="card-action"
            type="button"
            aria-label="Detaya git"
          >
            <ArrowRight size={18} />
          </button>
        </article>
      </div>
    </section>
  )
}