import { useState } from 'react'
import { svgBase, VISTAS, COLOR_MARCA } from '../lib/diagramas'
import { nombreDano, TIPOS_DANO } from '../lib/formato'
import type { Dano, Diagrama as TipoDiagrama, Vista } from '../lib/tipos'
import { Chips } from './ui'

interface Props {
  diagrama: TipoDiagrama
  danos: Dano[]                 // marcas editables de esta acta
  previos?: Dano[]              // marcas de otra acta (solo se muestran)
  onChange?: (d: Dano[]) => void
  numeroInicial?: number
}

/** Diagrama tocable: cada toque agrega una marca numerada. */
export default function DiagramaDanos({ diagrama, danos, previos = [], onChange, numeroInicial = 1 }: Props) {
  const [vista, setVista] = useState<Vista>('izquierda')
  const [sel, setSel] = useState<number | null>(null)
  const editable = !!onChange

  function tocar(e: React.MouseEvent<SVGSVGElement>) {
    if (!editable) return
    const r = e.currentTarget.getBoundingClientRect()
    const x = Math.min(1, Math.max(0, (e.clientX - r.left) / r.width))
    const y = Math.min(1, Math.max(0, (e.clientY - r.top) / r.height))
    const n = Math.max(numeroInicial - 1, ...danos.map(d => d.numero_marca)) + 1
    onChange!([...danos, { numero_marca: n, vista, posicion_x: +x.toFixed(4), posicion_y: +y.toFixed(4), tipo_dano: 'golpe', descripcion: '' }])
    setSel(n)
  }
  const cambiar = (n: number, c: Partial<Dano>) => onChange?.(danos.map(d => (d.numero_marca === n ? { ...d, ...c } : d)))
  const quitar = (n: number) => { onChange?.(danos.filter(d => d.numero_marca !== n)); setSel(null) }
  const enVista = (l: Dano[]) => l.filter(d => d.vista === vista)

  return (
    <div className="space-y-3">
      <div className="bg-slate-100 p-1.5 rounded-2xl flex flex-wrap gap-1 border border-slate-200 text-xs font-bold">
        {VISTAS.map(v => {
          const cuenta = danos.filter(d => d.vista === v.k).length + previos.filter(d => d.vista === v.k).length
          return <button type="button" key={v.k} className={'flex-1 py-2 px-2 rounded-xl transition ' + (vista === v.k ? 'bg-industrial-navy text-white shadow-md' : 'text-slate-600 hover:text-slate-900')} onClick={() => setVista(v.k)}>{v.n}{cuenta ? ` (${cuenta})` : ''}</button>
        })}
      </div>
      <svg viewBox="0 0 320 160" className="w-full h-auto bg-white border-2 border-slate-200 rounded-2xl cursor-crosshair" onClick={tocar} role="img" aria-label={`Vista ${vista}`}>
        <rect width="320" height="160" fill="#fff" />
        <g dangerouslySetInnerHTML={{ __html: svgBase(diagrama, vista) }} />
        {enVista(previos).map(d => (
          <g key={'p' + d.numero_marca}>
            <circle cx={d.posicion_x * 320} cy={d.posicion_y * 160} r="10" fill={COLOR_MARCA.previo} stroke="#fff" strokeWidth="2" />
            <text x={d.posicion_x * 320} y={d.posicion_y * 160 + 4} textAnchor="middle" fontSize="11" fontWeight="700" fill="#fff">{d.numero_marca}</text>
          </g>
        ))}
        {enVista(danos).map(d => (
          <g key={d.numero_marca} onClick={e => { e.stopPropagation(); setSel(d.numero_marca) }}>
            <circle cx={d.posicion_x * 320} cy={d.posicion_y * 160} r={sel === d.numero_marca ? 13 : 10}
              fill={editable && numeroInicial > 1 ? COLOR_MARCA.nuevo : COLOR_MARCA.preexistente} stroke="#fff" strokeWidth="2" />
            <text x={d.posicion_x * 320} y={d.posicion_y * 160 + 4} textAnchor="middle" fontSize="11" fontWeight="700" fill="#fff">{d.numero_marca}</text>
          </g>
        ))}
      </svg>
      {editable && <p className="text-[11px] text-slate-500">Toque el dibujo donde está el daño. Después elija el tipo y escriba una descripción corta.</p>}
      <div className="space-y-2 text-xs">
        {previos.map(d => (
          <div key={'p' + d.numero_marca} className="flex items-center gap-2 text-slate-500"><span className="w-6 h-6 rounded-full bg-slate-400 text-white font-bold flex items-center justify-center">{d.numero_marca}</span>{nombreDano(d.tipo_dano)} · {d.descripcion || 'sin descripción'} <em>(registrado al ingreso)</em></div>
        ))}
        {danos.map(d => (
          <div key={d.numero_marca} className={'p-2.5 rounded-xl border bg-white space-y-2 ' + (sel === d.numero_marca ? 'border-industrial-blue ring-2 ring-industrial-blue/20' : 'border-slate-200')} onClick={() => { setSel(d.numero_marca); setVista(d.vista) }}>
            <div className="flex items-center gap-2 flex-wrap"><span className={'w-6 h-6 rounded-full text-white font-bold flex items-center justify-center ' + (numeroInicial > 1 ? 'bg-amber-600' : 'bg-red-700')}>{d.numero_marca}</span>
              <strong>{nombreDano(d.tipo_dano)}</strong> · {VISTAS.find(v => v.k === d.vista)?.n}{!editable && d.descripcion ? ` · ${d.descripcion}` : ''}
              {editable && <button type="button" className="btn-peligro ml-auto py-1 px-2" onClick={e => { e.stopPropagation(); quitar(d.numero_marca) }}>Quitar</button>}
            </div>
            {editable && sel === d.numero_marca && (
              <div className="space-y-2">
                <Chips opciones={TIPOS_DANO} valor={d.tipo_dano} onChange={k => cambiar(d.numero_marca, { tipo_dano: k })} />
                <input className="campo-texto" placeholder="Descripción del daño" value={d.descripcion || ''} onChange={e => cambiar(d.numero_marca, { descripcion: e.target.value })} />
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}
