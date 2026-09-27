import { useRef, useState, type ReactNode, type FormEvent } from 'react'
import { Plus, Trash2, X } from 'lucide-react'
import { useInventoryCosts } from '../queries/useCosting'
import { useSaveRecipe, useSaveMenuProduct } from '../mutations/useCostingCommands'
import { costMoney, costNumber, recipeInputSchema, productInputSchema, recipePreview, menuPreview, type Recipe, type RecipeInput, type ProductInput, type MenuProduct } from '../model/costing'
import { parseQuantity, units } from '../../inventory/model/inventory'

function Modal({ title, busy, onClose, children }: { title: string; busy: boolean; onClose: () => void; children: ReactNode }) {
  return <div className="finance-dialog-backdrop"><section className="finance-dialog costing-dialog" role="dialog" aria-modal="true" aria-labelledby="costing-dialog-title">
    <div className="finance-dialog-heading"><h2 id="costing-dialog-title">{title}</h2><button type="button" title="Kapat" aria-label="Kapat" disabled={busy} onClick={onClose}><X size={20} /></button></div>{children}</section></div>
}
export function MissingCost({ count }: { count: number }) {
  return <p className="costing-warning" role="status">Bu reçetenin maliyeti tamamlanamıyor. {count} malzemede alış maliyeti bulunmuyor.</p>
}
function Field({ label, children }: { label: string; children: ReactNode }) { return <label className="finance-dialog-field"><span>{label}</span>{children}</label> }
function Status({ value, onChange }: { value: 'ACTIVE' | 'PASSIVE'; onChange: (v: 'ACTIVE' | 'PASSIVE') => void }) {
  return <Field label="Durum"><select value={value} onChange={(e) => onChange(e.target.value as 'ACTIVE' | 'PASSIVE')}><option value="ACTIVE">Aktif</option><option value="PASSIVE">Pasif</option></select></Field>
}
export function RecipeDialog({ recipe, location, onClose }: { recipe?: Recipe; location: string; onClose: () => void }) {
  const [input, setInput] = useState<RecipeInput>(() => recipe ? { ...recipe, code: recipe.code ?? '', category: recipe.category ?? '', portions: String(recipe.portions),
    lines: recipe.lines.map((l) => ({ inventoryItemId: l.inventoryItemId, quantityBase: String(l.quantityBase), notes: l.notes ?? '' })) }
    : { name: '', code: '', category: '', currencyCode: 'TRY', portions: '1', status: 'ACTIVE', lines: [{ inventoryItemId: '', quantityBase: '', notes: '' }] })
  const costs = useInventoryCosts(input.currencyCode, location)
  const mutation = useSaveRecipe()
  const submitting = useRef(false)
  const parsed = recipeInputSchema.safeParse(input)
  const available = input.lines.every((l) => costs.data?.items.some((i) => i.id === l.inventoryItemId))
  const preview = recipePreview(input.lines.map((l) => {
    const item = costs.data?.items.find((i) => i.id === l.inventoryItemId)
    return { quantityBase: parseQuantity(l.quantityBase) ?? 0, lastUnitCost: item?.lastPurchase?.unitCost ?? null, weightedUnitCost: item?.weightedPurchaseUnitCost ?? null }
  }), parseQuantity(input.portions) ?? 0)
  function lineChange(index: number, patch: Partial<RecipeInput['lines'][number]>) { setInput((v) => ({ ...v, lines: v.lines.map((l, i) => i === index ? { ...l, ...patch } : l) })) }
  async function submit(e: FormEvent) {
    e.preventDefault()
    if (!parsed.success || !available || submitting.current || mutation.isPending) return
    submitting.current = true
    try { await mutation.mutateAsync({ id: recipe?.id, input }); onClose() } catch { /* Keep input for retry. */ } finally { submitting.current = false }
  }
  return <Modal title={recipe ? 'Reçeteyi Düzenle' : 'Yeni Reçete'} busy={mutation.isPending} onClose={onClose}><form onSubmit={submit}>
    <fieldset disabled={mutation.isPending} className="costing-fields">
      {([['name', 'Reçete adı'], ['code', 'Kod'], ['category', 'Kategori'], ['currencyCode', 'Para birimi'], ['portions', 'Porsiyon sayısı']] as const).map(([key, label]) => <Field key={key} label={label}><input value={input[key]} onChange={(e) => setInput({ ...input, [key]: key === 'currencyCode' ? e.target.value.toUpperCase() : e.target.value })} /></Field>)}
      {recipe ? <Status value={input.status} onChange={(status) => setInput({ ...input, status })} /> : null}
    </fieldset>
    {costs.isError ? <div role="alert">{costs.error.message}<button type="button" onClick={() => { void costs.refetch() }}>Tekrar dene</button></div> : costs.isPending ? <p role="status">Alış maliyetleri yükleniyor...</p> : null}
    <fieldset disabled={mutation.isPending} className="costing-lines">{input.lines.map((line, index) => {
      const item = costs.data?.items.find((i) => i.id === line.inventoryItemId)
      const quantity = parseQuantity(line.quantityBase)
      return <div className="costing-line" key={index}>
        <Field label={`Stok Kartı ${index + 1}`}><select value={line.inventoryItemId} onChange={(e) => lineChange(index, { inventoryItemId: e.target.value })}><option value="">Malzeme seçin</option>
          {line.inventoryItemId && !item ? <option value={line.inventoryItemId} disabled>{recipe?.lines.find((l) => l.inventoryItemId === line.inventoryItemId)?.itemName ?? 'Kullanılamayan malzeme'} (pasif)</option> : null}
          {costs.data?.items.map((i) => <option key={i.id} value={i.id}>{i.name}</option>)}</select></Field>
        <Field label={`Baz miktar ${index + 1}`}><input inputMode="decimal" value={line.quantityBase} onChange={(e) => lineChange(index, { quantityBase: e.target.value })} /></Field>
        <span>{item ? units[item.baseUnit] : '—'}</span>
        <button type="button" title="Malzemeyi kaldır" aria-label={`Malzeme ${index + 1} kaldır`} disabled={input.lines.length === 1} onClick={() => setInput({ ...input, lines: input.lines.filter((_, i) => i !== index) })}><Trash2 size={17} /></button>
        <Field label={`Not ${index + 1}`}><input value={line.notes} onChange={(e) => lineChange(index, { notes: e.target.value })} /></Field>
        <div className="costing-line-cost"><span>Son: {costMoney(item?.lastPurchase?.unitCost ?? null, input.currencyCode, 6)}</span><span>Ağırlıklı: {costMoney(item?.weightedPurchaseUnitCost ?? null, input.currencyCode, 6)}</span>
          <span>Satır Son / Ağırlıklı: {costMoney(quantity !== null && item?.lastPurchase ? quantity * item.lastPurchase.unitCost : null, input.currencyCode)} / {costMoney(quantity !== null && item?.weightedPurchaseUnitCost != null ? quantity * item.weightedPurchaseUnitCost : null, input.currencyCode)}</span></div>
      </div>
    })}<button type="button" className="finance-refresh-button" disabled={input.lines.length >= 200} onClick={() => setInput({ ...input, lines: [...input.lines, { inventoryItemId: '', quantityBase: '', notes: '' }] })}><Plus size={16} />Malzeme Ekle</button></fieldset>
    {preview.missing > 0 && !costs.isPending ? <MissingCost count={preview.missing} /> : null}
    <dl className="costing-totals"><div><dt>Batch Son Alış Maliyeti</dt><dd>{costMoney(parsed.success ? preview.last : null, input.currencyCode)}</dd></div><div><dt>Batch Ağırlıklı Maliyet</dt><dd>{costMoney(parsed.success ? preview.weighted : null, input.currencyCode)}</dd></div><div><dt>Porsiyon Son Alış Maliyeti</dt><dd>{costMoney(parsed.success ? preview.perLast : null, input.currencyCode)}</dd></div><div><dt>Porsiyon Ağırlıklı Maliyet</dt><dd>{costMoney(parsed.success ? preview.perWeighted : null, input.currencyCode)}</dd></div></dl>
    {mutation.error ? <p role="alert" className="finance-dialog-error">{mutation.error.message}</p> : null}
    <div className="finance-dialog-actions"><button type="button" disabled={mutation.isPending} onClick={onClose}>Vazgeç</button><button type="submit" className="primary" disabled={!parsed.success || !available || costs.isError || mutation.isPending}>Reçeteyi Kaydet</button></div>
  </form></Modal>
}
export function MenuProductDialog({ product, recipes, onClose }: { product?: MenuProduct; recipes: Recipe[]; onClose: () => void }) {
  const [input, setInput] = useState<ProductInput>(() => product ? { ...product, code: product.code ?? '', category: product.category ?? '', salePriceGross: String(product.salePriceGross), salesTaxRate: String(product.salesTaxRate), targetFoodCostPct: product.targetFoodCostPct === null ? '' : String(product.targetFoodCostPct) }
    : { name: '', code: '', category: '', recipeId: '', currencyCode: 'TRY', salePriceGross: '', salesTaxRate: '', targetFoodCostPct: '', costMethod: 'WEIGHTED_PURCHASE', status: 'ACTIVE' })
  const mutation = useSaveMenuProduct()
  const submitting = useRef(false)
  const parsed = productInputSchema.safeParse(input)
  const recipe = recipes.find((r) => r.id === input.recipeId)
  const cost = recipe?.costingComplete ? input.costMethod === 'LAST_PURCHASE' ? recipe.costPerPortionLast : recipe.costPerPortionWeighted : null
  const preview = parsed.success ? menuPreview(parsed.data.salePriceGross, parsed.data.salesTaxRate, cost, parsed.data.targetFoodCostPct) : null
  async function submit(e: FormEvent) {
    e.preventDefault()
    if (!parsed.success || !recipe || recipe.currencyCode !== input.currencyCode || submitting.current || mutation.isPending) return
    submitting.current = true
    try { await mutation.mutateAsync({ id: product?.id, input }); onClose() } catch { /* Keep input for retry. */ } finally { submitting.current = false }
  }
  return <Modal title={product ? 'Menü Ürününü Düzenle' : 'Yeni Menü Ürünü'} busy={mutation.isPending} onClose={onClose}><form onSubmit={submit}><fieldset disabled={mutation.isPending} className="costing-fields">
    {([['name', 'Ürün adı'], ['code', 'Kod'], ['category', 'Kategori'], ['salePriceGross', 'KDV dahil satış fiyatı'], ['salesTaxRate', 'Satış KDV %'], ['targetFoodCostPct', 'Hedef Food Cost %']] as const).map(([key, label]) => <Field key={key} label={label}><input value={input[key]} onChange={(e) => setInput({ ...input, [key]: e.target.value })} /></Field>)}
    <Field label="Reçete"><select value={input.recipeId} onChange={(e) => { const r = recipes.find((v) => v.id === e.target.value); setInput({ ...input, recipeId: e.target.value, currencyCode: r?.currencyCode ?? 'TRY' }) }}><option value="">Reçete seçin</option>{recipes.map((r) => <option key={r.id} value={r.id}>{r.name} · {r.currencyCode}{r.status === 'PASSIVE' ? ' (Pasif)' : ''}</option>)}</select></Field>
    <Field label="Cost yöntemi"><select value={input.costMethod} onChange={(e) => setInput({ ...input, costMethod: e.target.value as ProductInput['costMethod'] })}><option value="WEIGHTED_PURCHASE">Ağırlıklı Alış Maliyeti</option><option value="LAST_PURCHASE">Son Alış Maliyeti</option></select></Field>
    {product ? <Status value={input.status} onChange={(status) => setInput({ ...input, status })} /> : null}
  </fieldset>{recipe && !recipe.costingComplete ? <MissingCost count={recipe.missingCostItemCount} /> : null}
    <dl className="costing-totals"><div><dt>Net Satış</dt><dd>{costMoney(preview?.net ?? null, input.currencyCode)}</dd></div><div><dt>Porsiyon Maliyeti</dt><dd>{costMoney(cost, input.currencyCode)}</dd></div><div><dt>Food Cost %</dt><dd>{costNumber(preview?.foodCostPct ?? null)}</dd></div><div><dt>Katkı Payı (Genel gider öncesi)</dt><dd>{costMoney(preview?.margin ?? null, input.currencyCode)}</dd></div><div><dt>Hedef Food Cost’a Göre Fiyat</dt><dd>{costMoney(preview?.suggestedGross ?? null, input.currencyCode)}</dd></div></dl>
    {mutation.error ? <p role="alert" className="finance-dialog-error">{mutation.error.message}</p> : null}
    <div className="finance-dialog-actions"><button type="button" disabled={mutation.isPending} onClick={onClose}>Vazgeç</button><button type="submit" className="primary" disabled={!parsed.success || !recipe || mutation.isPending}>Ürünü Kaydet</button></div>
  </form></Modal>
}
