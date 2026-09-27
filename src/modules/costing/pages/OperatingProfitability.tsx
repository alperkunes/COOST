import { useState } from 'react'
import { ArrowDownUp, Ban, Pencil, Plus, RefreshCw } from 'lucide-react'
import { useOperating } from '../queries/useOperating'
import { allocationLabels, expenseLabels, type Expense, type Period, type SalesFact } from '../model/operating'
import { costMoney, costNumber } from '../model/costing'
import { Field } from './CostingDialogs'
import { ExpenseDialog, SalesDialog, VoidExpenseDialog } from './OperatingDialogs'

type SortKey = 'netSales' | 'directContribution' | 'allocatedOperatingContribution' | 'allocatedOperatingMarginPct'
export function OperatingProfitability({ canWrite }: { canWrite: boolean }) {
  const [period, setPeriod] = useState<Period>(() => {
    const now = new Date(), endDate = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
    return { startDate: `${endDate.slice(0, 7)}-01`, endDate, currencyCode: 'TRY', locationId: '', allocationMethod: 'NET_SALES' }
  })
  const [sort, setSort] = useState<{ key: SortKey; descending: boolean }>({ key: 'netSales', descending: true })
  const [dialog, setDialog] = useState<{ kind: 'sales'; fact?: SalesFact } | { kind: 'expense'; expense?: Expense } | { kind: 'void'; expense: Expense } | null>(null)
  const { report, data, valid } = useOperating(period)
  const money = (value: number | null) => costMoney(value, period.currencyCode)
  const products = [...(report.data?.products ?? [])].sort((a, b) => {
    const x = a[sort.key], y = b[sort.key]
    return x === null ? y === null ? a.productName.localeCompare(b.productName) : 1 : y === null ? -1 : (x - y) * (sort.descending ? -1 : 1) || a.productName.localeCompare(b.productName)
  })
  const summary = report.data?.summary
  const locationName = (id: string | null) => id ? data.data?.locations.find((l) => l.id === id)?.name ?? id : 'İşletme geneli'
  const sortable = (label: string, key: SortKey) => <th aria-sort={sort.key === key ? sort.descending ? 'descending' : 'ascending' : 'none'}><button title={`${label} sıralaması`} onClick={() => setSort({ key, descending: sort.key !== key || !sort.descending })}>{label}<ArrowDownUp size={14} /></button></th>
  return <div className="operating-profitability">
    <div className="operating-filters">
      <Field label="Başlangıç tarihi"><input type="date" value={period.startDate} onChange={(e) => setPeriod({ ...period, startDate: e.target.value })} /></Field>
      <Field label="Bitiş tarihi"><input type="date" value={period.endDate} onChange={(e) => setPeriod({ ...period, endDate: e.target.value })} /></Field>
      <Field label="Para birimi"><input maxLength={3} value={period.currencyCode} onChange={(e) => setPeriod({ ...period, currencyCode: e.target.value.toUpperCase() })} /></Field>
      <Field label="Lokasyon"><select value={period.locationId} onChange={(e) => setPeriod({ ...period, locationId: e.target.value })}><option value="">Tüm lokasyonlar</option>{data.data?.locations.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}</select></Field>
      <Field label="Dağıtım yöntemi"><select value={period.allocationMethod} onChange={(e) => setPeriod({ ...period, allocationMethod: e.target.value as Period['allocationMethod'] })}>{Object.entries(allocationLabels).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></Field>
      <button className="finance-refresh-button" disabled={!valid || report.isFetching || data.isFetching} onClick={() => { void report.refetch(); void data.refetch() }}><RefreshCw size={16} />Yenile</button>
    </div>
    {!valid ? <p role="alert">Geçerli tarihler ve üç harfli para birimi girin. Dönem en fazla 366 gün olabilir.</p> : report.isPending ? <p role="status">Dönem kârlılığı yükleniyor...</p> : report.isError ? <p role="alert">{report.error.message}</p> : summary ? <>
      <dl className="operating-summary">{[
        ['Net Satış', money(summary.netSales)], ['Direkt Reçete Maliyeti', money(summary.estimatedRecipeCost)], ['Direkt Katkı', money(summary.directContribution)],
        ['İşletme Giderleri', money(summary.operatingCosts.total)], ['Dağıtılmış Faaliyet Katkısı', money(summary.allocatedOperatingContribution)], ['Faaliyet Marjı %', costNumber(summary.allocatedOperatingMarginPct)],
      ].map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{value}</dd></div>)}</dl>
      <dl className="costing-totals">{[['Sabit Gider', summary.operatingCosts.fixedOverhead], ['Personel', summary.operatingCosts.labor], ['Dağıtılan POS Komisyonu', summary.operatingCosts.posCommission], ['Diğer Değişken', summary.operatingCosts.otherVariable]].map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{money(value as number)}</dd></div>)}</dl>
      <p>Dönem satışlarına seçili reçete maliyet yöntemi uygulanmıştır.</p>
      {report.data?.allocationStatus === 'NO_SALES' ? <p role="status">Bu dönemde satış verisi yok. Gider dağıtımı hesaplanmadı.</p> : report.data?.allocationStatus === 'ZERO_ALLOCATION_BASE' ? <p role="status">Seçili yöntemin dağıtım tabanı sıfır. Gider dağıtımı hesaplanmadı.</p> : null}
      {products.some((p) => !p.costingComplete) ? <p className="costing-warning" role="status">Reçete maliyeti eksik. İlgili ürünlerin katkısı ve dönem toplam katkısı hesaplanamıyor.</p> : null}
      <div className="costing-table-wrap"><table><caption>Ürün Kârlılığı · {period.currencyCode}</caption><thead><tr><th>Ürün</th><th>Satış Adedi</th>{sortable('Net Satış', 'netSales')}<th>Reçete Maliyeti</th>{sortable('Direkt Katkı', 'directContribution')}<th>Dağıtılan Gider</th>{sortable('Dağıtılmış Faaliyet Katkısı', 'allocatedOperatingContribution')}{sortable('Faaliyet Marjı %', 'allocatedOperatingMarginPct')}<th>Hedef %</th><th>Hedeften puan</th><th>Hedef Faaliyet Marjına Göre Fiyat Referansı</th></tr></thead><tbody>
        {products.map((p) => <tr key={p.productId}><th scope="row">{p.productName}<small>{p.recipeCostMethod === 'LAST_PURCHASE' ? 'Son Alış' : 'Ağırlıklı Alış'}{!p.costingComplete ? ' · Maliyet eksik' : ''}</small></th><td>{costNumber(p.quantitySold, 4)}</td><td>{money(p.netSales)}</td><td>{money(p.estimatedRecipeCost)}</td><td>{money(p.directContribution)}</td><td>{money(p.allocatedOperatingCost)}</td><td>{money(p.allocatedOperatingContribution)}</td><td>{costNumber(p.allocatedOperatingMarginPct)}</td><td>{costNumber(p.targetOperatingMarginPct)}</td><td>{p.targetDifferencePp !== null && p.targetDifferencePp > 0 ? '+' : ''}{costNumber(p.targetDifferencePp)}</td><td>{money(p.suggestedGrossPriceAtTarget)}<small>KDV dahil · Net {money(p.suggestedNetPriceAtTarget)}</small></td></tr>)}
        {!products.length ? <tr><td colSpan={11}>Satış kaydı yok.</td></tr> : null}
      </tbody></table></div><p>Mevcut dönem gider dağılımı sabit kabul edilerek hesaplanmıştır.</p>
    </> : null}
    {valid && data.isError ? <p role="alert">{data.error.message}</p> : null}
    {valid && data.data ? <>
      <section className="operating-history"><div className="costing-record-heading"><h2>Satış Verisi</h2>{canWrite ? <button onClick={() => setDialog({ kind: 'sales' })}><Plus size={16} />Satış Ekle</button> : null}</div>
        <div className="costing-table-wrap"><table><thead><tr>{['Tarih', 'Lokasyon', 'Menü ürünü', 'Satış adedi', 'Brüt satış', 'Net satış', 'Kaynak', ''].map((h) => <th key={h}>{h}</th>)}</tr></thead><tbody>{data.data.sales.map((f) => <tr key={f.id}><td>{f.saleDate}</td><td>{locationName(f.locationId)}</td><th scope="row">{f.productName}</th><td>{costNumber(f.quantity, 4)}</td><td>{money(f.grossSales)}</td><td>{money(f.netSales)}</td><td>{f.sourceType === 'MANUAL' ? 'Manuel' : f.sourceType}</td><td>{canWrite && f.sourceType === 'MANUAL' ? <button title="Satışı düzenle" aria-label={`${f.productName} satışını düzenle`} onClick={() => setDialog({ kind: 'sales', fact: f })}><Pencil size={16} /></button> : null}</td></tr>)}</tbody></table></div>
      </section>
      <section className="operating-history"><div className="costing-record-heading"><h2>İşletme Giderleri</h2>{canWrite ? <button onClick={() => setDialog({ kind: 'expense' })}><Plus size={16} />Gider Ekle</button> : null}</div>
        <div className="costing-table-wrap"><table><thead><tr>{['Tarih', 'Kapsam', 'Kategori', 'Tutar', 'Para birimi', 'Açıklama', 'Durum', ''].map((h) => <th key={h}>{h}</th>)}</tr></thead><tbody>{data.data.expenses.map((e) => <tr key={e.id} className={e.status === 'VOID' ? 'operating-void' : undefined}><td>{e.occurredOn}</td><td>{locationName(e.locationId)}</td><td>{expenseLabels[e.category]}</td><td>{money(e.amount)}</td><td>{e.currencyCode}</td><td>{e.description}</td><td>{e.status === 'VOID' ? 'İptal (VOID)' : 'Aktif'}</td><td>{canWrite && e.status === 'ACTIVE' && e.sourceType === 'MANUAL' ? <><button title="Gideri düzenle" aria-label={`${e.description} düzenle`} onClick={() => setDialog({ kind: 'expense', expense: e })}><Pencil size={16} /></button><button title="Gideri iptal et" aria-label={`${e.description} iptal et`} onClick={() => setDialog({ kind: 'void', expense: e })}><Ban size={16} /></button></> : null}</td></tr>)}</tbody></table></div>
      </section>
    </> : null}
    {canWrite && data.data && dialog?.kind === 'sales' ? <SalesDialog fact={dialog.fact} data={data.data} period={period} onClose={() => setDialog(null)} /> : null}
    {canWrite && data.data && dialog?.kind === 'expense' ? <ExpenseDialog expense={dialog.expense} data={data.data} period={period} onClose={() => setDialog(null)} /> : null}
    {canWrite && dialog?.kind === 'void' ? <VoidExpenseDialog expense={dialog.expense} onClose={() => setDialog(null)} /> : null}
  </div>
}
