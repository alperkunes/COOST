import { readFile } from 'node:fs/promises'
import { resolve } from 'node:path'

const EXPECTED_STAGING_REF = 'gdngxdcqjlydeytolcww'
const projectRefPath = resolve('supabase', '.temp', 'project-ref')

let actualRef

try {
  actualRef = (await readFile(projectRefPath, 'utf8')).trim()
} catch {
  console.error('ERROR: Supabase linked project ref could not be read.')
  console.error('Run: npx supabase link --project-ref gdngxdcqjlydeytolcww')
  process.exit(1)
}

if (actualRef !== EXPECTED_STAGING_REF) {
  console.error('ERROR: Refusing to run staging RLS tests.')
  console.error(`Expected COOST-STAGING: ${EXPECTED_STAGING_REF}`)
  console.error(`Currently linked:       ${actualRef || '(empty)'}`)
  process.exit(1)
}

console.log(`OK - COOST-STAGING target verified (${actualRef})`)
