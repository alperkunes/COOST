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
        <h1>Ä°ÅŸletme Ã–zeti</h1>
        <p>
          Finans, operasyon ve yÃ¶netim sinyalleri burada tek bir noktada
          birleÅŸecek.
        </p>
      </div>

      <div className="dashboard-grid">
        <article className="dashboard-card">
          <div className="card-icon card-icon-blue">
            <LayoutDashboard size={23} />
          </div>

          <div className="card-content">
            <span>BUGÃœN</span>
            <strong>Foundation aktif</strong>
            <p>COOST uygulama kabuÄŸu Ã§alÄ±ÅŸÄ±yor.</p>
          </div>

          <button className="card-action" type="button" aria-label="Detaya git">
            <ArrowRight size={18} />
          </button>
        </article>

        <article className="dashboard-card">
          <div className="card-icon card-icon-purple">
            <Sparkles size={23} />
          </div>

          <div className="card-content">
            <span>ASÄ°STAN</span>
            <strong>HazÄ±rlanÄ±yor</strong>
            <p>Karar ve aksiyon motorlarÄ± sonraki aÅŸamalarda baÄŸlanacak.</p>
          </div>

          <button className="card-action" type="button" aria-label="Detaya git">
            <ArrowRight size={18} />
          </button>
        </article>

        <article className="dashboard-card">
          <div className="card-icon card-icon-green">
            <ShieldCheck size={23} />
          </div>

          <div className="card-content">
            <span>SÄ°STEM</span>
            <strong>Temiz baÅŸlangÄ±Ã§</strong>
            <p>Tenant, yetki ve audit altyapÄ±sÄ± henÃ¼z eklenmedi.</p>
          </div>

          <button className="card-action" type="button" aria-label="Detaya git">
            <ArrowRight size={18} />
          </button>
        </article>
      </div>
    </section>
  )
}