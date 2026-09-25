import { useRef, useState, type FormEvent } from 'react'
import { X, Pencil, Plus } from 'lucide-react'
import {
  createFinanceAccountSchema, updateFinanceAccountSchema,
  type FinanceManagedAccount, type CreateFinanceAccountInput,
} from '../model/financeAccountManagement'
import { useFinanceAccountLocations, useFinanceAccountManagement } from '../queries/useFinanceAccountManagement'
import { useManageFinanceAccount } from '../mutations/useManageFinanceAccount'

function AccountForm({ account, mutation, onBack, onSaved }: {
  account: FinanceManagedAccount | null
  mutation: ReturnType<typeof useManageFinanceAccount>
  onBack: () => void
  onSaved: () => void
}) {
  const locations = useFinanceAccountLocations()
  const submitting = useRef(false)
  const [name, setName] = useState(account?.name ?? '')
  const [accountType, setAccountType] = useState<CreateFinanceAccountInput['accountType']>('CASH')
  const [currencyCode, setCurrencyCode] = useState('TRY')
  const [locationId, setLocationId] = useState('')
  const [status, setStatus] = useState<FinanceManagedAccount['status']>(account?.status ?? 'ACTIVE')
  const createInput = { name, accountType, currencyCode, locationId: locationId || null }
  const updateInput = { accountId: account?.id ?? '', name, status }
  const valid = account ? updateFinanceAccountSchema.safeParse(updateInput).success
    && (name.trim() !== account.name || status !== account.status)
    : createFinanceAccountSchema.safeParse(createInput).success
  const pending = mutation.isPending

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!valid || pending || submitting.current) return
    submitting.current = true
    try {
      await mutation.mutateAsync(account
        ? { kind: 'update', input: updateInput }
        : { kind: 'create', input: createInput })
      onSaved()
    } catch {
      // Keep every input, including a rejected status change, for correction/retry.
    } finally {
      submitting.current = false
    }
  }

  return <form onSubmit={submit}>
    <h3>{account ? 'Hesabı Düzenle' : 'Yeni Hesap Ekle'}</h3>
    <label className="finance-dialog-field">
      <span>Hesap adı</span>
      <input autoFocus required maxLength={120} value={name} disabled={pending} onChange={(event) => setName(event.target.value)} />
      <small>2–120 karakter.</small>
    </label>
    {account ? <>
      <dl className="finance-account-details">
        <div><dt>Hesap tipi</dt><dd>{account.accountType === 'CASH' ? 'Nakit Kasa' : 'Banka Hesabı'}</dd></div>
        <div><dt>Para birimi</dt><dd>{account.currencyCode}</dd></div>
        <div><dt>Lokasyon</dt><dd>{account.locationName ?? 'İşletme geneli'}</dd></div>
      </dl>
      <label className="finance-dialog-field">
        <span>Durum</span>
        <select value={status} disabled={pending} onChange={(event) => setStatus(event.target.value as FinanceManagedAccount['status'])}>
          <option value="ACTIVE">Aktif</option><option value="PASSIVE">Pasif</option>
        </select>
        <small>Yalnızca bakiyesi sıfır olan hesaplar pasife alınabilir.</small>
      </label>
    </> : <>
      <label className="finance-dialog-field">
        <span>Hesap tipi</span>
        <select value={accountType} disabled={pending} onChange={(event) => setAccountType(event.target.value as CreateFinanceAccountInput['accountType'])}>
          <option value="CASH">Nakit Kasa</option><option value="BANK">Banka Hesabı</option>
        </select>
      </label>
      <label className="finance-dialog-field">
        <span>Para birimi</span>
        <input required value={currencyCode} disabled={pending} onChange={(event) => setCurrencyCode(event.target.value)} placeholder="TRY" />
        <small>Üç harfli para birimi kodu: TRY, USD, EUR.</small>
      </label>
      <label className="finance-dialog-field">
        <span>Lokasyon</span>
        <select value={locationId} disabled={pending || locations.isPending} onChange={(event) => setLocationId(event.target.value)}>
          <option value="">İşletme geneli</option>
          {locations.data?.map((location) => <option key={location.id} value={location.id}>{location.name}</option>)}
        </select>
      </label>
      {locations.isError ? <div className="finance-dialog-error" role="alert">Lokasyonlar yüklenemedi. <button type="button" onClick={() => { void locations.refetch() }}>Tekrar dene</button></div> : null}
      <div className="finance-dialog-info">Yeni hesap sıfır bakiye ile açılır. Başlangıç bakiyesi için ana ekrandaki Düzelt işlemini kullanın. Hesap tipi, para birimi ve lokasyon sonradan değiştirilemez.</div>
    </>}
    {mutation.isError ? <div className="finance-dialog-error" role="alert">{mutation.error.message}</div> : null}
    <div className="finance-dialog-actions">
      <button type="button" disabled={pending} onClick={onBack}>Geri</button>
      <button type="submit" className="primary" disabled={!valid || pending}>{pending ? 'Kaydediliyor...' : 'Kaydet'}</button>
    </div>
  </form>
}

export function FinanceAccountManagementDialog({ onClose }: { onClose: () => void }) {
  const query = useFinanceAccountManagement()
  const mutation = useManageFinanceAccount()
  const [editor, setEditor] = useState<FinanceManagedAccount | 'create' | null>(null)
  const [saved, setSaved] = useState(false)
  function openEditor(value: FinanceManagedAccount | 'create') {
    mutation.reset()
    setSaved(false)
    setEditor(value)
  }
  return <div className="finance-dialog-backdrop" role="presentation" onMouseDown={(event) => {
    if (event.target === event.currentTarget && !mutation.isPending) onClose()
  }}>
    <section className="finance-dialog finance-management-dialog" role="dialog" aria-modal="true" aria-labelledby="finance-management-title">
      <div className="finance-dialog-heading">
        <div><span>KASA / BANKA</span><h2 id="finance-management-title">Hesapları Yönet</h2></div>
        <button type="button" aria-label="Kapat" disabled={mutation.isPending} onClick={onClose}><X size={20} /></button>
      </div>
      {editor !== null ? <AccountForm key={editor === 'create' ? 'create' : editor.id}
        account={editor === 'create' ? null : editor} mutation={mutation} onBack={() => setEditor(null)} onSaved={() => {
          setSaved(true)
          setEditor(null)
        }} /> : <div className="finance-management-content">
        <button type="button" className="finance-refresh-button" onClick={() => openEditor('create')}><Plus size={16} />Yeni Hesap Ekle</button>
        {saved ? <div className="finance-dialog-info" role="status">Hesap kaydedildi.</div> : null}
        {query.isPending ? <p role="status">Hesaplar yükleniyor...</p> : query.isError ?
          <div className="finance-dialog-error" role="alert">Hesaplar yüklenemedi. <button type="button" onClick={() => { void query.refetch() }}>Tekrar dene</button></div> :
          query.data.accounts.length === 0 ? <p>Henüz hesap yok. İlk kasa veya banka hesabınızı ekleyin.</p> :
          <ul className="finance-management-list">{query.data.accounts.map((account) => <li key={account.id}>
            <div className="finance-management-account-heading"><strong>{account.name}</strong><span className="finance-readonly-badge">{account.status === 'ACTIVE' ? 'Aktif' : 'Pasif'}</span></div>
            <dl className="finance-account-details">
              <div><dt>Hesap tipi</dt><dd>{account.accountType === 'CASH' ? 'Nakit Kasa' : 'Banka Hesabı'}</dd></div>
              <div><dt>Para birimi</dt><dd>{account.currencyCode}</dd></div>
              <div><dt>Lokasyon</dt><dd>{account.locationName ?? 'İşletme geneli'}</dd></div>
              <div><dt>Bakiye</dt><dd>{new Intl.NumberFormat('tr-TR', { style: 'currency', currency: account.currencyCode }).format(account.balance)}</dd></div>
            </dl>
            <button type="button" className="finance-adjust-button" aria-label={`${account.name} hesabını düzenle`} onClick={() => openEditor(account)}><Pencil size={13} />Düzenle</button>
          </li>)}</ul>}
      </div>}
    </section>
  </div>
}
