import { z } from 'zod'
import {
  strFromU8,
  unzipSync,
} from 'fflate'

const MAX_QUANTITY = Number('999999999999.9999')
const MAX_MONEY = Number('99999999999999.99')

export const narposGrossSalesRowSchema = z.object({
  externalProductId: z.string().trim().min(1).max(200),
  externalProductCode: z.string().trim().max(200).nullable(),
  externalProductName: z.string().trim().min(1).max(200),
  quantity: z.number().nonnegative().max(MAX_QUANTITY),
  grossSales: z.number().nonnegative().max(MAX_MONEY),
}).refine(
  (row) => row.quantity > 0 || row.grossSales === 0,
)

export type NarposGrossSalesRow =
  z.infer<typeof narposGrossSalesRowSchema>

export type NarposProductSalesImport = {
  provider: 'NARPOS'
  source: 'PRODUCT_SALES_XLSX'
  businessDate: string
  currencyCode: 'TRY'
  rows: NarposGrossSalesRow[]
  quantityTotal: number
  grossSalesTotal: number
  rawSalesTotal: number
  roundingAdjustmentCents: number
}

export const narposGrossImportSchema = z.object({
  locationId: z.uuid(),
  businessDate: z.iso.date(),
  externalBatchKey: z.string().min(1).max(200),
  currencyCode: z.literal('TRY'),
  rows: z.array(narposGrossSalesRowSchema).min(1).max(5000),
})

export type NarposGrossImport =
  z.infer<typeof narposGrossImportSchema>

type RawNarposRow = {
  groupName: string
  productName: string
  portionName: string
  quantity: number
  rawGrossSales: number
}

type GroupedNarposRow = RawNarposRow & {
  identityKey: string
  order: number
}

const REQUIRED_HEADERS = [
  'Grup İsmi',
  'Ürün İsmi',
  'Porsiyon İsmi',
  'Toplam Adet',
  'Toplam Tutar',
] as const

function normalizeText(value: string) {
  return value
    .normalize('NFC')
    .replace(/\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

function identityText(value: string) {
  return normalizeText(value)
    .normalize('NFKC')
    .toLocaleUpperCase('tr-TR')
}

function decodeXml(value: string) {
  const named: Record<string, string> = {
    amp: '&',
    lt: '<',
    gt: '>',
    quot: '"',
    apos: "'",
  }

  return value
    .replace(
      /&#x([0-9a-f]+);/gi,
      (_, hex: string) =>
        String.fromCodePoint(
          Number.parseInt(hex, 16),
        ),
    )
    .replace(
      /&#([0-9]+);/g,
      (_, decimal: string) =>
        String.fromCodePoint(
          Number.parseInt(decimal, 10),
        ),
    )
    .replace(
      /&(amp|lt|gt|quot|apos);/g,
      (_, entity: string) =>
        named[entity] ?? '',
    )
}

function readTextTags(xml: string) {
  return [
    ...xml.matchAll(
      /<t(?:\s[^>]*)?>([\s\S]*?)<\/t>/g,
    ),
  ]
    .map((match) =>
      decodeXml(match[1]),
    )
    .join('')
}

function parseSharedStrings(xml?: string) {
  if (!xml) return []

  return [
    ...xml.matchAll(
      /<si(?:\s[^>]*)?>([\s\S]*?)<\/si>/g,
    ),
  ].map((match) =>
    readTextTags(match[1]),
  )
}

function cellColumn(reference: string) {
  const match =
    /^([A-Z]+)[0-9]+$/i.exec(reference)

  return match?.[1].toUpperCase() ?? ''
}

function readCell(
  attrs: string,
  body: string,
  sharedStrings: string[],
) {
  const type =
    /\bt="([^"]+)"/.exec(attrs)?.[1] ?? ''

  if (type === 'inlineStr') {
    return readTextTags(body)
  }

  const value =
    /<v(?:\s[^>]*)?>([\s\S]*?)<\/v>/
      .exec(body)?.[1]

  if (value === undefined) {
    return ''
  }

  const decoded =
    decodeXml(value).trim()

  if (type === 's') {
    const index =
      Number.parseInt(decoded, 10)

    if (
      !Number.isInteger(index) ||
      index < 0 ||
      index >= sharedStrings.length
    ) {
      throw new Error(
        'NarPOS Excel dosyasındaki metin tablosu geçersiz.',
      )
    }

    return sharedStrings[index]
  }

  return decoded
}

function parseSheet(
  xml: string,
  sharedStrings: string[],
) {
  const rows: Record<string, string>[] = []

  for (
    const rowMatch of xml.matchAll(
      /<row\b[^>]*>([\s\S]*?)<\/row>/g,
    )
  ) {
    const cells: Record<string, string> = {}

    for (
      const cellMatch of rowMatch[1].matchAll(
        /<c\b([^>]*)>([\s\S]*?)<\/c>/g,
      )
    ) {
      const attrs = cellMatch[1]
      const reference =
        /\br="([^"]+)"/.exec(attrs)?.[1]

      if (!reference) continue

      const column =
        cellColumn(reference)

      if (!column) continue

      cells[column] = readCell(
        attrs,
        cellMatch[2],
        sharedStrings,
      )
    }

    if (Object.keys(cells).length) {
      rows.push(cells)
    }
  }

  return rows
}

function parseNonNegativeNumber(
  value: string,
  label: string,
  rowNumber: number,
) {
  const normalized =
    normalizeText(value)

  if (
    !normalized ||
    !/^\d+(?:\.\d+)?(?:[Ee][+-]?\d+)?$/.test(
      normalized,
    )
  ) {
    throw new Error(
      `NarPOS satır ${rowNumber}: ${label} geçersiz.`,
    )
  }

  const number = Number(normalized)

  if (
    !Number.isFinite(number) ||
    number < 0
  ) {
    throw new Error(
      `NarPOS satır ${rowNumber}: ${label} geçersiz.`,
    )
  }

  return number
}

function quantityUnits(
  value: number,
  rowNumber: number,
) {
  const units =
    Math.round(value * 10_000)

  if (
    Math.abs(
      value * 10_000 - units,
    ) > 0.000001
  ) {
    throw new Error(
      `NarPOS satır ${rowNumber}: Toplam Adet en fazla 4 ondalık basamak içerebilir.`,
    )
  }

  return units
}

function cents(value: number) {
  return Math.round(
    value * 100 + 1e-8,
  )
}

function reconcileCents(
  rows: GroupedNarposRow[],
) {
  const allocations = rows.map(
    (row) => {
      const rawCents =
        row.rawGrossSales * 100
      const rounded =
        cents(row.rawGrossSales)

      return {
        row,
        cents: rounded,
        residual:
          rawCents - rounded,
      }
    },
  )

  const target =
    cents(
      rows.reduce(
        (sum, row) =>
          sum + row.rawGrossSales,
        0,
      ),
    )

  const initial =
    allocations.reduce(
      (sum, item) =>
        sum + item.cents,
      0,
    )

  const originalAdjustment =
    target - initial

  let remaining =
    originalAdjustment

  if (remaining !== 0) {
    const direction =
      remaining > 0 ? 1 : -1

    const candidates = [
      ...allocations,
    ].sort((a, b) => {
      if (
        a.residual !== b.residual
      ) {
        return direction > 0
          ? b.residual - a.residual
          : a.residual - b.residual
      }

      return (
        a.row.order -
        b.row.order
      )
    })

    let cursor = 0
    let guard = 0

    while (remaining !== 0) {
      const candidate =
        candidates[
          cursor %
            candidates.length
        ]

      if (
        direction > 0 ||
        candidate.cents > 0
      ) {
        candidate.cents +=
          direction
        remaining -= direction
      }

      cursor += 1
      guard += 1

      if (guard > 100_000) {
        throw new Error(
          'NarPOS kuruş mutabakatı tamamlanamadı.',
        )
      }
    }
  }

  const finalTotal =
    allocations.reduce(
      (sum, item) =>
        sum + item.cents,
      0,
    )

  if (finalTotal !== target) {
    throw new Error(
      'NarPOS satış toplamı kuruş bazında mutabık değil.',
    )
  }

  return {
    allocations,
    targetCents: target,
    roundingAdjustmentCents:
      originalAdjustment,
  }
}

async function sha256(
  value: string,
) {
  const digest =
    await crypto.subtle.digest(
      'SHA-256',
      new TextEncoder().encode(value),
    )

  return Array.from(
    new Uint8Array(digest),
    (part) =>
      part
        .toString(16)
        .padStart(2, '0'),
  ).join('')
}

export async function narposBatchKey(
  input: Omit<NarposGrossImport, 'externalBatchKey'>,
) {
  const canonical = {
    locationId: input.locationId,
    businessDate: input.businessDate,
    currencyCode: input.currencyCode,
    rows: [...input.rows].sort((a, b) =>
      a.externalProductId < b.externalProductId
        ? -1
        : a.externalProductId > b.externalProductId
          ? 1
          : 0
    ),
  }

  return `narpos-xlsx:${await sha256(JSON.stringify(canonical))}`
}

function businessDateFromFilename(
  filename: string,
) {
  const match =
    /(\d{4}-\d{2}-\d{2})_(\d{4}-\d{2}-\d{2})\.xlsx$/i.exec(
      filename.normalize('NFC'),
    )

  if (!match) {
    throw new Error(
      'NarPOS dosya adından tarih okunamadı. Tek günlük Ürün Satışları XLSX raporunu kullanın.',
    )
  }

  if (match[1] !== match[2]) {
    throw new Error(
      'NarPOS aktarımında yalnızca tek günlük Ürün Satışları raporu kullanılabilir.',
    )
  }

  return match[1]
}

function findWorksheet(
  files: Record<string, Uint8Array>,
) {
  const direct =
    files[
      'xl/worksheets/sheet1.xml'
    ]

  if (direct) return direct

  const key =
    Object.keys(files)
      .filter((name) =>
        /^xl\/worksheets\/sheet\d+\.xml$/i.test(
          name,
        ),
      )
      .sort()[0]

  if (!key) {
    throw new Error(
      'NarPOS Excel çalışma sayfası bulunamadı.',
    )
  }

  return files[key]
}

export async function normalizeNarposProductSalesXlsx(
  input:
    | ArrayBuffer
    | Uint8Array,
  filename: string,
): Promise<NarposProductSalesImport> {
  const businessDate =
    businessDateFromFilename(
      filename,
    )

  let files:
    Record<string, Uint8Array>

  try {
    files = unzipSync(
      input instanceof Uint8Array
        ? input
        : new Uint8Array(input),
    )
  } catch {
    throw new Error(
      'NarPOS XLSX dosyası açılamadı.',
    )
  }

  const workbook =
    files['xl/workbook.xml']

  if (workbook) {
    const workbookXml =
      strFromU8(workbook)

    if (
      !workbookXml.includes(
        'Ürün Satışları',
      )
    ) {
      throw new Error(
        'Seçilen Excel dosyası NarPOS Ürün Satışları raporu değil.',
      )
    }
  }

  const sharedStrings =
    parseSharedStrings(
      files['xl/sharedStrings.xml']
        ? strFromU8(
            files[
              'xl/sharedStrings.xml'
            ],
          )
        : undefined,
    )

  const sheetRows =
    parseSheet(
      strFromU8(
        findWorksheet(files),
      ),
      sharedStrings,
    )

  if (sheetRows.length < 2) {
    throw new Error(
      'NarPOS Ürün Satışları raporunda veri satırı bulunamadı.',
    )
  }

  const headerRow =
    sheetRows[0]

  const headerColumns =
    new Map<string, string>()

  for (
    const [column, value]
    of Object.entries(headerRow)
  ) {
    headerColumns.set(
      normalizeText(value),
      column,
    )
  }

  for (
    const header of
    REQUIRED_HEADERS
  ) {
    if (
      !headerColumns.has(header)
    ) {
      throw new Error(
        `NarPOS raporunda "${header}" kolonu bulunamadı.`,
      )
    }
  }

  const groupColumn =
    headerColumns.get(
      'Grup İsmi',
    )!
  const productColumn =
    headerColumns.get(
      'Ürün İsmi',
    )!
  const portionColumn =
    headerColumns.get(
      'Porsiyon İsmi',
    )!
  const quantityColumn =
    headerColumns.get(
      'Toplam Adet',
    )!
  const amountColumn =
    headerColumns.get(
      'Toplam Tutar',
    )!

  const rawRows:
    RawNarposRow[] = []

  for (
    let index = 1;
    index < sheetRows.length;
    index += 1
  ) {
    const row =
      sheetRows[index]

    const values = [
      row[groupColumn],
      row[productColumn],
      row[portionColumn],
      row[quantityColumn],
      row[amountColumn],
    ]

    if (
      values.every(
        (value) =>
          !normalizeText(
            value ?? '',
          ),
      )
    ) {
      continue
    }

    const rowNumber =
      index + 1

    const groupName =
      normalizeText(
        row[groupColumn] ?? '',
      )
    const productName =
      normalizeText(
        row[productColumn] ?? '',
      )
    const portionName =
      normalizeText(
        row[portionColumn] ?? '',
      )

    if (
      !groupName ||
      !productName ||
      !portionName
    ) {
      throw new Error(
        `NarPOS satır ${rowNumber}: grup, ürün ve porsiyon bilgileri zorunludur.`,
      )
    }

    const quantity =
      parseNonNegativeNumber(
        row[quantityColumn] ?? '',
        'Toplam Adet',
        rowNumber,
      )

    quantityUnits(
      quantity,
      rowNumber,
    )

    const rawGrossSales =
      parseNonNegativeNumber(
        row[amountColumn] ?? '',
        'Toplam Tutar',
        rowNumber,
      )

    if (
      quantity === 0 &&
      rawGrossSales !== 0
    ) {
      throw new Error(
        `NarPOS satır ${rowNumber}: sıfır adetli satırda satış tutarı olamaz.`,
      )
    }

    rawRows.push({
      groupName,
      productName,
      portionName,
      quantity,
      rawGrossSales,
    })
  }

  if (
    !rawRows.length ||
    rawRows.length > 5000
  ) {
    throw new Error(
      'NarPOS raporu 1–5000 satış satırı içermelidir.',
    )
  }

  const grouped =
    new Map<
      string,
      GroupedNarposRow
    >()

  for (
    const [
      index,
      row,
    ] of rawRows.entries()
  ) {
    const identityKey = [
      identityText(
        row.groupName,
      ),
      identityText(
        row.productName,
      ),
      identityText(
        row.portionName,
      ),
    ].join('\u001f')

    const existing =
      grouped.get(identityKey)

    if (existing) {
      existing.quantity =
        Math.round(
          (
            existing.quantity +
            row.quantity
          ) * 10_000,
        ) / 10_000

      existing.rawGrossSales +=
        row.rawGrossSales

      continue
    }

    grouped.set(
      identityKey,
      {
        ...row,
        identityKey,
        order: index,
      },
    )
  }

  const groupedRows =
    [...grouped.values()]

  const {
    allocations,
    targetCents,
    roundingAdjustmentCents,
  } = reconcileCents(
    groupedRows,
  )

  const rows:
    NarposGrossSalesRow[] = []

  for (
    const item of allocations
  ) {
    const hash =
      await sha256(
        item.row.identityKey,
      )

    const displayName =
      [
        item.row.groupName,
        item.row.productName,
        item.row.portionName,
      ]
        .join(' / ')
        .slice(0, 200)

    rows.push({
      externalProductId:
        `NARPOS:${hash}`,
      externalProductCode:
        null,
      externalProductName:
        displayName,
      quantity:
        item.row.quantity,
      grossSales:
        item.cents / 100,
    })
  }

  const quantityTotal =
    Math.round(
      groupedRows.reduce(
        (sum, row) =>
          sum +
          quantityUnits(
            row.quantity,
            row.order + 2,
          ),
        0,
      ),
    ) / 10_000

  const rawSalesTotal =
    groupedRows.reduce(
      (sum, row) =>
        sum +
        row.rawGrossSales,
      0,
    )

  return {
    provider: 'NARPOS',
    source:
      'PRODUCT_SALES_XLSX',
    businessDate,
    currencyCode: 'TRY',
    rows,
    quantityTotal,
    grossSalesTotal:
      targetCents / 100,
    rawSalesTotal:
      Number(
        rawSalesTotal.toFixed(8),
      ),
    roundingAdjustmentCents,
  }
}
