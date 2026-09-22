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
  'SUSPENDED',
])

export const invitationStatusSchema = z.enum([
  'PENDING',
  'ACCEPTED',
  'REVOKED',
  'EXPIRED',
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

export const profileSchema = z.object({
  id: z.uuid(),
  displayName: z.string().trim().min(2).max(120).nullable(),
  avatarUrl: z.string().url().nullable(),
  locale: z.string().trim().min(2).max(20),
  timezone: z.string().trim().min(2).max(80),
  createdAt: z.iso.datetime(),
  updatedAt: z.iso.datetime(),
})

export const membershipInvitationSchema = z.object({
  id: z.uuid(),
  tenantId: z.uuid(),
  email: z.string().email().max(320),
  status: invitationStatusSchema,
  invitedByUserId: z.uuid(),
  roleIds: z.array(z.uuid()),
  expiresAt: z.iso.datetime(),
  acceptedAt: z.iso.datetime().nullable(),
  createdAt: z.iso.datetime(),
  updatedAt: z.iso.datetime(),
})

export type Tenant = z.infer<typeof tenantSchema>
export type Location = z.infer<typeof locationSchema>
export type Membership = z.infer<typeof membershipSchema>
export type Profile = z.infer<typeof profileSchema>
export type MembershipInvitation = z.infer<
  typeof membershipInvitationSchema
>
export type TenantContext = z.infer<typeof tenantContextSchema>