export const moduleKeys = [
  'finance',
  'suppliers',
  'purchasing',
  'inventory',
  'checks',
  'staff',
  'assistant',
  'food-service',
  'retail',
] as const

export type ModuleKey = (typeof moduleKeys)[number]