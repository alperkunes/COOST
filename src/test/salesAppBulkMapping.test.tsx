import {
  QueryClient,
  QueryClientProvider,
} from '@tanstack/react-query'
import {
  cleanup,
  render,
  screen,
  waitFor,
} from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  vi,
} from 'vitest'
import type {
  SalesAppOverview,
} from '../modules/costing/model/salesApp'
import {
  SalesAppBulkMappingDialog,
} from '../modules/costing/pages/SalesAppBulkMappingDialog'

const {
  rpc,
  tenant,
} = vi.hoisted(() => ({
  rpc: vi.fn(),
  tenant: {
    tenantId:
      'b1111111-aaaa-4aaa-8aaa-111111111111',
  },
}))

vi.mock(
  '../shared/supabase/client',
  () => ({
    supabase: { rpc },
  }),
)

vi.mock(
  '../shared/tenant/useTenant',
  () => ({
    useTenant: () => tenant,
  }),
)

const locationId =
  'b1111111-bbbb-4bbb-8bbb-111111111111'

const productA =
  'b1111111-cccc-4ccc-8ccc-111111111111'

const productB =
  'b1111111-dddd-4ddd-8ddd-111111111111'

const mappingA =
  'b1111111-eeee-4eee-8eee-111111111111'

const mappingB =
  'b1111111-ffff-4fff-8fff-111111111111'

const overview:
  SalesAppOverview = {
    tenantId:
      tenant.tenantId,
    providerKey:
      'SALES_APP',
    summary: {
      mappedProductCount: 0,
      unmappedProductCount: 2,
      ignoredProductCount: 0,
      lastImportAt: null,
      lastImportBusinessDate:
        null,
    },
    locations: [
      {
        id: locationId,
        name: 'Nazilli',
      },
    ],
    menuProducts: [
      {
        id: productA,
        name: 'Et Tadım Tabağı',
        currencyCode: 'TRY',
      },
      {
        id: productB,
        name: 'Euro Ürün',
        currencyCode: 'EUR',
      },
    ],
    mappings: [
      {
        id: mappingA,
        externalProductId:
          'NARPOS:aaaaaaaa',
        externalProductCode:
          null,
        externalProductName:
          'ANA YEMEKLER / ET TADIM TABAĞI / Normal',
        locationId,
        locationName:
          'Nazilli',
        status: 'UNMAPPED',
        menuProductId: null,
        menuProductName: null,
      },
      {
        id: mappingB,
        externalProductId:
          'NARPOS:bbbbbbbb',
        externalProductCode:
          null,
        externalProductName:
          'BAŞLANGIÇLAR / Başlangıç / Normal',
        locationId,
        locationName:
          'Nazilli',
        status: 'UNMAPPED',
        menuProductId: null,
        menuProductName: null,
      },
      {
        id:
          'b1111111-1212-4121-8121-111111111111',
        externalProductId:
          'OTHER-1',
        externalProductCode:
          null,
        externalProductName:
          'Other Provider Product',
        locationId,
        locationName:
          'Nazilli',
        status: 'UNMAPPED',
        menuProductId: null,
        menuProductName: null,
      },
    ],
    recentImports: [],
  }

function renderDialog() {
  const client =
    new QueryClient({
      defaultOptions: {
        queries: {
          retry: false,
        },
        mutations: {
          retry: false,
        },
      },
    })

  render(
    <QueryClientProvider
      client={client}
    >
      <SalesAppBulkMappingDialog
        data={overview}
        onClose={vi.fn()}
      />
    </QueryClientProvider>,
  )

  return userEvent.setup()
}

beforeEach(() => {
  rpc.mockReset()

  rpc.mockResolvedValue({
    data: {
      mappingCount: 1,
    },
    error: null,
  })
})

afterEach(cleanup)

describe(
  'Sales App bulk mapping dialog',
  () => {
    it(
      'shows only NarPOS mappings',
      () => {
        renderDialog()

        expect(
          screen.getByText(
            'ET TADIM TABAĞI',
          ),
        ).toBeInTheDocument()

        expect(
          screen.getByText(
            'Başlangıç',
          ),
        ).toBeInTheDocument()

        expect(
          screen.queryByText(
            'Other Provider Product',
          ),
        ).not.toBeInTheDocument()
      },
    )

    it(
      'preselects a high-confidence exact NarPOS match without saving it',
      () => {
        renderDialog()

        const select =
          screen.getByLabelText(
            'ANA YEMEKLER / ET TADIM TABAĞI / Normal COOST eşleştirmesi',
          ) as HTMLSelectElement

        expect(
          select.value,
        ).toBe(productA)

        expect(
          screen.getByText(
            /Yüksek güven/,
          ),
        ).toBeInTheDocument()

        expect(
          rpc,
        ).not.toHaveBeenCalled()
      },
    )

    it(
      'sends changed mappings through one bulk RPC',
      async () => {
        const user =
          renderDialog()

        await user.selectOptions(
          screen.getByLabelText(
            'ANA YEMEKLER / ET TADIM TABAĞI / Normal COOST eşleştirmesi',
          ),
          productA,
        )

        await user.click(
          screen.getByRole(
            'button',
            {
              name:
                '1 Değişikliği Kaydet',
            },
          ),
        )

        await waitFor(() => {
          expect(
            rpc,
          ).toHaveBeenCalledWith(
            'bulk_update_sales_app_product_mappings',
            {
              p_tenant_id:
                tenant.tenantId,
              p_updates: [
                {
                  mappingId:
                    mappingA,
                  status:
                    'MAPPED',
                  menuProductId:
                    productA,
                },
              ],
            },
          )
        })
      },
    )

    it(
      'supports marking a NarPOS row as ignored',
      async () => {
        const user =
          renderDialog()

        await user.selectOptions(
          screen.getByLabelText(
            'BAŞLANGIÇLAR / Başlangıç / Normal COOST eşleştirmesi',
          ),
          '__IGNORED__',
        )

        await user.click(
          screen.getByRole(
            'button',
            {
              name:
                '2 Değişikliği Kaydet',
            },
          ),
        )

        await waitFor(() => {
          expect(
            rpc,
          ).toHaveBeenCalledWith(
            'bulk_update_sales_app_product_mappings',
            {
              p_tenant_id:
                tenant.tenantId,
              p_updates: [
                {
                  mappingId:
                    mappingA,
                  status:
                    'MAPPED',
                  menuProductId:
                    productA,
                },
                {
                  mappingId:
                    mappingB,
                  status:
                    'IGNORED',
                  menuProductId:
                    null,
                },
              ],
            },
          )
        })
      },
    )
  },
)
