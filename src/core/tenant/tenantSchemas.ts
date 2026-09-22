import { z } from 'zod'
import { moduleKeys } from '../access/modules'
import { permissionKeys } from '../access/permissions'

export const tenantStatusSchema = z.enum([
  'ACTIVE',
  'SUSPENDED',
  'ARCHIVED',
])

export const locationStatusSchema = z.enum([
  'ACTIVE',
  'PASSIVE',
])

export const membershipStatusSchema = z.enum([
  'ACTIVE',
  'INVITED',
  'SUSPENDED',
])

export const tenantSchema = z.object({
  id: z.uuid(),
  name: z.string().trim().min(2).max(120),
  status: tenantStatusSchema,
  createdAt: z.iso.datetime(),
})

export const locationSchema = z.object({
  id: z.uuid(),
  tenantId: z.uuid(),
  name: z.string().trim().min(2).max(120),
  status: locationStatusSchema,
  createdAt: z.iso.datetime(),
})

export const membershipSchema = z.object({
  id: z.uuid(),
  tenantId: z.uuid(),
  userId: z.uuid(),
  status: membershipStatusSchema,
  roleIds: z.array(z.uuid()),
})

export const tenantContextSchema = z.object({
  tenantId: z.uuid(),
  locationId: z.uuid().nullable(),
  userId: z.uuid(),
  modules: z.array(z.enum(moduleKeys)),
  permissions: z.array(z.enum(permissionKeys)),
})

export type Tenant = z.infer<typeof tenantSchema>
export type Location = z.infer<typeof locationSchema>
export type Membership = z.infer<typeof membershipSchema>
export type TenantContext = z.infer<typeof tenantContextSchema>