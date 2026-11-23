import { useState } from 'react'
import { tiempoTxt } from '../lib/ot'
import type { Intervencion } from '../lib/tipos'

/** Botones de intervención de una cápsula (como en la maqueta), agrupados por grupo y con buscador
 *  cuando la cápsula tiene muchas (ej. Motor con más de 80 trabajos del tempario). */
export default function ListaIntervenciones({ invs, onElegir, deshabilitado, conLapiz }: {
  invs: Intervencion[]; onElegir: (i: Intervencion) => void; deshabilitado?: boolean; conLapiz?: boolean
}) {
  const [q, setQ] = useState('')
  const norm = (t: string) => t.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')
  const palabras = norm(q).split(/\s+/).filter(Boolean)
  const visibles = invs.filter(i => palabras.every(p => norm(`${i.nombre} ${i.grupo || ''} ${i.codigo || ''}`).includes(p)))
  const grupos = [...new Set(visibles.map(i => i.grupo || ''))]
  return (
    <div className="space-y-2">
      {invs.length > 10 && (
        <div className="relative">
          <i className="fa-solid fa-magnifying-glass absolute left-3 top-2.5 text-slate-400 text-xs" />
          <input aria-label="Buscar intervención" className="w-full border border-slate-300 rounded-xl pl-8 pr-3 py-1.5 text-xs focus:outline-none focus:border-industrial-blue"
            placeholder={`Buscar entre ${invs.length} trabajos (ej. bomba, montaje, retenedor)…`} value={q} onChange={e => setQ(e.target.value)} />
        </div>
      )}
      <div className={'space-y-2 ' + (invs.length > 10 ? 'max-h-80 overflow-y-auto custom-scrollbar pr-1' : '')}>
        {grupos.map(g => (
          <div key={g} className="space-y-1.5">
            {g && <p className="text-[10px] font-black uppercase tracking-wider text-slate-400 pt-1">{g}</p>}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              {visibles.filter(i => (i.grupo || '') === g).map(i => (
                <button key={i.id} type="button" disabled={deshabilitado} onClick={() => onElegir(i)} title={[i.codigo && `Código ${i.codigo}`, i.nota].filter(Boolean).join(' · ') || undefined}
                  className={'p-2.5 text-left bg-slate-50 hover:bg-blue-50 border border-slate-200 hover:border-industrial-blue rounded-xl text-xs font-semibold text-slate-700 transition-all flex items-center justify-between gap-1 ' + (i.activo ? '' : 'line-through opacity-50')}>
                  <span className="pr-1">
                    {i.nombre}
                    {i.sistema_preventivo_id && <i className="fa-solid fa-calendar-check text-emerald-600 ml-1" title="Alimenta el registro de componentes" />}
                    {i.nota && <span className="block text-[10px] font-normal text-slate-500">{i.nota}</span>}
                  </span>
                  <span className="text-[10px] bg-slate-200 text-slate-700 px-1.5 py-0.5 rounded-md font-mono shrink-0">{tiempoTxt(i.horas_estandar)}{conLapiz && <i className="fa-solid fa-pen text-[8px] text-industrial-blue ml-1" />}</span>
                </button>
              ))}
            </div>
          </div>
        ))}
        {!visibles.length && <p className="text-[11px] text-slate-400 italic">Ningún trabajo coincide con “{q}”.</p>}
      </div>
    </div>
  )
}
