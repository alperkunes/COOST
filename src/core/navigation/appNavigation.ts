export type NavigationItem = {
  label: string
  path: string
}

export type NavigationSection = {
  label: string
  items: NavigationItem[]
}

export const appNavigation: NavigationSection[] = [
  {
    label: 'YONETIM',
    items: [
      { label: 'Bugun', path: '/' },
      { label: 'Asistan', path: '/assistant' },
    ],
  },
  {
    label: 'FINANS',
    items: [
      { label: 'Kasa ve Banka', path: '/finance' },
      { label: 'Tedarikciler', path: '/suppliers' },
      { label: 'Cekler', path: '/checks' },
    ],
  },
  {
    label: 'OPERASYON',
    items: [
      { label: 'Stok', path: '/inventory' },
      { label: 'Satinalma', path: '/purchasing' },
      { label: 'Personel', path: '/staff' },
    ],
  },
]