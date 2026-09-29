export type NormalizedSalesRow = {
  externalProductId: string
  externalProductCode: string | null
  externalProductName: string
  quantity: number
  grossSales: number
  netSales: number
}

export type NormalizedSalesDay = {
  businessDate: string
  currencyCode: string
  externalBatchKey: string
  rows: NormalizedSalesRow[]
}

export type SalesAppConnectionContext = {
  id: string
  tenantId: string
  locationId: string
  adapterKey: string
  externalLocationId: string
}

export type SalesAppAdapterContext = {
  connection: SalesAppConnectionContext
  businessDateStart: string
  businessDateEnd: string
}

export type SalesAppAdapter = {
  key: string
  fetchDailySales(
    context: SalesAppAdapterContext,
  ): Promise<NormalizedSalesDay[]>
}

export class SalesAppAdapterError extends Error {
  readonly code: string
  readonly httpStatus: number

  constructor(
    code: string,
    message: string,
    httpStatus = 422,
  ) {
    super(message)
    this.name = 'SalesAppAdapterError'
    this.code = code
    this.httpStatus = httpStatus
  }
}

const MAX_QUANTITY = Number('999999999999.9999')
const MAX_MONEY = Number('99999999999999.99')

const adapters = new Map<string, SalesAppAdapter>()

export function registerSalesAppAdapter(
  adapter: SalesAppAdapter,
) {
  const key = adapter.key.trim().toUpperCase()

  if (!/^[A-Z][A-Z0-9_]{1,63}$/.test(key)) {
    throw new Error('Invalid Sales App adapter key')
  }

  if (adapters.has(key)) {
    throw new Error(
      `Sales App adapter already registered: ${key}`,
    )
  }

  adapters.set(key, {
    ...adapter,
    key,
  })
}

export function getSalesAppAdapter(
  adapterKey: string,
): SalesAppAdapter {
  const key = adapterKey.trim().toUpperCase()
  const adapter = adapters.get(key)

  if (!adapter) {
    throw new SalesAppAdapterError(
      'SALES_APP_ADAPTER_NOT_AVAILABLE',
      'Bu Satış Uygulaması bağlantısı için sunucu adaptörü henüz yapılandırılmamış.',
      422,
    )
  }

  return adapter
}

function validDate(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false
  }

  const date = new Date(`${value}T00:00:00.000Z`)

  return (
    !Number.isNaN(date.getTime()) &&
    date.toISOString().slice(0, 10) === value
  )
}

function validScale(
  value: number,
  scale: number,
) {
  if (!Number.isFinite(value)) {
    return false
  }

  const factor = 10 ** scale

  return (
    Math.abs(
      value * factor -
        Math.round(value * factor),
    ) < 0.000001
  )
}

function normalizeRow(
  row: NormalizedSalesRow,
): NormalizedSalesRow {
  const externalProductId =
    row.externalProductId?.trim()

  const externalProductName =
    row.externalProductName?.trim()

  const externalProductCode =
    row.externalProductCode === null ||
    row.externalProductCode === undefined
      ? null
      : row.externalProductCode.trim() || null

  if (
    !externalProductId ||
    externalProductId.length > 200 ||
    !externalProductName ||
    externalProductName.length > 200 ||
    (externalProductCode !== null &&
      externalProductCode.length > 200) ||
    !validScale(row.quantity, 4) ||
    row.quantity < 0 ||
    row.quantity > MAX_QUANTITY ||
    !validScale(row.grossSales, 2) ||
    row.grossSales < 0 ||
    row.grossSales > MAX_MONEY ||
    !validScale(row.netSales, 2) ||
    row.netSales < 0 ||
    row.netSales > MAX_MONEY ||
    (row.quantity === 0 &&
      (row.grossSales !== 0 ||
        row.netSales !== 0))
  ) {
    throw new SalesAppAdapterError(
      'SALES_APP_ADAPTER_ROW_INVALID',
      'Satış Uygulamasından alınan ürün satırı geçersiz.',
    )
  }

  return {
    externalProductId,
    externalProductCode,
    externalProductName,
    quantity: row.quantity,
    grossSales: row.grossSales,
    netSales: row.netSales,
  }
}

export function normalizeSalesDays(
  days: NormalizedSalesDay[],
  businessDateStart: string,
  businessDateEnd: string,
): NormalizedSalesDay[] {
  if (!Array.isArray(days)) {
    throw new SalesAppAdapterError(
      'SALES_APP_ADAPTER_PAYLOAD_INVALID',
      'Satış Uygulaması geçersiz veri döndürdü.',
    )
  }

  const seenDates = new Set<string>()

  const normalized = days.map((day) => {
    const businessDate = day.businessDate?.trim()

    if (
      !businessDate ||
      !validDate(businessDate) ||
      businessDate < businessDateStart ||
      businessDate > businessDateEnd ||
      seenDates.has(businessDate)
    ) {
      throw new SalesAppAdapterError(
        'SALES_APP_ADAPTER_DATE_INVALID',
        'Satış Uygulaması geçersiz satış tarihi döndürdü.',
      )
    }

    seenDates.add(businessDate)

    const currencyCode =
      day.currencyCode?.trim().toUpperCase()

    const externalBatchKey =
      day.externalBatchKey?.trim()

    if (
      !currencyCode ||
      !/^[A-Z]{3}$/.test(currencyCode) ||
      !externalBatchKey ||
      externalBatchKey.length > 200 ||
      !Array.isArray(day.rows) ||
      day.rows.length < 1 ||
      day.rows.length > 5000
    ) {
      throw new SalesAppAdapterError(
        'SALES_APP_ADAPTER_PAYLOAD_INVALID',
        'Satış Uygulaması geçersiz günlük satış verisi döndürdü.',
      )
    }

    const productIds = new Set<string>()

    const rows = day.rows.map((row) => {
      const normalizedRow = normalizeRow(row)

      if (
        productIds.has(
          normalizedRow.externalProductId,
        )
      ) {
        throw new SalesAppAdapterError(
          'SALES_APP_ADAPTER_DUPLICATE_PRODUCT',
          'Satış Uygulaması aynı ürünü günlük veride birden fazla kez döndürdü.',
        )
      }

      productIds.add(
        normalizedRow.externalProductId,
      )

      return normalizedRow
    })

    return {
      businessDate,
      currencyCode,
      externalBatchKey,
      rows,
    }
  })

  return normalized.sort((a, b) =>
    a.businessDate.localeCompare(b.businessDate),
  )
}