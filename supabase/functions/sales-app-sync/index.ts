import { createClient } from 'npm:@supabase/supabase-js@2.117.1'

import {
  getSalesAppAdapter,
  normalizeSalesDays,
  SalesAppAdapterError,
} from '../_shared/sales-app-sync.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods':
    'POST, OPTIONS',
}

type SyncRequest = {
  tenantId: string
  connectionId: string
  businessDateStart: string
  businessDateEnd: string
}

type PublicError = {
  code: string
  message: string
  httpStatus: number
}

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

function json(
  body: unknown,
  status = 200,
) {
  return new Response(
    JSON.stringify(body),
    {
      status,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json; charset=utf-8',
      },
    },
  )
}

function readManagedKey(
  modernName: string,
  legacyName: string,
) {
  const modern = Deno.env.get(modernName)

  if (modern) {
    try {
      const parsed = JSON.parse(modern)

      if (
        parsed &&
        typeof parsed === 'object'
      ) {
        if (
          typeof parsed.default === 'string' &&
          parsed.default.length > 0
        ) {
          return parsed.default
        }

        const first = Object.values(parsed).find(
          (value) =>
            typeof value === 'string' &&
            value.length > 0,
        )

        if (typeof first === 'string') {
          return first
        }
      }
    } catch {
      // Fall through to the legacy managed key.
    }
  }

  const legacy = Deno.env.get(legacyName)

  if (legacy) {
    return legacy
  }

  throw new Error(
    `Missing managed Supabase key: ${modernName}`,
  )
}

function parseBody(
  value: unknown,
): SyncRequest {
  if (
    !value ||
    typeof value !== 'object'
  ) {
    throw {
      code: 'SYNC_REQUEST_INVALID',
      message: 'Senkronizasyon isteği geçersiz.',
      httpStatus: 400,
    } satisfies PublicError
  }

  const body = value as Record<string, unknown>

  const tenantId =
    typeof body.tenantId === 'string'
      ? body.tenantId.trim()
      : ''

  const connectionId =
    typeof body.connectionId === 'string'
      ? body.connectionId.trim()
      : ''

  const businessDateStart =
    typeof body.businessDateStart === 'string'
      ? body.businessDateStart.trim()
      : ''

  const businessDateEnd =
    typeof body.businessDateEnd === 'string'
      ? body.businessDateEnd.trim()
      : ''

  if (
    !uuidPattern.test(tenantId) ||
    !uuidPattern.test(connectionId) ||
    !/^\d{4}-\d{2}-\d{2}$/.test(
      businessDateStart,
    ) ||
    !/^\d{4}-\d{2}-\d{2}$/.test(
      businessDateEnd,
    )
  ) {
    throw {
      code: 'SYNC_REQUEST_INVALID',
      message: 'Senkronizasyon isteği geçersiz.',
      httpStatus: 400,
    } satisfies PublicError
  }

  return {
    tenantId,
    connectionId,
    businessDateStart,
    businessDateEnd,
  }
}

function mapRpcError(
  error: {
    code?: string
    message?: string
  },
): PublicError {
  if (error.code === '42501') {
    return {
      code: 'SYNC_PERMISSION_DENIED',
      message:
        'Bu işlem için yetkiniz bulunmuyor.',
      httpStatus: 403,
    }
  }

  if (error.code === '22023') {
    return {
      code: 'SYNC_REQUEST_REJECTED',
      message:
        'Senkronizasyon isteği geçerli değil veya bağlantı hazır değil.',
      httpStatus: 400,
    }
  }

  if (error.code === '55000') {
    return {
      code: 'SYNC_ALREADY_ACTIVE',
      message:
        'Bu bağlantı için devam eden bir senkronizasyon zaten var.',
      httpStatus: 409,
    }
  }

  return {
    code: 'SYNC_REQUEST_FAILED',
    message:
      'Senkronizasyon isteği oluşturulamadı.',
    httpStatus: 500,
  }
}

function safeError(
  error: unknown,
): PublicError {
  if (
    error instanceof SalesAppAdapterError
  ) {
    return {
      code: error.code,
      message: error.message,
      httpStatus: error.httpStatus,
    }
  }

  if (
    error &&
    typeof error === 'object' &&
    'code' in error &&
    'message' in error &&
    'httpStatus' in error
  ) {
    const candidate =
      error as PublicError

    if (
      typeof candidate.code === 'string' &&
      typeof candidate.message === 'string' &&
      typeof candidate.httpStatus === 'number'
    ) {
      return candidate
    }
  }

  return {
    code: 'SYNC_INTERNAL_ERROR',
    message:
      'Senkronizasyon tamamlanamadı.',
    httpStatus: 500,
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    })
  }

  if (req.method !== 'POST') {
    return json(
      {
        error: {
          code: 'METHOD_NOT_ALLOWED',
          message:
            'Yalnızca POST isteği desteklenir.',
        },
      },
      405,
    )
  }

  const authorization =
    req.headers.get('Authorization')

  if (
    !authorization ||
    !authorization.startsWith('Bearer ')
  ) {
    return json(
      {
        error: {
          code: 'AUTHENTICATION_REQUIRED',
          message:
            'Oturum doğrulaması gerekli.',
        },
      },
      401,
    )
  }

  let runId: string | null = null
  let adminClient:
    | ReturnType<typeof createClient>
    | null = null

  try {
    const body = parseBody(
      await req.json(),
    )

    const supabaseUrl =
      Deno.env.get('SUPABASE_URL')

    if (!supabaseUrl) {
      throw new Error(
        'SUPABASE_URL is unavailable',
      )
    }

    const publishableKey =
      readManagedKey(
        'SUPABASE_PUBLISHABLE_KEYS',
        'SUPABASE_ANON_KEY',
      )

    const secretKey =
      readManagedKey(
        'SUPABASE_SECRET_KEYS',
        'SUPABASE_SERVICE_ROLE_KEY',
      )

    const userClient = createClient(
      supabaseUrl,
      publishableKey,
      {
        global: {
          headers: {
            Authorization: authorization,
          },
        },
        auth: {
          persistSession: false,
          autoRefreshToken: false,
          detectSessionInUrl: false,
        },
      },
    )

    adminClient = createClient(
      supabaseUrl,
      secretKey,
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
          detectSessionInUrl: false,
        },
      },
    )

    const requestResult =
      await userClient.rpc(
        'request_sales_app_sync',
        {
          p_tenant_id: body.tenantId,
          p_connection_id:
            body.connectionId,
          p_business_date_start:
            body.businessDateStart,
          p_business_date_end:
            body.businessDateEnd,
        },
      )

    if (requestResult.error) {
      throw mapRpcError(
        requestResult.error,
      )
    }

    if (
      typeof requestResult.data !==
      'string'
    ) {
      throw new Error(
        'Sync request did not return a run id',
      )
    }

    runId = requestResult.data

    const connectionResult =
      await adminClient
        .from('sales_app_connections')
        .select(
          [
            'id',
            'tenant_id',
            'location_id',
            'adapter_key',
            'external_location_id',
            'provider_key',
            'status',
          ].join(','),
        )
        .eq('id', body.connectionId)
        .eq('tenant_id', body.tenantId)
        .single()

    if (
      connectionResult.error ||
      !connectionResult.data
    ) {
      throw {
        code:
          'SYNC_CONNECTION_NOT_AVAILABLE',
        message:
          'Satış Uygulaması bağlantısı bulunamadı.',
        httpStatus: 409,
      } satisfies PublicError
    }

    const connection =
      connectionResult.data

    if (
      connection.provider_key !==
        'SALES_APP' ||
      connection.status !== 'ACTIVE' ||
      !connection.adapter_key ||
      !connection.external_location_id
    ) {
      throw {
        code: 'SYNC_CONNECTION_NOT_READY',
        message:
          'Satış Uygulaması bağlantısı senkronizasyona hazır değil.',
        httpStatus: 409,
      } satisfies PublicError
    }

    const startedAt =
      new Date().toISOString()

    const claimResult =
      await adminClient
        .from('sales_app_sync_runs')
        .update({
          status: 'RUNNING',
          started_at: startedAt,
        })
        .eq('id', runId)
        .eq('tenant_id', body.tenantId)
        .eq('status', 'QUEUED')
        .select('id')
        .maybeSingle()

    if (
      claimResult.error ||
      !claimResult.data
    ) {
      throw {
        code: 'SYNC_RUN_NOT_CLAIMED',
        message:
          'Senkronizasyon çalışması başlatılamadı.',
        httpStatus: 409,
      } satisfies PublicError
    }

    const adapter =
      getSalesAppAdapter(
        connection.adapter_key,
      )

    const rawDays =
      await adapter.fetchDailySales({
        connection: {
          id: connection.id,
          tenantId:
            connection.tenant_id,
          locationId:
            connection.location_id,
          adapterKey:
            connection.adapter_key,
          externalLocationId:
            connection.external_location_id,
        },
        businessDateStart:
          body.businessDateStart,
        businessDateEnd:
          body.businessDateEnd,
      })

    const days = normalizeSalesDays(
      rawDays,
      body.businessDateStart,
      body.businessDateEnd,
    )

    const importBatchIds: string[] = []
    let importedRowCount = 0

    for (const day of days) {
      const importResult =
        await userClient.rpc(
          'import_sales_app_daily_sales',
          {
            p_tenant_id:
              body.tenantId,
            p_location_id:
              connection.location_id,
            p_business_date:
              day.businessDate,
            p_external_batch_key:
              day.externalBatchKey,
            p_currency_code:
              day.currencyCode,
            p_rows: day.rows,
          },
        )

      if (importResult.error) {
        throw {
          code: 'SYNC_IMPORT_FAILED',
          message:
            'Satış verileri COOST sistemine aktarılamadı.',
          httpStatus: 500,
        } satisfies PublicError
      }

      if (
        typeof importResult.data ===
        'string'
      ) {
        importBatchIds.push(
          importResult.data,
        )
      }

      importedRowCount +=
        day.rows.length
    }

    const completedAt =
      new Date().toISOString()

    const completeResult =
      await adminClient
        .from('sales_app_sync_runs')
        .update({
          status: 'SUCCEEDED',
          finished_at: completedAt,
          import_batch_count:
            importBatchIds.length,
          imported_row_count:
            importedRowCount,
          error_code: null,
          error_message: null,
          metadata: {
            adapterKey:
              connection.adapter_key,
            importBatchIds,
          },
        })
        .eq('id', runId)
        .eq('tenant_id', body.tenantId)
        .eq('status', 'RUNNING')
        .select('id')
        .maybeSingle()

    if (
      completeResult.error ||
      !completeResult.data
    ) {
      throw {
        code: 'SYNC_COMPLETION_FAILED',
        message:
          'Senkronizasyon sonucu kaydedilemedi.',
        httpStatus: 500,
      } satisfies PublicError
    }

    return json({
      runId,
      status: 'SUCCEEDED',
      importBatchCount:
        importBatchIds.length,
      importedRowCount,
    })
  } catch (error) {
    const publicError =
      safeError(error)

    if (runId && adminClient) {
      try {
        await adminClient
          .from('sales_app_sync_runs')
          .update({
            status: 'FAILED',
            finished_at:
              new Date().toISOString(),
            error_code:
              publicError.code.slice(
                0,
                120,
              ),
            error_message:
              publicError.message.slice(
                0,
                1000,
              ),
          })
          .eq('id', runId)
          .in(
            'status',
            ['QUEUED', 'RUNNING'],
          )
      } catch {
        // Preserve the original failure.
      }
    }

    return json(
      {
        runId,
        status:
          runId ? 'FAILED' : null,
        error: {
          code: publicError.code,
          message:
            publicError.message,
        },
      },
      publicError.httpStatus,
    )
  }
})