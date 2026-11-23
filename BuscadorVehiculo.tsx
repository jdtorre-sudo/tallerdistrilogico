import { useMemo, useState } from 'react'
import type { Catalogos } from '../lib/catalogos'
import { tipoDe } from '../lib/catalogos'
import { edad, lectura } from '../lib/formato'
import type { Vehiculo } from '../lib/tipos'
import { Pildora } from './ui'

/** Busca el vehículo por código o placa y muestra su ficha (tipo, marca, centro de costo, propio o rentado y edad). */
export default function BuscadorVehiculo({ cat, valor, onChange }: { cat: Catalogos; valor?: Vehiculo | null; onChange: (v: Vehiculo | null) => void }) {
  const [texto, setTexto] = useState('')
  const lista = useMemo(() => {
    const t = texto.trim().toUpperCase().replace(/[\s-]/g, '')
    if (!t) return []
    return cat.vehiculos.filter(v => v.estado !== 'venta' && (v.codigo.toUpperCase().includes(t) || (v.placa || '').toUpperCase().replace(/-/g, '').includes(t))).slice(0, 8)
  }, [texto, cat])

  if (valor) {
    const t = tipoDe(cat, valor)
    const cc = cat.centros.find(c => c.id === valor.centro_costo_id)
    const cli = cat.clientes.find(c => c.id === valor.cliente_id)
    return (
      <div className="bg-slate-50 p-4 rounded-2xl border-2 border-industrial-blue space-y-2 text-xs">
        <div className="flex justify-between items-center gap-2">
          <span className="font-black text-industrial-blue text-base"><i className="fa-solid fa-truck-front mr-1.5" />{valor.codigo}{valor.placa ? ' · ' + valor.placa : ''}</span>
          <button type="button" className="btn-gris py-1.5" onClick={() => onChange(null)}>Cambiar</button>
        </div>
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-x-4 gap-y-1">
          <p><b className="text-slate-600">Tipo:</b> {t?.nombre}</p>
          <p><b className="text-slate-600">Marca / modelo:</b> {[valor.marca, valor.modelo].filter(Boolean).join(' ') || '—'}</p>
          <p><b className="text-slate-600">Edad:</b> {edad(valor.fecha_ingreso_flota) || '—'}</p>
          <p><b className="text-slate-600">Centro de costo:</b> {cc?.codigo || '—'}</p>
          <p><b className="text-slate-600">Última lectura:</b> {lectura(valor.lectura_actual, t?.unidad_medida)}</p>
          <p>{valor.propiedad === 'rentado' ? <Pildora tipo="alerta">Rentado a {cli?.nombre || 'cliente'}</Pildora> : <Pildora tipo="ok">Propio</Pildora>}</p>
        </div>
        {valor.estado !== 'activo' && <p className="text-amber-700 font-semibold">Estado en Maestros: {valor.estado}</p>}
      </div>
    )
  }
  return (
    <div className="relative">
      <i className="fa-solid fa-magnifying-glass absolute left-3 top-3 text-slate-400 text-xs" />
      <input id="buscar-vehiculo" autoFocus className="campo-texto pl-8" inputMode="search" placeholder="Escriba código o placa (DC001, GSA…)" value={texto} onChange={e => setTexto(e.target.value)} />
      {lista.length > 0 && (
        <div className="mt-1 bg-white border border-slate-200 rounded-2xl shadow-xl overflow-hidden divide-y divide-slate-100">
          {lista.map(v => (
            <button type="button" key={v.id} className="w-full text-left p-3 hover:bg-blue-50 text-xs flex items-center gap-2" onClick={() => { onChange(v); setTexto('') }}>
              <b className="text-industrial-blue">{v.codigo}</b><span>{v.placa || ''}</span>
              <span className="text-slate-500">{tipoDe(cat, v)?.nombre} · {v.marca} {v.modelo}</span>
              {v.propiedad === 'rentado' && <Pildora tipo="alerta">Rentado</Pildora>}
            </button>
          ))}
        </div>
      )}
      {texto && lista.length === 0 && <p className="text-[11px] text-slate-500 mt-1">No se encontró ningún vehículo con “{texto}”.</p>}
    </div>
  )
}
