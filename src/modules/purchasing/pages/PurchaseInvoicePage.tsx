import { useState } from 'react'
import { Plus, RefreshCw } from 'lucide-react'
import { hasAccess } from '../../../core/access/accessUtils'
import { useTenant } from '../../../shared/tenant/useTenant'
import { usePurchaseInvoiceOverview } from '../queries/usePurchaseInvoices'
import { invoiceMoney, type InvoiceHeader } from '../model/purchaseInvoices'
import { PurchaseInvoiceForm, PurchaseInvoiceDetailDialog, PurchaseInvoicePostDialog } from './PurchaseInvoiceDialogs'
import '../../finance/pages/FinancePage.css'
import './PurchaseInvoicePage.css'

export function PurchaseInvoicePage() {
  const { context, tenantId } = useTenant()
  const query = usePurchaseInvoiceOverview()
  const [mode, setMode] = useState<{ kind: 'create' } | { kind: 'view' | 'edit'; id: string } | { kind: 'post'; invoice: InvoiceHeader } | null>(null)
  const canWrite = !!context && hasAccess(context, { requiredModule: 'purchasing', requiredPermission: 'purchasing.write' }) && context.modules.includes('suppliers')
  if (query.isPending) return <section className="finance-state"><strong>Faturalar yükleniyor...</strong></section>
  if (query.isError) return <section className="finance-state finance-state-error"><strong>Faturalar alınamadı</strong><span>{query.error.message}</span><button onClick={() => { void query.refetch() }}>Tekrar dene</button></section>
  const { summary, invoices } = query.data
  return <section className="finance-page">
    <div className="finance-heading"><div><span className="eyebrow">SATINALMA</span><h1>Tedarikçi Faturaları</h1><p>Fatura kalemlerini kaydedin, taslakları kontrol edin ve tedarikçi borcuna işleyin.</p></div>
      <div className="finance-heading-actions">{canWrite ? <button className="finance-refresh-button" onClick={() => setMode({ kind: 'create' })}><Plus size={16} />Yeni Fatura</button> : null}
        <button className="finance-refresh-button" disabled={query.isFetching} onClick={() => { void query.refetch() }}><RefreshCw size={16} />Yenile</button></div></div>
    <div className="finance-summary-grid">
      <article className="finance-summary-card"><div><span>Taslak Fatura</span><strong>{summary.draftCount}</strong></div></article>
      <article className="finance-summary-card"><div><span>İşlenmiş Fatura</span><strong>{summary.postedCount}</strong></div></article>
      <article className="finance-summary-card"><div><span>Toplam Satınalma</span><div className="finance-summary-values">{summary.postedTotals.length ? summary.postedTotals.map((total) => <strong key={total.currencyCode}>{invoiceMoney(total.amount, total.currencyCode)}</strong>) : <strong>—</strong>}</div></div></article>
    </div>
    <section className="finance-panel"><div className="finance-panel-heading"><div><span>FATURALAR</span><h2>Son faturalar</h2></div><small>{invoices.length} kayıt</small></div>
      {invoices.length === 0 ? <div className="finance-empty-state">Henüz fatura yok.</div> : <div className="purchase-invoice-list">{invoices.map((invoice) => <article key={invoice.id}>
        <div className="purchase-line-heading"><h3>{invoice.supplierName} · {invoice.invoiceNumber}</h3><span className="finance-readonly-badge">{invoice.status === 'POSTED' ? 'İşlendi' : 'Taslak'}</span></div>
        <dl className="finance-account-details"><div><dt>Fatura Tarihi</dt><dd>{invoice.invoiceDate}</dd></div><div><dt>Vade</dt><dd>{invoice.dueDate ?? '—'}</dd></div>
          <div><dt>Lokasyon</dt><dd>{invoice.locationName ?? 'İşletme geneli'}</dd></div><div><dt>Tutar</dt><dd>{invoiceMoney(invoice.grandTotal, invoice.currencyCode)}</dd></div></dl>
        <div className="purchase-actions"><button className="finance-refresh-button" aria-label={`${invoice.invoiceNumber} görüntüle`} onClick={() => setMode({ kind: 'view', id: invoice.id })}>Görüntüle</button>
          {canWrite && invoice.status === 'DRAFT' ? <><button className="finance-refresh-button" aria-label={`${invoice.invoiceNumber} düzenle`} onClick={() => setMode({ kind: 'edit', id: invoice.id })}>Düzenle</button>
            <button className="finance-refresh-button" aria-label={`${invoice.invoiceNumber} faturayı işle`} onClick={() => setMode({ kind: 'post', invoice })}>Faturayı İşle</button></> : null}</div>
      </article>)}</div>}
    </section>
    {canWrite && mode?.kind === 'create' ? <PurchaseInvoiceForm key={tenantId} onClose={() => setMode(null)} /> : null}
    {mode?.kind === 'view' || (canWrite && mode?.kind === 'edit') ? <PurchaseInvoiceDetailDialog key={`${tenantId}-${mode.id}`} invoiceId={mode.id} edit={mode.kind === 'edit'} onClose={() => setMode(null)} /> : null}
    {canWrite && mode?.kind === 'post' ? <PurchaseInvoicePostDialog invoice={mode.invoice} onClose={() => setMode(null)} /> : null}
  </section>
}
