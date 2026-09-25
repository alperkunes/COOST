import { useState } from 'react'
import { Building2, Plus, RefreshCw } from 'lucide-react'
import { useTenant } from '../../../shared/tenant/useTenant'
import { hasAccess } from '../../../core/access/accessUtils'
import { useSupplierOverview } from '../queries/useSuppliers'
import { balanceLabel, money, supplierTotals, canPaySupplier, type Supplier } from '../model/suppliers'
import { SupplierFormDialog, SupplierPaymentDialog } from './SupplierDialogs'
import '../../finance/pages/FinancePage.css'
import './SupplierPage.css'

export function SupplierPage() {
  const { context, tenantId } = useTenant()
  const query = useSupplierOverview()
  const [editor, setEditor] = useState<Supplier | 'create' | null>(null)
  const [paymentSupplierId, setPaymentSupplierId] = useState<string | null>(null)
  const canWrite = !!context && hasAccess(context, { requiredModule: 'suppliers', requiredPermission: 'suppliers.write' })
  const canPay = canPaySupplier(context)
  if (query.isPending) return <section className="finance-state"><RefreshCw className="finance-spinner" /><strong>Tedarikçiler yükleniyor...</strong></section>
  if (query.isError) return <section className="finance-state finance-state-error"><strong>Tedarikçiler alınamadı</strong><span>{query.error.message}</span>
    <button type="button" onClick={() => { void query.refetch() }}>Tekrar dene</button></section>
  const { suppliers, recentPayments } = query.data
  const totals = supplierTotals(suppliers)
  return <section className="finance-page supplier-page">
    <div className="finance-heading"><div><span className="eyebrow">TEDARİKÇİLER</span><h1>Tedarikçiler</h1><p>Borçları, avansları ve kasa/banka ödemelerini para birimi bazında izleyin.</p></div>
      <div className="finance-heading-actions">
        {canWrite ? <button className="finance-refresh-button" onClick={() => setEditor('create')}><Plus size={16} />Yeni Tedarikçi</button> : null}
        <button className="finance-refresh-button" disabled={query.isFetching} onClick={() => { void query.refetch() }}><RefreshCw size={16} />Yenile</button>
      </div></div>
    <div className="finance-summary-grid">
      <article className="finance-summary-card"><div><span>Toplam Tedarikçi Borcu</span><div className="finance-summary-values">
        {totals.length ? totals.map((total) => <strong key={total.currencyCode}>{money(total.debt, total.currencyCode)}</strong>) : <strong>—</strong>}
      </div></div></article>
      <article className="finance-summary-card"><div><span>Tedarikçi Avansı</span><div className="finance-summary-values">
        {totals.length ? totals.map((total) => <strong key={total.currencyCode}>{money(total.advance, total.currencyCode)}</strong>) : <strong>—</strong>}
      </div></div></article>
      <article className="finance-summary-card"><div><span>Aktif Tedarikçi</span><strong>{suppliers.filter((item) => item.status === 'ACTIVE').length}</strong></div></article>
    </div>
    <section className="finance-panel"><div className="finance-panel-heading"><div><span>TEDARİKÇİ LİSTESİ</span><h2>İş ortakları</h2></div><small>{suppliers.length} tedarikçi</small></div>
      {suppliers.length === 0 ? <div className="finance-empty-state"><Building2 /><strong>Henüz tedarikçi yok</strong><span>{canWrite ? 'Yeni Tedarikçi ile ilk kaydı ekleyin.' : 'Tedarikçi eklemek için işletme yetkilinizle iletişime geçin.'}</span></div> :
        <div className="supplier-list">{suppliers.map((supplier) => <article className="supplier-card" key={supplier.id}>
          <div className="supplier-card-heading"><h3>{supplier.name}</h3><span className="finance-readonly-badge">{supplier.status === 'ACTIVE' ? 'Aktif' : 'Pasif'}</span></div>
          <dl className="finance-account-details"><div><dt>VKN/TCKN</dt><dd>{supplier.taxNumber ?? '—'}</dd></div><div><dt>İletişim</dt><dd>{[supplier.phone, supplier.email].filter(Boolean).join(' · ') || '—'}</dd></div></dl>
          {supplier.notes ? <p className="supplier-notes">{supplier.notes}</p> : null}
          <div className="supplier-balances">{supplier.balances.length ? supplier.balances.map((balance) => <strong key={balance.currencyCode}>{balanceLabel(balance.amount, balance.currencyCode)}</strong>) : <span>Hareket yok · Bakiye sıfır</span>}</div>
          <div className="supplier-card-actions">
            {canWrite ? <button className="finance-refresh-button" aria-label={`${supplier.name} düzenle`} onClick={() => setEditor(supplier)}>Düzenle</button> : null}
            {canPay && supplier.status === 'ACTIVE' ? <button className="finance-refresh-button" aria-label={`${supplier.name} ödeme yap`} onClick={() => setPaymentSupplierId(supplier.id)}>Ödeme Yap</button> : null}
          </div>
        </article>)}</div>}
    </section>
    <section className="finance-panel"><div className="finance-panel-heading"><div><span>SON ÖDEMELER</span><h2>Tedarikçi ödemeleri</h2></div></div>
      {recentPayments.length === 0 ? <div className="finance-empty-state">Henüz ödeme yok.</div> : <div className="supplier-payments">
        {recentPayments.map((payment) => <article key={payment.id}><div><strong>{payment.supplierName}</strong><span>{payment.financeAccountName}</span><p>{payment.description}</p>
          <small>{new Intl.DateTimeFormat('tr-TR', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(payment.occurredAt))}</small></div><strong>{money(payment.amount, payment.currencyCode)}</strong></article>)}
      </div>}
    </section>
    {canWrite && editor !== null ? <SupplierFormDialog key={`${tenantId}-${editor === 'create' ? 'create' : editor.id}`} supplier={editor === 'create' ? undefined : editor} onClose={() => setEditor(null)} /> : null}
    {canPay && paymentSupplierId !== null ? <SupplierPaymentDialog key={`${tenantId}-${paymentSupplierId}`} suppliers={suppliers} initialSupplierId={paymentSupplierId} onClose={() => setPaymentSupplierId(null)} /> : null}
  </section>
}
