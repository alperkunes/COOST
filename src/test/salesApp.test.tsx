import { cleanup, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import {
  mappingLabels,
  normalizeSalesAppCsv,
  salesAppPreview,
  salesAppRowSchema,
  salesSourceLabel,
  type SalesAppImport,
  type SalesAppOverview,
} from '../modules/costing/model/salesApp'
import {
  useImportNarposSalesApp,
  useImportSalesApp,
  useReprocessSalesApp,
} from '../modules/costing/mutations/useSalesAppCommands'
import {
  MappingDialog,
  SalesAppPanel,
} from '../modules/costing/pages/SalesAppPanel'
import type { NarposGrossImport } from '../modules/costing/model/narpos'

const { rpc, tenant } = vi.hoisted(() => ({
  rpc: vi.fn(),
  tenant: {
    tenantId: 'a1111111-aaaa-4aaa-8aaa-111111111111',
  },
}))

vi.mock('../shared/supabase/client', () => ({
  supabase: { rpc },
}))

vi.mock('../shared/tenant/useTenant', () => ({
  useTenant: () => tenant,
}))

const locationId = 'a1111111-bbbb-4bbb-8bbb-111111111111'
const productId = 'a1111111-cccc-4ccc-8ccc-111111111111'
const secondProductId = 'a1111111-dddd-4ddd-8ddd-111111111111'
const mappingId = 'a1111111-eeee-4eee-8eee-111111111111'
const secondMappingId = 'a1111111-ffff-4fff-8fff-111111111111'
const batchId = 'a1111111-1111-4111-8111-222222222222'

const overview: SalesAppOverview = {
  tenantId: tenant.tenantId,
  providerKey: 'SALES_APP',
  summary: {
    mappedProductCount: 1,
    unmappedProductCount: 0,
    ignoredProductCount: 1,
    lastImportAt: '2026-09-27T17:00:00.000Z',
    lastImportBusinessDate: '2026-09-27',
  },
  locations: [
    {
      id: locationId,
      name: 'Nazilli',
    },
  ],
  menuProducts: [
    {
      id: productId,
      name: 'Antrikot Menü',
      currencyCode: 'TRY',
    },
    {
      id: secondProductId,
      name: 'Euro Menü',
      currencyCode: 'EUR',
    },
  ],
  mappings: [
    {
      id: mappingId,
      externalProductId: 'EXT-1',
      externalProductCode: 'A-1',
      externalProductName: 'Harici Antrikot',
      locationId,
      locationName: 'Nazilli',
      status: 'MAPPED',
      menuProductId: productId,
      menuProductName: 'Antrikot Menü',
    },
    {
      id: secondMappingId,
      externalProductId: 'EXT-2',
      externalProductCode: null,
      externalProductName: 'Servis Ücreti',
      locationId: null,
      locationName: null,
      status: 'IGNORED',
      menuProductId: null,
      menuProductName: null,
    },
  ],
  recentImports: [
    {
      id: batchId,
      businessDate: '2026-09-27',
      locationId,
      location: 'Nazilli',
      currencyCode: 'TRY',
      externalBatchKey: 'csv:test',
      status: 'COMPLETED',
      rowCount: 2,
      mappedRowCount: 1,
      unmappedRowCount: 0,
      importedAt: '2026-09-27T17:00:00.000Z',
      canReprocess: true,
    },
  ],
}

function createClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  })
}

function renderWithClient(node: React.ReactNode) {
  const client = createClient()
  const invalidate = vi.spyOn(client, 'invalidateQueries')

  render(
    <QueryClientProvider client={client}>
      {node}
    </QueryClientProvider>,
  )

  return {
    client,
    invalidate,
    user: userEvent.setup(),
  }
}

function ImportHarness({ input }: { input: SalesAppImport }) {
  const mutation = useImportSalesApp()

  return (
    <button
      type="button"
      onClick={() => mutation.mutate(input)}
    >
      Import
    </button>
  )
}

function NarposImportHarness({
  input,
}: {
  input: NarposGrossImport
}) {
  const mutation =
    useImportNarposSalesApp()

  return (
    <button
      type="button"
      onClick={() =>
        mutation.mutate(input)
      }
    >
      Import NarPOS
    </button>
  )
}

function ReprocessHarness() {
  const mutation = useReprocessSalesApp()

  return (
    <button
      type="button"
      onClick={() => mutation.mutate(batchId)}
    >
      Reprocess
    </button>
  )
}

beforeEach(() => {
  rpc.mockReset()

  rpc.mockImplementation(async (name: string) => {
    if (name === 'get_sales_app_integration_overview') {
      return {
        data: overview,
        error: null,
      }
    }

    if (name === 'get_sales_app_sync_overview') {
      return {
        data: {
          tenantId: tenant.tenantId,
          providerKey: 'SALES_APP',
          locations: [
            {
              id: locationId,
              name: 'Nazilli',
            },
          ],
          connections: [],
          recentRuns: [],
        },
        error: null,
      }
    }

    return {
      data: batchId,
      error: null,
    }
  })
})

afterEach(cleanup)

describe('sales app CSV normalization', () => {
  it('normalizes a valid CSV', () => {
    const csv = [
      'product_id,product_code,product_name,quantity,gross_sales,net_sales,currency',
      'EXT-1,A-1,Harici Antrikot,2.5,1100.00,1000.00,TRY',
      'EXT-2,,Servis Ücreti,1,100.00,90.00,TRY',
    ].join('\n')

    const result = normalizeSalesAppCsv(csv)

    expect(result.currencyCode).toBe('TRY')
    expect(result.rows).toHaveLength(2)
    expect(result.rows[0]).toEqual({
      externalProductId: 'EXT-1',
      externalProductCode: 'A-1',
      externalProductName: 'Harici Antrikot',
      quantity: 2.5,
      grossSales: 1100,
      netSales: 1000,
    })
  })

  it('rejects duplicate external product ids', () => {
    const csv = [
      'product_id,product_code,product_name,quantity,gross_sales,net_sales,currency',
      'EXT-1,A-1,Ürün 1,1,100,90,TRY',
      'EXT-1,A-2,Ürün 2,1,100,90,TRY',
    ].join('\n')

    expect(() => normalizeSalesAppCsv(csv))
      .toThrow(/Yinelenen harici ürün kimliği/)
  })

  it('rejects mixed currencies', () => {
    const csv = [
      'product_id,product_code,product_name,quantity,gross_sales,net_sales,currency',
      'EXT-1,A-1,Ürün 1,1,100,90,TRY',
      'EXT-2,A-2,Ürün 2,1,100,90,EUR',
    ].join('\n')

    expect(() => normalizeSalesAppCsv(csv))
      .toThrow(/tek bir geçerli para birimi/)
  })

  it('rejects zero quantity with positive sales', () => {
    expect(
      salesAppRowSchema.safeParse({
        externalProductId: 'EXT-1',
        externalProductCode: null,
        externalProductName: 'Ürün',
        quantity: 0,
        grossSales: 100,
        netSales: 90,
      }).success,
    ).toBe(false)
  })
})

describe('sales app mapping preview', () => {
  it('resolves mapped, ignored and unmapped rows', () => {
    const result = salesAppPreview(
      [
        {
          externalProductId: 'EXT-1',
          externalProductCode: 'A-1',
          externalProductName: 'Harici Antrikot',
          quantity: 1,
          grossSales: 110,
          netSales: 100,
        },
        {
          externalProductId: 'EXT-2',
          externalProductCode: null,
          externalProductName: 'Servis Ücreti',
          quantity: 1,
          grossSales: 10,
          netSales: 9,
        },
        {
          externalProductId: 'EXT-3',
          externalProductCode: null,
          externalProductName: 'Yeni Ürün',
          quantity: 1,
          grossSales: 55,
          netSales: 50,
        },
      ],
      overview.mappings,
      locationId,
    )

    expect(result.counts).toEqual({
      MAPPED: 1,
      UNMAPPED: 1,
      IGNORED: 1,
    })

    expect(result.rows[0].menuProductId).toBe(productId)
    expect(result.rows[1].status).toBe('IGNORED')
    expect(result.rows[2].status).toBe('UNMAPPED')
  })

  it('uses user-facing generic sales app labels', () => {
    expect(mappingLabels.MAPPED).toBe('Eşleştirildi')
    expect(salesSourceLabel('MANUAL')).toBe('Manuel')
    expect(salesSourceLabel('SALES_APP')).toBe('Satış Uygulaması')
    expect(salesSourceLabel('IMPORT')).toBe('İçe Aktarım')
  })
})

describe('sales app panel', () => {
  it('shows overview but hides write actions for read-only users', async () => {
    renderWithClient(
      <SalesAppPanel
        canWrite={false}
        onClose={vi.fn()}
      />,
    )

    expect(
      await screen.findByRole('heading', {
        name: 'Satış Uygulaması',
      }),
    ).toBeInTheDocument()

    expect(await screen.findByText('Harici Antrikot')).toBeInTheDocument()

    expect(
      screen.queryByRole('button', {
        name: /Satış Dosyası \/ Veri İçe Aktar/,
      }),
    ).not.toBeInTheDocument()

    expect(
      screen.queryByRole('button', {
        name: /NarPOS Excel İçe Aktar/,
      }),
    ).not.toBeInTheDocument()

    expect(
      screen.queryByRole('button', {
        name: /NarPOS Toplu Eşleştir/,
      }),
    ).not.toBeInTheDocument()

    expect(
      screen.queryByRole('button', {
        name: /^Harici Antrikot eşleştir$/ ,
      }),
    ).not.toBeInTheDocument()
  })

  it('shows import and mapping controls for writers', async () => {
    renderWithClient(
      <SalesAppPanel
        canWrite
        onClose={vi.fn()}
      />,
    )

    expect(
      await screen.findByRole('button', {
        name: /Satış Dosyası \/ Veri İçe Aktar/,
      }),
    ).toBeInTheDocument()

    expect(
      screen.getByRole('button', {
        name: /NarPOS Excel İçe Aktar/,
      }),
    ).toBeInTheDocument()

    expect(
      screen.getByRole('button', {
        name: /^Harici Antrikot eşleştir$/ ,
      }),
    ).toBeInTheDocument()
  })
})

describe('sales app commands', () => {
  it('updates a product mapping through the RPC', async () => {
    const close = vi.fn()

    const { user } = renderWithClient(
      <MappingDialog
        data={overview}
        mapping={overview.mappings[0]}
        status="MAPPED"
        onClose={close}
      />,
    )

    await user.selectOptions(
      screen.getByLabelText('COOST Menü Ürünü'),
      productId,
    )

    await user.click(
      screen.getByRole('button', {
        name: 'Onayla',
      }),
    )

    await waitFor(() => {
      expect(close).toHaveBeenCalledOnce()
    })

    expect(rpc).toHaveBeenCalledWith(
      'update_sales_app_product_mapping',
      {
        p_tenant_id: tenant.tenantId,
        p_mapping_id: mappingId,
        p_status: 'MAPPED',
        p_menu_product_id: productId,
      },
    )
  })

  it('imports normalized daily sales and invalidates dependent models', async () => {
    const input: SalesAppImport = {
      locationId,
      businessDate: '2026-09-27',
      externalBatchKey: 'csv:test',
      currencyCode: 'TRY',
      rows: [
        {
          externalProductId: 'EXT-1',
          externalProductCode: 'A-1',
          externalProductName: 'Harici Antrikot',
          quantity: 10,
          grossSales: 1100,
          netSales: 1000,
        },
      ],
    }

    const { user, invalidate } = renderWithClient(
      <ImportHarness input={input} />,
    )

    await user.click(
      screen.getByRole('button', {
        name: 'Import',
      }),
    )

    await waitFor(() => {
      expect(rpc).toHaveBeenCalledWith(
        'import_sales_app_daily_sales',
        {
          p_tenant_id: tenant.tenantId,
          p_location_id: locationId,
          p_business_date: '2026-09-27',
          p_external_batch_key: 'csv:test',
          p_currency_code: 'TRY',
          p_rows: input.rows,
        },
      )
    })

    expect(invalidate).toHaveBeenCalledWith({
      queryKey: ['sales-app', tenant.tenantId],
    })

    expect(invalidate).toHaveBeenCalledWith({
      queryKey: ['operating-data', tenant.tenantId],
    })

    expect(invalidate).toHaveBeenCalledWith({
      queryKey: ['operating-profitability', tenant.tenantId],
    })
  })

  it('imports NarPOS gross sales through the tax-inclusive RPC', async () => {
    const input: NarposGrossImport = {
      locationId,
      businessDate: '2026-09-29',
      externalBatchKey: 'narpos-xlsx:test',
      currencyCode: 'TRY',
      rows: [
        {
          externalProductId: 'NARPOS:test',
          externalProductCode: null,
          externalProductName: 'ANA YEMEKLER / ET TADIM TABAĞI / Normal',
          quantity: 3,
          grossSales: 5981.11,
        },
      ],
    }

    const { user, invalidate } =
      renderWithClient(
        <NarposImportHarness
          input={input}
        />,
      )

    await user.click(
      screen.getByRole(
        'button',
        {
          name: 'Import NarPOS',
        },
      ),
    )

    await waitFor(() => {
      expect(rpc).toHaveBeenCalledWith(
        'import_sales_app_daily_gross_sales',
        {
          p_tenant_id:
            tenant.tenantId,
          p_location_id:
            locationId,
          p_business_date:
            '2026-09-29',
          p_external_batch_key:
            'narpos-xlsx:test',
          p_currency_code:
            'TRY',
          p_rows: input.rows,
        },
      )
    })

    expect(
      invalidate,
    ).toHaveBeenCalledWith({
      queryKey: [
        'sales-app',
        tenant.tenantId,
      ],
    })
  })

  it('reprocesses an existing import batch', async () => {
    const { user } = renderWithClient(<ReprocessHarness />)

    await user.click(
      screen.getByRole('button', {
        name: 'Reprocess',
      }),
    )

    await waitFor(() => {
      expect(rpc).toHaveBeenCalledWith(
        'reprocess_sales_app_import_batch',
        {
          p_tenant_id: tenant.tenantId,
          p_batch_id: batchId,
        },
      )
    })
  })
})