import type { ModuleKey } from '../access/modules'
import type { PermissionKey } from '../access/permissions'

export type NavigationItem = {
  label: string
  path: string
  requiredModule?: ModuleKey
  requiredPermission?: PermissionKey
}

export type NavigationSection = {
  label: string
  items: NavigationItem[]
}

export const appNavigation: NavigationSection[] = [
  {
    label: 'YÖNETİM',
    items: [
      { label: 'Bugün', path: '/' },
      {
        label: 'Asistan',
        path: '/assistant',
        requiredModule: 'assistant',
        requiredPermission: 'assistant.read',
      },
    ],
  },
  {
    label: 'FINANS',
    items: [
      {
        label: 'Kasa ve Banka',
        path: '/finance',
        requiredModule: 'finance',
        requiredPermission: 'finance.read',
      },
      {
        label: 'Tedarikçiler',
        path: '/suppliers',
        requiredModule: 'suppliers',
        requiredPermission: 'suppliers.read',
      },
      {
        label: 'Çekler',
        path: '/checks',
        requiredModule: 'checks',
        requiredPermission: 'checks.read',
      },
    ],
  },
  {
    label: 'OPERASYON',
    items: [
      {
        label: 'Stok',
        path: '/inventory',
        requiredModule: 'inventory',
        requiredPermission: 'inventory.read',
      },
      {
        label: 'Satınalma',
        path: '/purchasing',
        requiredModule: 'purchasing',
        requiredPermission: 'purchasing.read',
      },
      {
        label: 'Personel',
        path: '/staff',
        requiredModule: 'staff',
        requiredPermission: 'staff.read',
      },
    ],
  },
]