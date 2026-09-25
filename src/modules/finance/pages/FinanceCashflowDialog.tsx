import { useRef, useState, type FormEvent } from 'react'
import { X } from 'lucide-react'
import type { FinanceOverviewAccount } from '../model/financeOverview'
import { parseCashflowAmount, type FinanceCashflowType } from '../model/financeCashflow'
import { useCreateFinanceCashflow } from '../mutations/useCreateFinanceCashflow'

export function FinanceCashflowDialog({ accounts, onClose }: {
  accounts: FinanceOverviewAccount[]
  onClose: () => void
}) {
  const mutation = useCreateFinanceCashflow()
  const submitting = useRef(false)
  const [transactionType, setTransactionType] = useState<FinanceCashflowType>('INCOME')
  const [accountId, setAccountId] = useState('')
  const [amountInput, setAmountInput] = useState('')
  const [description, setDescription] = useState('')
  const activeAccounts = accounts.filter((account) => account.status === 'ACTIVE')
  const account = activeAccounts.find((item) => item.id === accountId)
  const amount = parseCashflowAmount(amountInput)
  const canSubmit = account && amount !== null && description.trim().length >= 2
    && description.trim().length <= 500 && !mutation.isPending

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!canSubmit || !account || amount === null || submitting.current) return
    submitting.current = true
    try {
      await mutation.mutateAsync({ accountId: account.id, transactionType, amount, description })
      onClose()
    } catch {
      // Preserve the form for retry after an RPC error.
    } finally {
      submitting.current = false
    }
  }

  return (
    <div className="finance-dialog-backdrop" role="presentation" onMouseDown={(event) => {
      if (event.target === event.currentTarget && !submitting.current) onClose()
    }}>
      <section className="finance-dialog" role="dialog" aria-modal="true" aria-labelledby="finance-cashflow-title">
        <div className="finance-dialog-heading">
          <div><span>FİNANS HAREKETİ</span><h2 id="finance-cashflow-title">Gelir / Gider Ekle</h2></div>
          <button type="button" aria-label="Kapat" disabled={mutation.isPending} onClick={onClose}><X size={20} /></button>
        </div>
        <form onSubmit={handleSubmit}>
          <label className="finance-dialog-field">
            <span>İşlem türü</span>
            <select autoFocus value={transactionType} disabled={mutation.isPending} onChange={(event) => setTransactionType(event.target.value as FinanceCashflowType)}>
              <option value="INCOME">Gelir</option>
              <option value="EXPENSE">Gider</option>
            </select>
          </label>
          <label className="finance-dialog-field">
            <span>Hesap</span>
            <select required value={accountId} disabled={mutation.isPending} onChange={(event) => setAccountId(event.target.value)}>
              <option value="">Hesap seçin</option>
              {activeAccounts.map((item) => <option key={item.id} value={item.id}>{item.name} ({item.currencyCode})</option>)}
            </select>
          </label>
          <label className="finance-dialog-field">
            <span id="cashflow-amount-label">Tutar</span>
            <div className="finance-money-input">
              <input aria-labelledby="cashflow-amount-label" required inputMode="decimal" placeholder="0,00" value={amountInput} disabled={mutation.isPending} onChange={(event) => setAmountInput(event.target.value)} aria-invalid={amountInput !== '' && amount === null} />
              <span>{account?.currencyCode}</span>
            </div>
            <small>Sıfırdan büyük, en fazla iki ondalıklı bir tutar girin. Gider için de eksi işareti kullanmayın.</small>
          </label>
          <label className="finance-dialog-field">
            <span>Açıklama</span>
            <textarea required rows={3} minLength={2} maxLength={500} value={description} disabled={mutation.isPending} onChange={(event) => setDescription(event.target.value)} placeholder="Örn. Satış tahsilatı veya kira ödemesi" />
            <small>2–500 karakter. Bu açıklama denetim kaydında saklanır.</small>
          </label>
          {mutation.isError ? <div className="finance-dialog-error" role="alert">{mutation.error.message || 'İşlem kaydedilemedi.'}</div> : null}
          <div className="finance-dialog-actions">
            <button type="button" disabled={mutation.isPending} onClick={onClose}>Vazgeç</button>
            <button type="submit" className="primary" disabled={!canSubmit}>{mutation.isPending ? 'Kaydediliyor...' : 'Kaydet'}</button>
          </div>
        </form>
      </section>
    </div>
  )
}
