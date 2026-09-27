import { useRef, useState, type FormEvent } from 'react'
import { Ban, Link, RefreshCw, Unlink, Upload, X } from 'lucide-react'
import { useSalesApp } from '../queries/useSalesApp'
import { useImportSalesApp, useReprocessSalesApp, useUpdateSalesAppMapping } from '../mutations/useSalesAppCommands'
import { mappingLabels, normalizeSalesAppCsv, salesAppBatchKey, salesAppPreview, type SalesAppMapping, type SalesAppOverview, type SalesAppRow } from '../model/salesApp'
import { costNumber } from '../model/costing'
import { Field, Modal } from './CostingDialogs'

export function SalesAppPanel({ canWrite, onClose }: { canWrite: boolean; onClose: () => void }) {
  const query = useSalesApp()
  const [tab, setTab] = useState<'mappings' | 'history'>('mappings')
  const [dialog, setDialog] = useState<{ kind: 'import' } | { kind: 'mapping'; mapping: SalesAppMapping; status: SalesAppMapping['status'] } | { kind: 'reprocess'; batch: SalesAppOverview['recentImports'][number] } | null>(null)
  const data = query.data
  return <section className="sales-app-panel" aria-label="Satış Uygulaması yönetimi">
    <div className="costing-record-heading"><h2>Satış Uygulaması</h2><button title="Yenile" aria-label="Satış uygulamasını yenile" disabled={query.isFetching} onClick={() => { void query.refetch() }}><RefreshCw size={16} /></button>{canWrite && data ? <button onClick={() => setDialog({ kind: 'import' })}><Upload size={16} />Satış Dosyası / Veri İçe Aktar</button> : null}<button title="Kapat" aria-label="Satış uygulamasını kapat" onClick={onClose}><X size={16} /></button></div>
    {query.isPending ? <p role="status">Satış uygulaması yükleniyor...</p> : query.isError ? <p role="alert">{query.error.message}</p> : data ? <>
      <dl className="costing-totals"><div><dt>Eşleştirildi</dt><dd>{data.summary.mappedProductCount}</dd></div><div><dt>Eşleştirilmedi</dt><dd>{data.summary.unmappedProductCount}</dd></div><div><dt>Hariç Tutuldu</dt><dd>{data.summary.ignoredProductCount}</dd></div><div><dt>Son İçe Aktarım</dt><dd>{data.summary.lastImportBusinessDate ?? 'Henüz yok'}{data.summary.lastImportAt ? <small>{new Date(data.summary.lastImportAt).toLocaleString('tr-TR')}</small> : null}</dd></div></dl>
      <div className="costing-toolbar"><div role="tablist" aria-label="Satış uygulaması bölümleri">{([['mappings', 'Ürün Eşleştirmeleri'], ['history', 'İçe Aktarım Geçmişi']] as const).map(([key, label]) => <button key={key} role="tab" id={`sales-app-tab-${key}`} aria-controls="sales-app-content" aria-selected={tab === key} onClick={() => setTab(key)}>{label}</button>)}</div></div>
      <div role="tabpanel" id="sales-app-content" aria-labelledby={`sales-app-tab-${tab}`} className="costing-table-wrap">{tab === 'mappings' ? <table><thead><tr>{['Satış Uygulaması Ürünü', 'Harici Kod', 'Lokasyon', 'Durum', 'COOST Menü Ürünü', ''].map((h) => <th key={h}>{h}</th>)}</tr></thead><tbody>{data.mappings.map((m) => <tr key={m.id}><th scope="row">{m.externalProductName}<small>{m.externalProductId}</small></th><td>{m.externalProductCode ?? '—'}</td><td>{m.locationName ?? 'İşletme geneli'}</td><td>{mappingLabels[m.status]}</td><td>{m.menuProductName ?? '—'}</td><td>{canWrite ? <div className="sales-app-actions"><button title="Eşleştir" aria-label={`${m.externalProductName} eşleştir`} onClick={() => setDialog({ kind: 'mapping', mapping: m, status: 'MAPPED' })}><Link size={16} /></button>{m.status !== 'IGNORED' ? <button title="Hariç Tut" aria-label={`${m.externalProductName} hariç tut`} onClick={() => setDialog({ kind: 'mapping', mapping: m, status: 'IGNORED' })}><Ban size={16} /></button> : null}{m.status !== 'UNMAPPED' ? <button title="Eşleştirmeyi Kaldır" aria-label={`${m.externalProductName} eşleştirmeyi kaldır`} onClick={() => setDialog({ kind: 'mapping', mapping: m, status: 'UNMAPPED' })}><Unlink size={16} /></button> : null}</div> : null}</td></tr>)}{!data.mappings.length ? <tr><td colSpan={6}>Henüz harici ürün yok.</td></tr> : null}</tbody></table> : <table><thead><tr>{['İş Günü', 'Lokasyon', 'Para Birimi', 'Durum', 'Toplam Satır', 'Eşleşmiş', 'Eşleşmemiş', 'İçe Aktarım Zamanı', ''].map((h) => <th key={h}>{h}</th>)}</tr></thead><tbody>{data.recentImports.map((b) => <tr key={b.id}><th scope="row">{b.businessDate}</th><td>{b.location}</td><td>{b.currencyCode}</td><td>{b.status === 'COMPLETED' ? 'Tamamlandı' : b.status === 'FAILED' ? 'Başarısız' : 'İşleniyor'}</td><td>{b.rowCount}</td><td>{b.mappedRowCount}</td><td>{b.unmappedRowCount}</td><td>{new Date(b.importedAt).toLocaleString('tr-TR')}</td><td>{canWrite && b.canReprocess ? <button title="Güncel eşleştirmelerle yeniden işle" aria-label={`${b.businessDate} yeniden işle`} onClick={() => setDialog({ kind: 'reprocess', batch: b })}><RefreshCw size={16} />Yeniden İşle</button> : null}</td></tr>)}{!data.recentImports.length ? <tr><td colSpan={9}>Henüz içe aktarım yok.</td></tr> : null}</tbody></table>}</div>
    </> : null}
    {canWrite && data && dialog?.kind === 'import' ? <SalesAppImportDialog data={data} onClose={() => { setDialog(null); setTab('history') }} /> : null}
    {canWrite && data && dialog?.kind === 'mapping' ? <MappingDialog data={data} mapping={dialog.mapping} status={dialog.status} onClose={() => setDialog(null)} /> : null}
    {canWrite && dialog?.kind === 'reprocess' ? <ReprocessDialog batch={dialog.batch} onClose={() => setDialog(null)} /> : null}
  </section>
}

export function MappingDialog({ data, mapping, status, onClose }: { data: SalesAppOverview; mapping: SalesAppMapping; status: SalesAppMapping['status']; onClose: () => void }) {
  const [productId, setProductId] = useState(mapping.menuProductId ?? '')
  const mutation = useUpdateSalesAppMapping(), submitting = useRef(false)
  async function submit(e: FormEvent) {
    e.preventDefault()
    if (submitting.current || mutation.isPending || (status === 'MAPPED' && !productId)) return
    submitting.current = true
    try { await mutation.mutateAsync({ id: mapping.id, status, productId: status === 'MAPPED' ? productId : null }); onClose() } catch { /* Preserve selection for retry. */ } finally { submitting.current = false }
  }
  return <Modal title={status === 'MAPPED' ? 'Ürün Eşleştir' : status === 'IGNORED' ? 'Hariç Tut' : 'Eşleştirmeyi Kaldır'} busy={mutation.isPending} onClose={onClose}><form onSubmit={submit}><p>{mapping.externalProductName}</p>{status === 'MAPPED' ? <Field label="COOST Menü Ürünü"><select disabled={mutation.isPending} value={productId} onChange={(e) => setProductId(e.target.value)}><option value="">Seçin</option>{data.menuProducts.map((p) => <option key={p.id} value={p.id}>{p.name} · {p.currencyCode}</option>)}</select></Field> : null}<p>Geçmiş satışlar değişmez. Güncel eşleştirmeyi geçmişe uygulamak için ilgili içe aktarımı yeniden işleyin.</p>{mutation.isError ? <p role="alert">{mutation.error.message}</p> : null}<button type="submit" disabled={mutation.isPending || (status === 'MAPPED' && !productId)}>Onayla</button></form></Modal>
}
function ReprocessDialog({ batch, onClose }: { batch: SalesAppOverview['recentImports'][number]; onClose: () => void }) {
  const mutation = useReprocessSalesApp(), submitting = useRef(false)
  async function submit(e: FormEvent) {
    e.preventDefault(); if (submitting.current || mutation.isPending) return
    submitting.current = true
    try { await mutation.mutateAsync(batch.id); onClose() } catch { /* Preserve confirmation for retry. */ } finally { submitting.current = false }
  }
  return <Modal title="İçe Aktarımı Yeniden İşle" busy={mutation.isPending} onClose={onClose}><form onSubmit={submit}><p>{batch.businessDate} · {batch.location} · {batch.currencyCode}</p><p>Güncel eşleştirmelerle günlük satış toplamları yeniden oluşturulacak. İçe aktarım satır geçmişi korunacak.</p>{mutation.isError ? <p role="alert">{mutation.error.message}</p> : null}<button type="submit" disabled={mutation.isPending}>Yeniden İşlemeyi Onayla</button></form></Modal>
}

export function SalesAppImportDialog({ data, onClose }: { data: SalesAppOverview; onClose: () => void }) {
  const [locationId, setLocationId] = useState(''), [businessDate, setBusinessDate] = useState('')
  const [file, setFile] = useState<{ rows: SalesAppRow[]; currencyCode: string } | null>(null)
  const [error, setError] = useState(''), [reading, setReading] = useState(false), [busy, setBusy] = useState(false), [confirmed, setConfirmed] = useState(false)
  const mutation = useImportSalesApp(), submitting = useRef(false), readVersion = useRef(0)
  const preview = file ? salesAppPreview(file.rows, data.mappings, locationId) : null
  const mismatch = preview?.rows.some((r) => r.status === 'MAPPED' && data.menuProducts.find((p) => p.id === r.menuProductId)?.currencyCode !== file?.currencyCode)
  async function readFile(selected?: File) {
    const version = ++readVersion.current
    setFile(null); setError(''); setConfirmed(false)
    if (!selected) { setReading(false); return }
    if (selected.size > 5 * 1024 * 1024) { setError('Dosya en fazla 5 MB olabilir.'); setReading(false); return }
    setReading(true)
    try { const parsed = normalizeSalesAppCsv(await selected.text()); if (version === readVersion.current) setFile(parsed) } catch (e) { if (version === readVersion.current) setError(e instanceof Error ? e.message : 'Dosya okunamadı.') } finally { if (version === readVersion.current) setReading(false) }
  }
  const valid = !!file && !!locationId && /^\d{4}-\d{2}-\d{2}$/.test(businessDate) && confirmed && !mismatch && !reading
  async function submit(e: FormEvent) {
    e.preventDefault(); if (!valid || !file || submitting.current || busy) return
    submitting.current = true; setBusy(true); setError('')
    try {
      const input = { ...file, locationId, businessDate }
      await mutation.mutateAsync({ ...input, externalBatchKey: await salesAppBatchKey(input) }); onClose()
    } catch (e) { setError(e instanceof Error ? e.message : 'İçe aktarım tamamlanamadı.') } finally { submitting.current = false; setBusy(false) }
  }
  return <Modal title="Satış Dosyası / Veri İçe Aktar" busy={busy || reading} onClose={onClose}><form onSubmit={submit}>
    <fieldset className="costing-fields" disabled={busy || reading}><Field label="Lokasyon"><select value={locationId} onChange={(e) => { setLocationId(e.target.value); setConfirmed(false) }}><option value="">Seçin</option>{data.locations.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}</select></Field><Field label="İş günü tarihi"><input type="date" value={businessDate} onChange={(e) => { setBusinessDate(e.target.value); setConfirmed(false) }} /></Field><Field label="CSV dosyası"><input type="file" accept=".csv,text/csv" onChange={(e) => { void readFile(e.target.files?.[0]) }} /></Field></fieldset>
    {reading ? <p role="status">Dosya okunuyor...</p> : null}
    {preview ? <><dl className="costing-totals"><div><dt>Toplam satır</dt><dd>{preview.rows.length}</dd></div>{Object.entries(preview.counts).map(([key, value]) => <div key={key}><dt>{mappingLabels[key as SalesAppMapping['status']]}</dt><dd>{value}</dd></div>)}</dl><p>Para birimi: {file?.currencyCode}</p><div className="costing-table-wrap sales-app-preview"><table><thead><tr><th>Ürün</th><th>Adet</th><th>Net Satış</th><th>Durum</th></tr></thead><tbody>{preview.rows.slice(0, 100).map((r) => <tr key={r.externalProductId}><th>{r.externalProductName}</th><td>{costNumber(r.quantity, 4)}</td><td>{costNumber(r.netSales)}</td><td>{mappingLabels[r.status]}</td></tr>)}</tbody></table></div>{preview.rows.length > 100 ? <p>İlk 100 satır gösteriliyor.</p> : null}<p className="costing-warning">Bu dosya seçili gün, lokasyon ve para birimi için tam günlük satış verisidir. Önceki Satış Uygulaması toplamlarının yerini alır; dosyada olmayan önceki ürünler sıfırlanır. Eşleşen manuel kayıtlar da değiştirilir. Eşleşmemiş ve hariç tutulan satırlar geçmişte saklanır, kârlılık raporuna dahil edilmez.</p><label className="sales-app-confirm"><input type="checkbox" disabled={busy} checked={confirmed} onChange={(e) => setConfirmed(e.target.checked)} />Günlük satış toplamlarının değiştirilmesini onaylıyorum.</label></> : null}
    {mismatch ? <p role="alert">Eşleştirilen menü ürünü ile dosyanın para birimi aynı olmalıdır.</p> : null}{error ? <p role="alert">{error}</p> : null}<button type="submit" disabled={!valid || busy}><Upload size={16} />{busy ? 'İçe Aktarılıyor...' : 'İçe Aktarımı Onayla'}</button>
  </form></Modal>
}
