import { useRef, useState, type FormEvent } from 'react'
import { Field, Modal } from './CostingDialogs'
import { expenseInputSchema, expenseLabels, salesInputSchema, type Expense, type ExpenseInput, type OperatingData, type Period, type SalesFact, type SalesInput } from '../model/operating'
import { useSaveOperatingCost, useSaveSalesFact, useVoidOperatingCost } from '../mutations/useOperatingCommands'

export function SalesDialog({ fact, data, period, onClose }: { fact?: SalesFact; data: OperatingData; period: Period; onClose: () => void }) {
  const [input, setInput] = useState<SalesInput>(() => fact ? { saleDate: fact.saleDate, locationId: fact.locationId, productId: fact.productId, quantity: String(fact.quantity), grossSales: String(fact.grossSales), netSales: String(fact.netSales) } : { saleDate: period.endDate, locationId: period.locationId, productId: '', quantity: '', grossSales: '', netSales: '' })
  const mutation = useSaveSalesFact(), submitting = useRef(false)
  const valid = salesInputSchema.safeParse(input).success && data.products.some((p) => p.id === input.productId) && data.locations.some((l) => l.id === input.locationId)
  async function submit(e: FormEvent) {
    e.preventDefault()
    if (!valid || submitting.current || mutation.isPending) return
    submitting.current = true
    try { await mutation.mutateAsync(input); onClose() } catch { /* Preserve values for retry. */ } finally { submitting.current = false }
  }
  const existing = data.sales.some((f) => f.saleDate === input.saleDate && f.locationId === input.locationId && f.productId === input.productId)
  return <Modal title={fact ? 'Satışı Düzenle' : 'Satış Verisi'} busy={mutation.isPending} onClose={onClose}><form onSubmit={submit}>
    <fieldset disabled={mutation.isPending} className="costing-fields">
      <Field label="Tarih"><input type="date" disabled={!!fact} value={input.saleDate} onChange={(e) => setInput({ ...input, saleDate: e.target.value })} /></Field>
      <Field label="Lokasyon"><select disabled={!!fact} value={input.locationId} onChange={(e) => setInput({ ...input, locationId: e.target.value })}><option value="">Seçin</option>{data.locations.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}</select></Field>
      <Field label="Menü ürünü"><select disabled={!!fact} value={input.productId} onChange={(e) => setInput({ ...input, productId: e.target.value })}><option value="">Seçin</option>{data.products.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</select></Field>
      {([['quantity', 'Satış adedi'], ['grossSales', 'Brüt satış'], ['netSales', 'Net satış']] as const).map(([key, label]) => <Field key={key} label={label}><input inputMode="decimal" value={input[key]} onChange={(e) => setInput({ ...input, [key]: e.target.value })} /></Field>)}
    </fieldset><p>Kaynak: Manuel · {period.currencyCode}</p>
    {existing && !fact ? <p role="status">Aynı gün, lokasyon ve ürün kaydının mevcut toplamları güncellenecek.</p> : null}
    <p>Narpos entegrasyonu geldiğinde bu veriler otomatik senkronize edilebilecektir.</p>
    {mutation.isError ? <p role="alert">{mutation.error.message}</p> : null}
    <button type="submit" disabled={!valid || mutation.isPending}>{mutation.isPending ? 'Kaydediliyor...' : 'Kaydet'}</button>
  </form></Modal>
}

export function ExpenseDialog({ expense, data, period, onClose }: { expense?: Expense; data: OperatingData; period: Period; onClose: () => void }) {
  const [input, setInput] = useState<ExpenseInput>(() => expense ? { ...expense, locationId: expense.locationId ?? '', amount: String(expense.amount) } : { occurredOn: period.endDate, locationId: period.locationId, currencyCode: period.currencyCode, category: 'FIXED_OVERHEAD', amount: '', description: '' })
  const mutation = useSaveOperatingCost(), submitting = useRef(false)
  const valid = expenseInputSchema.safeParse(input).success
  async function submit(e: FormEvent) {
    e.preventDefault()
    if (!valid || submitting.current || mutation.isPending) return
    submitting.current = true
    try { await mutation.mutateAsync({ id: expense?.id, input }); onClose() } catch { /* Preserve values for retry. */ } finally { submitting.current = false }
  }
  return <Modal title={expense ? 'Gideri Düzenle' : 'Yeni İşletme Gideri'} busy={mutation.isPending} onClose={onClose}><form onSubmit={submit}>
    <fieldset disabled={mutation.isPending} className="costing-fields">
      <Field label="Tarih"><input type="date" value={input.occurredOn} onChange={(e) => setInput({ ...input, occurredOn: e.target.value })} /></Field>
      <Field label="Kapsam"><select value={input.locationId} onChange={(e) => setInput({ ...input, locationId: e.target.value })}><option value="">İşletme geneli</option>{data.locations.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}</select></Field>
      <Field label="Kategori"><select value={input.category} onChange={(e) => setInput({ ...input, category: e.target.value as ExpenseInput['category'] })}>{Object.entries(expenseLabels).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></Field>
      <Field label="Tutar"><input inputMode="decimal" value={input.amount} onChange={(e) => setInput({ ...input, amount: e.target.value })} /></Field>
      <Field label="Para birimi"><input maxLength={3} value={input.currencyCode} onChange={(e) => setInput({ ...input, currencyCode: e.target.value.toUpperCase() })} /></Field>
      <Field label="Açıklama"><input maxLength={500} value={input.description} onChange={(e) => setInput({ ...input, description: e.target.value })} /></Field>
    </fieldset><p>Bu kayıt kârlılık analizine dahil edilir; kasa/banka hareketi oluşturmaz.</p>
    {mutation.isError ? <p role="alert">{mutation.error.message}</p> : null}
    <button type="submit" disabled={!valid || mutation.isPending}>{mutation.isPending ? 'Kaydediliyor...' : 'Kaydet'}</button>
  </form></Modal>
}

export function VoidExpenseDialog({ expense, onClose }: { expense: Expense; onClose: () => void }) {
  const mutation = useVoidOperatingCost(), submitting = useRef(false)
  async function submit(e: FormEvent) {
    e.preventDefault()
    if (submitting.current || mutation.isPending) return
    submitting.current = true
    try { await mutation.mutateAsync(expense.id); onClose() } catch { /* Keep confirmation open for retry. */ } finally { submitting.current = false }
  }
  return <Modal title="Gideri İptal Et" busy={mutation.isPending} onClose={onClose}><form onSubmit={submit}><p>{expense.description} kaydı rapordan çıkarılacak, geçmişte korunacaktır.</p>{mutation.isError ? <p role="alert">{mutation.error.message}</p> : null}<button type="submit" disabled={mutation.isPending}>İptali Onayla</button></form></Modal>
}
