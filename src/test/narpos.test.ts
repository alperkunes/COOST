import {
  strToU8,
  zipSync,
} from 'fflate'
import {
  describe,
  expect,
  it,
} from 'vitest'
import {
  normalizeNarposProductSalesXlsx,
} from '../modules/costing/model/narpos'

function workbook(
  dataRows: Array<
    [
      string,
      string,
      string,
      string,
      string,
    ]
  >,
) {
  const strings = [
    'Grup İsmi',
    'Ürün İsmi',
    'Porsiyon İsmi',
    'Toplam Adet',
    'Toplam Tutar',
  ]

  const shared = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    ...strings.map(
      (value) =>
        `<si><t>${value}</t></si>`,
    ),
    '</sst>',
  ].join('')

  const header = [
    '<c r="A1" t="s"><v>0</v></c>',
    '<c r="B1" t="s"><v>1</v></c>',
    '<c r="C1" t="s"><v>2</v></c>',
    '<c r="D1" t="s"><v>3</v></c>',
    '<c r="E1" t="s"><v>4</v></c>',
  ].join('')

  const body =
    dataRows
      .map(
        (
          [
            group,
            product,
            portion,
            quantity,
            amount,
          ],
          index,
        ) => {
          const row =
            index + 2

          return [
            `<row r="${row}">`,
            `<c r="A${row}" t="inlineStr"><is><t>${group}</t></is></c>`,
            `<c r="B${row}" t="inlineStr"><is><t>${product}</t></is></c>`,
            `<c r="C${row}" t="inlineStr"><is><t>${portion}</t></is></c>`,
            `<c r="D${row}"><v>${quantity}</v></c>`,
            `<c r="E${row}"><v>${amount}</v></c>`,
            '</row>',
          ].join('')
        },
      )
      .join('')

  const sheet = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    '<sheetData>',
    `<row r="1">${header}</row>`,
    body,
    '</sheetData>',
    '</worksheet>',
  ].join('')

  const book = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    '<sheets>',
    '<sheet name="Ürün Satışları" sheetId="1"/>',
    '</sheets>',
    '</workbook>',
  ].join('')

  return zipSync({
    'xl/workbook.xml':
      strToU8(book),
    'xl/sharedStrings.xml':
      strToU8(shared),
    'xl/worksheets/sheet1.xml':
      strToU8(sheet),
  })
}

describe(
  'NarPOS product sales XLSX',
  () => {
    it(
      'reads the NarPOS columns and preserves zero-value quantity rows',
      async () => {
        const file = workbook([
          [
            'ANA YEMEKLER',
            'ET TADIM TABAĞI',
            'Normal',
            '3',
            '5981.11397902',
          ],
          [
            'BAŞLANGIÇLAR',
            'Başlangıç',
            'Normal',
            '11',
            '0',
          ],
        ])

        const result =
          await normalizeNarposProductSalesXlsx(
            file,
            'Urun_Satislari_2026-09-29_2026-09-29.xlsx',
          )

        expect(
          result.businessDate,
        ).toBe('2026-09-29')

        expect(
          result.currencyCode,
        ).toBe('TRY')

        expect(
          result.quantityTotal,
        ).toBe(14)

        expect(
          result.rows,
        ).toHaveLength(2)

        expect(
          result.rows[1].quantity,
        ).toBe(11)

        expect(
          result.rows[1].grossSales,
        ).toBe(0)

        expect(
          result.rows[0].externalProductId,
        ).toMatch(
          /^NARPOS:[0-9a-f]{64}$/,
        )
      },
    )

    it(
      'reconciles row rounding without changing the daily gross total',
      async () => {
        const file = workbook([
          [
            'GRUP',
            'ÜRÜN 1',
            'Normal',
            '1',
            '10.004',
          ],
          [
            'GRUP',
            'ÜRÜN 2',
            'Normal',
            '1',
            '10.004',
          ],
          [
            'GRUP',
            'ÜRÜN 3',
            'Normal',
            '1',
            '10.004',
          ],
          [
            'GRUP',
            'ÜRÜN 4',
            'Normal',
            '1',
            '10.004',
          ],
          [
            'GRUP',
            'ÜRÜN 5',
            'Normal',
            '1',
            '10.004',
          ],
        ])

        const result =
          await normalizeNarposProductSalesXlsx(
            file,
            'Urun_Satislari_2026-09-29_2026-09-29.xlsx',
          )

        expect(
          result.rawSalesTotal,
        ).toBe(50.02)

        expect(
          result.grossSalesTotal,
        ).toBe(50.02)

        expect(
          result.roundingAdjustmentCents,
        ).toBe(2)

        expect(
          result.rows.reduce(
            (sum, row) =>
              sum +
              Math.round(
                row.grossSales *
                  100,
              ),
            0,
          ),
        ).toBe(5002)
      },
    )

    it(
      'keeps the external identity stable for the same group, product and portion',
      async () => {
        const file = workbook([
          [
            'KIRMIZI ŞARAP',
            'MAHREM KIRMIZI',
            'Normal',
            '3',
            '6748.53949708',
          ],
        ])

        const first =
          await normalizeNarposProductSalesXlsx(
            file,
            'Urun_Satislari_2026-09-29_2026-09-29.xlsx',
          )

        const second =
          await normalizeNarposProductSalesXlsx(
            file,
            'Urun_Satislari_2026-09-29_2026-09-29.xlsx',
          )

        expect(
          first.rows[0]
            .externalProductId,
        ).toBe(
          second.rows[0]
            .externalProductId,
        )
      },
    )

    it(
      'combines duplicate NarPOS group-product-portion rows before import',
      async () => {
        const file = workbook([
          [
            'TATLILAR',
            'KARPUZ-KAVUN',
            'Normal',
            '2',
            '500.001',
          ],
          [
            'TATLILAR',
            'KARPUZ-KAVUN',
            'Normal',
            '1.5',
            '349.93756847',
          ],
        ])

        const result =
          await normalizeNarposProductSalesXlsx(
            file,
            'Urun_Satislari_2026-09-29_2026-09-29.xlsx',
          )

        expect(
          result.rows,
        ).toHaveLength(1)

        expect(
          result.rows[0].quantity,
        ).toBe(3.5)

        expect(
          result.grossSalesTotal,
        ).toBe(849.94)
      },
    )

    it(
      'rejects a multi-day NarPOS report',
      async () => {
        const file = workbook([
          [
            'GRUP',
            'ÜRÜN',
            'Normal',
            '1',
            '100',
          ],
        ])

        await expect(
          normalizeNarposProductSalesXlsx(
            file,
            'Urun_Satislari_2026-09-28_2026-09-29.xlsx',
          ),
        ).rejects.toThrow(
          /yalnızca tek günlük/,
        )
      },
    )
  },
)
