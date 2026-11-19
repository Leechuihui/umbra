import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './app.tsx'
import { I18nProvider } from './i18n/context'
import { ThemeProvider } from './theme/context'

createRoot(document.getElementById('root')!).render(
  // <StrictMode>
  <I18nProvider>
    <ThemeProvider>
      <App />
    </ThemeProvider>
  </I18nProvider>
  // </StrictMode>,
)
