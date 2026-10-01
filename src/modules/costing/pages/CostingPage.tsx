import { useState } from 'react'
import { Link } from 'react-router-dom'
import { Pencil, Plus, RefreshCw } from 'lucide-react'
import { useTenant } from '../../../shared/tenant/useTenant'
import { hasAccess } from '../../../core/access/accessUtils'
import { useInventoryCosts, useRecipeCosts, useMenuCosts } from '../queries/useCosting'
import { costingReadiness, costMoney, costNumber, sourceUnitLabel, subrecipeCostStatusLabel, type Recipe, type MenuProduct } from '../model/costing'
import { units } from '../../inventory/model/inventory'
import { RecipeDialog, MenuProductDialog, MissingCost } from './CostingDialogs'
import { OperatingProfitability } from './OperatingProfitability'
import '../../finance/pages/FinancePage.css'
import './CostingPage.css'

export function CostingPage() {
  const { tenantId } = useTenant()
  return <CostingContent key={tenantId} />
}

function CostingReadinessPanel({ recipes, canPurchase }: { recipes: Recipe[]; canPurchase: boolean }) {
  const readiness = costingReadiness(recipes)
  if (!readiness.totalRecipes) return <div className="costing-readiness"><h2>Maliyet Hazırlık Merkezi</h2><p>Henüz reçete yok.</p></div>

  return <div className="costing-readiness">
    <div className="costing-readiness-intro">
      <div><h2>Maliyet Hazırlık Merkezi</h2><p>Gerçek maliyet oluşmadan ürün kârlılığı hesaplanmaz. Eksikler, en fazla reçeteyi etkileyenden başlayarak sıralanır.</p></div>
      <strong>{readiness.readyRecipes} / {readiness.totalRecipes} reçete hazır</strong>
    </div>
    <dl className="costing-readiness-summary">
      <div><dt>Hazırlık oranı</dt><dd>{costNumber(readiness.readinessPct, 1)}%</dd><small>{readiness.incompleteRecipes} reçete eksik</small></div>
      <div><dt>Alış maliyeti bekleyen malzeme</dt><dd>{readiness.missingPurchaseItemCount}</dd><small>Gerçek satınalma verisi gerekli</small></div>
      <div><dt>Birim dönüşümü bekleyen satır</dt><dd>{readiness.conversionBlockerCount}</dd><small>Tahmin yapılmaz</small></div>
      <div><dt>Alt reçete engeli</dt><dd>{readiness.subrecipeBlockerCount}</dd><small>Kullanım / verim / alt maliyet</small></div>
    </dl>

    {readiness.incompleteRecipes === 0 ? <p className="costing-readiness-success" role="status">Tüm reçeteler maliyet hesabına hazır.</p> : null}

    {readiness.missingPurchaseItems.length ? <section className="costing-readiness-section">
      <div className="costing-record-heading"><div><h3>1. Alış maliyeti eksikleri</h3><p>Önce en çok reçeteyi bloke eden malzemeleri tamamlayın. Alış maliyetinin kaynağı satınalma / faturadır; burada manuel maliyet uydurulmaz.</p></div>{canPurchase ? <Link className="costing-action-link" to="/purchasing">Satınalma / Faturaya Git</Link> : null}</div>
      <div className="costing-table-wrap"><table><caption>Etki sırasına göre alış maliyeti kuyruğu</caption><thead><tr><th>Malzeme</th><th>Baz birim</th><th>Etkilenen reçete</th><th>Eksik satır</th></tr></thead><tbody>
        {readiness.missingPurchaseItems.map((item) => <tr key={item.inventoryItemId}><th scope="row">{item.itemName}</th><td>{units[item.baseUnit]}</td><td>{item.recipeCount}</td><td>{item.lineCount}</td></tr>)}
      </tbody></table></div>
    </section> : null}

    {readiness.conversionBlockers.length ? <section className="costing-readiness-section">
      <div className="costing-record-heading"><div><h3>2. Birim dönüşümü gereken satırlar</h3><p>Yoğunluk, adet ağırlığı veya benzeri gerçek dönüşüm verisi girilene kadar bu satırlar maliyete katılmaz.</p></div></div>
      <div className="costing-table-wrap"><table><caption>Dönüşüm kuyruğu</caption><thead><tr><th>Reçete</th><th>Malzeme</th><th>Kaynak miktar</th><th>Stok baz birimi</th></tr></thead><tbody>
        {readiness.conversionBlockers.map((line) => <tr key={`${line.recipeId}-${line.unresolvedLineId}`}><th scope="row">{line.recipeName}<small>{line.recipeCode}</small></th><td>{line.itemName}</td><td>{costNumber(line.sourceQuantity, 4)} {sourceUnitLabel(line.sourceUnit)}</td><td>{units[line.baseUnit]}</td></tr>)}
      </tbody></table></div>
    </section> : null}

    {readiness.subrecipeBlockers.length ? <section className="costing-readiness-section">
      <div className="costing-record-heading"><div><h3>3. Alt reçete engelleri</h3><p>Alt reçetenin kullanım miktarı, üretim verimi veya kendi maliyeti tamamlanmalıdır.</p></div></div>
      <div className="costing-table-wrap"><table><caption>Alt reçete kuyruğu</caption><thead><tr><th>Ana reçete</th><th>Alt reçete</th><th>Durum</th></tr></thead><tbody>
        {readiness.subrecipeBlockers.map((line, index) => <tr key={`${line.recipeId}-${line.subrecipeId}-${index}`}><th scope="row">{line.recipeName}<small>{line.recipeCode}</small></th><td>{line.subrecipeName}<small>{line.subrecipeCode}</small></td><td>{subrecipeCostStatusLabel(line.costStatus)}</td></tr>)}
      </tbody></table></div>
    </section> : null}
  </div>
}

function CostingContent() {
  const { context } = useTenant()
  const canWrite = !!context && hasAccess(context, { requiredModule: 'food-service', requiredPermission: 'food-service.costing.write' })
  const canPurchase = !!context && hasAccess(context, { requiredModule: 'purchasing', requiredPermission: 'purchasing.read' })
  const [tab, setTab] = useState<'readiness' | 'purchase' | 'recipe' | 'menu' | 'period'>('readiness')
  const [currency, setCurrency] = useState('TRY')
  const [location, setLocation] = useState('')
  const [dialog, setDialog] = useState<{ kind: 'recipe'; recipe?: Recipe } | { kind: 'menu'; product?: MenuProduct } | null>(null)
  const inventory = useInventoryCosts(currency, location), recipes = useRecipeCosts(location), menu = useMenuCosts(location)
  const current = tab === 'purchase' ? inventory : tab === 'menu' ? menu : recipes
  return <section className="finance-page costing-page">
    <div className="finance-heading"><div><span className="eyebrow">YÖNETİM</span><h1>Maliyet</h1><p>Gerçek maliyet · fiyatlandırma · ürün kârlılığı</p></div>
      {tab !== 'period' ? <button className="finance-refresh-button" disabled={current.isFetching} onClick={() => { void inventory.refetch(); void recipes.refetch(); void menu.refetch() }}><RefreshCw size={16} />Yenile</button> : null}</div>
    <div className="costing-toolbar"><div role="tablist" aria-label="Maliyet bölümleri">{([['readiness', 'Hazırlık Merkezi'], ['purchase', 'Alış Maliyetleri'], ['recipe', 'Reçeteler'], ['menu', 'Menü Kârlılığı'], ['period', 'Dönem Kârlılığı']] as const).map(([key, label]) => <button key={key} id={`costing-tab-${key}`} role="tab" aria-selected={tab === key} aria-controls="costing-panel" onClick={() => setTab(key)}>{label}</button>)}</div>
      {tab !== 'period' ? <label className="finance-dialog-field"><span>Lokasyon</span><select value={location} onChange={(e) => setLocation(e.target.value)}><option value="">Tüm lokasyonlar</option>{inventory.data?.locations.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}</select></label> : null}
      {tab === 'purchase' ? <label className="finance-dialog-field"><span>Para birimi filtresi</span><input aria-label="Para birimi filtresi" maxLength={3} value={currency} onChange={(e) => setCurrency(e.target.value.toUpperCase())} /></label> : null}
      {canWrite && (tab === 'recipe' || tab === 'menu') ? <button className="finance-refresh-button" disabled={recipes.isPending || recipes.isError} onClick={() => setDialog({ kind: tab === 'recipe' ? 'recipe' : 'menu' })}><Plus size={16} />{tab === 'recipe' ? 'Yeni Reçete' : 'Yeni Menü Ürünü'}</button> : null}
    </div>
    <div role="tabpanel" id="costing-panel" aria-labelledby={`costing-tab-${tab}`}>
      {tab === 'period' ? <OperatingProfitability canWrite={canWrite} /> : tab === 'purchase' && !/^[A-Z]{3}$/.test(currency) ? <p role="status">Üç harfli para birimi girin.</p> : current.isPending ? <p role="status">Maliyetler yükleniyor...</p> : current.isError ? <div role="alert">{current.error.message}<button onClick={() => { void current.refetch() }}>Tekrar dene</button></div> : <>
        {tab === 'readiness' ? <CostingReadinessPanel recipes={recipes.data?.recipes ?? []} canPurchase={canPurchase} /> : tab === 'purchase' ? <div className="costing-table-wrap"><table><caption>Alış Maliyetleri · {currency}</caption><thead><tr>{['Stok kartı', 'Baz birim', 'Son alış / baz birim', 'Önceki alış', 'Değişim %', 'Ağırlıklı Alış Maliyeti', 'Son tedarikçi', 'Son fatura tarihi'].map((h) => <th key={h}>{h}</th>)}</tr></thead><tbody>
          {inventory.data?.items.map((i) => <tr key={i.id}><th scope="row">{i.name}<small>{i.sku}</small></th><td>{units[i.baseUnit]}</td>{i.costStatus === 'NO_PURCHASE_COST' ? <td colSpan={6}>Alış maliyeti yok</td> : <><td>{costMoney(i.lastPurchase?.unitCost ?? null, currency, 6)}</td><td>{costMoney(i.previousPurchase?.unitCost ?? null, currency, 6)}</td><td>{i.priceChangePct !== null && i.priceChangePct > 0 ? '+' : ''}{costNumber(i.priceChangePct)}</td><td>{costMoney(i.weightedPurchaseUnitCost, currency, 6)}</td><td>{i.lastPurchase?.supplierName}</td><td>{i.lastPurchase?.invoiceDate}<small>{i.lastPurchase?.invoiceNumber}</small></td></>}</tr>)}
          {!inventory.data?.items.length ? <tr><td colSpan={8}>Aktif stok kartı yok.</td></tr> : null}
        </tbody></table></div> : tab === 'recipe' ? <div className="costing-recipes">{recipes.data?.recipes.length ? recipes.data.recipes.map((r) => <article key={r.id} className="costing-recipe">
          <div className="costing-record-heading"><h2>{r.name}</h2><span>{r.currencyCode} · {costNumber(r.portions, 4)} porsiyon · {r.status === 'ACTIVE' ? 'Aktif' : 'Pasif'}</span>{canWrite ? <button title="Reçeteyi düzenle" aria-label={`${r.name} düzenle`} onClick={() => setDialog({ kind: 'recipe', recipe: r })}><Pencil size={17} /></button> : null}</div>
          {!r.costingComplete ? <>{r.missingPurchaseCostItemCount > 0 ? <MissingCost count={r.missingPurchaseCostItemCount} /> : null}{r.missingConversionItemCount > 0 ? <p className="costing-warning" role="status">{r.missingConversionItemCount} reçete satırında kaynak birim, stok baz birimine güvenle dönüştürülemiyor. Maliyet hesaplanmadı.</p> : null}{r.missingSubrecipeCostCount > 0 ? <p className="costing-warning" role="status">{r.missingSubrecipeCostCount} alt reçete bağlantısında kullanım/verim veya alt reçete maliyeti eksik.</p> : null}</> : null}
          <div className="costing-table-wrap"><table><thead><tr>{['Malzeme', 'Baz miktar', 'Son birim maliyet', 'Ağırlıklı birim maliyet', 'Son satır maliyeti', 'Ağırlıklı satır maliyeti'].map((h) => <th key={h}>{h}</th>)}</tr></thead><tbody>{r.lines.map((l, index) => <tr key={`${l.inventoryItemId}-${index}`}><th scope="row">{l.itemName}{l.costStatus === 'NO_PURCHASE_COST' ? <small>Alış maliyeti yok</small> : null}</th><td>{costNumber(l.quantityBase, 4)} {units[l.baseUnit]}</td><td>{costMoney(l.lastUnitCost, r.currencyCode, 6)}</td><td>{costMoney(l.weightedUnitCost, r.currencyCode, 6)}</td><td>{costMoney(l.lastLineCost, r.currencyCode)}</td><td>{costMoney(l.weightedLineCost, r.currencyCode)}</td></tr>)}</tbody></table></div>
          {r.unresolvedLines.length ? <div className="costing-table-wrap"><table><caption>Birim dönüşümü bekleyen reçete satırları</caption><thead><tr><th>Malzeme</th><th>Kaynak miktar</th><th>Stok baz birimi</th><th>Durum</th></tr></thead><tbody>{r.unresolvedLines.map((l) => <tr key={l.unresolvedLineId}><th scope="row">{l.itemName}<small>{l.sourceLineKey}</small></th><td>{costNumber(l.sourceQuantity, 4)} {sourceUnitLabel(l.sourceUnit)}</td><td>{units[l.baseUnit]}</td><td>Dönüşüm verisi gerekli</td></tr>)}</tbody></table></div> : null}
          {r.subrecipeLines.length ? <div className="costing-table-wrap"><table><caption>Alt reçeteler</caption><thead><tr><th>Alt reçete</th><th>Kullanım</th><th>Üretim verimi</th><th>Durum</th></tr></thead><tbody>{r.subrecipeLines.map((l, index) => <tr key={`${l.subrecipeId}-${index}`}><th scope="row">{l.subrecipeName}<small>{l.subrecipeCode}</small></th><td>{l.quantity === null || l.unit === null ? '—' : `${costNumber(l.quantity, 4)} ${units[l.unit]}`}</td><td>{l.yieldQuantity === null || l.yieldUnit === null ? '—' : `${costNumber(l.yieldQuantity, 4)} ${units[l.yieldUnit]}`}</td><td>{subrecipeCostStatusLabel(l.costStatus)}</td></tr>)}</tbody></table></div> : null}
          <dl className="costing-totals"><div><dt>Batch Son Alış Maliyeti</dt><dd>{costMoney(r.totalLastCost, r.currencyCode)}</dd></div><div><dt>Batch Ağırlıklı Maliyet</dt><dd>{costMoney(r.totalWeightedCost, r.currencyCode)}</dd></div><div><dt>Porsiyon Son Alış Maliyeti</dt><dd>{costMoney(r.costPerPortionLast, r.currencyCode)}</dd></div><div><dt>Porsiyon Ağırlıklı Maliyet</dt><dd>{costMoney(r.costPerPortionWeighted, r.currencyCode)}</dd></div></dl>
        </article>) : <p>Henüz reçete yok.</p>}</div> : <div className="costing-table-wrap"><table><caption>Menü Kârlılığı</caption><thead><tr>{['Ürün', 'Satış Fiyatı (KDV dahil)', 'Net Satış', 'Porsiyon Maliyeti', 'Food Cost %', 'Katkı Payı (Genel gider öncesi)', 'Hedef Food Cost %', 'Hedeften (puan)', 'Hedef Food Cost’a Göre Fiyat', ''].map((h) => <th key={h}>{h}</th>)}</tr></thead><tbody>{menu.data?.products.map((p) => <tr key={p.id}><th scope="row">{p.name}<small>{p.recipeName} · {p.costMethod === 'LAST_PURCHASE' ? 'Son Alış' : 'Ağırlıklı Alış'} · {p.status === 'ACTIVE' ? 'Aktif' : 'Pasif'}</small>{!p.costingComplete ? <small className="costing-missing">Maliyet eksik: {p.missingCostItemCount} kalem</small> : null}</th><td>{costMoney(p.salePriceGross, p.currencyCode)}</td><td>{costMoney(p.salePriceNet, p.currencyCode)}</td><td>{costMoney(p.recipeCostPerPortion, p.currencyCode)}</td><td>{costNumber(p.foodCostPct)}</td><td>{costMoney(p.contributionMargin, p.currencyCode)}</td><td>{costNumber(p.targetFoodCostPct)}</td><td>{p.targetDifferencePp !== null && p.targetDifferencePp > 0 ? '+' : ''}{costNumber(p.targetDifferencePp)}</td><td>{costMoney(p.suggestedGrossPrice, p.currencyCode)}</td><td>{canWrite ? <button title="Menü ürününü düzenle" aria-label={`${p.name} düzenle`} onClick={() => setDialog({ kind: 'menu', product: p })}><Pencil size={17} /></button> : null}</td></tr>)}{!menu.data?.products.length ? <tr><td colSpan={10}>Henüz menü ürünü yok.</td></tr> : null}</tbody></table></div>}
      </>}
    </div>
    {canWrite && dialog?.kind === 'recipe' ? <RecipeDialog recipe={dialog.recipe} location={location} onClose={() => setDialog(null)} /> : null}
    {canWrite && dialog?.kind === 'menu' ? <MenuProductDialog product={dialog.product} recipes={recipes.data?.recipes ?? []} onClose={() => setDialog(null)} /> : null}
  </section>
}
