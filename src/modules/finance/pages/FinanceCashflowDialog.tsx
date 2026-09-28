import { useEffect, useRef, useState, type FormEvent, type KeyboardEvent } from 'react'
import { X } from 'lucide-react'
import type { FinanceOverviewAccount } from '../model/financeOverview'
import { isCashflowDescriptionValid, parseCashflowAmount, type FinanceCashflowType } from '../model/financeCashflow'
import { useCreateFinanceCashflow } from '../mutations/useCreateFinanceCashflow'

export function FinanceCashflowDialog({ accounts, onClose }: {
  accounts: FinanceOverviewAccount[]
  onClose: () => void
}) {
  const mutation = useCreateFinanceCashflow()
  const submitting = useRef(false)
  const dialogRef = useRef<HTMLElement>(null)
  const [transactionType, setTransactionType] = useState<FinanceCashflowType>('INCOME')
  const [accountId, setAccountId] = useState('')
  const [amountInput, setAmountInput] = useState('')
  const [description, setDescription] = useState('')
  const account = accounts.find((item) => item.id === accountId && item.status === 'ACTIVE')
  const amount = parseCashflowAmount(amountInput)
  const canSubmit = account && amount !== null && isCashflowDescriptionValid(description) && !mutation.isPending

  useEffect(() => {
    const previousFocus = document.activeElement as HTMLElement | null
    dialogRef.current?.querySelector<HTMLSelectElement>('select')?.focus()
    return () => previousFocus?.focus()
  }, [])

  function handleKeyDown(event: KeyboardEvent<HTMLElement>) {
    if (event.key === 'Escape' && !submitting.current) {
      event.preventDefault()
      onClose()
    }
    if (event.key !== 'Tab') return
    const controls = dialogRef.current?.querySelectorAll<HTMLElement>('button:not(:disabled), select:not(:disabled), input:not(:disabled), textarea:not(:disabled)')
    if (!controls?.length) {
      event.preventDefault()
      return
    }
    const first = controls[0]
    const last = controls[controls.length - 1]
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!canSubmit || !account || amount === null || submitting.current) return
    submitting.current = true
    try {
      await mutation.mutateAsync({ accountId: account.id, transactionType, amount, description })
      onClose()
    } catch {
      // Preserve all form values so a failed request can be retried.
    } finally {
      submitting.current = false
    }
  }

  return (
    <div className="finance-dialog-backdrop" role="presentation" onMouseDown={(event) => {
      if (event.target === event.currentTarget && !submitting.current) onClose()
    }}>
      <section ref={dialogRef} className="finance-dialog" role="dialog" aria-modal="true" aria-labelledby="finance-cashflow-title" onKeyDown={handleKeyDown}>
        <div className="finance-dialog-heading">
          <div><span>NAKİT HAREKETİ</span><h2 id="finance-cashflow-title">Gelir / Gider Ekle</h2></div>
          <button type="button" aria-label="Kapat" disabled={mutation.isPending} onClick={onClose}><X size={20} /></button>
        </div>
        <form onSubmit={handleSubmit}>
          <label className="finance-dialog-field">
            <span>İşlem türü</span>
            <select value={transactionType} disabled={mutation.isPending} onChange={(event) => setTransactionType(event.target.value as FinanceCashflowType)}>
              <option value="INCOME">Gelir</option>
              <option value="EXPENSE">Gider</option>
            </select>
          </label>
          <label className="finance-dialog-field">
            <span>Hesap</span>
            <select required value={accountId} disabled={mutation.isPending} onChange={(event) => setAccountId(event.target.value)}>
              <option value="">Hesap seçin</option>
              {accounts.filter((item) => item.status === 'ACTIVE').map((item) => <option key={item.id} value={item.id}>{item.name} ({item.currencyCode})</option>)}
            </select>
          </label>
          <label className="finance-dialog-field">
            <span id="cashflow-amount-label">Tutar</span>
            <div className="finance-money-input">
              <input aria-labelledby="cashflow-amount-label" aria-describedby="cashflow-amount-help" required inputMode="decimal" placeholder="0,00" value={amountInput} disabled={mutation.isPending} onChange={(event) => setAmountInput(event.target.value)} aria-invalid={amountInput !== '' && amount === null} />
              <span>{account?.currencyCode}</span>
            </div>
            <small id="cashflow-amount-help">Pozitif, en fazla iki ondalıklı tutar girin. Gider için eksi işareti kullanmayın.</small>
          </label>
          <label className="finance-dialog-field">
            <span id="cashflow-description-label">Açıklama</span>
            <textarea aria-labelledby="cashflow-description-label" aria-describedby="cashflow-description-help" required rows={3} minLength={2} maxLength={500} value={description} disabled={mutation.isPending} onChange={(event) => setDescription(event.target.value)} placeholder={transactionType === 'INCOME' ? 'Örn. Nakit satış tahsilatı' : 'Örn. Ofis malzemesi ödemesi'} />
            <small id="cashflow-description-help">2–500 karakter. Bu açıklama denetim kaydında saklanır.</small>
          </label>
          {mutation.isError ? <div className="finance-dialog-error" role="alert">{mutation.error.message || 'Gelir / gider kaydedilemedi.'}</div> : null}
          <div className="finance-dialog-actions">
            <button type="button" disabled={mutation.isPending} onClick={onClose}>Vazgeç</button>
            <button type="submit" className="primary" disabled={!canSubmit}>{mutation.isPending ? 'Kaydediliyor...' : transactionType === 'INCOME' ? 'Geliri Kaydet' : 'Gideri Kaydet'}</button>
          </div>
        </form>
      </section>
    </div>
  )
}
