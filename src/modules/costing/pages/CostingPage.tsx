import { useState } from 'react'
import { Pencil, Plus, RefreshCw } from 'lucide-react'
import { useTenant } from '../../../shared/tenant/useTenant'
import { hasAccess } from '../../../core/access/accessUtils'
import { useInventoryCosts, useRecipeCosts, useMenuCosts } from '../queries/useCosting'
import { costMoney, costNumber, type Recipe, type MenuProduct } from '../model/costing'
import { units } from '../../inventory/model/inventory'
import { RecipeDialog, MenuProductDialog, MissingCost } from './CostingDialogs'
import { OperatingProfitability } from './OperatingProfitability'
import '../../finance/pages/FinancePage.css'
import './CostingPage.css'

export function CostingPage() {
  const { tenantId } = useTenant()
  return <CostingContent key={tenantId} />
}
function CostingContent() {
  const { context } = useTenant()
  const canWrite = !!context && hasAccess(context, { requiredModule: 'food-service', requiredPermission: 'food-service.costing.write' })
  const [tab, setTab] = useState<'purchase' | 'recipe' | 'menu' | 'period'>('purchase')
  const [currency, setCurrency] = useState('TRY')
  const [location, setLocation] = useState('')
  const [dialog, setDialog] = useState<{ kind: 'recipe'; recipe?: Recipe } | { kind: 'menu'; product?: MenuProduct } | null>(null)
  const inventory = useInventoryCosts(currency, location), recipes = useRecipeCosts(location), menu = useMenuCosts(location)
  const current = tab === 'purchase' ? inventory : tab === 'recipe' ? recipes : menu
  return <section className="finance-page costing-page">
    <div className="finance-heading"><div><span className="eyebrow">YÖNETİM</span><h1>Maliyet</h1><p>Net Alış Maliyeti · Purchase Cost Reference</p></div>
      {tab !== 'period' ? <button className="finance-refresh-button" disabled={current.isFetching} onClick={() => { void inventory.refetch(); void recipes.refetch(); void menu.refetch() }}><RefreshCw size={16} />Yenile</button> : null}</div>
    <div className="costing-toolbar"><div role="tablist" aria-label="Maliyet bölümleri">{([['purchase', 'Alış Maliyetleri'], ['recipe', 'Reçeteler'], ['menu', 'Menü Kârlılığı'], ['period', 'Dönem Kârlılığı']] as const).map(([key, label]) => <button key={key} id={`costing-tab-${key}`} role="tab" aria-selected={tab === key} aria-controls="costing-panel" onClick={() => setTab(key)}>{label}</button>)}</div>
      {tab !== 'period' ? <label className="finance-dialog-field"><span>Lokasyon</span><select value={location} onChange={(e) => setLocation(e.target.value)}><option value="">Tüm lokasyonlar</option>{inventory.data?.locations.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}</select></label> : null}
      {tab === 'purchase' ? <label className="finance-dialog-field"><span>Para birimi filtresi</span><input aria-label="Para birimi filtresi" maxLength={3} value={currency} onChange={(e) => setCurrency(e.target.value.toUpperCase())} /></label> : null}
      {canWrite && (tab === 'recipe' || tab === 'menu') ? <button className="finance-refresh-button" disabled={recipes.isPending || recipes.isError} onClick={() => setDialog({ kind: tab === 'recipe' ? 'recipe' : 'menu' })}><Plus size={16} />{tab === 'recipe' ? 'Yeni Reçete' : 'Yeni Menü Ürünü'}</button> : null}
    </div>
    <div role="tabpanel" id="costing-panel" aria-labelledby={`costing-tab-${tab}`}>
      {tab === 'period' ? <OperatingProfitability canWrite={canWrite} /> : tab === 'purchase' && !/^[A-Z]{3}$/.test(currency) ? <p role="status">Üç harfli para birimi girin.</p> : current.isPending ? <p role="status">Maliyetler yükleniyor...</p> : current.isError ? <div role="alert">{current.error.message}<button onClick={() => { void current.refetch() }}>Tekrar dene</button></div> : <>
        {tab === 'purchase' ? <div className="costing-table-wrap"><table><caption>Alış Maliyetleri · {currency}</caption><thead><tr>{['Stok kartı', 'Baz birim', 'Son alış / baz birim', 'Önceki alış', 'Değişim %', 'Ağırlıklı Alış Maliyeti', 'Son tedarikçi', 'Son fatura tarihi'].map((h) => <th key={h}>{h}</th>)}</tr></thead><tbody>
          {inventory.data?.items.map((i) => <tr key={i.id}><th scope="row">{i.name}<small>{i.sku}</small></th><td>{units[i.baseUnit]}</td>{i.costStatus === 'NO_PURCHASE_COST' ? <td colSpan={6}>Alış maliyeti yok</td> : <><td>{costMoney(i.lastPurchase?.unitCost ?? null, currency, 6)}</td><td>{costMoney(i.previousPurchase?.unitCost ?? null, currency, 6)}</td><td>{i.priceChangePct !== null && i.priceChangePct > 0 ? '+' : ''}{costNumber(i.priceChangePct)}</td><td>{costMoney(i.weightedPurchaseUnitCost, currency, 6)}</td><td>{i.lastPurchase?.supplierName}</td><td>{i.lastPurchase?.invoiceDate}<small>{i.lastPurchase?.invoiceNumber}</small></td></>}</tr>)}
          {!inventory.data?.items.length ? <tr><td colSpan={8}>Aktif stok kartı yok.</td></tr> : null}
        </tbody></table></div> : tab === 'recipe' ? <div className="costing-recipes">{recipes.data?.recipes.length ? recipes.data.recipes.map((r) => <article key={r.id} className="costing-recipe">
          <div className="costing-record-heading"><h2>{r.name}</h2><span>{r.currencyCode} · {costNumber(r.portions, 4)} porsiyon · {r.status === 'ACTIVE' ? 'Aktif' : 'Pasif'}</span>{canWrite ? <button title="Reçeteyi düzenle" aria-label={`${r.name} düzenle`} onClick={() => setDialog({ kind: 'recipe', recipe: r })}><Pencil size={17} /></button> : null}</div>
          {!r.costingComplete ? <MissingCost count={r.missingCostItemCount} /> : null}
          <div className="costing-table-wrap"><table><thead><tr>{['Malzeme', 'Baz miktar', 'Son birim maliyet', 'Ağırlıklı birim maliyet', 'Son satır maliyeti', 'Ağırlıklı satır maliyeti'].map((h) => <th key={h}>{h}</th>)}</tr></thead><tbody>{r.lines.map((l) => <tr key={l.inventoryItemId}><th scope="row">{l.itemName}{l.costStatus === 'NO_PURCHASE_COST' ? <small>Alış maliyeti yok</small> : null}</th><td>{costNumber(l.quantityBase, 4)} {units[l.baseUnit]}</td><td>{costMoney(l.lastUnitCost, r.currencyCode, 6)}</td><td>{costMoney(l.weightedUnitCost, r.currencyCode, 6)}</td><td>{costMoney(l.lastLineCost, r.currencyCode)}</td><td>{costMoney(l.weightedLineCost, r.currencyCode)}</td></tr>)}</tbody></table></div>
          <dl className="costing-totals"><div><dt>Batch Son Alış Maliyeti</dt><dd>{costMoney(r.totalLastCost, r.currencyCode)}</dd></div><div><dt>Batch Ağırlıklı Maliyet</dt><dd>{costMoney(r.totalWeightedCost, r.currencyCode)}</dd></div><div><dt>Porsiyon Son Alış Maliyeti</dt><dd>{costMoney(r.costPerPortionLast, r.currencyCode)}</dd></div><div><dt>Porsiyon Ağırlıklı Maliyet</dt><dd>{costMoney(r.costPerPortionWeighted, r.currencyCode)}</dd></div></dl>
        </article>) : <p>Henüz reçete yok.</p>}</div> : <div className="costing-table-wrap"><table><caption>Menü Kârlılığı</caption><thead><tr>{['Ürün', 'Satış Fiyatı (KDV dahil)', 'Net Satış', 'Porsiyon Maliyeti', 'Food Cost %', 'Katkı Payı (Genel gider öncesi)', 'Hedef Food Cost %', 'Hedeften (puan)', 'Hedef Food Cost’a Göre Fiyat', ''].map((h) => <th key={h}>{h}</th>)}</tr></thead><tbody>{menu.data?.products.map((p) => <tr key={p.id}><th scope="row">{p.name}<small>{p.recipeName} · {p.costMethod === 'LAST_PURCHASE' ? 'Son Alış' : 'Ağırlıklı Alış'} · {p.status === 'ACTIVE' ? 'Aktif' : 'Pasif'}</small>{!p.costingComplete ? <small className="costing-missing">Maliyet eksik: {p.missingCostItemCount} malzeme</small> : null}</th><td>{costMoney(p.salePriceGross, p.currencyCode)}</td><td>{costMoney(p.salePriceNet, p.currencyCode)}</td><td>{costMoney(p.recipeCostPerPortion, p.currencyCode)}</td><td>{costNumber(p.foodCostPct)}</td><td>{costMoney(p.contributionMargin, p.currencyCode)}</td><td>{costNumber(p.targetFoodCostPct)}</td><td>{p.targetDifferencePp !== null && p.targetDifferencePp > 0 ? '+' : ''}{costNumber(p.targetDifferencePp)}</td><td>{costMoney(p.suggestedGrossPrice, p.currencyCode)}</td><td>{canWrite ? <button title="Menü ürününü düzenle" aria-label={`${p.name} düzenle`} onClick={() => setDialog({ kind: 'menu', product: p })}><Pencil size={17} /></button> : null}</td></tr>)}{!menu.data?.products.length ? <tr><td colSpan={10}>Henüz menü ürünü yok.</td></tr> : null}</tbody></table></div>}
      </>}
    </div>
    {canWrite && dialog?.kind === 'recipe' ? <RecipeDialog recipe={dialog.recipe} location={location} onClose={() => setDialog(null)} /> : null}
    {canWrite && dialog?.kind === 'menu' ? <MenuProductDialog product={dialog.product} recipes={recipes.data?.recipes ?? []} onClose={() => setDialog(null)} /> : null}
  </section>
}
