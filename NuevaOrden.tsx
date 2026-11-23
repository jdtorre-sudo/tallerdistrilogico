import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase, ok, mensajeError } from '../lib/supabase'
import { cargarCatalogos, invalidarCatalogos, tipoDe, nombreConductor, type Catalogos } from '../lib/catalogos'
import { useSesion } from '../lib/sesion'
import { COMBUSTIBLE, TALLERES, lectura as fmtLectura, uuid } from '../lib/formato'
import { TIPOS_OT } from '../lib/ot'
import type { Dano, FilaChecklist, Vehiculo } from '../lib/tipos'
import BuscadorVehiculo from '../components/BuscadorVehiculo'
import Checklist from '../components/Checklist'
import DiagramaDanos from '../components/Diagrama'
import { Aviso, Campo, Cargando, TituloSeccion, useToast } from '../components/ui'

const ahoraLocal = () => { const d = new Date(); d.setMinutes(d.getMinutes() - d.getTimezoneOffset()); return d.toISOString().slice(0, 16) }

function Bloque({ n, titulo, children, ayuda }: { n: number; titulo: string; children: React.ReactNode; ayuda?: string }) {
  return (
    <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
      <div className="px-5 py-3 border-b border-slate-200 bg-slate-50/70 flex items-center gap-2">
        <span className="w-6 h-6 rounded-lg bg-industrial-navy text-white text-[11px] font-black flex items-center justify-center">{n}</span>
        <h3 className="font-bold text-slate-800 text-sm">{titulo}</h3>
      </div>
      <div className="p-5 space-y-4">{ayuda && <p className="text-xs text-slate-500 -mt-1">{ayuda}</p>}{children}</div>
    </div>
  )
}

/** Abrir OT: segmento 1 (vehículo y recepción) y segmento 2 (solicitud del chofer). */
export default function NuevaOrden() {
  const { tiene } = useSesion()
  const toast = useToast()
  const nav = useNavigate()
  const [cat, setCat] = useState<Catalogos | null>(null)
  const [veh, setVeh] = useState<Vehiculo | null>(null)
  const [f, setF] = useState({ motivo_ingreso: 'correctivo', conductor_id: '', fecha_hora: ahoraLocal(), lectura: '', combustible: '', prioridad: 'media', inmovilizado: false,
    fabricacion_descripcion: '', fabricacion_cantidad: '1', observaciones: '' })
  const [checklist, setChecklist] = useState<FilaChecklist[]>([])
  const [danos, setDanos] = useState<Dano[]>([])
  const [sols, setSols] = useState<{ descripcion: string; taller_sugerido: string }[]>([{ descripcion: '', taller_sugerido: 'mecanica' }])
  const [error, setError] = useState('')
  const [ocupado, setOcupado] = useState(false)
  useEffect(() => { cargarCatalogos(true).then(setCat).catch(e => setError(mensajeError(e))) }, [])
  useEffect(() => { if (veh?.conductor_asignado_id) setF(x => ({ ...x, conductor_id: x.conductor_id || veh.conductor_asignado_id! })) }, [veh])

  if (!tiene('operar_ot')) return <Aviso tipo="alerta">Solo el supervisor (asesor de servicios) o el maestro abren órdenes de trabajo.</Aviso>
  if (!cat) return error ? <Aviso tipo="mal">{error}</Aviso> : <Cargando />
  const tv = tipoDe(cat, veh)
  const fabricacion = f.motivo_ingreso === 'fabricacion'
  const lect = Number(f.lectura.replace(',', '.'))
  const errorKm = veh && f.lectura !== '' && lect < Number(veh.lectura_actual) ? `No puede ser menor a la última registrada (${fmtLectura(veh.lectura_actual, tv?.unidad_medida)}).` : ''
  const avisoKm = veh && f.lectura !== '' && !errorKm && lect - Number(veh.lectura_actual) > Number(cat.config.diferencia_max_hunter_km || 500) * 20 ? 'Es mucho mayor que la última lectura registrada: revise que esté bien escrita.' : ''
  const items = cat.items.filter(i => i.activo && (!i.tipo_vehiculo_id || i.tipo_vehiculo_id === veh?.tipo_vehiculo_id))

  async function abrir() {
    setError('')
    if (!veh && !fabricacion) return setError('Elija el vehículo (por código o placa).')
    if (veh && f.lectura === '') return setError(`Escriba el ${tv?.unidad_medida === 'horas' ? 'horómetro' : 'kilometraje'} de ingreso.`)
    if (errorKm) return setError(errorKm)
    if (fabricacion && !veh && !f.fabricacion_descripcion.trim()) return setError('Describa qué se fabrica (ej. portallantas).')
    const sinObs = checklist.find(c => c.resultado && c.resultado !== 'ok' && !c.observacion?.trim())
    if (sinObs) return setError('Escriba una observación en los ítems del checklist marcados como Falta o Dañado.')
    setOcupado(true)
    try {
      const r = ok(await supabase.rpc('abrir_ot', { p: {
        id_local: uuid(), vehiculo_id: veh?.id || null, conductor_id: f.conductor_id || null, motivo_ingreso: f.motivo_ingreso,
        fecha_hora: new Date(f.fecha_hora).toISOString(), lectura: veh ? lect : null, combustible: veh ? f.combustible || null : null,
        prioridad: f.prioridad, inmovilizado: f.inmovilizado, observaciones: f.observaciones,
        fabricacion_descripcion: fabricacion ? f.fabricacion_descripcion : null, fabricacion_cantidad: fabricacion ? Number(f.fabricacion_cantidad) || null : null,
        checklist: veh ? checklist : [], danos: veh ? danos : [], solicitudes: sols.filter(s => s.descripcion.trim())
      } })) as { ot_id: string; ot_numero: string }
      invalidarCatalogos()
      toast('OT abierta', `Se abrió la orden ${r.ot_numero}.`)
      nav(`/ot/${r.ot_id}`)
    } catch (e) { setError(mensajeError(e)) } finally { setOcupado(false) }
  }

  const chip = (on: boolean) => 'py-2 px-3 border rounded-xl text-xs font-bold transition-all ' + (on ? 'bg-industrial-blue text-white border-industrial-blue shadow' : 'bg-slate-50 text-slate-700 border-slate-200 hover:bg-slate-100')
  return (
    <section className="space-y-5">
      <TituloSeccion icono="fa-file-circle-plus" titulo="Nueva orden de trabajo" subtitulo="Segmento 1 (vehículo y recepción) y segmento 2 (solicitud del chofer). Las fotos se agregan en la OT apenas se abre." />

      <Bloque n={1} titulo="Vehículo y recepción">
        <Campo etiqueta="Tipo de OT">
          <div className="flex flex-wrap gap-1.5">{TIPOS_OT.map(t => <button type="button" key={t.k} className={chip(f.motivo_ingreso === t.k)} onClick={() => setF({ ...f, motivo_ingreso: t.k })}>{t.n}</button>)}</div>
        </Campo>
        <Campo etiqueta={fabricacion ? 'Vehículo (opcional en fabricación para stock)' : 'Vehículo *'}><BuscadorVehiculo cat={cat} valor={veh} onChange={v => { setVeh(v); setDanos([]); setChecklist([]) }} /></Campo>
        {fabricacion && (
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div className="sm:col-span-2"><Campo etiqueta="Qué se fabrica"><input className="campo-texto" placeholder="Ej. Portallantas para stock" value={f.fabricacion_descripcion} onChange={e => setF({ ...f, fabricacion_descripcion: e.target.value })} /></Campo></div>
            <Campo etiqueta="Cantidad"><input className="campo-texto" inputMode="numeric" value={f.fabricacion_cantidad} onChange={e => setF({ ...f, fabricacion_cantidad: e.target.value })} /></Campo>
          </div>
        )}
        {veh && (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <Campo etiqueta="Chofer"><select className="campo-texto" value={f.conductor_id} onChange={e => setF({ ...f, conductor_id: e.target.value })}>
              <option value="">—</option>{cat.conductores.filter(c => c.activo).map(c => <option key={c.id} value={c.id}>{nombreConductor(c)}</option>)}</select></Campo>
            <Campo etiqueta="Fecha y hora de ingreso"><input type="datetime-local" className="campo-texto" value={f.fecha_hora} onChange={e => setF({ ...f, fecha_hora: e.target.value })} /></Campo>
            <Campo etiqueta={(tv?.unidad_medida === 'horas' ? 'Horómetro' : 'Kilometraje') + ' de ingreso *'} error={errorKm} ayuda={avisoKm || `Última registrada: ${fmtLectura(veh.lectura_actual, tv?.unidad_medida)}`}>
              <input id="lectura" className="campo-texto font-bold" inputMode="decimal" value={f.lectura} onChange={e => setF({ ...f, lectura: e.target.value })} />
            </Campo>
            <Campo etiqueta="Combustible"><div className="flex gap-1.5">{COMBUSTIBLE.map(c => <button type="button" key={c} className={chip(f.combustible === c) + ' flex-1'} onClick={() => setF({ ...f, combustible: c })}>{c}</button>)}</div></Campo>
            <Campo etiqueta="Prioridad"><div className="flex gap-1.5">{[['alta', 'Alta'], ['media', 'Media'], ['baja', 'Baja']].map(([k, n]) => <button type="button" key={k} className={chip(f.prioridad === k) + ' flex-1'} onClick={() => setF({ ...f, prioridad: k })}>{n}</button>)}</div></Campo>
            <label className="flex items-center gap-2 text-xs font-bold text-slate-700 pt-5"><input type="checkbox" className="w-5 h-5 accent-industrial-red" checked={f.inmovilizado} onChange={e => setF({ ...f, inmovilizado: e.target.checked })} />Vehículo inmovilizado (no puede operar)</label>
          </div>
        )}
        {veh && <details className="bg-slate-50 rounded-2xl border border-slate-200 p-4" open>
          <summary className="cursor-pointer text-xs font-bold text-slate-700 uppercase">Checklist de recepción</summary>
          <div className="mt-3"><Checklist items={items} valores={checklist} onChange={setChecklist} /></div>
        </details>}
        {veh && tv && <details className="bg-slate-50 rounded-2xl border border-slate-200 p-4">
          <summary className="cursor-pointer text-xs font-bold text-slate-700 uppercase">Diagrama de daños ({danos.length})</summary>
          <div className="mt-3"><DiagramaDanos diagrama={tv.diagrama} danos={danos} onChange={setDanos} /></div>
        </details>}
        <Campo etiqueta="Observaciones de la recepción"><textarea className="campo-texto" rows={2} value={f.observaciones} onChange={e => setF({ ...f, observaciones: e.target.value })} /></Campo>
      </Bloque>

      <Bloque n={2} titulo="Solicitud del chofer" ayuda="Lo que reporta el chofer. Cada línea terminará atendida (con trabajos), no realizada o descartada.">
        {sols.map((s, i) => (
          <div key={i} className="flex flex-col sm:flex-row gap-2 sm:items-center">
            <span className="text-xs font-mono text-slate-400 w-6">#{i + 1}</span>
            <input aria-label={`Solicitud ${i + 1}`} className="campo-texto flex-1" placeholder="Ej. La compuerta trasera no cierra" value={s.descripcion} onChange={e => setSols(sols.map((x, j) => j === i ? { ...x, descripcion: e.target.value } : x))} />
            <div className="flex gap-1">{TALLERES.map(t => <button type="button" key={t.k} className={chip(s.taller_sugerido === t.k)} onClick={() => setSols(sols.map((x, j) => j === i ? { ...x, taller_sugerido: t.k } : x))}>{t.n}</button>)}</div>
            <button type="button" className="p-2 text-slate-400 hover:text-industrial-red" aria-label="Quitar línea" onClick={() => setSols(sols.length > 1 ? sols.filter((_, j) => j !== i) : [{ descripcion: '', taller_sugerido: 'mecanica' }])}><i className="fa-solid fa-xmark" /></button>
          </div>
        ))}
        <button type="button" className="btn-gris" onClick={() => setSols([...sols, { descripcion: '', taller_sugerido: 'mecanica' }])}><i className="fa-solid fa-plus" />Agregar línea</button>
      </Bloque>

      {error && <Aviso tipo="mal">{error}</Aviso>}
      <div className="flex justify-end gap-2 sticky bottom-0 bg-white/90 backdrop-blur py-3">
        <button className="btn-gris" onClick={() => nav('/ot')}>Cancelar</button>
        <button className="btn-rojo py-3 px-6 text-sm" disabled={ocupado} onClick={abrir}><i className="fa-solid fa-folder-open" />{ocupado ? 'Abriendo…' : 'Abrir orden de trabajo'}</button>
      </div>
    </section>
  )
}
