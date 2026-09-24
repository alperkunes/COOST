import { z } from 'zod'

export const financeAccountTypeSchema = z.enum([
  'CASH',
  'BANK',
])

export const financeTransactionTypeSchema = z.enum([
  'INCOME',
  'EXPENSE',
  'TRANSFER',
  'ADJUSTMENT',
])

export const financeOverviewAccountSchema = z.object({
  id: z.uuid(),
  name: z.string().trim().min(1),
  accountType: financeAccountTypeSchema,
  currencyCode: z.string().regex(/^[A-Z]{3}$/),
  status: z.literal('ACTIVE'),
  balance: z.number(),
})

export const financeOverviewEntrySchema = z.object({
  id: z.uuid(),
  accountId: z.uuid(),
  accountName: z.string().trim().min(1),
  accountType: financeAccountTypeSchema,
  currencyCode: z.string().regex(/^[A-Z]{3}$/),
  amount: z.number(),
})

export const financeOverviewTransactionSchema = z.object({
  id: z.uuid(),
  transactionType: financeTransactionTypeSchema,
  occurredAt: z.string().min(1),
  description: z.string().nullable(),
  sourceType: z.string().nullable(),
  sourceId: z.uuid().nullable(),
  entries: z.array(financeOverviewEntrySchema),
})

export const financeOverviewSchema = z.object({
  tenantId: z.uuid(),
  accounts: z.array(financeOverviewAccountSchema),
  recentTransactions: z.array(
    financeOverviewTransactionSchema,
  ),
})

export type FinanceOverview = z.infer<
  typeof financeOverviewSchema
>

export type FinanceOverviewAccount = z.infer<
  typeof financeOverviewAccountSchema
>

export type FinanceOverviewTransaction = z.infer<
  typeof financeOverviewTransactionSchema
>