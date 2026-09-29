import { z } from 'zod'

export const salesAppConnectionStatus =
  z.enum(['DRAFT', 'ACTIVE', 'PAUSED'])

export type SalesAppConnectionStatus =
  z.infer<typeof salesAppConnectionStatus>

export const salesAppSyncRunStatus =
  z.enum([
    'QUEUED',
    'RUNNING',
    'SUCCEEDED',
    'FAILED',
    'SKIPPED',
  ])

export type SalesAppSyncRunStatus =
  z.infer<typeof salesAppSyncRunStatus>

export const salesAppSyncTriggerType =
  z.enum([
    'MANUAL',
    'SCHEDULED',
    'RETRY',
  ])

export const salesAppSyncOverviewSchema =
  z.object({
    tenantId: z.uuid(),
    providerKey: z.literal('SALES_APP'),

    locations: z.array(
      z.object({
        id: z.uuid(),
        name: z.string().min(1),
      }),
    ),

    connections: z.array(
      z.object({
        id: z.uuid(),
        locationId: z.uuid(),
        locationName: z.string().min(1),
        providerKey: z.literal('SALES_APP'),
        adapterKey: z.string().nullable(),
        externalLocationId: z.string().nullable(),
        status: salesAppConnectionStatus,
        syncEnabled: z.boolean(),
        syncLookbackDays: z.number().int().min(1).max(31),
        createdAt: z.string().min(1),
        updatedAt: z.string().min(1),
      }),
    ),

    recentRuns: z.array(
      z.object({
        id: z.uuid(),
        connectionId: z.uuid(),
        locationId: z.uuid(),
        locationName: z.string().min(1),
        triggerType: salesAppSyncTriggerType,
        status: salesAppSyncRunStatus,
        businessDateStart: z.iso.date(),
        businessDateEnd: z.iso.date(),
        startedAt: z.string().nullable(),
        finishedAt: z.string().nullable(),
        importBatchCount:
          z.number().int().nonnegative(),
        importedRowCount:
          z.number().int().nonnegative(),
        errorCode: z.string().nullable(),
        errorMessage: z.string().nullable(),
        createdAt: z.string().min(1),
      }),
    ),
  })

export type SalesAppSyncOverview =
  z.infer<typeof salesAppSyncOverviewSchema>

export type SalesAppConnection =
  SalesAppSyncOverview['connections'][number]

const adapterKeySchema =
  z.string()
    .trim()
    .max(64)
    .refine(
      (value) =>
        value === '' ||
        /^[A-Za-z][A-Za-z0-9_]{1,63}$/.test(value),
      'Adaptör anahtarı harf ile başlamalı ve yalnızca harf, rakam veya alt çizgi içermelidir.',
    )

const externalLocationSchema =
  z.string()
    .trim()
    .max(200)

export const salesAppConnectionCreateSchema =
  z.object({
    locationId: z.uuid(),
    adapterKey: adapterKeySchema,
    externalLocationId:
      externalLocationSchema,
    syncLookbackDays:
      z.number().int().min(1).max(31),
  })

export type SalesAppConnectionCreate =
  z.infer<
    typeof salesAppConnectionCreateSchema
  >

export const salesAppConnectionUpdateSchema =
  z.object({
    connectionId: z.uuid(),
    adapterKey: adapterKeySchema,
    externalLocationId:
      externalLocationSchema,
    status: salesAppConnectionStatus,
    syncEnabled: z.boolean(),
    syncLookbackDays:
      z.number().int().min(1).max(31),
  })
  .superRefine((value, ctx) => {
    if (
      value.status === 'ACTIVE' &&
      (
        !value.adapterKey.trim() ||
        !value.externalLocationId.trim()
      )
    ) {
      ctx.addIssue({
        code: 'custom',
        path: ['status'],
        message:
          'Aktif bağlantı için adaptör ve harici lokasyon kimliği gereklidir.',
      })
    }

    if (
      value.syncEnabled &&
      value.status !== 'ACTIVE'
    ) {
      ctx.addIssue({
        code: 'custom',
        path: ['syncEnabled'],
        message:
          'Otomatik senkronizasyon yalnızca aktif bağlantıda açılabilir.',
      })
    }
  })

export type SalesAppConnectionUpdate =
  z.infer<
    typeof salesAppConnectionUpdateSchema
  >

export const salesAppSyncRequestSchema =
  z.object({
    connectionId: z.uuid(),
    businessDateStart: z.iso.date(),
    businessDateEnd: z.iso.date(),
  })
  .superRefine((value, ctx) => {
    const start =
      Date.parse(`${value.businessDateStart}T00:00:00Z`)
    const end =
      Date.parse(`${value.businessDateEnd}T00:00:00Z`)

    if (end < start) {
      ctx.addIssue({
        code: 'custom',
        path: ['businessDateEnd'],
        message:
          'Bitiş tarihi başlangıç tarihinden önce olamaz.',
      })
      return
    }

    const days =
      Math.round(
        (end - start) / 86_400_000,
      )

    if (days > 31) {
      ctx.addIssue({
        code: 'custom',
        path: ['businessDateEnd'],
        message:
          'Senkronizasyon aralığı en fazla 31 gün olabilir.',
      })
    }
  })

export type SalesAppSyncRequest =
  z.infer<typeof salesAppSyncRequestSchema>

const syncCommandErrors:
  Record<string, string> = {
    SALES_APP_CONNECTION_INVALID:
      'Bağlantı ayarlarını kontrol edin.',
    SALES_APP_CONNECTION_EXISTS:
      'Bu lokasyon için Satış Uygulaması bağlantısı zaten var.',
    SALES_APP_CONNECTION_NOT_AVAILABLE:
      'Satış Uygulaması bağlantısı bulunamadı.',
    SALES_APP_SYNC_ALREADY_ACTIVE:
      'Bu bağlantı için devam eden bir senkronizasyon zaten var.',
    SALES_APP_SYNC_PERIOD_INVALID:
      'Senkronizasyon tarih aralığını kontrol edin.',
    SALES_APP_CONNECTION_NOT_READY:
      'Satış Uygulaması bağlantısı senkronizasyona hazır değil.',
  }

export function salesAppSyncCommandError(
  message: string,
) {
  return syncCommandErrors[message] ??
    message
}

export const salesAppSyncResultSchema =
  z.object({
    runId: z.uuid(),
    status: z.literal('SUCCEEDED'),
    importBatchCount:
      z.number().int().nonnegative(),
    importedRowCount:
      z.number().int().nonnegative(),
  })

export const salesAppSyncFailureSchema =
  z.object({
    runId: z.uuid().nullable(),
    status: z.literal('FAILED').nullable(),
    error: z.object({
      code: z.string().min(1),
      message: z.string().min(1),
    }),
  })

export function salesAppSyncStatusLabel(
  status: SalesAppSyncRunStatus,
) {
  switch (status) {
    case 'QUEUED':
      return 'Sırada'
    case 'RUNNING':
      return 'Çalışıyor'
    case 'SUCCEEDED':
      return 'Tamamlandı'
    case 'FAILED':
      return 'Başarısız'
    case 'SKIPPED':
      return 'Atlandı'
  }
}
