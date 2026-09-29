import { useTenant } from '../../../shared/tenant/useTenant'
import { hasAccess } from '../../../core/access/accessUtils'
import { SalesAppPanel } from './SalesAppPanel'
import '../../finance/pages/FinancePage.css'
import './CostingPage.css'

export function SalesAppPage() {
  const { context } = useTenant()

  const canWrite =
    !!context &&
    hasAccess(context, {
      requiredModule: 'food-service',
      requiredPermission:
        'food-service.costing.write',
    })

  return (
    <section className="finance-page costing-page">
      <div className="finance-heading">
        <div>
          <span className="eyebrow">
            YÖNETİM
          </span>
          <h1>Satış Uygulaması</h1>
          <p>
            Entegrasyon · Ürün Eşleştirme ·
            Satış Aktarımı · Senkronizasyon
          </p>
        </div>
      </div>

      <SalesAppPanel
        canWrite={canWrite}
        standalone
      />
    </section>
  )
}
