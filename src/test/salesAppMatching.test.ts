import {
  describe,
  expect,
  it,
} from 'vitest'
import {
  suggestSalesAppMapping,
} from '../modules/costing/model/salesAppMatching'
import type {
  SalesAppMapping,
  SalesAppOverview,
} from '../modules/costing/model/salesApp'

function mapping(
  name: string,
): SalesAppMapping {
  return {
    id:
      'c1111111-aaaa-4aaa-8aaa-111111111111',
    externalProductId:
      'NARPOS:test',
    externalProductCode:
      null,
    externalProductName:
      name,
    locationId:
      'c1111111-bbbb-4bbb-8bbb-111111111111',
    locationName:
      'Nazilli',
    status:
      'UNMAPPED',
    menuProductId:
      null,
    menuProductName:
      null,
  }
}

const menu = (
  values: Array<
    [
      string,
      string,
    ]
  >,
): SalesAppOverview['menuProducts'] =>
  values.map(
    ([id, name]) => ({
      id,
      name,
      currencyCode: 'TRY',
    }),
  )

describe(
  'Sales App smart matching',
  () => {
    it(
      'gives high confidence to the same Turkish product name',
      () => {
        const suggestion =
          suggestSalesAppMapping(
            mapping(
              'ANA YEMEKLER / DANA BONFİLE / Normal',
            ),
            menu([
              [
                'c1111111-1111-4111-8111-111111111111',
                'Dana Bonfile',
              ],
              [
                'c1111111-2222-4222-8222-111111111111',
                'Antrikot Izgara',
              ],
            ]),
          )

        expect(
          suggestion?.menuProductName,
        ).toBe(
          'Dana Bonfile',
        )

        expect(
          suggestion?.confidence,
        ).toBe('HIGH')

        expect(
          suggestion?.score,
        ).toBe(100)
      },
    )

    it(
      'uses portion information for non-normal NarPOS portions',
      () => {
        const suggestion =
          suggestSalesAppMapping(
            mapping(
              'RAKILAR / TEKİRDAĞ ALTIN SERİ / 100CL',
            ),
            menu([
              [
                'c1111111-1111-4111-8111-111111111111',
                'Tekirdağ Altın Seri 35 CL',
              ],
              [
                'c1111111-2222-4222-8222-111111111111',
                'Tekirdağ Altın Seri 100 CL',
              ],
            ]),
          )

        expect(
          suggestion?.menuProductName,
        ).toBe(
          'Tekirdağ Altın Seri 100 CL',
        )

        expect(
          suggestion?.confidence,
        ).toBe('HIGH')
      },
    )

    it(
      'does not mark a base-name match high when NarPOS has a meaningful portion',
      () => {
        const suggestion =
          suggestSalesAppMapping(
            mapping(
              'RAKILAR / BEYLERBEYİ GÖBEK / 50CL',
            ),
            menu([
              [
                'c1111111-1111-4111-8111-111111111111',
                'Beylerbeyi Göbek',
              ],
            ]),
          )

        expect(
          suggestion?.menuProductName,
        ).toBe(
          'Beylerbeyi Göbek',
        )

        expect(
          suggestion?.confidence,
        ).toBe('MEDIUM')
      },
    )

    it(
      'returns no suggestion for unrelated names',
      () => {
        const suggestion =
          suggestSalesAppMapping(
            mapping(
              'TATLILAR / KESME DONDURMA / Normal',
            ),
            menu([
              [
                'c1111111-1111-4111-8111-111111111111',
                'Dana Bonfile',
              ],
            ]),
          )

        expect(
          suggestion,
        ).toBeNull()
      },
    )
  },
)
