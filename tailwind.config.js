/** Misma paleta y tipografía que las maquetas de referencia (referencias/*.html). */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      fontFamily: { sans: ['Inter', 'sans-serif'] },
      colors: {
        industrial: {
          navy: '#0f172a', blue: '#1e3a8a', accent: '#2563eb', red: '#dc2626', darkred: '#991b1b',
          steel: '#64748b', light: '#f8fafc', cardbg: '#ffffff', border: '#e2e8f0'
        }
      }
    }
  },
  plugins: []
}
