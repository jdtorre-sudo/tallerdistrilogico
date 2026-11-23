// Dibujos simples de cada tipo de vehículo en 4 vistas, para marcar daños.
// Todos usan viewBox 0 0 320 160 y colores fijos (sirven también para el PDF).
import type { Diagrama, Vista } from './tipos'

const C = { cuerpo: '#d4dae1', cabina: '#b9cde8', vidrio: '#ffffff', rueda: '#1f2329', aro: '#8a95a3', linea: '#56606d', luz: '#f2b705', roja: '#d13b3b' }
const st = `stroke="${C.linea}" stroke-width="1.5"`
const rueda = (x: number, y = 128, r = 20) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${C.rueda}"/><circle cx="${x}" cy="${y}" r="${r * 0.4}" fill="${C.aro}"/>`
const cabinaLateral = (ancho = 86) => `
  <path d="M14 118 V60 Q14 36 36 34 H${14 + ancho - 14} Q${14 + ancho} 34 ${14 + ancho} 50 V118 Z" fill="${C.cabina}" ${st}/>
  <rect x="24" y="44" width="${ancho * 0.36}" height="26" rx="3" fill="${C.vidrio}" ${st}/>
  <rect x="${28 + ancho * 0.38}" y="44" width="${ancho * 0.34}" height="26" rx="3" fill="${C.vidrio}" ${st}/>
  <rect x="6" y="108" width="16" height="10" rx="2" fill="${C.cuerpo}" ${st}/>`

function lateral(d: Diagrama): string {
  switch (d) {
    case 'cabezal': return `
      <rect x="96" y="104" width="214" height="12" rx="2" fill="${C.cuerpo}" ${st}/>
      <rect x="196" y="92" width="76" height="12" rx="2" fill="${C.cuerpo}" ${st}/>
      <rect x="104" y="80" width="30" height="24" rx="4" fill="${C.cuerpo}" ${st}/>
      ${cabinaLateral()}${rueda(54)}${rueda(216)}${rueda(264)}`
    case 'plataforma': return `
      <rect x="96" y="108" width="214" height="10" fill="${C.cuerpo}" ${st}/>
      <rect x="96" y="86" width="218" height="16" fill="${C.cuerpo}" ${st}/>
      ${[110, 150, 190, 230, 270, 306].map(x => `<rect x="${x}" y="64" width="5" height="22" fill="${C.cuerpo}" ${st}/>`).join('')}
      ${cabinaLateral(80)}${rueda(54)}${rueda(228)}${rueda(276)}`
    case 'recolector': return `
      <rect x="96" y="108" width="210" height="10" fill="${C.cuerpo}" ${st}/>
      <path d="M98 104 V24 H270 Q306 24 308 60 V104 Z" fill="${C.cuerpo}" ${st}/>
      <path d="M270 24 V104" ${st} fill="none"/>
      <rect x="276" y="70" width="26" height="8" fill="${C.luz}"/>
      ${cabinaLateral(80)}${rueda(54)}${rueda(220)}${rueda(268)}`
    case 'montacargas': return `
      <rect x="40" y="12" width="12" height="118" fill="${C.cuerpo}" ${st}/>
      <rect x="10" y="126" width="44" height="6" fill="${C.linea}"/>
      <rect x="10" y="96" width="6" height="36" fill="${C.linea}"/>
      <path d="M70 50 H190 V30" ${st} fill="none"/><path d="M70 50 V108" ${st} fill="none"/>
      <path d="M64 108 V80 H120 V60 H200 V108 Z" fill="${C.cabina}" ${st}/>
      <rect x="200" y="58" width="60" height="62" rx="6" fill="${C.cuerpo}" ${st}/>
      <rect x="64" y="104" width="196" height="12" fill="${C.cuerpo}" ${st}/>
      ${rueda(100, 128, 18)}${rueda(226, 130, 16)}`
  }
}

function frontal(d: Diagrama): string {
  if (d === 'montacargas') return `
    <rect x="110" y="10" width="12" height="122" fill="${C.cuerpo}" ${st}/><rect x="198" y="10" width="12" height="122" fill="${C.cuerpo}" ${st}/>
    <rect x="110" y="20" width="100" height="8" fill="${C.cuerpo}" ${st}/>
    <rect x="120" y="128" width="20" height="10" fill="${C.linea}"/><rect x="180" y="128" width="20" height="10" fill="${C.linea}"/>
    <rect x="128" y="50" width="64" height="60" fill="${C.cabina}" ${st}/>
    <rect x="86" y="112" width="24" height="36" rx="4" fill="${C.rueda}"/><rect x="210" y="112" width="24" height="36" rx="4" fill="${C.rueda}"/>`
  const caja = d === 'recolector' ? `<rect x="70" y="6" width="180" height="22" fill="${C.cuerpo}" ${st}/>` : ''
  return `${caja}
    <rect x="80" y="22" width="160" height="96" rx="8" fill="${C.cabina}" ${st}/>
    <rect x="92" y="32" width="136" height="34" rx="4" fill="${C.vidrio}" ${st}/>
    <rect x="120" y="74" width="80" height="32" rx="3" fill="${C.cuerpo}" ${st}/>
    ${[80, 86, 92, 98].map(y => `<path d="M124 ${y} H196" ${st}/>`).join('')}
    <rect x="88" y="78" width="24" height="12" rx="2" fill="${C.luz}" ${st}/><rect x="208" y="78" width="24" height="12" rx="2" fill="${C.luz}" ${st}/>
    <rect x="62" y="34" width="10" height="26" rx="2" fill="${C.cuerpo}" ${st}/><rect x="248" y="34" width="10" height="26" rx="2" fill="${C.cuerpo}" ${st}/>
    <path d="M72 46 H80 M240 46 H248" ${st}/>
    <rect x="74" y="112" width="172" height="12" rx="3" fill="${C.cuerpo}" ${st}/>
    <rect x="84" y="124" width="26" height="28" rx="4" fill="${C.rueda}"/><rect x="210" y="124" width="26" height="28" rx="4" fill="${C.rueda}"/>`
}

function posterior(d: Diagrama): string {
  const luces = `<rect x="78" y="104" width="22" height="10" fill="${C.roja}"/><rect x="220" y="104" width="22" height="10" fill="${C.roja}"/>`
  const ruedasDobles = `<rect x="70" y="118" width="22" height="34" rx="4" fill="${C.rueda}"/><rect x="94" y="118" width="22" height="34" rx="4" fill="${C.rueda}"/>
    <rect x="204" y="118" width="22" height="34" rx="4" fill="${C.rueda}"/><rect x="228" y="118" width="22" height="34" rx="4" fill="${C.rueda}"/>`
  switch (d) {
    case 'cabezal': return `
      <rect x="90" y="14" width="140" height="80" rx="6" fill="${C.cabina}" ${st}/>
      <rect x="120" y="26" width="80" height="22" rx="3" fill="${C.vidrio}" ${st}/>
      <ellipse cx="160" cy="98" rx="46" ry="8" fill="${C.cuerpo}" ${st}/>
      <rect x="72" y="100" width="176" height="18" fill="${C.cuerpo}" ${st}/>${luces}${ruedasDobles}`
    case 'plataforma': return `
      <rect x="110" y="20" width="100" height="50" rx="6" fill="${C.cabina}" ${st}/>
      <rect x="56" y="70" width="208" height="20" fill="${C.cuerpo}" ${st}/>
      <rect x="56" y="48" width="6" height="22" fill="${C.cuerpo}" ${st}/><rect x="258" y="48" width="6" height="22" fill="${C.cuerpo}" ${st}/>
      <rect x="72" y="96" width="176" height="20" fill="${C.cuerpo}" ${st}/>${luces}${ruedasDobles}`
    case 'recolector': return `
      <path d="M62 112 V30 Q62 10 82 10 H238 Q258 10 258 30 V112 Z" fill="${C.cuerpo}" ${st}/>
      <path d="M80 30 H240 V92 H80 Z" fill="${C.cabina}" ${st}/>
      <path d="M90 92 Q160 70 230 92" ${st} fill="none"/>
      <rect x="66" y="98" width="20" height="10" fill="${C.luz}"/><rect x="234" y="98" width="20" height="10" fill="${C.luz}"/>
      <rect x="72" y="106" width="176" height="12" fill="${C.cuerpo}" ${st}/>${ruedasDobles}`
    case 'montacargas': return `
      <rect x="110" y="14" width="100" height="10" fill="${C.cuerpo}" ${st}/>
      <path d="M114 24 V60 M206 24 V60" ${st}/>
      <rect x="92" y="60" width="136" height="70" rx="10" fill="${C.cuerpo}" ${st}/>
      <rect x="104" y="72" width="16" height="8" fill="${C.roja}"/><rect x="200" y="72" width="16" height="8" fill="${C.roja}"/>
      <rect x="96" y="124" width="24" height="28" rx="4" fill="${C.rueda}"/><rect x="200" y="124" width="24" height="28" rx="4" fill="${C.rueda}"/>`
  }
}

export function svgBase(d: Diagrama, v: Vista): string {
  if (v === 'izquierda') return lateral(d)
  if (v === 'derecha') return `<g transform="translate(320,0) scale(-1,1)">${lateral(d)}</g>`
  if (v === 'frontal') return frontal(d)
  return posterior(d)
}

export const VISTAS: { k: Vista; n: string }[] = [
  { k: 'frontal', n: 'Frente' }, { k: 'posterior', n: 'Atrás' }, { k: 'izquierda', n: 'Izquierda' }, { k: 'derecha', n: 'Derecha' }
]

export const COLOR_MARCA = { preexistente: '#bf2424', nuevo: '#a86f00', previo: '#8a95a3' }

/** SVG completo con marcas, para convertir a imagen en el PDF. */
export function svgCompleto(d: Diagrama, v: Vista, marcas: { n: number; x: number; y: number; color: string }[]): string {
  const m = marcas.map(k => `<circle cx="${k.x * 320}" cy="${k.y * 160}" r="10" fill="${k.color}" stroke="#fff" stroke-width="2"/>
    <text x="${k.x * 320}" y="${k.y * 160 + 4}" text-anchor="middle" font-family="Arial" font-weight="700" font-size="11" fill="#fff">${k.n}</text>`).join('')
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 160" width="640" height="320"><rect width="320" height="160" fill="#fff"/>${svgBase(d, v)}${m}</svg>`
}

export async function svgAPng(svg: string): Promise<string> {
  const img = new Image()
  img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg)
  await img.decode()
  const c = document.createElement('canvas'); c.width = 640; c.height = 320
  c.getContext('2d')!.drawImage(img, 0, 0, 640, 320)
  return c.toDataURL('image/png')
}
