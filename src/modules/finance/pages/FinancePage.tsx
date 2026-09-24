import {
  ArrowDownLeft,
  ArrowLeftRight,
  ArrowUpRight,
  Banknote,
  Building2,
  Landmark,
  RefreshCw,
  WalletCards,
} from 'lucide-react'
import type {
  FinanceOverviewAccount,
  FinanceOverviewTransaction,
} from '../model/financeOverview'
import { useFinanceOverview } from '../queries/useFinanceOverview'
import './FinancePage.css'

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

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat('tr-TR', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value))
}

function getTotalsByCurrency(
  accounts: FinanceOverviewAccount[],
) {
  const totals = new Map<string, number>()

  for (const account of accounts) {
    totals.set(
      account.currencyCode,
      (totals.get(account.currencyCode) ?? 0) +
        account.balance,
    )
  }

  return Array.from(totals.entries()).map(
    ([currencyCode, amount]) => ({
      currencyCode,
      amount,
    }),
  )
}

function SummaryValue({
  accounts,
}: {
  accounts: FinanceOverviewAccount[]
}) {
  const totals = getTotalsByCurrency(accounts)

  if (totals.length === 0) {
    return <strong>—</strong>
  }

  return (
    <div className="finance-summary-values">
      {totals.map((total) => (
        <strong key={total.currencyCode}>
          {formatMoney(
            total.amount,
            total.currencyCode,
          )}
        </strong>
      ))}
    </div>
  )
}

function getTransactionMeta(
  transaction: FinanceOverviewTransaction,
) {
  const positiveEntry = transaction.entries.find(
    (entry) => entry.amount > 0,
  )

  const negativeEntry = transaction.entries.find(
    (entry) => entry.amount < 0,
  )

  switch (transaction.transactionType) {
    case 'INCOME':
      return {
        label: 'Gelir',
        icon: ArrowDownLeft,
        tone: 'income',
        amount:
          positiveEntry?.amount ??
          transaction.entries[0]?.amount ??
          null,
        currencyCode:
          positiveEntry?.currencyCode ??
          transaction.entries[0]?.currencyCode ??
          'TRY',
        route:
          positiveEntry?.accountName ??
          transaction.entries[0]?.accountName ??
          null,
      }

    case 'EXPENSE':
      return {
        label: 'Gider',
        icon: ArrowUpRight,
        tone: 'expense',
        amount:
          negativeEntry?.amount ??
          transaction.entries[0]?.amount ??
          null,
        currencyCode:
          negativeEntry?.currencyCode ??
          transaction.entries[0]?.currencyCode ??
          'TRY',
        route:
          negativeEntry?.accountName ??
          transaction.entries[0]?.accountName ??
          null,
      }

    case 'TRANSFER':
      return {
        label: 'Transfer',
        icon: ArrowLeftRight,
        tone: 'transfer',
        amount:
          positiveEntry?.amount ??
          (negativeEntry
            ? Math.abs(negativeEntry.amount)
            : null),
        currencyCode:
          positiveEntry?.currencyCode ??
          negativeEntry?.currencyCode ??
          'TRY',
        route:
          negativeEntry && positiveEntry
            ? `${negativeEntry.accountName} → ${positiveEntry.accountName}`
            : null,
      }

    case 'ADJUSTMENT':
      return {
        label: 'Düzeltme',
        icon: ArrowLeftRight,
        tone: 'adjustment',
        amount:
          transaction.entries[0]?.amount ?? null,
        currencyCode:
          transaction.entries[0]?.currencyCode ??
          'TRY',
        route:
          transaction.entries[0]?.accountName ??
          null,
      }
  }
}

export function FinancePage() {
  const financeQuery = useFinanceOverview()

  if (financeQuery.isPending) {
    return (
      <section className="finance-state">
        <RefreshCw
          className="finance-spinner"
          size={28}
        />
        <strong>Finans verileri yükleniyor</strong>
        <span>
          Kasa ve banka bakiyeleri hazırlanıyor.
        </span>
      </section>
    )
  }

  if (financeQuery.isError) {
    return (
      <section className="finance-state finance-state-error">
        <strong>Finans özeti alınamadı</strong>
        <span>
          {financeQuery.error instanceof Error
            ? financeQuery.error.message
            : 'Beklenmeyen bir hata oluştu.'}
        </span>

        <button
          type="button"
          onClick={() => {
            void financeQuery.refetch()
          }}
        >
          Tekrar dene
        </button>
      </section>
    )
  }

  const overview = financeQuery.data
  const accounts = overview.accounts

  const cashAccounts = accounts.filter(
    (account) => account.accountType === 'CASH',
  )

  const bankAccounts = accounts.filter(
    (account) => account.accountType === 'BANK',
  )

  return (
    <section className="finance-page">
      <div className="finance-heading">
        <div>
          <span className="eyebrow">
            FİNANS
          </span>

          <h1>Kasa ve Banka</h1>

          <p>
            Nakit ve banka hesaplarının güncel
            bakiyelerini, transferlerini ve son
            hareketlerini tek noktadan izleyin.
          </p>
        </div>

        <div className="finance-heading-actions">
          <span className="finance-readonly-badge">
            Salt okunur
          </span>

          <button
            className="finance-refresh-button"
            type="button"
            disabled={financeQuery.isFetching}
            onClick={() => {
              void financeQuery.refetch()
            }}
          >
            <RefreshCw
              size={16}
              className={
                financeQuery.isFetching
                  ? 'finance-spinner'
                  : undefined
              }
            />
            Yenile
          </button>
        </div>
      </div>

      <div className="finance-summary-grid">
        <article className="finance-summary-card">
          <div className="finance-summary-icon">
            <Banknote size={22} />
          </div>

          <div>
            <span>TOPLAM NAKİT</span>
            <SummaryValue accounts={cashAccounts} />
            <small>
              {cashAccounts.length} aktif kasa
            </small>
          </div>
        </article>

        <article className="finance-summary-card">
          <div className="finance-summary-icon">
            <Landmark size={22} />
          </div>

          <div>
            <span>TOPLAM BANKA</span>
            <SummaryValue accounts={bankAccounts} />
            <small>
              {bankAccounts.length} aktif banka
            </small>
          </div>
        </article>

        <article className="finance-summary-card">
          <div className="finance-summary-icon">
            <WalletCards size={22} />
          </div>

          <div>
            <span>TOPLAM BAKİYE</span>
            <SummaryValue accounts={accounts} />
            <small>
              {accounts.length} aktif hesap
            </small>
          </div>
        </article>
      </div>

      <div className="finance-layout">
        <section className="finance-panel">
          <div className="finance-panel-heading">
            <div>
              <span>HESAPLAR</span>
              <h2>Kasa ve banka hesapları</h2>
            </div>

            <small>
              Bakiye hareketlerden hesaplanır
            </small>
          </div>

          {accounts.length === 0 ? (
            <div className="finance-empty-state">
              <Building2 size={28} />
              <strong>
                Henüz kasa veya banka hesabı yok
              </strong>
              <span>
                Hesap tanımlama özelliği bir sonraki
                adımda eklenecek.
              </span>
            </div>
          ) : (
            <div className="finance-account-list">
              {accounts.map((account) => (
                <article
                  className="finance-account-row"
                  key={account.id}
                >
                  <div
                    className={`finance-account-icon finance-account-icon-${account.accountType.toLowerCase()}`}
                  >
                    {account.accountType ===
                    'CASH' ? (
                      <Banknote size={20} />
                    ) : (
                      <Landmark size={20} />
                    )}
                  </div>

                  <div className="finance-account-copy">
                    <strong>{account.name}</strong>
                    <span>
                      {account.accountType ===
                      'CASH'
                        ? 'Nakit kasa'
                        : 'Banka hesabı'}
                    </span>
                  </div>

                  <strong className="finance-account-balance">
                    {formatMoney(
                      account.balance,
                      account.currencyCode,
                    )}
                  </strong>
                </article>
              ))}
            </div>
          )}
        </section>

        <section className="finance-panel">
          <div className="finance-panel-heading">
            <div>
              <span>SON HAREKETLER</span>
              <h2>Finans hareketleri</h2>
            </div>

            <small>
              Son{' '}
              {
                overview.recentTransactions
                  .length
              }{' '}
              işlem
            </small>
          </div>

          {overview.recentTransactions.length ===
          0 ? (
            <div className="finance-empty-state">
              <ArrowLeftRight size={28} />
              <strong>
                Henüz finans hareketi yok
              </strong>
              <span>
                İlk işlem kaydedildiğinde burada
                görünecek.
              </span>
            </div>
          ) : (
            <div className="finance-transaction-list">
              {overview.recentTransactions.map(
                (transaction) => {
                  const meta =
                    getTransactionMeta(transaction)

                  const Icon = meta.icon

                  return (
                    <article
                      className="finance-transaction-row"
                      key={transaction.id}
                    >
                      <div
                        className={`finance-transaction-icon finance-transaction-${meta.tone}`}
                      >
                        <Icon size={18} />
                      </div>

                      <div className="finance-transaction-copy">
                        <div>
                          <strong>
                            {transaction.description ??
                              meta.label}
                          </strong>

                          <span>
                            {meta.route ??
                              meta.label}
                          </span>
                        </div>

                        <small>
                          {formatDateTime(
                            transaction.occurredAt,
                          )}
                        </small>
                      </div>

                      <div className="finance-transaction-amount">
                        <span>{meta.label}</span>

                        <strong>
                          {meta.amount === null
                            ? '—'
                            : formatMoney(
                                meta.amount,
                                meta.currencyCode,
                              )}
                        </strong>
                      </div>
                    </article>
                  )
                },
              )}
            </div>
          )}
        </section>
      </div>
    </section>
  )
}