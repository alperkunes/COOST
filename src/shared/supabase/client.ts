import { createClient } from '@supabase/supabase-js'
import type { Database } from './database.types'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabasePublishableKey =
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY

if (!supabaseUrl) {
  throw new Error('VITE_SUPABASE_URL is not configured')
}

if (!supabasePublishableKey) {
  throw new Error(
    'VITE_SUPABASE_PUBLISHABLE_KEY is not configured',
  )
}

if (!supabasePublishableKey.startsWith('sb_publishable_')) {
  throw new Error(
    'COOST browser client requires a Supabase publishable key',
  )
}

export const supabase = createClient<Database>(
  supabaseUrl,
  supabasePublishableKey,
  {
    db: {
      schema: 'public',
    },
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  },
)