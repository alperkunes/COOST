import { useRef, useState, type FormEvent } from 'react'
import { X } from 'lucide-react'
import type { FinanceOverviewAccount } from '../model/financeOverview'
import { canTransferBetween, parseTransferAmount } from '../model/financeTransfer'
import { useCreateFinanceTransfer } from '../mutations/useCreateFinanceTransfer'

export function FinanceTransferDialog({ accounts, onClose }: {
  accounts: FinanceOverviewAccount[]
  onClose: () => void
}) {
  const mutation = useCreateFinanceTransfer()
  const submitting = useRef(false)
  const [fromId, setFromId] = useState('')
  const [toId, setToId] = useState('')
  const [amountInput, setAmountInput] = useState('')
  const [description, setDescription] = useState('')
  const fromAccount = accounts.find((account) => account.id === fromId)
  const toAccount = accounts.find((account) => account.id === toId)
  const amount = parseTransferAmount(amountInput)
  const canSubmit = fromAccount && toAccount && canTransferBetween(fromAccount, toAccount)
    && amount !== null && description.trim().length >= 2
    && description.trim().length <= 500 && !mutation.isPending

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!canSubmit || !fromAccount || !toAccount || amount === null || submitting.current) return
    submitting.current = true
    try {
      await mutation.mutateAsync({ fromAccount, toAccount, amount, description })
      onClose()
    } catch {
      // Keep entered values and show the mutation error for retry.
    } finally {
      submitting.current = false
    }
  }

  return (
    <div className="finance-dialog-backdrop" role="presentation" onMouseDown={(event) => {
      if (event.target === event.currentTarget && !mutation.isPending) onClose()
    }}>
      <section className="finance-dialog" role="dialog" aria-modal="true" aria-labelledby="finance-transfer-title">
        <div className="finance-dialog-heading">
          <div><span>HESAPLAR ARASI</span><h2 id="finance-transfer-title">Para Transferi</h2></div>
          <button type="button" aria-label="Kapat" disabled={mutation.isPending} onClick={onClose}><X size={20} /></button>
        </div>
        <form onSubmit={handleSubmit}>
          <label className="finance-dialog-field">
            <span>Kaynak hesap</span>
            <select autoFocus required value={fromId} disabled={mutation.isPending} onChange={(event) => {
              setFromId(event.target.value)
              setToId('')
            }}>
              <option value="">Hesap seçin</option>
              {accounts.map((account) => <option key={account.id} value={account.id}>{account.name} ({account.currencyCode})</option>)}
            </select>
          </label>
          <label className="finance-dialog-field">
            <span id="transfer-target-label">Hedef hesap</span>
            <select aria-labelledby="transfer-target-label" required value={toId} disabled={!fromAccount || mutation.isPending} onChange={(event) => setToId(event.target.value)}>
              <option value="">Hesap seçin</option>
              {accounts.map((account) => <option key={account.id} value={account.id} disabled={!fromAccount || !canTransferBetween(fromAccount, account)}>{account.name} ({account.currencyCode})</option>)}
            </select>
            <small>Yalnızca aynı para birimindeki farklı hesaplara transfer yapılabilir.</small>
          </label>
          {fromAccount && !accounts.some((account) => canTransferBetween(fromAccount, account)) ? (
            <div className="finance-dialog-info" role="status">Bu para biriminde transfer yapılabilecek başka hesap yok.</div>
          ) : null}
          <label className="finance-dialog-field">
            <span id="transfer-amount-label">Tutar</span>
            <div className="finance-money-input">
              <input aria-labelledby="transfer-amount-label" required inputMode="decimal" placeholder="0,00" value={amountInput} disabled={mutation.isPending} onChange={(event) => setAmountInput(event.target.value)} aria-invalid={amountInput !== '' && amount === null} />
              <span>{fromAccount?.currencyCode}</span>
            </div>
            <small>Sıfırdan büyük, en fazla iki ondalıklı bir tutar girin.</small>
          </label>
          <label className="finance-dialog-field">
            <span>Açıklama</span>
            <textarea required rows={3} minLength={2} maxLength={500} value={description} disabled={mutation.isPending} onChange={(event) => setDescription(event.target.value)} placeholder="Örn. Kasadan banka hesabına aktarım" />
            <small>2–500 karakter. Bu açıklama denetim kaydında saklanır.</small>
          </label>
          {mutation.isError ? <div className="finance-dialog-error" role="alert">{mutation.error.message || 'Transfer kaydedilemedi.'}</div> : null}
          <div className="finance-dialog-actions">
            <button type="button" disabled={mutation.isPending} onClick={onClose}>Vazgeç</button>
            <button type="submit" className="primary" disabled={!canSubmit}>{mutation.isPending ? 'Kaydediliyor...' : 'Transferi Kaydet'}</button>
          </div>
        </form>
      </section>
    </div>
  )
}

