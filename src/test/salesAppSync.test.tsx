import {
  cleanup,
  render,
  screen,
  waitFor,
} from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import {
  QueryClient,
  QueryClientProvider,
} from '@tanstack/react-query'
import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  vi,
} from 'vitest'

import {
  salesAppConnectionUpdateSchema,
  salesAppSyncRequestSchema,
  type SalesAppSyncOverview,
} from '../modules/costing/model/salesAppSync'
import {
  useRunSalesAppSync,
} from '../modules/costing/mutations/useSalesAppSyncCommands'
import {
  SalesAppSyncSection,
} from '../modules/costing/pages/SalesAppSyncSection'

const {
  rpc,
  invoke,
  tenant,
} = vi.hoisted(() => ({
  rpc: vi.fn(),
  invoke: vi.fn(),
  tenant: {
    tenantId:
      'a1111111-aaaa-4aaa-8aaa-111111111111',
  },
}))

vi.mock(
  '../shared/supabase/client',
  () => ({
    supabase: {
      rpc,
      functions: {
        invoke,
      },
    },
  }),
)

vi.mock(
  '../shared/tenant/useTenant',
  () => ({
    useTenant: () => tenant,
  }),
)

const locationId =
  'a1111111-bbbb-4bbb-8bbb-111111111111'

const connectionId =
  'a1111111-cccc-4ccc-8ccc-111111111111'

const runId =
  'a1111111-dddd-4ddd-8ddd-111111111111'

const baseOverview: SalesAppSyncOverview = {
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
}

let overview:
  SalesAppSyncOverview

function createClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
      mutations: {
        retry: false,
      },
    },
  })
}

function renderWithClient(
  node: React.ReactNode,
) {
  const client = createClient()

  const invalidate =
    vi.spyOn(
      client,
      'invalidateQueries',
    )

  render(
    <QueryClientProvider
      client={client}
    >
      {node}
    </QueryClientProvider>,
  )

  return {
    client,
    invalidate,
    user: userEvent.setup(),
  }
}

function RunSyncHarness() {
  const mutation =
    useRunSalesAppSync()

  return (
    <>
      <button
        type="button"
        onClick={() =>
          mutation.mutate({
            connectionId,
            businessDateStart:
              '2026-09-29',
            businessDateEnd:
              '2026-09-30',
          })
        }
      >
        Run Sync
      </button>

      {mutation.isSuccess ? (
        <span>Sync success</span>
      ) : null}

      {mutation.isError ? (
        <span role="alert">
          {mutation.error.message}
        </span>
      ) : null}
    </>
  )
}

beforeEach(() => {
  overview = {
    ...baseOverview,
    locations: [
      ...baseOverview.locations,
    ],
    connections: [],
    recentRuns: [],
  }

  rpc.mockReset()
  invoke.mockReset()

  rpc.mockImplementation(
    async (name: string) => {
      if (
        name ===
        'get_sales_app_sync_overview'
      ) {
        return {
          data: overview,
          error: null,
        }
      }

      if (
        name ===
        'create_sales_app_connection'
      ) {
        return {
          data: connectionId,
          error: null,
        }
      }

      if (
        name ===
        'update_sales_app_connection'
      ) {
        return {
          data: connectionId,
          error: null,
        }
      }

      return {
        data: null,
        error: null,
      }
    },
  )

  invoke.mockResolvedValue({
    data: {
      runId,
      status: 'SUCCEEDED',
      importBatchCount: 1,
      importedRowCount: 4,
    },
    error: null,
  })
})

afterEach(cleanup)

describe(
  'sales app sync validation',
  () => {
    it(
      'requires adapter and external location for active connections',
      () => {
        const result =
          salesAppConnectionUpdateSchema.safeParse(
            {
              connectionId,
              adapterKey: '',
              externalLocationId: '',
              status: 'ACTIVE',
              syncEnabled: false,
              syncLookbackDays: 1,
            },
          )

        expect(
          result.success,
        ).toBe(false)
      },
    )

    it(
      'rejects reversed and over-31-day sync periods',
      () => {
        expect(
          salesAppSyncRequestSchema.safeParse(
            {
              connectionId,
              businessDateStart:
                '2026-09-30',
              businessDateEnd:
                '2026-09-29',
            },
          ).success,
        ).toBe(false)

        expect(
          salesAppSyncRequestSchema.safeParse(
            {
              connectionId,
              businessDateStart:
                '2026-08-01',
              businessDateEnd:
                '2026-09-30',
            },
          ).success,
        ).toBe(false)
      },
    )
  },
)

describe(
  'sales app sync UI',
  () => {
    it(
      'shows connection and run history without write actions for read-only users',
      async () => {
        overview = {
          ...overview,

          connections: [
            {
              id: connectionId,
              locationId,
              locationName:
                'Nazilli',
              providerKey:
                'SALES_APP',
              adapterKey:
                'GENERIC_TEST',
              externalLocationId:
                'EXT-NAZILLI-01',
              status: 'ACTIVE',
              syncEnabled: false,
              syncLookbackDays: 1,
              createdAt:
                '2026-09-29T18:00:00.000Z',
              updatedAt:
                '2026-09-29T18:00:00.000Z',
            },
          ],

          recentRuns: [
            {
              id: runId,
              connectionId,
              locationId,
              locationName:
                'Nazilli',
              triggerType:
                'MANUAL',
              status:
                'SUCCEEDED',
              businessDateStart:
                '2026-09-29',
              businessDateEnd:
                '2026-09-29',
              startedAt:
                '2026-09-29T18:01:00.000Z',
              finishedAt:
                '2026-09-29T18:01:03.000Z',
              importBatchCount: 1,
              importedRowCount: 4,
              errorCode: null,
              errorMessage: null,
              createdAt:
                '2026-09-29T18:01:00.000Z',
            },
          ],
        }

        renderWithClient(
          <SalesAppSyncSection
            canWrite={false}
          />,
        )

        expect(
          await screen.findByText(
            'GENERIC_TEST',
          ),
        ).toBeInTheDocument()

        expect(
          screen.getByText(
            'Tamamlandı',
          ),
        ).toBeInTheDocument()

        expect(
          screen.queryByRole(
            'button',
            {
              name:
                /Yeni Bağlantı/,
            },
          ),
        ).not.toBeInTheDocument()

        expect(
          screen.queryByRole(
            'button',
            {
              name:
                /bağlantısını düzenle/,
            },
          ),
        ).not.toBeInTheDocument()

        expect(
          screen.queryByRole(
            'button',
            {
              name:
                /Şimdi Senkronize Et/,
            },
          ),
        ).not.toBeInTheDocument()
      },
    )

    it(
      'creates a draft connection through the RPC',
      async () => {
        const { user } =
          renderWithClient(
            <SalesAppSyncSection
              canWrite
            />,
          )

        await user.click(
          await screen.findByRole(
            'button',
            {
              name:
                /Yeni Bağlantı/,
            },
          ),
        )

        await user.selectOptions(
          screen.getByLabelText(
            'Lokasyon',
          ),
          locationId,
        )

        await user.click(
          screen.getByRole(
            'button',
            {
              name:
                /Bağlantı Oluştur/,
            },
          ),
        )

        await waitFor(() => {
          expect(
            rpc,
          ).toHaveBeenCalledWith(
            'create_sales_app_connection',
            {
              p_tenant_id:
                tenant.tenantId,
              p_location_id:
                locationId,
              p_adapter_key:
                undefined,
              p_external_location_id:
                undefined,
              p_sync_lookback_days:
                1,
            },
          )
        })
      },
    )
  },
)

describe(
  'sales app sync command',
  () => {
    it(
      'invokes the authenticated edge function and refreshes dependent models',
      async () => {
        const {
          user,
          invalidate,
        } = renderWithClient(
          <RunSyncHarness />,
        )

        await user.click(
          screen.getByRole(
            'button',
            {
              name:
                'Run Sync',
            },
          ),
        )

        expect(
          await screen.findByText(
            'Sync success',
          ),
        ).toBeInTheDocument()

        expect(
          invoke,
        ).toHaveBeenCalledWith(
          'sales-app-sync',
          {
            body: {
              tenantId:
                tenant.tenantId,
              connectionId,
              businessDateStart:
                '2026-09-29',
              businessDateEnd:
                '2026-09-30',
            },
          },
        )

        await waitFor(() => {
          expect(
            invalidate,
          ).toHaveBeenCalledWith({
            queryKey: [
              'sales-app-sync',
              tenant.tenantId,
            ],
          })
        })

        expect(
          invalidate,
        ).toHaveBeenCalledWith({
          queryKey: [
            'sales-app',
            tenant.tenantId,
          ],
        })

        expect(
          invalidate,
        ).toHaveBeenCalledWith({
          queryKey: [
            'operating-data',
            tenant.tenantId,
          ],
        })

        expect(
          invalidate,
        ).toHaveBeenCalledWith({
          queryKey: [
            'operating-profitability',
            tenant.tenantId,
          ],
        })
      },
    )
  },
)
