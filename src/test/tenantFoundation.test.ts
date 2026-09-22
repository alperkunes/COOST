import { describe, expect, it } from 'vitest'
import {
  tenantContextSchema,
  tenantSchema,
} from '../core/tenant/tenantSchemas'
import {
  hasModule,
  hasPermission,
} from '../core/access/accessUtils'

const tenantId = '11111111-1111-4111-8111-111111111111'
const locationId = '22222222-2222-4222-8222-222222222222'
const userId = '33333333-3333-4333-8333-333333333333'

describe('tenant foundation', () => {
  it('accepts a valid tenant', () => {
    const tenant = tenantSchema.parse({
      id: tenantId,
      name: 'Demo Business',
      status: 'ACTIVE',
      createdAt: '2026-09-22T15:00:00.000Z',
    })

    expect(tenant.id).toBe(tenantId)
  })

  it('rejects invalid tenant identifiers', () => {
    expect(() =>
      tenantSchema.parse({
        id: 'invalid-id',
        name: 'Demo Business',
        status: 'ACTIVE',
        createdAt: '2026-09-22T15:00:00.000Z',
      }),
    ).toThrow()
  })

  it('evaluates enabled modules and permissions from tenant context', () => {
    const context = tenantContextSchema.parse({
      tenantId,
      locationId,
      userId,
      modules: ['finance', 'inventory'],
      permissions: ['finance.read', 'inventory.read'],
    })

    expect(hasModule(context, 'finance')).toBe(true)
    expect(hasModule(context, 'food-service')).toBe(false)

    expect(hasPermission(context, 'finance.read')).toBe(true)
    expect(hasPermission(context, 'finance.write')).toBe(false)
  })
})