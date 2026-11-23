import { RESULTADOS, nombreResultado } from '../lib/formato'
import type { FilaChecklist, ItemChecklist } from '../lib/tipos'

interface Props {
  items: ItemChecklist[]
  valores: FilaChecklist[]
  onChange: (v: FilaChecklist[]) => void
  ingreso?: FilaChecklist[]   // para comparar en el acta de entrega
}

export default function Checklist({ items, valores, onChange, ingreso }: Props) {
  const grupos = [...new Set(items.map(i => i.grupo))]
  const val = (id: string) => valores.find(v => v.item_checklist_id === id)
  const poner = (id: string, c: Partial<FilaChecklist>) => {
    const existe = val(id)
    onChange(existe ? valores.map(v => (v.item_checklist_id === id ? { ...v, ...c } : v)) : [...valores, { item_checklist_id: id, ...c }])
  }
  const todoOk = () => onChange(items.map(i => ({ item_checklist_id: i.id, resultado: 'ok' as const })))
  const revisados = valores.filter(v => v.resultado).length

  return (
    <div className="space-y-3">
      <div className="flex justify-between items-center gap-2">
        <span className="text-xs font-bold text-slate-600 uppercase">{revisados} de {items.length} revisados</span>
        <button type="button" className="btn-verde" onClick={todoOk}><i className="fa-solid fa-check-double" />Marcar todo OK</button>
      </div>
      {grupos.map(g => (
        <div key={g} className="space-y-2">
          <h4 className="text-[11px] font-bold text-industrial-blue uppercase tracking-wider border-b border-slate-100 pb-1">{g}</h4>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
          {items.filter(i => i.grupo === g).map(i => {
            const v = val(i.id)
            const antes = ingreso?.find(x => x.item_checklist_id === i.id)
            const cambio = ingreso && v?.resultado && antes?.resultado && antes.resultado !== v.resultado
            const empeoro = cambio && antes!.resultado === 'ok'
            return (
              <div key={i.id} className={'p-3 rounded-2xl border space-y-2 text-xs ' + (empeoro ? 'border-industrial-red bg-red-50' : 'border-slate-200 bg-slate-50')}>
                <div className="flex justify-between gap-2"><strong className="text-slate-800">{i.nombre}</strong>
                  {ingreso && <span className="text-[11px] text-slate-500">Ingreso: <b>{nombreResultado(antes?.resultado)}</b></span>}
                </div>
                <div className="grid grid-cols-3 gap-1.5">
                  {RESULTADOS.map(r => {
                    const on = v?.resultado === r.k
                    const color = r.k === 'ok' ? 'bg-emerald-600 border-emerald-600' : r.k === 'falta' ? 'bg-amber-500 border-amber-500' : 'bg-industrial-red border-industrial-red'
                    return <button type="button" key={r.k} className={'py-1.5 border rounded-xl font-bold transition-all ' + (on ? color + ' text-white shadow' : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-100')} onClick={() => poner(i.id, { resultado: r.k as FilaChecklist['resultado'] })}>{r.n}</button>
                  })}
                </div>
                {v?.resultado && v.resultado !== 'ok' && (
                  <input className="campo-texto" placeholder="Observación (obligatoria)" value={v.observacion || ''} onChange={e => poner(i.id, { observacion: e.target.value })} />
                )}
                {empeoro && <span className="text-[11px] text-industrial-red font-semibold">Diferencia con el ingreso: entró {nombreResultado(antes!.resultado)} y sale {nombreResultado(v!.resultado)}.</span>}
              </div>
            )
          })}
          </div>
        </div>
      ))}
    </div>
  )
}

export function checklistCompleto(items: ItemChecklist[], valores: FilaChecklist[]): string | null {
  const falta = items.filter(i => !valores.find(v => v.item_checklist_id === i.id && v.resultado))
  if (falta.length) return `Faltan ${falta.length} ítems por revisar (${falta.slice(0, 3).map(f => f.nombre).join(', ')}${falta.length > 3 ? '…' : ''}).`
  const sinObs = valores.filter(v => v.resultado && v.resultado !== 'ok' && !v.observacion?.trim())
  if (sinObs.length) return 'Escriba una observación en los ítems marcados como Falta o Dañado.'
  return null
}
