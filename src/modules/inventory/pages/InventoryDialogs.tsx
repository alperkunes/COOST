import { useRef, useState, type FormEvent, type ReactNode } from 'react'
import { X } from 'lucide-react'
import { useInventoryContext, useInventoryCountDetail } from '../queries/useInventory'
import { useSaveInventoryItem, useCreateInventoryMovement, useCreateInventoryCount, useUpdateInventoryCount, usePostInventoryCount, useCancelInventoryCount } from '../mutations/useInventoryCommands'
import { units, movementNames, itemInputSchema, movementInputSchema, parseQuantity, quantityText, signedQuantity, countDifference,
  type ItemInput, type InventoryItem, type MovementInput, type CountDetail } from '../model/inventory'

function Modal({ title, busy = false, onClose, children }: { title: string; busy?: boolean; onClose: () => void; children: ReactNode }) {
  return <div className="finance-dialog-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget && !busy) onClose() }}>
    <section className="finance-dialog inventory-dialog" role="dialog" aria-modal="true" aria-labelledby="inventory-dialog-title">
      <div className="finance-dialog-heading"><div><span>STOK YÖNETİMİ</span><h2 id="inventory-dialog-title">{title}</h2></div>
        <button type="button" aria-label="Kapat" disabled={busy} onClick={onClose}><X size={20} /></button></div>{children}
    </section></div>
}
function ErrorMessage({ error }: { error: Error | null }) { return error ? <div role="alert" className="finance-dialog-error">{error.message}</div> : null }
function Actions({ onClose, busy, disabled, label = 'Kaydet' }: { onClose: () => void; busy: boolean; disabled: boolean; label?: string }) {
  return <div className="finance-dialog-actions"><button type="button" disabled={busy} onClick={onClose}>Vazgeç</button>
    <button type="submit" className="primary" disabled={busy || disabled}>{busy ? 'Kaydediliyor...' : label}</button></div>
}
export function InventoryItemDialog({ item, onClose }: { item?: InventoryItem; onClose: () => void }) {
  const mutation = useSaveInventoryItem()
  const submitting = useRef(false)
  const [input, setInput] = useState<ItemInput>({ name: item?.name ?? '', sku: item?.sku ?? '', category: item?.category ?? '', baseUnit: item?.baseUnit ?? 'EACH',
    criticalStock: item?.criticalStock == null ? '' : String(item.criticalStock), status: item?.status ?? 'ACTIVE' })
  const valid = itemInputSchema.safeParse(input).success
  async function submit(event: FormEvent) {
    event.preventDefault()
    if (!valid || submitting.current || mutation.isPending) return
    submitting.current = true
    try { await mutation.mutateAsync({ itemId: item?.id, input }); onClose() } catch { /* Preserve edits for retry. */ } finally { submitting.current = false }
  }
  return <Modal title={item ? 'Stok Kartını Düzenle' : 'Yeni Stok Kartı'} busy={mutation.isPending} onClose={onClose}><form onSubmit={submit}>
    <fieldset className="inventory-fields" disabled={mutation.isPending}>
      {([['name', 'Ad'], ['sku', 'SKU'], ['category', 'Kategori'], ['criticalStock', 'Kritik Stok']] as const).map(([key, label]) => <label className="finance-dialog-field" key={key}><span>{label}</span>
        <input value={input[key]} inputMode={key === 'criticalStock' ? 'decimal' : undefined} onChange={(event) => setInput({ ...input, [key]: event.target.value })} /></label>)}
      <label className="finance-dialog-field"><span>Baz Birim</span><select disabled={!!item} value={input.baseUnit} onChange={(event) => setInput({ ...input, baseUnit: event.target.value as ItemInput['baseUnit'] })}>
        {Object.entries(units).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
      {item ? <label className="finance-dialog-field"><span>Durum</span><select value={input.status} onChange={(event) => setInput({ ...input, status: event.target.value as ItemInput['status'] })}><option value="ACTIVE">Aktif</option><option value="PASSIVE">Pasif</option></select></label> : null}
    </fieldset><p className="finance-dialog-help">Miktarlar baz birimdedir. Kritik stok boş bırakılabilir; sıfır veya pozitif, en fazla 4 ondalık olmalıdır.</p>
    {!valid ? <p role="status">Ad en az 2 karakter olmalı; alanları ve miktarı kontrol edin.</p> : null}<ErrorMessage error={mutation.error} />
    <Actions onClose={onClose} busy={mutation.isPending} disabled={!valid} />
  </form></Modal>
}
export function InventoryMovementDialog({ onClose }: { onClose: () => void }) {
  const context = useInventoryContext()
  const mutation = useCreateInventoryMovement()
  const submitting = useRef(false)
  const [input, setInput] = useState<MovementInput>({ itemId: '', locationId: '', movementType: 'RECEIPT', quantity: '', direction: 'INCREASE', description: '' })
  const parsed = movementInputSchema.safeParse(input)
  const item = context.data?.items.find((value) => value.id === input.itemId)
  const valid = parsed.success && !!item && context.data?.locations.some((value) => value.id === input.locationId)
  async function submit(event: FormEvent) {
    event.preventDefault()
    if (!valid || submitting.current || mutation.isPending) return
    submitting.current = true
    try { await mutation.mutateAsync(input); onClose() } catch { /* Preserve values. */ } finally { submitting.current = false }
  }
  return <Modal title="Hareket Ekle" busy={mutation.isPending} onClose={onClose}><form onSubmit={submit}>
    <ErrorMessage error={context.error} />{context.isError ? <button type="button" onClick={() => { void context.refetch() }}>Tekrar dene</button> : null}
    <fieldset className="inventory-fields" disabled={mutation.isPending || context.isPending}>
      <label className="finance-dialog-field"><span>Stok Kartı</span><select value={input.itemId} onChange={(event) => setInput({ ...input, itemId: event.target.value })}><option value="">Ürün seçin</option>{context.data?.items.map((value) => <option key={value.id} value={value.id}>{value.name} · {units[value.baseUnit]}</option>)}</select></label>
      <label className="finance-dialog-field"><span>Lokasyon</span><select value={input.locationId} onChange={(event) => setInput({ ...input, locationId: event.target.value })}><option value="">Lokasyon seçin</option>{context.data?.locations.map((value) => <option key={value.id} value={value.id}>{value.name}</option>)}</select></label>
      <label className="finance-dialog-field"><span>Hareket Tipi</span><select value={input.movementType} onChange={(event) => setInput({ ...input, movementType: event.target.value as MovementInput['movementType'] })}>
        {Object.entries(movementNames).filter(([value]) => value !== 'COUNT_ADJUSTMENT').map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
      {input.movementType === 'MANUAL_ADJUSTMENT' ? <label className="finance-dialog-field"><span>Yön</span><select value={input.direction} onChange={(event) => setInput({ ...input, direction: event.target.value as MovementInput['direction'] })}><option value="INCREASE">Artır</option><option value="DECREASE">Azalt</option></select></label> : null}
      <label className="finance-dialog-field"><span>Miktar</span><input inputMode="decimal" value={input.quantity} onChange={(event) => setInput({ ...input, quantity: event.target.value })} /></label>
      <label className="finance-dialog-field"><span>Açıklama</span><input value={input.description} onChange={(event) => setInput({ ...input, description: event.target.value })} /></label>
    </fieldset><p className="finance-dialog-help">Miktarı pozitif ve en fazla 4 ondalıkla girin. Açıklama 2–500 karakter olmalıdır.</p>
    {parsed.success && item ? <p>Stok etkisi: {quantityText(signedQuantity(input.movementType, parsed.data.quantity, input.direction))} {units[item.baseUnit]}</p> : null}
    <ErrorMessage error={mutation.error} /><Actions onClose={onClose} busy={mutation.isPending} disabled={!valid || context.isError} />
  </form></Modal>
}
export function InventoryCountStartDialog({ onClose, onCreated }: { onClose: () => void; onCreated: (id: string) => void }) {
  const context = useInventoryContext()
  const mutation = useCreateInventoryCount()
  const submitting = useRef(false)
  const [locationId, setLocationId] = useState('')
  const [notes, setNotes] = useState('')
  const valid = !!context.data?.locations.some((value) => value.id === locationId) && !!context.data?.items.length && notes.trim().length <= 2000
  async function submit(event: FormEvent) {
    event.preventDefault()
    if (!valid || submitting.current || mutation.isPending) return
    submitting.current = true
    try { onCreated(await mutation.mutateAsync({ locationId, notes })) } catch { /* Retry. */ } finally { submitting.current = false }
  }
  return <Modal title="Sayım Başlat" busy={mutation.isPending} onClose={onClose}><form onSubmit={submit}>
    <ErrorMessage error={context.error} />{context.isError ? <button type="button" onClick={() => { void context.refetch() }}>Tekrar dene</button> : null}
    <fieldset className="inventory-fields" disabled={mutation.isPending}><label className="finance-dialog-field"><span>Lokasyon</span><select value={locationId} onChange={(event) => setLocationId(event.target.value)}><option value="">Lokasyon seçin</option>{context.data?.locations.map((value) => <option key={value.id} value={value.id}>{value.name}</option>)}</select></label>
      <label className="finance-dialog-field"><span>Notlar</span><textarea value={notes} onChange={(event) => setNotes(event.target.value)} /></label></fieldset>
    <p>Aktif stok kartlarının sistem miktarları bu lokasyon için kaydedilir. Sayılan miktarlar işleme sırasında güncel stokla karşılaştırılır.</p>
    {context.data?.items.length === 0 ? <p role="status">Önce aktif bir stok kartı oluşturun.</p> : null}
    <ErrorMessage error={mutation.error} /><Actions onClose={onClose} busy={mutation.isPending} disabled={!valid || context.isError} label="Sayımı Başlat" />
  </form></Modal>
}
export function InventoryCountDialog({ countId, canCount, canAdjust, onClose }: { countId: string; canCount: boolean; canAdjust: boolean; onClose: () => void }) {
  const query = useInventoryCountDetail(countId)
  if (query.isPending) return <Modal title="Sayım" onClose={onClose}><p role="status">Yükleniyor...</p></Modal>
  if (query.isError) return <Modal title="Sayım" onClose={onClose}><ErrorMessage error={query.error} /><button onClick={() => { void query.refetch() }}>Tekrar dene</button></Modal>
  return <InventoryCountForm detail={query.data} canCount={canCount} canAdjust={canAdjust} onClose={onClose} />
}
export function InventoryCountForm({ detail, canCount, canAdjust, onClose }: { detail: CountDetail; canCount: boolean; canAdjust: boolean; onClose: () => void }) {
  const update = useUpdateInventoryCount()
  const post = usePostInventoryCount()
  const submitting = useRef(false)
  const locked = detail.status !== 'DRAFT' || !canCount
  const [values, setValues] = useState(() => Object.fromEntries(detail.lines.map((line) => [line.itemId, line.countedQuantity == null ? '' : String(line.countedQuantity)])))
  const [dirty, setDirty] = useState(false)
  const [confirm, setConfirm] = useState(false)
  const busy = update.isPending || post.isPending
  const valid = detail.lines.length > 0 && detail.lines.every((line) => parseQuantity(values[line.itemId] ?? '', true) !== null)
  async function save(event: FormEvent) {
    event.preventDefault()
    if (locked || !valid || submitting.current || busy) return
    submitting.current = true
    try { await update.mutateAsync({ countId: detail.id, lines: detail.lines.map((line) => ({ itemId: line.itemId, countedQuantity: parseQuantity(values[line.itemId], true)! })) }); setDirty(false) }
    catch { /* Keep entered quantities. */ } finally { submitting.current = false }
  }
  async function postCount() {
    if (locked || !canAdjust || !confirm || dirty || !valid || submitting.current || busy) return
    submitting.current = true
    try { await post.mutateAsync(detail.id); onClose() } catch { /* Preserve confirmation for retry. */ } finally { submitting.current = false }
  }
  return <Modal title={detail.status === 'CANCELLED' ? 'İptal Edildi' : detail.status === 'POSTED' ? 'İşlenmiş Sayım' : 'Stok Sayımı'} busy={busy} onClose={onClose}>
    <p>{detail.notes}</p><p className="finance-dialog-help">Sistem ve fark, taslakta başlangıç miktarını gösterir. İşlerken güncel stok yeniden hesaplanır.</p>
    {locked ? <p>Salt okunur · {detail.status !== 'DRAFT' ? 'Bu sayım değiştirilemez.' : 'Sayım yetkisi gerekir.'}</p> : null}
    <form onSubmit={save}><fieldset disabled={locked || busy || confirm} className="inventory-fields inventory-count-lines">
      {detail.lines.map((line) => { const counted = parseQuantity(values[line.itemId] ?? '', true); return <article key={line.itemId} className="inventory-count-line">
        <strong>{line.itemName} · {units[line.baseUnit]}</strong><span>Sistem: {quantityText(line.systemQuantity)}</span>
        <label className="finance-dialog-field"><span>Sayılan · {line.itemName}</span><input inputMode="decimal" value={values[line.itemId] ?? ''} onChange={(event) => { setValues({ ...values, [line.itemId]: event.target.value }); setDirty(true) }} /></label>
        <span>Fark: {counted == null ? '—' : quantityText(countDifference(counted, line.systemQuantity))}</span>
      </article> })}</fieldset>
      <ErrorMessage error={update.error} />{!locked ? <div className="finance-dialog-actions"><button type="submit" disabled={busy || !valid || !dirty || confirm}>Sayımı Kaydet</button>
        {canAdjust ? <button type="button" className="primary" disabled={busy || !valid || dirty || confirm} onClick={() => setConfirm(true)}>Sayımı İşle</button> : null}</div> : null}
      {dirty ? <p role="status">İşlemeden önce sayılan miktarları kaydedin.</p> : null}
    </form>
    {confirm && !locked ? <div className="inventory-confirm"><p>Sayım farkları stok hareketi olarak işlenecektir. İşlenmiş sayım değiştirilemez.</p><ErrorMessage error={post.error} />
      <div className="finance-dialog-actions"><button disabled={busy} onClick={() => setConfirm(false)}>Vazgeç</button><button className="primary" disabled={busy} onClick={() => { void postCount() }}>{busy ? 'İşleniyor...' : 'Onayla ve İşle'}</button></div></div> : null}
  </Modal>
}
export function InventoryCountCancelDialog({ countId, onClose }: { countId: string; onClose: () => void }) {
  const mutation = useCancelInventoryCount()
  const submitting = useRef(false)
  async function submit(event: FormEvent) {
    event.preventDefault()
    if (submitting.current || mutation.isPending) return
    submitting.current = true
    try { await mutation.mutateAsync(countId); onClose() } catch { /* Keep confirmation for retry. */ } finally { submitting.current = false }
  }
  return <Modal title="Sayımı İptal Et" busy={mutation.isPending} onClose={onClose}><form onSubmit={submit}>
    <p>Bu taslak sayım iptal edilecek. Herhangi bir stok hareketi oluşmayacaktır.</p>
    <ErrorMessage error={mutation.error} />
    <Actions onClose={onClose} busy={mutation.isPending} disabled={false} label="Onayla ve İptal Et" />
  </form></Modal>
}
