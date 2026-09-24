import type { FinanceOverviewAccount } from './financeOverview'

export function parseTransferAmount(value: string): number | null {
  const input = value.trim()
  // Accept decimal dots or Turkish decimal commas with optional grouping.
  if (!/^(?:\d+(?:[.,]\d{1,2})?|\d{1,3}(?:\.\d{3})+,\d{1,2})$/.test(input)) {
    return null
  }
  const amount = Number(input.includes(',') ? input.replace(/\./g, '').replace(',', '.') : input)
  return Number.isFinite(amount) && amount > 0 && amount < 100000000000000
    ? amount : null
}

export function canTransferBetween(from: FinanceOverviewAccount, to: FinanceOverviewAccount) {
  return from.id !== to.id && from.currencyCode === to.currencyCode
}
