// Piezas de la OT compartidas entre los ambientes (cápsulas) y la vista de la OT:
// formulario de datos del trabajo, tabla resumen de trabajos y novedades (imprevistos / no realizados).
// Estilo y textos tomados de referencias/gestion_produccion_soldadura.html.
import { useState } from 'react'
import { supabase, ok, mensajeError } from '../../lib/supabase'
import type { Tecnico, Taller } from '../../lib/tipos'
import { ESTADOS_TRABAJO, MATERIALES, ORIGENES_TRABAJO, estadoTrabajo, horasTxt, nombreMaterial, nombreOrigenTrabajo,
  type Hallazgo, type Imprevisto, type Solicitud, type Trabajo } from '../../lib/ot'
import { Aviso, Campo, Modal, Pildora, useToast } from '../ui'

export interface Complejidad { id: string; codigo: string; nombre: string; multiplicador: number; activo: boolean }

/** Todo lo que necesita el formulario: catálogos y estado de la OT. */
export interface ContextoOT {
  tecnicos: Tecnico[]; complejidades: Complejidad[]
  causas: string[]; motivosImprevisto: string[]; motivosNoRealizado: string[]; motivosDescarte: string[]
  solicitudes: Solicitud[]; hallazgos: Hallazgo[]
}

export interface DatosTrabajo {
  cantidad: number; complejidad_id: string | null
  tecnicos: { tecnico_id: string; porcentaje: number }[]; repartoManual: boolean
  observacion: string; origen: string; solicitud_id: string; hallazgo_id: string; hallazgo_nuevo: string
  causa: string; material_base: string
}

export const datosIniciales = (ctx: ContextoOT, taller: Taller): DatosTrabajo => {
  const sol = ctx.solicitudes.find(s => !s.anulado && s.estado === 'pendiente' && s.taller_sugerido === taller)
  return {
    cantidad: 1, complejidad_id: ctx.complejidades.find(c => c.codigo === 'moderado')?.id || null, tecnicos: [], repartoManual: false,
    observacion: '', origen: sol ? 'chofer' : 'hallazgo', solicitud_id: sol?.id || '', hallazgo_id: '', hallazgo_nuevo: '', causa: '', material_base: taller === 'soldadura' ? 'hierro_negro' : ''
  }
}
export const datosDeTrabajo = (t: Trabajo): DatosTrabajo => ({
  cantidad: Number(t.cantidad), complejidad_id: t.complejidad_id, repartoManual: true,
  tecnicos: t.tecnicos.map(x => ({ tecnico_id: x.tecnico_id, porcentaje: Number(x.porcentaje) })),
  observacion: t.observacion || '', origen: t.origen, solicitud_id: t.solicitud_id || '', hallazgo_id: t.hallazgo_id || '', hallazgo_nuevo: '',
  causa: t.causa || '', material_base: t.material_base || ''
})

/** Valida y arma lo que se envía a guardar_trabajo(). */
export function paraGuardar(d: DatosTrabajo, taller: Taller): { error?: string; p?: Record<string, unknown> } {
  if (!d.tecnicos.length) return { error: 'Asigne al menos un técnico.' }
  if (d.repartoManual) {
    const suma = d.tecnicos.reduce((a, t) => a + Number(t.porcentaje || 0), 0)
    if (Math.abs(suma - 100) > 0.05) return { error: `El reparto de horas debe sumar 100 % (ahora suma ${suma.toLocaleString('es-EC')} %).` }
  }
  if (d.origen === 'chofer' && !d.solicitud_id) return { error: 'Elija la línea de la solicitud del chofer que atiende este trabajo.' }
  if (d.origen === 'hallazgo' && !d.hallazgo_id && !d.hallazgo_nuevo.trim()) return { error: 'Describa el hallazgo o elija uno registrado.' }
  return {
    p: {
      cantidad: d.cantidad, complejidad_id: d.complejidad_id, observacion: d.observacion, origen: d.origen,
      solicitud_id: d.origen === 'chofer' ? d.solicitud_id : null, hallazgo_id: d.origen === 'hallazgo' ? d.hallazgo_id || null : null,
      hallazgo_nuevo: d.origen === 'hallazgo' && !d.hallazgo_id ? { descripcion: d.hallazgo_nuevo } : null,
      causa: d.causa, material_base: taller === 'soldadura' ? d.material_base : null,
      tecnicos: d.tecnicos.map(t => d.repartoManual ? { tecnico_id: t.tecnico_id, porcentaje: Number(t.porcentaje) } : { tecnico_id: t.tecnico_id })
    }
  }
}

const btnOpcion = (on: boolean) => 'py-1.5 px-2 border rounded-xl text-xs font-bold transition-all ' + (on ? 'bg-industrial-blue text-white border-industrial-blue shadow' : 'bg-slate-50 text-slate-700 border-slate-200 hover:bg-slate-100')

/** Formulario de "Datos" del trabajo (paso 3 de la cápsula y edición en la OT). */
export function FormTrabajo({ d, set, ctx, taller, aplicaComplejidad, horasUnitarias, conOrigen = true }: {
  d: DatosTrabajo; set: (d: DatosTrabajo) => void; ctx: ContextoOT; taller: Taller; aplicaComplejidad: boolean; horasUnitarias: number; conOrigen?: boolean
}) {
  const [todos, setTodos] = useState(false)
  const mult = aplicaComplejidad ? Number(ctx.complejidades.find(c => c.id === d.complejidad_id)?.multiplicador || 1) : 1
  const total = Math.round(horasUnitarias * d.cantidad * mult * 100) / 100
  const tecnicos = ctx.tecnicos.filter(t => t.activo && (todos || t.especialidad === taller || t.especialidad === 'ambas' || d.tecnicos.some(x => x.tecnico_id === t.id)))
  const iguales = (ids: string[]) => {
    const base = Math.floor(10000 / Math.max(1, ids.length)) / 100
    return ids.map((id, i) => ({ tecnico_id: id, porcentaje: i === 0 ? Math.round((100 - base * (ids.length - 1)) * 100) / 100 : base }))
  }
  const alternar = (id: string) => {
    const ids = d.tecnicos.some(x => x.tecnico_id === id) ? d.tecnicos.filter(x => x.tecnico_id !== id).map(x => x.tecnico_id) : [...d.tecnicos.map(x => x.tecnico_id), id]
    set({ ...d, tecnicos: d.repartoManual ? ids.map(i => d.tecnicos.find(x => x.tecnico_id === i) || { tecnico_id: i, porcentaje: 0 }) : iguales(ids) })
  }
  const solicitudes = ctx.solicitudes.filter(s => !s.anulado && (s.estado === 'pendiente' || s.estado === 'atendida' || s.id === d.solicitud_id))
  const hallazgos = ctx.hallazgos.filter(h => !h.anulado && (h.estado === 'pendiente' || h.estado === 'aprobado'))
  const suma = d.tecnicos.reduce((a, t) => a + Number(t.porcentaje || 0), 0)

  return (
    <div className="space-y-3 text-xs">
      <div className="flex items-center justify-between">
        <label className="font-bold text-slate-600 uppercase">Cantidad:</label>
        <div className="flex items-center gap-2">
          <button type="button" aria-label="Menos" onClick={() => set({ ...d, cantidad: Math.max(1, d.cantidad - 1) })} className="bg-slate-200 hover:bg-slate-300 text-slate-700 w-8 h-8 rounded-lg font-bold">-</button>
          <input aria-label="Cantidad" inputMode="decimal" className="font-bold text-sm w-12 text-center border border-slate-300 rounded-lg py-1" value={d.cantidad}
            onChange={e => { const n = Number(e.target.value.replace(',', '.')); if (!isNaN(n) && n > 0) set({ ...d, cantidad: n }) }} />
          <button type="button" aria-label="Más" onClick={() => set({ ...d, cantidad: d.cantidad + 1 })} className="bg-slate-200 hover:bg-slate-300 text-slate-700 w-8 h-8 rounded-lg font-bold">+</button>
        </div>
      </div>
      {aplicaComplejidad && (
        <div>
          <label className="block font-bold text-slate-600 uppercase mb-1">Complejidad:</label>
          <div className="grid grid-cols-3 gap-1.5">
            {ctx.complejidades.filter(c => c.activo).map(c => <button type="button" key={c.id} onClick={() => set({ ...d, complejidad_id: c.id })} className={btnOpcion(d.complejidad_id === c.id)}>{c.nombre}</button>)}
          </div>
        </div>
      )}
      <div>
        <div className="flex justify-between items-center mb-1">
          <label className="font-bold text-slate-600 uppercase">Técnicos asignados:</label>
          <label className="flex items-center gap-1 text-[11px] text-slate-500"><input type="checkbox" checked={todos} onChange={e => setTodos(e.target.checked)} />Ver todos</label>
        </div>
        <div className="flex flex-wrap gap-1.5">
          {tecnicos.map(t => {
            const on = d.tecnicos.some(x => x.tecnico_id === t.id)
            return <button type="button" key={t.id} onClick={() => alternar(t.id)} className={'py-1 px-2.5 border rounded-xl text-xs font-bold ' + (on ? 'bg-slate-800 text-white border-slate-800' : 'bg-slate-50 text-slate-700 border-slate-200')}>{t.codigo} · {t.nombres.split(' ')[0]}</button>
          })}
          {!tecnicos.length && <span className="text-slate-400 italic">No hay técnicos de este taller. Marque “Ver todos”.</span>}
        </div>
        {d.tecnicos.length > 1 && (
          <div className="mt-2 bg-slate-50 border border-slate-200 rounded-xl p-2 space-y-1.5">
            <div className="flex justify-between items-center">
              <span className="font-bold text-slate-600">Reparto de {horasTxt(total)}-hombre</span>
              <label className="flex items-center gap-1 text-[11px] text-slate-500"><input type="checkbox" checked={d.repartoManual}
                onChange={e => set({ ...d, repartoManual: e.target.checked, tecnicos: e.target.checked ? d.tecnicos : iguales(d.tecnicos.map(x => x.tecnico_id)) })} />Cambiar reparto</label>
            </div>
            {d.tecnicos.map(x => {
              const t = ctx.tecnicos.find(y => y.id === x.tecnico_id)
              return (
                <div key={x.tecnico_id} className="flex items-center gap-2">
                  <span className="flex-1 font-semibold">{t?.codigo} · {t?.nombres}</span>
                  {d.repartoManual
                    ? <span className="flex items-center gap-1"><input aria-label={`Porcentaje de ${t?.codigo}`} inputMode="decimal" className="w-14 text-right border border-slate-300 rounded-lg px-1.5 py-0.5 font-bold" value={x.porcentaje}
                        onChange={e => set({ ...d, tecnicos: d.tecnicos.map(y => y.tecnico_id === x.tecnico_id ? { ...y, porcentaje: Number(e.target.value.replace(',', '.')) || 0 } : y) })} />%</span>
                    : <span className="font-bold">{x.porcentaje.toLocaleString('es-EC')} %</span>}
                  <span className="font-mono w-16 text-right">{horasTxt(total * x.porcentaje / 100)}</span>
                </div>
              )
            })}
            {d.repartoManual && Math.abs(suma - 100) > 0.05 && <p className="text-industrial-red font-bold">Suma {suma.toLocaleString('es-EC')} %: debe ser 100 %.</p>}
          </div>
        )}
      </div>
      {conOrigen && (
        <div>
          <label className="block font-bold text-slate-600 uppercase mb-1">Origen:</label>
          <div className="grid grid-cols-3 gap-1.5">{ORIGENES_TRABAJO.map(o => <button type="button" key={o.k} onClick={() => set({ ...d, origen: o.k })} className={btnOpcion(d.origen === o.k)}>{o.n}</button>)}</div>
          {d.origen === 'chofer' && (
            <select aria-label="Línea de la solicitud del chofer" className="campo-texto mt-1.5 text-xs" value={d.solicitud_id} onChange={e => set({ ...d, solicitud_id: e.target.value })}>
              <option value="">— Línea de la solicitud del chofer —</option>
              {solicitudes.map(s => <option key={s.id} value={s.id}>#{s.numero_linea} {s.descripcion} {s.estado === 'atendida' ? '(ya atendida)' : ''}</option>)}
            </select>
          )}
          {d.origen === 'hallazgo' && (
            <div className="mt-1.5 space-y-1.5">
              {hallazgos.length > 0 && <select aria-label="Hallazgo" className="campo-texto text-xs" value={d.hallazgo_id} onChange={e => set({ ...d, hallazgo_id: e.target.value })}>
                <option value="">— Hallazgo nuevo (escríbalo abajo) —</option>
                {hallazgos.map(h => <option key={h.id} value={h.id}>#{h.numero_linea} {h.descripcion} ({h.estado})</option>)}
              </select>}
              {!d.hallazgo_id && <input className="campo-texto text-xs" placeholder="¿Qué se encontró en la revisión? (queda en el segmento 3)" value={d.hallazgo_nuevo} onChange={e => set({ ...d, hallazgo_nuevo: e.target.value })} />}
            </div>
          )}
        </div>
      )}
      <div className={'grid gap-2 ' + (taller === 'soldadura' ? 'grid-cols-2' : 'grid-cols-1')}>
        <div><label className="block font-bold text-slate-600 uppercase mb-1">Causa:</label>
          <select aria-label="Causa" className="campo-texto text-xs" value={d.causa} onChange={e => set({ ...d, causa: e.target.value })}><option value="">—</option>{ctx.causas.map(c => <option key={c}>{c}</option>)}</select></div>
        {taller === 'soldadura' && <div><label className="block font-bold text-slate-600 uppercase mb-1">Material base:</label>
          <select aria-label="Material base" className="campo-texto text-xs" value={d.material_base} onChange={e => set({ ...d, material_base: e.target.value })}>{MATERIALES.map(m => <option key={m.k} value={m.k}>{m.n}</option>)}</select></div>}
      </div>
      <div>
        <label className="block font-bold text-slate-600 uppercase mb-1">Observación (opcional):</label>
        <input className="w-full border border-slate-300 rounded-xl px-3 py-1.5 text-xs focus:outline-none focus:border-industrial-blue" placeholder="Ej. Soldadura en cordón..." value={d.observacion} onChange={e => set({ ...d, observacion: e.target.value })} />
      </div>
      <p className="text-[11px] text-slate-500">Producción estándar: {horasTxt(horasUnitarias)} × {d.cantidad.toLocaleString('es-EC')}{aplicaComplejidad ? ` × ${mult.toLocaleString('es-EC')}` : ''} = <b className="text-industrial-red">{horasTxt(total)}</b>-hombre</p>
    </div>
  )
}

/** Tabla resumen de trabajos (como "Resumen de Trabajos Registrados" de la maqueta). */
export function TablaTrabajos({ trabajos, puedeOperar, onEditar, onEstado, onNoRealizado, onAnular, mostrarTaller }: {
  trabajos: Trabajo[]; puedeOperar: boolean; mostrarTaller?: boolean
  onEditar: (t: Trabajo) => void; onEstado: (t: Trabajo, e: string) => void; onNoRealizado: (t: Trabajo) => void; onAnular: (t: Trabajo) => void
}) {
  const visibles = trabajos.filter(t => !t.anulado)
  if (!visibles.length) return (
    <div className="py-10 text-center"><i className="fa-solid fa-inbox text-slate-300 text-4xl mb-3" /><h4 className="text-slate-600 font-semibold text-sm">No hay trabajos registrados todavía</h4>
      <p className="text-slate-400 text-xs mt-1">Abra el ambiente del taller y expanda una cápsula para registrar la primera intervención.</p></div>
  )
  return (
    <div className="overflow-x-auto custom-scrollbar">
      <table className="w-full text-left border-collapse text-xs">
        <thead><tr className="bg-slate-100/80 text-slate-600 uppercase tracking-wider font-semibold border-b border-slate-200 text-[11px]">
          <th className="py-3 px-3">#</th>{mostrarTaller && <th className="py-3 px-3">Taller</th>}<th className="py-3 px-3">Componente</th><th className="py-3 px-3">Elemento</th><th className="py-3 px-3">Intervención</th>
          <th className="py-3 px-3 text-center">Cant.</th><th className="py-3 px-3 text-center">Complejidad</th><th className="py-3 px-3">Técnicos</th>
          <th className="py-3 px-3 text-right">Prod. estándar</th><th className="py-3 px-3">Estado</th><th className="py-3 px-3">Origen / causa</th><th className="py-3 px-3">Observación</th>
          {puedeOperar && <th className="py-3 px-3 text-center">Acciones</th>}
        </tr></thead>
        <tbody className="divide-y divide-slate-100">
          {visibles.map(t => {
            const e = estadoTrabajo(t.estado)
            return (
              <tr key={t.id} className="hover:bg-slate-50 transition-colors align-top">
                <td className="py-3 px-3 font-mono text-slate-400">{t.numero_linea}</td>
                {mostrarTaller && <td className="py-3 px-3">{t.taller === 'soldadura' ? 'Soldadura' : 'Mecánica'}</td>}
                <td className="py-3 px-3 font-bold text-slate-800 uppercase">{t.sistema_nombre}</td>
                <td className="py-3 px-3 text-slate-600">{t.elemento_nombre || '—'}</td>
                <td className="py-3 px-3 font-semibold text-industrial-blue">{t.intervencion_nombre}</td>
                <td className="py-3 px-3 text-center font-bold">{Number(t.cantidad).toLocaleString('es-EC')}</td>
                <td className="py-3 px-3 text-center"><span className={'px-2 py-0.5 rounded text-[10px] font-bold ' + (t.complejidad_nombre === 'Grave' ? 'bg-red-100 text-industrial-red' : t.complejidad_nombre === 'Moderado' ? 'bg-amber-100 text-amber-700' : t.complejidad_nombre ? 'bg-blue-100 text-blue-700' : 'bg-slate-100 text-slate-500')}>{t.complejidad_nombre || 'No aplica'}</span></td>
                <td className="py-3 px-3">{t.tecnicos.map(x => <div key={x.tecnico_id} className="whitespace-nowrap"><span className="bg-slate-100 px-1.5 py-0.5 rounded font-bold">{x.codigo}</span> <span className="text-slate-500">{Number(x.porcentaje).toLocaleString('es-EC')}% · {horasTxt(x.horas)}</span></div>)}</td>
                <td className="py-3 px-3 text-right font-mono font-bold text-slate-800 whitespace-nowrap">{horasTxt(t.horas_estandar)}</td>
                <td className="py-3 px-3">
                  {puedeOperar && t.estado !== 'no_realizado'
                    ? <select aria-label={`Estado del trabajo ${t.numero_linea}`} className="bg-white border border-slate-300 rounded-lg px-1.5 py-1 text-[11px] font-bold" value={t.estado}
                        onChange={ev => ev.target.value === 'no_realizado' ? onNoRealizado(t) : onEstado(t, ev.target.value)}>
                        {ESTADOS_TRABAJO.map(x => <option key={x.k} value={x.k}>{x.n}</option>)}
                      </select>
                    : <Pildora tipo={e.tono}>{e.n}</Pildora>}
                  {t.estado === 'no_realizado' && <p className="text-[10px] text-industrial-red mt-1">{t.motivo_no_realizado}{t.detalle_no_realizado ? ` · ${t.detalle_no_realizado}` : ''}</p>}
                </td>
                <td className="py-3 px-3 text-slate-600">
                  <p className="font-semibold">{nombreOrigenTrabajo(t.origen)}{t.solicitud_linea ? ` #${t.solicitud_linea}` : t.hallazgo_linea ? ` #${t.hallazgo_linea}` : ''}</p>
                  <p className="text-[10px] text-slate-500">{[t.causa, nombreMaterial(t.material_base)].filter(Boolean).join(' · ')}</p>
                </td>
                <td className="py-3 px-3 text-slate-500 italic max-w-[180px]">{t.observacion || 'Sin observación'}</td>
                {puedeOperar && <td className="py-3 px-3 text-center whitespace-nowrap">
                  <button onClick={() => onEditar(t)} className="p-1.5 bg-blue-50 text-industrial-blue hover:bg-blue-100 rounded-lg mr-1" title="Editar trabajo" aria-label={`Editar trabajo ${t.numero_linea}`}><i className="fa-solid fa-pen-to-square" /></button>
                  <button onClick={() => onAnular(t)} className="p-1.5 bg-red-50 text-industrial-red hover:bg-red-100 rounded-lg" title="Anular trabajo" aria-label={`Anular trabajo ${t.numero_linea}`}><i className="fa-solid fa-ban" /></button>
                </td>}
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}

/** Imprevistos y trabajos no realizados (las dos secciones secundarias de la maqueta). */
export function Novedades({ trabajos, imprevistos, ctx, puedeOperar, onCambio }: {
  trabajos: Trabajo[]; imprevistos: Imprevisto[]; ctx: ContextoOT; puedeOperar: boolean; onCambio: () => void
}) {
  const toast = useToast()
  const imps = imprevistos.filter(i => !i.anulado)
  const nrs = trabajos.filter(t => !t.anulado && t.estado === 'no_realizado')
  const titulo = (id: string) => { const t = trabajos.find(x => x.id === id); return t ? `${t.sistema_nombre.toUpperCase()} > ${t.elemento_nombre || '—'} > ${t.intervencion_nombre}` : '' }
  async function resolver(i: Imprevisto, estado: string) {
    try { ok(await supabase.from('ot_imprevistos').update({ estado }).eq('id', i.id)); toast(estado === 'aprobado' ? 'Aprobado' : 'Rechazado', 'Imprevisto validado por el supervisor.', estado === 'aprobado' ? 'ok' : 'alerta'); onCambio() }
    catch (e) { toast('No se pudo', mensajeError(e), 'alerta') }
  }
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-4 space-y-3">
        <div className="flex justify-between items-center border-b border-slate-100 pb-2">
          <h4 className="font-bold text-xs uppercase tracking-wider text-amber-700 flex items-center gap-1.5"><i className="fa-regular fa-clock" />Imprevistos registrados (afectación)</h4>
          <span className="text-[10px] bg-amber-100 text-amber-800 px-2 py-0.5 rounded-full font-bold">{imps.length}</span>
        </div>
        <div className="space-y-2 text-xs max-h-60 overflow-y-auto custom-scrollbar">
          {!imps.length && <p className="text-slate-400 italic text-[11px]">Sin imprevistos reportados en esta orden.</p>}
          {imps.map(i => {
            const tec = ctx.tecnicos.find(t => t.id === i.tecnico_id)
            return (
              <div key={i.id} className="bg-amber-50/60 p-2.5 rounded-xl border border-amber-200 flex justify-between items-center gap-2">
                <div><p className="font-bold text-slate-800">{titulo(i.trabajo_id)}</p>
                  <p className="text-slate-600 text-[11px]">Téc: {tec?.codigo} {tec?.nombres} | Motivo: {i.motivo}{i.detalle ? ` — ${i.detalle}` : ''} ({i.minutos} min)</p></div>
                <div className="flex items-center gap-1 shrink-0">
                  <span className={'px-2 py-0.5 rounded text-[10px] font-bold ' + (i.estado === 'aprobado' ? 'bg-emerald-100 text-emerald-700' : i.estado === 'rechazado' ? 'bg-red-100 text-industrial-red' : 'bg-amber-200 text-amber-900')}>{i.estado === 'aprobado' ? 'Aprobado' : i.estado === 'rechazado' ? 'Rechazado' : 'Pendiente'}</span>
                  {puedeOperar && i.estado === 'pendiente' && <>
                    <button onClick={() => resolver(i, 'aprobado')} className="bg-emerald-600 text-white px-1.5 py-0.5 rounded text-[10px] font-bold" aria-label="Aprobar imprevisto">✓</button>
                    <button onClick={() => resolver(i, 'rechazado')} className="bg-red-600 text-white px-1.5 py-0.5 rounded text-[10px] font-bold" aria-label="Rechazar imprevisto">✕</button></>}
                </div>
              </div>
            )
          })}
        </div>
      </div>
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-4 space-y-3">
        <div className="flex justify-between items-center border-b border-slate-100 pb-2">
          <h4 className="font-bold text-xs uppercase tracking-wider text-industrial-red flex items-center gap-1.5"><i className="fa-solid fa-ban" />Trabajos no realizados (pendientes)</h4>
          <span className="text-[10px] bg-red-100 text-industrial-red px-2 py-0.5 rounded-full font-bold">{nrs.length}</span>
        </div>
        <div className="space-y-2 text-xs max-h-60 overflow-y-auto custom-scrollbar">
          {!nrs.length && <p className="text-slate-400 italic text-[11px]">Sin trabajos no realizados registrados.</p>}
          {nrs.map(t => (
            <div key={t.id} className="bg-red-50/60 p-2.5 rounded-xl border border-red-200 flex justify-between items-center gap-2">
              <div><p className="font-bold text-slate-800">{titulo(t.id)}</p><p className="text-slate-600 text-[11px]">Causa: {t.motivo_no_realizado}{t.detalle_no_realizado ? ` — ${t.detalle_no_realizado}` : ''}</p></div>
              <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-red-100 text-industrial-red shrink-0">PENDIENTE DE ATENCIÓN</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

/** Ventana "Registrar imprevisto durante el trabajo". */
export function ModalImprevisto({ ot, trabajos, ctx, onCerrar, onListo, titulo }: {
  ot: string; trabajos: Trabajo[]; ctx: ContextoOT; onCerrar: () => void; onListo: () => void; titulo: string
}) {
  const toast = useToast()
  const activos = trabajos.filter(t => !t.anulado && t.estado !== 'no_realizado')
  const [f, setF] = useState({ trabajo_id: activos[0]?.id || '', tecnico_id: activos[0]?.tecnicos[0]?.tecnico_id || '', motivo: ctx.motivosImprevisto[0] || '', detalle: '', minutos: '30' })
  const [error, setError] = useState('')
  const trabajo = activos.find(t => t.id === f.trabajo_id)
  return (
    <Modal titulo="Registrar imprevisto durante el trabajo" icono="fa-clock" onCerrar={onCerrar}
      pie={<><button className="btn-gris" onClick={onCerrar}>Cancelar</button><button className="bg-amber-500 hover:bg-amber-600 text-slate-950 font-bold px-4 py-2 rounded-xl text-xs shadow" onClick={async () => {
        setError('')
        if (!f.trabajo_id) return setError('Debe seleccionar un trabajo válido registrado en la OT.')
        if (!f.tecnico_id) return setError('Elija el técnico afectado.')
        if (!f.motivo) return setError('Debe elegir el motivo del imprevisto.')
        const min = parseInt(f.minutos); if (!(min > 0)) return setError('Indique los minutos de afectación.')
        try { ok(await supabase.from('ot_imprevistos').insert({ orden_trabajo_id: ot, trabajo_id: f.trabajo_id, tecnico_id: f.tecnico_id, motivo: f.motivo, detalle: f.detalle || null, minutos: min })); toast('Imprevisto registrado', 'Guardado y listo para validación del supervisor.'); onListo() }
        catch (e) { setError(mensajeError(e)) }
      }}>Guardar imprevisto</button></>}>
      <Campo etiqueta="Vehículo / OT"><input readOnly className="campo-texto bg-slate-100 font-bold" value={titulo} /></Campo>
      <Campo etiqueta="Trabajo registrado en la OT">
        <select className="campo-texto" value={f.trabajo_id} onChange={e => { const t = activos.find(x => x.id === e.target.value); setF({ ...f, trabajo_id: e.target.value, tecnico_id: t?.tecnicos[0]?.tecnico_id || '' }) }}>
          {!activos.length && <option value="">⚠️ No hay trabajos registrados todavía (agregue un trabajo primero)</option>}
          {activos.map(t => <option key={t.id} value={t.id}>{t.sistema_nombre.toUpperCase()} {'>'} {t.elemento_nombre || '—'} {'>'} {t.intervencion_nombre} ({Number(t.cantidad)} u.)</option>)}
        </select>
      </Campo>
      <Campo etiqueta="Técnico afectado">
        <select className="campo-texto" value={f.tecnico_id} onChange={e => setF({ ...f, tecnico_id: e.target.value })}>
          {(trabajo?.tecnicos || []).map(t => <option key={t.tecnico_id} value={t.tecnico_id}>{t.codigo} · {t.nombre}</option>)}
        </select>
      </Campo>
      <Campo etiqueta="Motivo"><select className="campo-texto" value={f.motivo} onChange={e => setF({ ...f, motivo: e.target.value })}>{ctx.motivosImprevisto.map(m => <option key={m}>{m}</option>)}</select></Campo>
      <Campo etiqueta="Detalle (texto libre)"><input className="campo-texto" placeholder="Ej. Falta de pernos de sujeción necesarios..." value={f.detalle} onChange={e => setF({ ...f, detalle: e.target.value })} /></Campo>
      <Campo etiqueta="Tiempo de afectación (minutos)"><input className="campo-texto font-bold" inputMode="numeric" value={f.minutos} onChange={e => setF({ ...f, minutos: e.target.value })} /></Campo>
      {error && <Aviso tipo="mal">{error}</Aviso>}
    </Modal>
  )
}

/** Ventana "Registrar trabajo no realizado" (motivo obligatorio). */
export function ModalNoRealizado({ trabajos, ctx, inicial, onCerrar, onListo, titulo }: {
  trabajos: Trabajo[]; ctx: ContextoOT; inicial?: string; onCerrar: () => void; onListo: () => void; titulo: string
}) {
  const toast = useToast()
  const activos = trabajos.filter(t => !t.anulado && t.estado !== 'no_realizado' && t.estado !== 'terminado')
  const [f, setF] = useState({ id: inicial || activos[0]?.id || '', motivo: ctx.motivosNoRealizado[0] || '', detalle: '' })
  const [error, setError] = useState('')
  return (
    <Modal titulo="Registrar trabajo no realizado" icono="fa-ban" onCerrar={onCerrar}
      pie={<><button className="btn-gris" onClick={onCerrar}>Cancelar</button><button className="btn-rojo" onClick={async () => {
        setError('')
        if (!f.id) return setError('Debe seleccionar un trabajo válido registrado en la OT.')
        if (!f.motivo) return setError('Debe ingresar el motivo de no ejecución.')
        try { ok(await supabase.from('ot_trabajos').update({ estado: 'no_realizado', motivo_no_realizado: f.motivo, detalle_no_realizado: f.detalle || null }).eq('id', f.id)); toast('Trabajo no realizado', 'Agregado a la lista de seguimiento de pendientes.', 'alerta'); onListo() }
        catch (e) { setError(mensajeError(e)) }
      }}>Registrar trabajo pendiente</button></>}>
      <Campo etiqueta="Vehículo / OT"><input readOnly className="campo-texto bg-slate-100 font-bold" value={titulo} /></Campo>
      <Campo etiqueta="Trabajo de la orden">
        <select className="campo-texto" value={f.id} onChange={e => setF({ ...f, id: e.target.value })}>
          {!activos.length && <option value="">⚠️ No hay trabajos pendientes en la orden</option>}
          {activos.map(t => <option key={t.id} value={t.id}>{t.sistema_nombre.toUpperCase()} {'>'} {t.elemento_nombre || '—'} {'>'} {t.intervencion_nombre} ({Number(t.cantidad)} u.)</option>)}
        </select>
      </Campo>
      <Campo etiqueta="Motivo de no ejecución"><select className="campo-texto" value={f.motivo} onChange={e => setF({ ...f, motivo: e.target.value })}>{ctx.motivosNoRealizado.map(m => <option key={m}>{m}</option>)}</select></Campo>
      <Campo etiqueta="Detalle (texto libre)"><textarea className="campo-texto" rows={3} placeholder="Ej. No hay electrodos 6013 disponibles en bodega..." value={f.detalle} onChange={e => setF({ ...f, detalle: e.target.value })} /></Campo>
      {error && <Aviso tipo="mal">{error}</Aviso>}
    </Modal>
  )
}

/** Ventana "Editar registro de trabajo". */
export function ModalEditarTrabajo({ t, ctx, aplicaComplejidad, onCerrar, onListo }: { t: Trabajo; ctx: ContextoOT; aplicaComplejidad: boolean; onCerrar: () => void; onListo: () => void }) {
  const toast = useToast()
  const [d, setD] = useState(datosDeTrabajo(t))
  const [error, setError] = useState('')
  return (
    <Modal titulo={`Editar registro de trabajo #${t.numero_linea}`} icono="fa-pen-to-square" onCerrar={onCerrar}
      pie={<><button className="btn-gris" onClick={onCerrar}>Cancelar</button><button className="btn-azul" onClick={async () => {
        setError('')
        const r = paraGuardar(d, t.taller); if (r.error) return setError(r.error)
        try { ok(await supabase.rpc('guardar_trabajo', { p: { ...r.p, id: t.id } })); toast('Registro actualizado', 'Los cambios se guardaron correctamente.'); onListo() }
        catch (e) { setError(mensajeError(e)) }
      }}>Guardar cambios</button></>}>
      <p className="text-xs font-bold text-slate-700">{t.sistema_nombre.toUpperCase()} {'>'} {t.elemento_nombre || '—'} {'>'} {t.intervencion_nombre}</p>
      <FormTrabajo d={d} set={setD} ctx={ctx} taller={t.taller} aplicaComplejidad={aplicaComplejidad} horasUnitarias={Number(t.horas_unitarias)} />
      {error && <Aviso tipo="mal">{error}</Aviso>}
    </Modal>
  )
}

/** Carga los catálogos y el estado de la OT que usan los formularios. */
export async function cargarContextoOT(ot: string | null, tecnicos: Tecnico[], leerLista: (l: string, t?: Taller) => Promise<string[]>, taller?: Taller): Promise<ContextoOT> {
  const [complejidades, causas, motivosImprevisto, motivosNoRealizado, motivosDescarte, solicitudes, hallazgos] = await Promise.all([
    supabase.from('complejidades').select('*').order('orden').then(r => ok(r) as Complejidad[]),
    leerLista('causa_dano', taller), leerLista('motivo_imprevisto', taller), leerLista('motivo_no_realizado', taller), leerLista('motivo_descarte', taller),
    ot ? supabase.from('ot_solicitudes').select('*').eq('orden_trabajo_id', ot).order('numero_linea').then(r => ok(r) as Solicitud[]) : Promise.resolve([] as Solicitud[]),
    ot ? supabase.from('ot_hallazgos').select('*').eq('orden_trabajo_id', ot).order('numero_linea').then(r => ok(r) as Hallazgo[]) : Promise.resolve([] as Hallazgo[])
  ])
  return { tecnicos, complejidades, causas, motivosImprevisto, motivosNoRealizado, motivosDescarte, solicitudes, hallazgos }
}
