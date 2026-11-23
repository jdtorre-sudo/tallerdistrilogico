import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['logo.png', 'icono.svg'],
      manifest: {
        name: 'Taller Distrilógico',
        short_name: 'Taller',
        description: 'Sistema de gestión del taller de la flota Distrilógico',
        lang: 'es-EC',
        start_url: '/',
        display: 'standalone',
        orientation: 'any',
        background_color: '#ffffff',
        theme_color: '#0f172a',
        icons: [
          { src: 'icono-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'icono-512.png', sizes: '512x512', type: 'image/png' },
          { src: 'icono-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' }
        ]
      },
      workbox: {
        navigateFallback: '/index.html',
        navigateFallbackDenylist: [/^\/api\//],
        globPatterns: ['**/*.{js,css,html,svg,png,woff2,woff,ttf}'],
        maximumFileSizeToCacheInBytes: 6 * 1024 * 1024
      }
    })
  ],
  build: { chunkSizeWarningLimit: 2500 },
  // Solo para pruebas locales: las funciones /api las atiende el servidor simulado (pruebas/servidor_simulado.mjs)
  server: { proxy: { '/api': 'http://localhost:54321' } }
})
