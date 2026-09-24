import {
  useMemo,
  useState,
  type FormEvent,
} from 'react'
import { X } from 'lucide-react'
import type { FinanceOverviewAccount } from '../model/financeOverview'
import { useCreateFinanceAdjustment } from '../mutations/useCreateFinanceAdjustment'

type FinanceAdjustmentDialogProps = {
  account: FinanceOverviewAccount
  onClose: () => void
}

function parseMoneyInput(value: string) {
  const trimmed = value.trim()

  if (!trimmed) {
    return null
  }

  const normalized = trimmed.includes(',')
    ? trimmed.replace(/\./g, '').replace(',', '.')
    : trimmed

  const parsed = Number(normalized)

  return Number.isFinite(parsed) ? parsed : null
}

function roundMoney(value: number) {
  return Math.round((value + Number.EPSILON) * 100) / 100
}

function formatMoney(
  amount: number,
  currencyCode: string,
) {
  return new Intl.NumberFormat('tr-TR', {
    style: 'currency',
    currency: currencyCode,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount)
}

export function FinanceAdjustmentDialog({
  account,
  onClose,
}: FinanceAdjustmentDialogProps) {
  const mutation = useCreateFinanceAdjustment()

  const [newBalanceInput, setNewBalanceInput] =
    useState(() =>
      account.balance.toFixed(2).replace('.', ','),
    )

  const [description, setDescription] =
    useState('')

  const newBalance = useMemo(
    () => parseMoneyInput(newBalanceInput),
    [newBalanceInput],
  )

  const adjustmentAmount =
    newBalance !== null
      ? roundMoney(newBalance - account.balance)
      : null

  async function handleSubmit(
    event: FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault()

    if (
      newBalance === null ||
      adjustmentAmount === null ||
      adjustmentAmount === 0
    ) {
      return
    }

    try {
      await mutation.mutateAsync({
        accountId: account.id,
        amount: adjustmentAmount,
        description,
      })

      onClose()
    } catch {
      // Mutation error is rendered inside the dialog.
    }
  }

  const descriptionValid =
    description.trim().length >= 2 &&
    description.trim().length <= 500

  const canSubmit =
    adjustmentAmount !== null &&
    adjustmentAmount !== 0 &&
    descriptionValid &&
    !mutation.isPending

  return (
    <div
      className="finance-dialog-backdrop"
      role="presentation"
      onMouseDown={(event) => {
        if (
          event.target === event.currentTarget &&
          !mutation.isPending
        ) {
          onClose()
        }
      }}
    >
      <section
        className="finance-dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="finance-adjustment-title"
      >
        <div className="finance-dialog-heading">
          <div>
            <span>BAKİYE DÜZELT</span>

            <h2 id="finance-adjustment-title">
              {account.name}
            </h2>
          </div>

          <button
            type="button"
            aria-label="Kapat"
            disabled={mutation.isPending}
            onClick={onClose}
          >
            <X size={20} />
          </button>
        </div>

        <div className="finance-dialog-current">
          <span>Mevcut bakiye</span>

          <strong>
            {formatMoney(
              account.balance,
              account.currencyCode,
            )}
          </strong>
        </div>

        <form onSubmit={handleSubmit}>
          <label className="finance-dialog-field">
            <span>Yeni gerçek bakiye</span>

            <div className="finance-money-input">
              <input
                autoFocus
                inputMode="decimal"
                value={newBalanceInput}
                onChange={(event) => {
                  setNewBalanceInput(
                    event.target.value,
                  )
                }}
                placeholder="0,00"
              />

              <span>
                {account.currencyCode}
              </span>
            </div>
          </label>

          <div className="finance-adjustment-preview">
            <span>Sisteme işlenecek fark</span>

            <strong>
              {adjustmentAmount === null
                ? '—'
                : formatMoney(
                    adjustmentAmount,
                    account.currencyCode,
                  )}
            </strong>
          </div>

          <label className="finance-dialog-field">
            <span>Açıklama</span>

            <textarea
              rows={3}
              maxLength={500}
              value={description}
              onChange={(event) => {
                setDescription(event.target.value)
              }}
              placeholder="Örn. Banka ekstresi mutabakatı"
            />

            <small>
              Bu açıklama denetim kaydında saklanır.
            </small>
          </label>

          {adjustmentAmount === 0 ? (
            <div className="finance-dialog-info">
              Yeni bakiye mevcut bakiye ile aynı.
            </div>
          ) : null}

          {mutation.isError ? (
            <div className="finance-dialog-error">
              {mutation.error instanceof Error
                ? mutation.error.message
                : 'Düzeltme kaydedilemedi.'}
            </div>
          ) : null}

          <div className="finance-dialog-actions">
            <button
              type="button"
              disabled={mutation.isPending}
              onClick={onClose}
            >
              Vazgeç
            </button>

            <button
              type="submit"
              className="primary"
              disabled={!canSubmit}
            >
              {mutation.isPending
                ? 'Kaydediliyor...'
                : 'Bakiyeyi Güncelle'}
            </button>
          </div>
        </form>
      </section>
    </div>
  )
}