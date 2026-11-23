import React from 'react'
import ReactDOM from 'react-dom/client'
import { HashRouter } from 'react-router-dom'
import { registerSW } from 'virtual:pwa-register'
import App from './App'
import { ProveedorSesion } from './lib/sesion'
import { ProveedorToast } from './components/ui'
import './estilos.css'

registerSW({ immediate: true })

ReactDOM.createRoot(document.getElementById('raiz')!).render(
  <React.StrictMode>
    <HashRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
      <ProveedorSesion>
        <ProveedorToast>
          <App />
        </ProveedorToast>
      </ProveedorSesion>
    </HashRouter>
  </React.StrictMode>
)
