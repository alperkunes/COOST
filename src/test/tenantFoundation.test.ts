import { describe, expect, it } from 'vitest'
import {
  membershipInvitationSchema,
  membershipSchema,
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

  it('does not model invitations as memberships', () => {
    expect(() =>
      membershipSchema.parse({
        id: '44444444-4444-4444-8444-444444444444',
        tenantId,
        userId,
        status: 'INVITED',
        roleIds: [],
      }),
    ).toThrow()
  })

  it('accepts a pending membership invitation', () => {
    const invitation = membershipInvitationSchema.parse({
      id: '55555555-5555-4555-8555-555555555555',
      tenantId,
      email: 'owner@example.com',
      status: 'PENDING',
      invitedByUserId: userId,
      roleIds: ['66666666-6666-4666-8666-666666666666'],
      expiresAt: '2026-09-29T15:00:00.000Z',
      acceptedAt: null,
      createdAt: '2026-09-22T15:00:00.000Z',
      updatedAt: '2026-09-22T15:00:00.000Z',
    })

    expect(invitation.status).toBe('PENDING')
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