import { useRef, useState, type FormEvent, type ReactNode } from 'react'
import { X } from 'lucide-react'
import { useSaveSupplier, useCreateSupplierPayment } from '../mutations/useSupplierCommands'
import { useSupplierPaymentContext } from '../queries/useSuppliers'
import { supplierFormSchema, parseSupplierAmount, balanceLabel, money, type Supplier, type SupplierFormInput } from '../model/suppliers'

function Dialog({ title, pending, onClose, children }: { title: string; pending: boolean; onClose: () => void; children: ReactNode }) {
  return <div className="finance-dialog-backdrop" role="presentation" onMouseDown={(event) => {
    if (event.target === event.currentTarget && !pending) onClose()
  }}><section className="finance-dialog" role="dialog" aria-modal="true" aria-labelledby="supplier-dialog-title">
    <div className="finance-dialog-heading"><div><span>TEDARİKÇİLER</span><h2 id="supplier-dialog-title">{title}</h2></div>
      <button type="button" aria-label="Kapat" disabled={pending} onClick={onClose}><X size={20} /></button>
    </div>{children}
  </section></div>
}

export function SupplierFormDialog({ supplier, onClose }: { supplier?: Supplier; onClose: () => void }) {
  const mutation = useSaveSupplier()
  const submitting = useRef(false)
  const [input, setInput] = useState<SupplierFormInput>({ name: supplier?.name ?? '', taxNumber: supplier?.taxNumber ?? '',
    phone: supplier?.phone ?? '', email: supplier?.email ?? '', notes: supplier?.notes ?? '', status: supplier?.status ?? 'ACTIVE' })
  const parsed = supplierFormSchema.safeParse(input)
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!parsed.success || submitting.current || mutation.isPending) return
    submitting.current = true
    try { await mutation.mutateAsync({ supplierId: supplier?.id, input }); onClose() }
    catch { /* Keep the form for correction or retry. */ }
    finally { submitting.current = false }
  }
  const fields = [
    ['name', 'Ad / Ünvan', 160], ['taxNumber', 'VKN/TCKN', 11], ['phone', 'Telefon', 40], ['email', 'E-posta', 254],
  ] as const
  return <Dialog title={supplier ? 'Tedarikçiyi Düzenle' : 'Yeni Tedarikçi'} pending={mutation.isPending} onClose={onClose}>
    <form onSubmit={submit}>
      {fields.map(([field, label, maxLength]) => <label className="finance-dialog-field" key={field}>
        <span>{label}</span><input autoFocus={field === 'name'} required={field === 'name'} maxLength={maxLength}
          value={input[field]} disabled={mutation.isPending} onChange={(event) => setInput({ ...input, [field]: event.target.value })}
          aria-invalid={input[field] !== '' && !parsed.success && parsed.error.issues.some((issue) => issue.path[0] === field)} />
        {field === 'name' ? <small>2–160 karakter.</small> : field === 'taxNumber' ? <small>İsteğe bağlı, 10 veya 11 rakam.</small> : null}
      </label>)}
      <label className="finance-dialog-field"><span>Not</span><textarea rows={3} maxLength={2000} value={input.notes}
        disabled={mutation.isPending} onChange={(event) => setInput({ ...input, notes: event.target.value })} /></label>
      {supplier ? <label className="finance-dialog-field"><span>Durum</span><select value={input.status} disabled={mutation.isPending}
        onChange={(event) => setInput({ ...input, status: event.target.value as SupplierFormInput['status'] })}>
        <option value="ACTIVE">Aktif</option><option value="PASSIVE">Pasif</option>
      </select><small>Tüm para birimlerindeki borç ve avans bakiyeleri sıfırsa pasife alınabilir.</small></label> : null}
      {mutation.isError ? <div role="alert" className="finance-dialog-error">{mutation.error.message}</div> : null}
      <div className="finance-dialog-actions"><button type="button" disabled={mutation.isPending} onClick={onClose}>Vazgeç</button>
        <button type="submit" className="primary" disabled={!parsed.success || mutation.isPending}>{mutation.isPending ? 'Kaydediliyor...' : 'Kaydet'}</button></div>
    </form>
  </Dialog>
}

export function SupplierPaymentDialog({ suppliers, initialSupplierId = '', onClose }: {
  suppliers: Supplier[]; initialSupplierId?: string; onClose: () => void
}) {
  const context = useSupplierPaymentContext()
  const mutation = useCreateSupplierPayment()
  const submitting = useRef(false)
  const [supplierId, setSupplierId] = useState(initialSupplierId)
  const [accountId, setAccountId] = useState('')
  const [amountInput, setAmountInput] = useState('')
  const [description, setDescription] = useState('')
  const supplier = suppliers.find((item) => item.id === supplierId && item.status === 'ACTIVE')
  const account = context.data?.accounts.find((item) => item.id === accountId)
  const amount = parseSupplierAmount(amountInput)
  const balance = supplier?.balances.find((item) => item.currencyCode === account?.currencyCode)?.amount ?? 0
  const result = amount === null ? null : Math.round((balance - amount) * 100) / 100
  const valid = supplier && account && !context.isError && amount !== null && description.trim().length >= 2 && description.trim().length <= 500
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!valid || !supplier || !account || amount === null || submitting.current || mutation.isPending) return
    submitting.current = true
    try { await mutation.mutateAsync({ supplierId: supplier.id, financeAccountId: account.id, amount, description }); onClose() }
    catch { /* Mutation error is shown without clearing entered values. */ }
    finally { submitting.current = false }
  }
  return <Dialog title="Tedarikçiye Ödeme Yap" pending={mutation.isPending} onClose={onClose}>
    <form onSubmit={submit}>
      <label className="finance-dialog-field"><span>Tedarikçi</span><select autoFocus required value={supplierId} disabled={mutation.isPending}
        onChange={(event) => setSupplierId(event.target.value)}><option value="">Tedarikçi seçin</option>
        {suppliers.filter((item) => item.status === 'ACTIVE').map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
      </select></label>
      <label className="finance-dialog-field"><span>Ödeme hesabı</span><select required value={accountId} disabled={mutation.isPending || context.isPending}
        onChange={(event) => setAccountId(event.target.value)}><option value="">Hesap seçin</option>
        {context.data?.accounts.map((item) => <option key={item.id} value={item.id}>{item.name} ({item.currencyCode})</option>)}
      </select></label>
      {context.isPending ? <p role="status">Ödeme hesapları yükleniyor...</p> : null}
      {context.isError ? <div className="finance-dialog-error" role="alert">{context.error.message} <button type="button" onClick={() => { void context.refetch() }}>Tekrar dene</button></div> : null}
      {context.data?.accounts.length === 0 ? <div className="finance-dialog-info">Ödeme yapılabilecek aktif kasa/banka hesabı yok.</div> : null}
      {account ? <small>Hesap bakiyesi: {money(account.derivedBalance, account.currencyCode)}</small> : null}
      <label className="finance-dialog-field"><span id="supplier-payment-amount">Tutar</span><div className="finance-money-input">
        <input aria-labelledby="supplier-payment-amount" required inputMode="decimal" placeholder="0,00" value={amountInput}
          disabled={mutation.isPending} onChange={(event) => setAmountInput(event.target.value)} aria-invalid={!!amountInput && amount === null} />
        <span>{account?.currencyCode}</span></div><small>Pozitif, en fazla iki ondalıklı tutar girin.</small></label>
      {supplier && account ? <div className="supplier-payment-preview" aria-label="Ödeme sonrası bakiye">
        <div><span>Mevcut bakiye</span><strong>{balanceLabel(balance, account.currencyCode)}</strong></div>
        <div><span>Ödeme</span><strong>{amount === null ? '—' : money(amount, account.currencyCode)}</strong></div>
        <div><span>Sonuç</span><strong>{result === null ? '—' : balanceLabel(result, account.currencyCode)}</strong></div>
        <small>Borcu aşan ödeme tedarikçiye avans olarak kaydedilir.</small>
      </div> : null}
      <label className="finance-dialog-field"><span>Açıklama</span><textarea required rows={3} maxLength={500} value={description}
        disabled={mutation.isPending} onChange={(event) => setDescription(event.target.value)} /><small>2–500 karakter.</small></label>
      {mutation.isError ? <div className="finance-dialog-error" role="alert">{mutation.error.message}</div> : null}
      <div className="finance-dialog-actions"><button type="button" disabled={mutation.isPending} onClick={onClose}>Vazgeç</button>
        <button type="submit" className="primary" disabled={!valid || mutation.isPending}>{mutation.isPending ? 'Kaydediliyor...' : 'Ödemeyi Kaydet'}</button></div>
    </form>
  </Dialog>
}
