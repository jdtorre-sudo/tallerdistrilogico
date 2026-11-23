import { useState } from 'react'
import { LISTAS, TALLERES, nombreTaller } from '../lib/formato'
import { PantallaCatalogo } from './Catalogos'

/** Listas editables: las del taller (sección 7) y las del kardex. */
export default function Listas() {
  const [lista, setLista] = useState(LISTAS[0].k)
  const def = LISTAS.find(l => l.k === lista)!
  const boton = (l: typeof LISTAS[number]) => (
    <button key={l.k} onClick={() => setLista(l.k)}
      className={'py-1.5 px-3 border rounded-xl text-xs font-bold transition-all ' + (l.k === lista ? 'bg-industrial-blue text-white border-industrial-blue shadow' : 'bg-slate-50 text-slate-700 border-slate-200 hover:bg-slate-100')}>{l.n}</button>
  )
  return (
    <div className="space-y-4">
      <div className="bg-slate-50 p-4 rounded-2xl border border-slate-200 space-y-3">
        <div><p className="text-[11px] font-bold uppercase tracking-wider text-slate-500 mb-1.5">Listas del taller</p>
          <div className="flex flex-wrap gap-1.5">{LISTAS.filter(l => !l.grupo).map(boton)}</div></div>
        <div><p className="text-[11px] font-bold uppercase tracking-wider text-slate-500 mb-1.5">Listas del kardex (registro de componentes, conteos, compras, herramientas)</p>
          <div className="flex flex-wrap gap-1.5">{LISTAS.filter(l => l.grupo === 'kardex').map(boton)}</div></div>
      </div>
      <PantallaCatalogo key={lista} tabla="listas_valores" titulo={def.n} subtitulo={def.d} orden="orden" filtro={{ lista }}
        campos={[
          { k: 'valor', n: 'Opción', requerido: true },
          ...(def.porTaller ? [{ k: 'taller', n: 'Taller (vacío = ambos)', tipo: 'seleccion' as const, opciones: () => TALLERES, mostrar: (f: any) => f.taller ? nombreTaller(f.taller) : 'Ambos' }] : []),
          { k: 'descripcion', n: 'Ayuda (opcional)' },
          { k: 'orden', n: 'Orden', tipo: 'numero' }, { k: 'activo', n: 'Activo', tipo: 'si_no' }
        ]} />
    </div>
  )
}
