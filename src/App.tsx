import './App.css'
import { AppProviders } from './app/AppProviders'
import { AppRouter } from './app/AppRouter'
import { AppGate } from './shared/auth/AppGate'

function App() {
  return (
    <AppProviders>
      <AppGate>
        <AppRouter />
      </AppGate>
    </AppProviders>
  )
}

export default App