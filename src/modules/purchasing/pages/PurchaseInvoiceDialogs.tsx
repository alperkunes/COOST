import { useRef, useState, type FormEvent, type ReactNode } from 'react'
import { X } from 'lucide-react'
import { usePurchaseInvoiceContext, usePurchaseInvoiceDetail } from '../queries/usePurchaseInvoices'
import { useSavePurchaseDraft, usePostPurchaseInvoice } from '../mutations/usePurchaseInvoiceCommands'
import { emptyInvoiceLine, invoiceDraftSchema, invoiceLineInputSchema, invoiceLineMath, invoiceFormFromDetail,
  invoiceMoney, type InvoiceDraftInput, type InvoiceLineInput, type InvoiceDetail, type InvoiceHeader } from '../model/purchaseInvoices'

function Modal({ title, busy = false, onClose, children }: { title: string; busy?: boolean; onClose: () => void; children: ReactNode }) {
  return <div className="finance-dialog-backdrop" role="presentation" onMouseDown={(event) => {
    if (event.target === event.currentTarget && !busy) onClose()
  }}><section className="finance-dialog purchase-dialog" role="dialog" aria-modal="true" aria-labelledby="purchase-dialog-title">
    <div className="finance-dialog-heading"><div><span>SATINALMA</span><h2 id="purchase-dialog-title">{title}</h2></div>
      <button type="button" aria-label="Kapat" disabled={busy} onClick={onClose}><X size={20} /></button></div>{children}
  </section></div>
}

export function PurchaseInvoiceForm({ detail, readOnly = false, onClose }: { detail?: InvoiceDetail; readOnly?: boolean; onClose: () => void }) {
  const locked = readOnly || detail?.invoice.status === 'POSTED'
  const context = usePurchaseInvoiceContext(!locked)
  const mutation = useSavePurchaseDraft()
  const submitting = useRef(false)
  const [input, setInput] = useState<InvoiceDraftInput>(() => detail ? invoiceFormFromDetail(detail) : {
    supplierId: '', locationId: '', invoiceNumber: '', invoiceDate: new Intl.DateTimeFormat('sv-SE').format(new Date()),
    dueDate: '', currencyCode: 'TRY', description: '', lines: [emptyInvoiceLine()],
  })
  const parsed = invoiceDraftSchema.safeParse(input)
  const preview = input.lines.map((line) => {
    const parsedLine = invoiceLineInputSchema.safeParse(line)
    return parsedLine.success ? invoiceLineMath(parsedLine.data) : null
  })
  const totals = locked && detail ? { netAmount: detail.invoice.subtotal, taxAmount: detail.invoice.taxTotal, grossAmount: detail.invoice.grandTotal }
    : preview.every((line) => line !== null) ? preview.reduce((sum, line) => ({ netAmount: sum.netAmount + line!.netAmount,
      taxAmount: sum.taxAmount + line!.taxAmount, grossAmount: sum.grossAmount + line!.grossAmount }), { netAmount: 0, taxAmount: 0, grossAmount: 0 }) : null
  const supplierAvailable = context.data?.suppliers.some((supplier) => supplier.id === input.supplierId)
  const locationAvailable = !input.locationId || context.data?.locations.some((location) => location.id === input.locationId)
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (locked || !parsed.success || !supplierAvailable || !locationAvailable || context.isError || submitting.current || mutation.isPending) return
    submitting.current = true
    try { await mutation.mutateAsync({ invoiceId: detail?.invoice.id, input }); onClose() }
    catch { /* Keep entered headers and lines for retry. */ }
    finally { submitting.current = false }
  }
  function lineChange(index: number, patch: Partial<InvoiceLineInput>) {
    setInput((previous) => ({ ...previous, lines: previous.lines.map((line, i) => i === index ? { ...line, ...patch } : line) }))
  }
  const fields = [['invoiceNumber', 'Fatura No'], ['invoiceDate', 'Fatura Tarihi'], ['dueDate', 'Vade Tarihi'], ['currencyCode', 'Para Birimi']] as const
  const lineFields = [['description', 'Malzeme / Ürün Açıklaması'], ['supplierProductCode', 'Tedarikçi Ürün Kodu'],
    ['quantity', 'Miktar'], ['unit', 'Birim'], ['unitPrice', 'Birim Fiyat'], ['taxRate', 'KDV %']] as const
  return <Modal title={locked ? 'Fatura Detayı' : detail ? 'Taslak Faturayı Düzenle' : 'Yeni Fatura'} busy={mutation.isPending} onClose={onClose}>
    <form onSubmit={submit}>
      {!locked && context.isPending ? <p role="status">Tedarikçi ve lokasyonlar yükleniyor...</p> : null}
      {!locked && context.isError ? <div role="alert" className="finance-dialog-error">{context.error.message} <button type="button" onClick={() => { void context.refetch() }}>Tekrar dene</button></div> : null}
      {locked ? <div className="finance-dialog-info">{detail?.invoice.status === 'POSTED' ? 'İşlendi · Bu fatura değiştirilemez.' : 'Taslak · Salt okunur görünüm'}</div> : null}
      <fieldset disabled={locked || mutation.isPending} className="purchase-fields">
        <div className="purchase-header-grid">
          <label className="finance-dialog-field"><span>Tedarikçi</span><select required value={input.supplierId} onChange={(event) => setInput({ ...input, supplierId: event.target.value })}>
            <option value="">Tedarikçi seçin</option>
            {detail && !context.data?.suppliers.some((supplier) => supplier.id === detail.invoice.supplierId) ? <option value={detail.invoice.supplierId} disabled={!locked}>{detail.invoice.supplierName}{locked ? '' : ' (kullanılamıyor)'}</option> : null}
            {context.data?.suppliers.map((supplier) => <option key={supplier.id} value={supplier.id}>{supplier.name}</option>)}
          </select></label>
          {fields.map(([key, label]) => <label className="finance-dialog-field" key={key}><span>{label}</span>
            <input required={key !== 'dueDate'} type={key === 'invoiceDate' || key === 'dueDate' ? 'date' : 'text'} value={input[key]}
              onChange={(event) => setInput({ ...input, [key]: event.target.value })} /></label>)}
          <label className="finance-dialog-field"><span>Lokasyon</span><select value={input.locationId} onChange={(event) => setInput({ ...input, locationId: event.target.value })}>
            <option value="">İşletme geneli</option>
            {detail?.invoice.locationId && !context.data?.locations.some((location) => location.id === detail.invoice.locationId) ? <option value={detail.invoice.locationId} disabled={!locked}>{detail.invoice.locationName}{locked ? '' : ' (kullanılamıyor)'}</option> : null}
            {context.data?.locations.map((location) => <option key={location.id} value={location.id}>{location.name}</option>)}
          </select></label>
        </div>
        <label className="finance-dialog-field"><span>Açıklama</span><textarea rows={2} maxLength={2000} value={input.description} onChange={(event) => setInput({ ...input, description: event.target.value })} /></label>
        <div className="purchase-line-list">{input.lines.map((line, index) => {
          const amounts = locked && detail ? detail.lines[index] : preview[index]
          return <section className="purchase-line" key={index} aria-label={`Fatura satırı ${index + 1}`}>
            <div className="purchase-line-heading"><strong>Satır {index + 1}</strong>{!locked ? <button type="button" className="finance-adjust-button" disabled={input.lines.length === 1}
              onClick={() => setInput({ ...input, lines: input.lines.filter((_, i) => i !== index) })}>Satır {index + 1} kaldır</button> : null}</div>
            <div className="purchase-line-grid">{lineFields.map(([key, label]) => <label className="finance-dialog-field" key={key}><span>{label}</span>
              <input aria-label={`${label} ${index + 1}`} required={key !== 'supplierProductCode'} inputMode={['quantity', 'unitPrice', 'taxRate'].includes(key) ? 'decimal' : 'text'}
                value={line[key]} onChange={(event) => lineChange(index, { [key]: event.target.value })} /></label>)}</div>
            <label className="purchase-tax-checkbox"><input type="checkbox" checked={line.priceIncludesTax} onChange={(event) => lineChange(index, { priceIncludesTax: event.target.checked })} aria-label={`KDV Dahil ${index + 1}`} />KDV Dahil</label>
            <div className="purchase-line-totals"><span>Net: {amounts ? invoiceMoney(amounts.netAmount, input.currencyCode) : '—'}</span>
              <span>KDV: {amounts ? invoiceMoney(amounts.taxAmount, input.currencyCode) : '—'}</span><strong>Toplam: {amounts ? invoiceMoney(amounts.grossAmount, input.currencyCode) : '—'}</strong></div>
          </section>
        })}</div>
        {!locked ? <button type="button" className="finance-refresh-button" disabled={input.lines.length >= 200} onClick={() => setInput({ ...input, lines: [...input.lines, emptyInvoiceLine()] })}>Satır Ekle</button> : null}
      </fieldset>
      <div className="purchase-invoice-totals"><span>Ara Toplam: {totals ? invoiceMoney(totals.netAmount, input.currencyCode) : '—'}</span>
        <span>KDV: {totals ? invoiceMoney(totals.taxAmount, input.currencyCode) : '—'}</span><strong>Genel Toplam: {totals ? invoiceMoney(totals.grossAmount, input.currencyCode) : '—'}</strong></div>
      {!locked && !parsed.success ? <div className="finance-dialog-info" role="status">Başlık ve satır alanlarını kontrol edin. Miktar pozitif; birim fiyat sıfır veya pozitif olmalıdır. Miktar ve birim fiyat en fazla 4, KDV oranı en fazla 3 ondalık kabul eder. Vade fatura tarihinden önce olamaz.</div> : null}
      {mutation.isError ? <div role="alert" className="finance-dialog-error">{mutation.error.message}</div> : null}
      <div className="finance-dialog-actions"><button type="button" disabled={mutation.isPending} onClick={onClose}>{locked ? 'Kapat' : 'Vazgeç'}</button>
        {!locked ? <button type="submit" className="primary" disabled={!parsed.success || !supplierAvailable || !locationAvailable || context.isError || mutation.isPending}>{mutation.isPending ? 'Kaydediliyor...' : 'Taslağı Kaydet'}</button> : null}</div>
    </form>
  </Modal>
}

export function PurchaseInvoiceDetailDialog({ invoiceId, edit, onClose }: { invoiceId: string; edit: boolean; onClose: () => void }) {
  const query = usePurchaseInvoiceDetail(invoiceId)
  if (query.isPending) return <Modal title="Fatura Detayı" onClose={onClose}><p className="purchase-loading" role="status">Fatura yükleniyor...</p></Modal>
  if (query.isError) return <Modal title="Fatura Detayı" onClose={onClose}><div role="alert" className="purchase-loading">{query.error.message}<button onClick={() => { void query.refetch() }}>Tekrar dene</button></div></Modal>
  return <PurchaseInvoiceForm detail={query.data} readOnly={!edit} onClose={onClose} />
}
export function PurchaseInvoicePostDialog({ invoice, onClose }: { invoice: InvoiceHeader; onClose: () => void }) {
  const mutation = usePostPurchaseInvoice()
  const submitting = useRef(false)
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (submitting.current || mutation.isPending || invoice.status !== 'DRAFT') return
    submitting.current = true
    try { await mutation.mutateAsync(invoice.id); onClose() }
    catch { /* Keep confirmation and show server error for retry. */ }
    finally { submitting.current = false }
  }
  return <Modal title="Faturayı İşle" busy={mutation.isPending} onClose={onClose}><form onSubmit={submit}>
    <strong>{invoice.supplierName} · {invoice.invoiceNumber}</strong><strong>{invoiceMoney(invoice.grandTotal, invoice.currencyCode)}</strong>
    <p>Bu işlem tedarikçi borcunu artıracaktır ve işlendiğinde fatura değiştirilemez.</p>
    {mutation.isError ? <div role="alert" className="finance-dialog-error">{mutation.error.message}</div> : null}
    <div className="finance-dialog-actions"><button type="button" disabled={mutation.isPending} onClick={onClose}>Vazgeç</button>
      <button type="submit" className="primary" disabled={mutation.isPending || invoice.status !== 'DRAFT'}>{mutation.isPending ? 'İşleniyor...' : 'Onayla ve İşle'}</button></div>
  </form></Modal>
}
