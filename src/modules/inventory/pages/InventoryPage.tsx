import { useState } from 'react'
import { hasAccess } from '../../../core/access/accessUtils'
import { useTenant } from '../../../shared/tenant/useTenant'
import { useInventoryOverview, useInventoryManagement, useInventoryCounts } from '../queries/useInventory'
import { units, movementNames, quantityText, type InventoryItem } from '../model/inventory'
import { InventoryItemDialog, InventoryMovementDialog, InventoryCountStartDialog, InventoryCountDialog } from './InventoryDialogs'
import '../../finance/pages/FinancePage.css'
import './InventoryPage.css'

export function InventoryPage() {
  const { tenantId } = useTenant()
  return <InventoryWorkspace key={tenantId} />
}
function InventoryWorkspace() {
  const { context } = useTenant()
  const [locationId, setLocationId] = useState('')
  const [manage, setManage] = useState(false)
  const [mode, setMode] = useState<{ kind: 'item'; item?: InventoryItem } | { kind: 'movement' | 'start' } | { kind: 'count'; id: string } | null>(null)
  const overview = useInventoryOverview(locationId)
  const management = useInventoryManagement(manage)
  const counts = useInventoryCounts()
  const canWrite = !!context && hasAccess(context, { requiredModule: 'inventory', requiredPermission: 'inventory.write' })
  const canAdjust = !!context && hasAccess(context, { requiredModule: 'inventory', requiredPermission: 'inventory.adjust' })
  const canCount = !!context && hasAccess(context, { requiredModule: 'inventory', requiredPermission: 'inventory.count' })
  if (overview.isPending) return <section className="finance-state">Stok yükleniyor...</section>
  if (overview.isError) return <section className="finance-state finance-state-error"><strong>{overview.error.message}</strong><button onClick={() => { void overview.refetch() }}>Tekrar dene</button></section>
  const data = overview.data
  const items = manage ? management.data?.items ?? [] : data.items.filter((item) => item.status === 'ACTIVE')
  return <section className="finance-page"><div className="finance-heading"><div><span className="eyebrow">STOK</span><h1>Stok Yönetimi</h1><p>Baz birimde stok takibi, hareketler ve sayımlar.</p></div>
    <div className="finance-heading-actions">{canWrite ? <button className="finance-refresh-button" onClick={() => setMode({ kind: 'item' })}>Yeni Stok Kartı</button> : null}
      {canAdjust ? <button className="finance-refresh-button" onClick={() => setMode({ kind: 'movement' })}>Hareket Ekle</button> : null}
      {canCount ? <button className="finance-refresh-button" onClick={() => setMode({ kind: 'start' })}>Sayım Başlat</button> : null}</div></div>
    <label className="finance-dialog-field inventory-filter"><span>Lokasyon Filtresi</span><select value={locationId} onChange={(event) => setLocationId(event.target.value)}><option value="">Tüm lokasyonlar</option>{data.locations.map((location) => <option key={location.id} value={location.id}>{location.name}{location.status === 'PASSIVE' ? ' (Pasif)' : ''}</option>)}</select></label>
    <div className="finance-summary-grid">{([['Aktif Stok Kartı', data.summary.activeItemCount], ['Kritik Stok', data.summary.criticalItemCount], ['Negatif Stok', data.summary.negativeItemCount]] as const).map(([label, value]) => <article className="finance-summary-card" key={label}><div><span>{label}</span><strong>{value}</strong></div></article>)}</div>
    <section className="finance-panel"><div className="finance-panel-heading"><h2>Stok Kartları</h2><label><input type="checkbox" checked={manage} onChange={(event) => setManage(event.target.checked)} /> Pasif kartları da yönet</label></div>
      {manage ? <p>Kart yönetimi miktarları tüm lokasyonların toplamıdır.</p> : null}
      {manage && management.isPending ? <p>Yükleniyor...</p> : manage && management.isError ? <div role="alert">{management.error.message}<button onClick={() => { void management.refetch() }}>Tekrar dene</button></div> :
        items.length === 0 ? <p className="finance-empty-state">Henüz stok kartı yok.</p> : <div className="inventory-cards">{items.map((item) => <article key={item.id} className={`inventory-card ${item.isNegative ? 'inventory-negative' : item.isCritical ? 'inventory-critical' : ''}`}>
          <div className="inventory-card-heading"><h3>{item.name}</h3><span>{item.status === 'PASSIVE' ? 'Pasif' : item.isNegative ? 'Negatif Stok' : item.isCritical ? 'Kritik Stok' : 'Normal'}</span></div>
          <strong>{quantityText(item.quantity)} {units[item.baseUnit]}</strong><dl className="finance-account-details"><div><dt>SKU</dt><dd>{item.sku ?? '—'}</dd></div><div><dt>Kategori</dt><dd>{item.category ?? '—'}</dd></div>
            <div><dt>Kritik Seviye</dt><dd>{item.criticalStock == null ? '—' : `${quantityText(item.criticalStock)} ${units[item.baseUnit]}`}</dd></div><div><dt>Durum</dt><dd>{item.status === 'ACTIVE' ? 'Aktif' : 'Pasif'}</dd></div></dl>
          {canWrite ? <button className="finance-refresh-button" aria-label={`${item.name} düzenle`} onClick={() => setMode({ kind: 'item', item })}>Düzenle</button> : null}</article>)}</div>}
    </section>
    <section className="finance-panel"><div className="finance-panel-heading"><h2>Son Sayımlar</h2></div>{counts.isError ? <div role="alert">{counts.error.message}<button onClick={() => { void counts.refetch() }}>Tekrar dene</button></div> : counts.isPending ? <p>Yükleniyor...</p> : counts.data.counts.length ? <div className="inventory-cards">{counts.data.counts.map((count) => <article className="inventory-card" key={count.id}><h3>{count.locationName}</h3><p>{new Date(count.countedAt).toLocaleString('tr-TR')} · {count.status === 'POSTED' ? 'İşlendi' : 'Taslak'}</p><button className="finance-refresh-button" onClick={() => setMode({ kind: 'count', id: count.id })}>{count.status === 'DRAFT' && canCount ? 'Sayımı Aç' : 'Görüntüle'}</button></article>)}</div> : <p className="finance-empty-state">Henüz sayım yok.</p>}</section>
    <section className="finance-panel"><div className="finance-panel-heading"><h2>Son Hareketler</h2></div>{data.recentMovements.length ? <div className="inventory-cards">{data.recentMovements.map((movement) => <article className="inventory-card" key={movement.id}><h3>{movement.itemName}</h3><strong>{movementNames[movement.movementType]} · {quantityText(movement.quantity)}</strong><p>{movement.locationName} · {new Date(movement.occurredAt).toLocaleString('tr-TR')}</p><p>{movement.description}</p></article>)}</div> : <p className="finance-empty-state">Henüz hareket yok.</p>}</section>
    {mode?.kind === 'item' && canWrite ? <InventoryItemDialog item={mode.item} onClose={() => setMode(null)} /> : null}
    {mode?.kind === 'movement' && canAdjust ? <InventoryMovementDialog onClose={() => setMode(null)} /> : null}
    {mode?.kind === 'start' && canCount ? <InventoryCountStartDialog onClose={() => setMode(null)} onCreated={(id) => setMode({ kind: 'count', id })} /> : null}
    {mode?.kind === 'count' ? <InventoryCountDialog countId={mode.id} canCount={canCount} canAdjust={canAdjust} onClose={() => setMode(null)} /> : null}
  </section>
}
