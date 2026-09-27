import { useRef, useState, type FormEvent } from 'react'
import { useInventoryPurchaseUnits } from '../queries/useInventory'
import { useSaveInventoryPurchaseUnit } from '../mutations/useInventoryCommands'
import { purchaseUnitInputSchema, units, type InventoryItem, type PurchaseUnit, type PurchaseUnitInput } from '../model/inventory'

export function InventoryPurchaseUnitsDialog({ item, canWrite, onClose }: { item: InventoryItem; canWrite: boolean; onClose: () => void }) {
  const query = useInventoryPurchaseUnits(item.id)
  const mutation = useSaveInventoryPurchaseUnit()
  const submitting = useRef(false)
  const [editing, setEditing] = useState<PurchaseUnit | null>(null)
  const [input, setInput] = useState<PurchaseUnitInput>({ name: '', conversion: '', status: 'ACTIVE' })
  const writable = canWrite && item.status === 'ACTIVE'
  const valid = purchaseUnitInputSchema.safeParse(input).success
  async function submit(event: FormEvent) {
    event.preventDefault()
    if (!writable || !valid || submitting.current || mutation.isPending) return
    submitting.current = true
    try { await mutation.mutateAsync({ itemId: item.id, unitId: editing?.id, input }); setEditing(null); setInput({ name: '', conversion: '', status: 'ACTIVE' }) }
    catch { /* Preserve edits for retry. */ } finally { submitting.current = false }
  }
  function edit(unit: PurchaseUnit) { mutation.reset(); setEditing(unit); setInput({ name: unit.name, conversion: String(unit.conversionToBase), status: unit.status }) }
  return <div className="finance-dialog-backdrop"><section className="finance-dialog inventory-dialog" role="dialog" aria-modal="true" aria-labelledby="purchase-units-title">
    <div className="finance-dialog-heading"><div><span>{item.name} · {units[item.baseUnit]}</span><h2 id="purchase-units-title">Satınalma Birimleri</h2></div><button aria-label="Kapat" disabled={mutation.isPending} onClick={onClose}>×</button></div>
    <div className="inventory-units-list">{query.isPending ? <p>Yükleniyor...</p> : query.isError ? <div role="alert">{query.error.message}<button onClick={() => { void query.refetch() }}>Tekrar dene</button></div> : query.data.units.length ? query.data.units.map((unit) => <article key={unit.id}>
      <span>1 {unit.name} = {new Intl.NumberFormat('tr-TR', { maximumFractionDigits: 6 }).format(unit.conversionToBase)} {units[item.baseUnit]} · {unit.status === 'ACTIVE' ? 'Aktif' : 'Pasif'}</span>
      {writable ? <button className="finance-refresh-button" disabled={mutation.isPending} aria-label={`${unit.name} düzenle`} onClick={() => edit(unit)}>Düzenle</button> : null}
    </article>) : <p>Henüz satınalma birimi yok.</p>}</div>
    {writable ? <form onSubmit={submit}><strong>{editing ? 'Birimi Düzenle' : 'Yeni Satınalma Birimi'}</strong><fieldset className="inventory-fields" disabled={mutation.isPending}>
      <label className="finance-dialog-field"><span>Birim Adı</span><input value={input.name} onChange={(event) => setInput({ ...input, name: event.target.value })} /></label>
      <label className="finance-dialog-field"><span>Baz Birime Dönüşüm</span><input inputMode="decimal" value={input.conversion} onChange={(event) => setInput({ ...input, conversion: event.target.value })} /></label>
      {editing ? <label className="finance-dialog-field"><span>Durum</span><select value={input.status} onChange={(event) => setInput({ ...input, status: event.target.value as PurchaseUnitInput['status'] })}><option value="ACTIVE">Aktif</option><option value="PASSIVE">Pasif</option></select></label> : null}
    </fieldset><p>1 satınalma birimi kaç {units[item.baseUnit]}? Pozitif, en fazla 6 ondalık girin. Değişiklikler gelecekte işlenecek taslaklara uygulanır.</p>
    {mutation.error ? <div role="alert" className="finance-dialog-error">{mutation.error.message}</div> : null}
    <div className="finance-dialog-actions">{editing ? <button type="button" disabled={mutation.isPending} onClick={() => { setEditing(null); mutation.reset(); setInput({ name: '', conversion: '', status: 'ACTIVE' }) }}>Yeni Birim</button> : null}
      <button type="submit" className="primary" disabled={!valid || mutation.isPending}>{mutation.isPending ? 'Kaydediliyor...' : 'Birimi Kaydet'}</button></div></form> : <p>Salt okunur · Birim yönetimi için aktif stok kartı ve stok düzenleme yetkisi gerekir.</p>}
  </section></div>
}
