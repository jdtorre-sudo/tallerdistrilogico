// La OT completa por segmentos (sección 4). Cada segmento es un bloque plegable con su propio estado.
import { useEffect, useState, type ReactNode } from 'react'
import { Link, useParams } from 'react-router-dom'
import { supabase, ok, mensajeError } from '../lib/supabase'
import { cargarCatalogos, nombreConductor, type Catalogos } from '../lib/catalogos'
import { useSesion } from '../lib/sesion'
import { ESTADOS_OT, TALLERES, duracion, fechaHora, lectura, nombreDano, nombreEstado, nombreResultado, nombreTaller } from '../lib/formato'
import { ESTADOS_HALLAZGO, ESTADOS_SOLICITUD, horasTxt, leerLista, leerTrabajos, nombreTipoOT, tituloOT, type FilaOT, type Imprevisto, type Trabajo } from '../lib/ot'
import type { Taller } from '../lib/tipos'
import Fotos from '../components/Fotos'
import { Aviso, BotonAnular, Campo, Cargando, Modal, Pildora, type TonoInsignia, useToast } from '../components/ui'
import { ModalEditarTrabajo, ModalNoRealizado, Novedades, TablaTrabajos, cargarContextoOT, type ContextoOT } from '../components/ot/Trabajos'

function Segmento({ n, titulo, icono, estado, tono = 'neutro', abierto = true, children }: { n: number | string; titulo: string; icono: string; estado?: string; tono?: TonoInsignia; abierto?: boolean; children: ReactNode }) {
  return (
    <details open={abierto} className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden group" data-segmento={n}>
      <summary className="px-5 py-3 bg-slate-50/70 flex items-center gap-3 cursor-pointer list-none">
        <span className="w-7 h-7 rounded-lg bg-industrial-navy text-white text-[11px] font-black flex items-center justify-center shrink-0">{n}</span>
        <i className={`fa-solid ${icono} text-industrial-red`} />
        <h3 className="font-bold text-slate-800 text-sm flex-1">{titulo}</h3>
        {estado && <Pildora tipo={tono}>{estado}</Pildora>}
        <i className="fa-solid fa-chevron-down text-slate-400 text-xs group-open:rotate-180 transition-transform" />
      </summary>
      <div className="p-5 border-t border-slate-200 space-y-4">{children}</div>
    </details>
  )
}

interface Datos {
  ot: FilaOT & Record<string, any>; trabajos: Trabajo[]; imprevistos: Imprevisto[]; ctx: ContextoOT
  checklist: { item_checklist_id: string; resultado: string; observacion: string | null }[]; danos: any[]
  observaciones: { id: string; fecha_hora: string; texto: string; tecnico_codigo: string | null; tecnico_nombre: string | null; anulado: boolean }[]
  historial: any[]; inspecciones: { sistema_id: string }[]
}

export default function OrdenDetalle() {
  const { id = '' } = useParams()
  const { tiene, perfil } = useSesion()
  const toast = useToast()
  const opera = tiene('operar_ot')
  const [cat, setCat] = useState<Catalogos | null>(null)
  const [d, setD] = useState<Datos | null>(null)
  const [error, setError] = useState('')
  const [modal, setModal] = useState<null | { editar: Trabajo } | { nr: Trabajo } | { anular: Trabajo } | { cerrarSol: { id: string; estado: string } } | { descartarH: string } | 'hallazgo' | 'solicitud'>(null)

  async function cargar() {
    try {
      const c = cat || await cargarCatalogos(); setCat(c)
      const [base, extra, trabajos, imprevistos, ctx, checklist, danos, observaciones, historial, inspecciones] = await Promise.all([
        supabase.from('v_ot_lista').select('*').eq('id', id).single().then(r => ok(r)),
        supabase.from('ordenes_trabajo').select('*').eq('id', id).single().then(r => ok(r)),
        leerTrabajos(id),
        supabase.from('ot_imprevistos').select('*').eq('orden_trabajo_id', id).order('creado_en').then(r => ok(r) as Imprevisto[]),
        cargarContextoOT(id, c.tecnicos, leerLista),
        supabase.from('ot_checklist').select('*').eq('orden_trabajo_id', id).then(r => ok(r) as any[]),
        supabase.from('danos_vehiculo').select('*').eq('orden_trabajo_id', id).eq('anulado', false).order('numero_marca').then(r => ok(r) as any[]),
        supabase.from('v_observaciones_ot').select('*').eq('orden_trabajo_id', id).order('fecha_hora').then(r => ok(r) as any[]),
        supabase.from('historial_estados_ot').select('*').eq('orden_trabajo_id', id).order('fecha_hora').then(r => ok(r) as any[]),
        supabase.from('ot_inspecciones').select('sistema_id').eq('orden_trabajo_id', id).eq('anulado', false).then(r => ok(r) as any[])
      ])
      setD({ ot: { ...(extra as any), ...(base as any) }, trabajos, imprevistos, ctx, checklist, danos, observaciones, historial, inspecciones })
    } catch (e) { setError(mensajeError(e)) }
  }
  useEffect(() => { cargar() }, [id])
  if (error) return <Aviso tipo="mal">{error}</Aviso>
  if (!d || !cat) return <Cargando />
  const { ot, trabajos, ctx } = d
  if (ot.formato === 'anterior') return <Aviso tipo="info">La {ot.numero} es del sistema anterior. Sus datos se conservan y se consultan en la exportación completa.</Aviso>
  const cerrada = ot.estado === 'entregado' || ot.anulado
  const puede = opera && !cerrada
  const veh = cat.vehiculos.find(v => v.id === ot.vehiculo_id)
  const miTecnico = cat.tecnicos.find(t => t.usuario_id === perfil?.id)
  const asignado = !!miTecnico && trabajos.some(t => !t.anulado && t.tecnicos.some(x => x.tecnico_id === miTecnico.id))
  const titulo = `${tituloOT(ot)} · ${ot.numero}`
  const activos = trabajos.filter(t => !t.anulado)
  const porTaller = (tl: Taller) => activos.filter(t => t.taller === tl)
  const sols = ctx.solicitudes.filter(s => !s.anulado), hall = ctx.hallazgos.filter(h => !h.anulado)
  const deChofer = activos.filter(t => t.origen === 'chofer').length, deHallazgo = activos.filter(t => t.origen === 'hallazgo').length

  async function accion(f: () => PromiseLike<{ data: unknown; error: any }>, titulo: string, msg?: string) {
    try { ok(await f()); toast(titulo, msg); await cargar(); return true } catch (e) { toast('No se pudo', mensajeError(e), 'alerta'); return false }
  }
  const estadoTrab = (tl: Taller) => {
    const l = porTaller(tl); if (!l.length) return { t: 'Sin trabajos', tono: 'neutro' as TonoInsignia }
    const ab = l.filter(t => t.estado === 'pendiente' || t.estado === 'en_proceso').length
    return ab ? { t: `${l.length - ab}/${l.length} cerrados`, tono: 'alerta' as TonoInsignia } : { t: `${l.length} cerrados`, tono: 'ok' as TonoInsignia }
  }

  return (
    <section className="space-y-5">
      {/* CABECERA */}
      <div className="bg-industrial-navy text-white rounded-2xl p-4 flex flex-col md:flex-row md:items-center gap-3 border-b-4 border-industrial-red">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <span className="font-mono text-xs bg-slate-800 border border-slate-700 px-2 py-0.5 rounded-lg">{ot.numero}</span>
            <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-industrial-red/20 text-red-300 border border-industrial-red/30 uppercase">{nombreTipoOT(ot.motivo_ingreso)}</span>
            {ot.inmovilizado && <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-red-600 text-white">INMOVILIZADO</span>}
            {ot.propiedad === 'rentado' && <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-amber-500/20 text-amber-300 border border-amber-500/40">RENTADO · {ot.cliente}</span>}
          </div>
          <h2 className="text-lg font-bold mt-1 truncate"><i className="fa-solid fa-truck-front mr-2 text-slate-400" />{tituloOT(ot)}</h2>
          <p className="text-xs text-slate-400">Ingreso {fechaHora(ot.fecha_apertura)} · {cerrada ? (ot.anulado ? 'Anulada' : `Cerrada ${fechaHora(ot.fecha_cierre)}`) : `Vehículo parado ${duracion(ot.horas_parado_actual)}`} · {horasTxt(ot.horas_estandar)} estándar</p>
        </div>
        <div className="flex flex-wrap gap-2 items-center">
          {puede ? (
            <select aria-label="Estado de la OT" className="bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-xs font-bold" value={ot.estado}
              onChange={e => accion(() => supabase.rpc('cambiar_estado_ot', { p_ot: ot.id, p_estado: e.target.value, p_comentario: null }), 'Estado actualizado', `La OT pasó a “${nombreEstado(e.target.value)}”.`)}>
              {ESTADOS_OT.map(x => <option key={x.k} value={x.k}>{x.n}</option>)}
            </select>
          ) : <span className="px-3 py-1.5 rounded-xl font-bold text-xs bg-slate-800 border border-slate-700">{ot.anulado ? 'ANULADA' : nombreEstado(ot.estado).toUpperCase()}</span>}
          {puede && <>
            <Link to={`/ambiente/mecanica?ot=${ot.id}`} className="bg-slate-700 hover:bg-slate-600 px-3 py-2 rounded-xl text-xs font-bold border border-slate-600"><i className="fa-solid fa-screwdriver-wrench mr-1" />Mecánica</Link>
            <Link to={`/ambiente/soldadura?ot=${ot.id}`} className="bg-industrial-red hover:bg-industrial-darkred px-3 py-2 rounded-xl text-xs font-bold"><i className="fa-solid fa-fire-flame-curved mr-1" />Soldadura</Link>
          </>}
        </div>
      </div>

      {/* SEGMENTO 1 */}
      <Segmento n={1} titulo="Vehículo y recepción" icono="fa-truck-front" estado="Recibido" tono="ok" abierto={false}>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-xs">
          {[['Vehículo', tituloOT(ot)], ['Tipo', ot.tipo_vehiculo || '—'], ['Marca / modelo', veh ? [veh.marca, veh.modelo].filter(Boolean).join(' ') : '—'], ['Centro de costo', ot.centro_costo || '—'],
            ['Chofer', nombreConductor(cat.conductores.find(c => c.id === ot.conductor_id)) || '—'], ['Ingreso', fechaHora(ot.fecha_apertura)],
            [ot.unidad_medida === 'horas' ? 'Horómetro' : 'Kilometraje', ot.lectura != null ? lectura(ot.lectura, ot.unidad_medida || 'km') : '—'], ['Combustible', ot.combustible || '—']].map(([k, v]) => (
            <div key={k} className="bg-slate-50 p-3 rounded-xl border border-slate-200"><p className="text-[10px] font-bold uppercase text-slate-400">{k}</p><p className="font-bold text-slate-800">{v}</p></div>
          ))}
        </div>
        {ot.observaciones_recepcion && <p className="text-xs"><b>Observaciones:</b> {ot.observaciones_recepcion}</p>}
        {d.checklist.length > 0 && <div className="text-xs"><p className="font-bold text-slate-600 uppercase mb-1">Checklist de recepción</p>
          <div className="flex flex-wrap gap-1">{d.checklist.map(c => { const it = cat.items.find(i => i.id === c.item_checklist_id)
            return <Pildora key={c.item_checklist_id} tipo={c.resultado === 'ok' ? 'ok' : c.resultado === 'falta' ? 'alerta' : 'mal'}>{it?.nombre}: {nombreResultado(c.resultado)}{c.observacion ? ` (${c.observacion})` : ''}</Pildora> })}</div></div>}
        {d.danos.length > 0 && <div className="text-xs"><p className="font-bold text-slate-600 uppercase mb-1">Daños registrados</p>
          {d.danos.map(x => <p key={x.id}><span className="bg-red-700 text-white rounded-full px-1.5 font-bold mr-1">{x.numero_marca}</span>{nombreDano(x.tipo_dano)} · {x.vista} · {x.descripcion || 'sin descripción'}</p>)}</div>}
        <Fotos titulo="Fotos de la recepción" tabla="ordenes_trabajo" registro={ot.id} categoria="recepcion" carpeta={ot.numero} puedeSubir={puede} />
      </Segmento>

      {/* SEGMENTO 2 */}
      <Segmento n={2} titulo="Solicitud del chofer" icono="fa-comment-dots" estado={sols.some(s => s.estado === 'pendiente') ? `${sols.filter(s => s.estado === 'pendiente').length} pendientes` : sols.length ? 'Resuelto' : 'Sin líneas'} tono={sols.some(s => s.estado === 'pendiente') ? 'alerta' : 'ok'}>
        {!sols.length && <p className="text-slate-400 italic text-xs">El chofer no reportó novedades.</p>}
        <div className="space-y-2">
          {sols.map(s => {
            const trabs = activos.filter(t => t.solicitud_id === s.id)
            return (
              <div key={s.id} className="bg-slate-50 p-3 rounded-2xl border border-slate-200 text-xs flex flex-col sm:flex-row sm:items-center gap-2">
                <span className="font-mono text-slate-400">#{s.numero_linea}</span>
                <div className="flex-1"><p className="font-bold text-slate-800">{s.descripcion}</p>
                  <p className="text-[11px] text-slate-500">Sugerido: {nombreTaller(s.taller_sugerido)}{trabs.length ? ` · ${trabs.length} trabajo(s): ${trabs.map(t => `#${t.numero_linea} ${t.intervencion_nombre}`).join(', ')}` : ''}{s.motivo ? ` · Motivo: ${s.motivo}` : ''}{s.comentario ? ` — ${s.comentario}` : ''}</p></div>
                <Pildora tipo={s.estado === 'atendida' ? 'ok' : s.estado === 'pendiente' ? 'alerta' : 'neutro'}>{ESTADOS_SOLICITUD[s.estado]}</Pildora>
                {puede && s.estado === 'pendiente' && <div className="flex gap-1">
                  <Link to={`/ambiente/${s.taller_sugerido}?ot=${ot.id}`} className="btn-azul py-1.5 px-2.5">Atender</Link>
                  <button className="btn-gris py-1.5 px-2.5" onClick={() => setModal({ cerrarSol: { id: s.id, estado: 'no_realizada' } })}>No realizada</button>
                  <button className="btn-gris py-1.5 px-2.5" onClick={() => setModal({ cerrarSol: { id: s.id, estado: 'descartada' } })}>Descartar</button>
                </div>}
              </div>
            )
          })}
        </div>
        {puede && <button className="btn-gris" onClick={() => setModal('solicitud')}><i className="fa-solid fa-plus" />Agregar línea</button>}
      </Segmento>

      {/* SEGMENTO 3 */}
      <Segmento n={3} titulo="Hallazgos en la revisión" icono="fa-magnifying-glass" estado={hall.some(h => h.estado === 'pendiente') ? `${hall.filter(h => h.estado === 'pendiente').length} por aprobar` : `${hall.length} hallazgos`} tono={hall.some(h => h.estado === 'pendiente') ? 'alerta' : 'info'}>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
          <div className="bg-slate-50 p-3 rounded-2xl border border-slate-200"><p className="text-[10px] font-bold uppercase text-slate-400">Trabajos por solicitud del chofer</p><p className="text-xl font-black text-industrial-navy">{deChofer}</p></div>
          <div className="bg-slate-50 p-3 rounded-2xl border border-slate-200"><p className="text-[10px] font-bold uppercase text-slate-400">Trabajos por hallazgos</p><p className="text-xl font-black text-industrial-red">{deHallazgo}</p></div>
          <div className="bg-slate-50 p-3 rounded-2xl border border-slate-200"><p className="text-[10px] font-bold uppercase text-slate-400">% de hallazgos</p><p className="text-xl font-black text-amber-600">{deChofer + deHallazgo ? Math.round(deHallazgo / (deChofer + deHallazgo) * 100) : 0} %</p></div>
        </div>
        {!hall.length && <p className="text-slate-400 italic text-xs">Sin hallazgos registrados. El supervisor los registra aquí o desde la cápsula (origen “Hallazgo”).</p>}
        <div className="space-y-2">
          {hall.map(h => (
            <div key={h.id} className="bg-slate-50 p-3 rounded-2xl border border-slate-200 text-xs flex flex-col sm:flex-row sm:items-center gap-2">
              <span className="font-mono text-slate-400">#{h.numero_linea}</span>
              <div className="flex-1"><p className="font-bold text-slate-800">{h.descripcion}</p>
                <p className="text-[11px] text-slate-500">{nombreTaller(h.taller)}{activos.some(t => t.hallazgo_id === h.id) ? ` · trabajo(s): ${activos.filter(t => t.hallazgo_id === h.id).map(t => '#' + t.numero_linea).join(', ')}` : ''}{h.motivo ? ` · Motivo: ${h.motivo}` : ''}</p></div>
              <Pildora tipo={h.estado === 'aprobado' ? 'ok' : h.estado === 'pendiente' ? 'alerta' : 'neutro'}>{ESTADOS_HALLAZGO[h.estado]}</Pildora>
              {puede && h.estado === 'pendiente' && <div className="flex gap-1">
                <Link to={`/ambiente/${h.taller}?ot=${ot.id}`} className="btn-azul py-1.5 px-2.5" title="Se aprueba al registrar su trabajo con origen Hallazgo">Aprobar y registrar trabajo</Link>
                <button className="btn-gris py-1.5 px-2.5" onClick={() => setModal({ descartarH: h.id })}>Descartar</button>
              </div>}
            </div>
          ))}
        </div>
        {puede && <button className="btn-gris" onClick={() => setModal('hallazgo')}><i className="fa-solid fa-plus" />Registrar hallazgo</button>}
      </Segmento>

      {/* SEGMENTOS 4 Y 5 */}
      {(['mecanica', 'soldadura'] as Taller[]).map(tl => {
        const e = estadoTrab(tl)
        const campo = tl === 'mecanica' ? 'obs_supervisor_mecanica' : 'obs_supervisor_soldadura'
        return (
          <Segmento key={tl} n={tl === 'mecanica' ? 4 : 5} titulo={`Trabajos de ${nombreTaller(tl).toLowerCase()}`} icono={tl === 'mecanica' ? 'fa-screwdriver-wrench' : 'fa-fire-flame-curved'} estado={e.t} tono={e.tono}>
            <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden">
              <TablaTrabajos trabajos={trabajos.filter(t => t.taller === tl)} puedeOperar={puede} onEditar={t => setModal({ editar: t })} onNoRealizado={t => setModal({ nr: t })} onAnular={t => setModal({ anular: t })}
                onEstado={(t, est) => accion(() => supabase.from('ot_trabajos').update({ estado: est }).eq('id', t.id), 'Estado actualizado', `Trabajo #${t.numero_linea}.`)} />
            </div>
            {puede && <Link to={`/ambiente/${tl}?ot=${ot.id}`} className="btn-azul"><i className="fa-solid fa-cubes" />Abrir ambiente {nombreTaller(tl)}</Link>}
            {tl === 'soldadura' && porTaller('soldadura').length > 0 && (
              <div className="space-y-3"><p className="text-[11px] font-bold uppercase tracking-wider text-slate-500">Fotos de antes y después</p>
                {porTaller('soldadura').map(t => (
                  <div key={t.id} className="bg-slate-50 p-3 rounded-2xl border border-slate-200 space-y-2">
                    <p className="text-xs font-bold text-slate-700">#{t.numero_linea} {t.sistema_nombre.toUpperCase()} {'>'} {t.elemento_nombre || '—'} {'>'} {t.intervencion_nombre}</p>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      <Fotos titulo="Antes" tabla="ot_trabajos" registro={t.id} categoria="antes" carpeta={ot.numero} puedeSubir={puede} />
                      <Fotos titulo="Después" tabla="ot_trabajos" registro={t.id} categoria="despues" carpeta={ot.numero} puedeSubir={puede} />
                    </div>
                  </div>
                ))}
              </div>
            )}
            <ObservacionSupervisor valor={ot[campo] || ''} editable={puede} etiqueta={`Observación del supervisor (segmento ${tl === 'mecanica' ? 4 : 5})`}
              onGuardar={v => accion(() => supabase.from('ordenes_trabajo').update({ [campo]: v || null }).eq('id', ot.id), 'Observación guardada')} />
          </Segmento>
        )
      })}

      <Segmento n="!" titulo="Novedades: imprevistos y no realizados" icono="fa-triangle-exclamation" estado={`${d.imprevistos.filter(i => !i.anulado && i.estado === 'pendiente').length} por validar`} tono={d.imprevistos.some(i => !i.anulado && i.estado === 'pendiente') ? 'alerta' : 'neutro'} abierto={false}>
        <Novedades trabajos={trabajos} imprevistos={d.imprevistos} ctx={ctx} puedeOperar={puede} onCambio={cargar} />
      </Segmento>

      <Segmento n={6} titulo="Repuestos e insumos" icono="fa-boxes-stacked" estado="Fase 3" abierto={false}>
        <p className="text-xs text-slate-500">En la Fase 3 bodega asigna aquí los repuestos (generan la salida en el kardex con la OT, el móvil y el km).</p>
      </Segmento>
      <Segmento n={7} titulo="Trabajos de terceros" icono="fa-handshake" estado="Fase 4" abierto={false}>
        <p className="text-xs text-slate-500">En la Fase 4: talleres externos, cotizaciones con cuadro comparativo, aprobación por monto, OC, factura y garantía.</p>
      </Segmento>

      {/* SEGMENTO 8 */}
      <Segmento n={8} titulo="Observaciones de técnicos" icono="fa-user-pen" estado={`${d.observaciones.filter(o => !o.anulado).length}`} tono="info">
        <p className="text-[11px] text-slate-500">Solo escriben los técnicos asignados a la OT. Fecha, hora y código se ponen solos. No se editan ni se borran: para corregir, se agrega otra observación.</p>
        <div className="space-y-2">
          {d.observaciones.filter(o => !o.anulado).map(o => (
            <div key={o.id} className="bg-slate-50 border-l-4 border-industrial-blue p-3 rounded-r-2xl text-xs">
              <p className="text-[11px] text-slate-500"><b className="text-industrial-blue">{o.tecnico_codigo}</b> · {o.tecnico_nombre} · {fechaHora(o.fecha_hora)}</p>
              <p className="text-slate-800 mt-0.5 whitespace-pre-wrap">{o.texto}</p>
            </div>
          ))}
          {!d.observaciones.length && <p className="text-slate-400 italic text-xs">Sin observaciones de técnicos.</p>}
        </div>
        {asignado && !cerrada && <NuevaObservacion codigo={miTecnico!.codigo} onEnviar={t => accion(() => supabase.from('comentarios_ot').insert({ orden_trabajo_id: ot.id, texto: t }), 'Observación guardada', 'Quedó registrada con su código.')} />}
        {!asignado && miTecnico && !cerrada && <p className="text-[11px] text-slate-400">Usted no está asignado a trabajos de esta OT, por eso no puede escribir aquí.</p>}
      </Segmento>

      {/* HISTORIAL Y ANULACIÓN */}
      <details className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5 text-xs">
        <summary className="cursor-pointer font-bold text-slate-700 uppercase">Historial de estados</summary>
        <table className="w-full mt-3"><tbody className="divide-y divide-slate-100">{d.historial.map(h => (
          <tr key={h.id}><td className="py-2 pr-3">{fechaHora(h.fecha_hora)}</td><td className="py-2 pr-3 font-bold">{nombreEstado(h.estado_nuevo)}</td><td className="py-2 pr-3">{cat.usuarios.find(u => u.id === h.usuario_id)?.nombre_completo}</td><td className="py-2 text-slate-500">{h.comentario}</td></tr>))}</tbody></table>
      </details>
      {puede && (
        <div className="flex flex-wrap gap-3 items-center justify-between border-2 border-dashed border-red-200 rounded-2xl p-4 text-xs">
          <span>Anular esta OT (por ejemplo, si se abrió por error). El vehículo podrá ingresar de nuevo. No se borra nada.</span>
          <BotonAnular texto="Anular OT" onAnular={async m => { await accion(() => supabase.from('ordenes_trabajo').update({ anulado: true, anulado_motivo: m }).eq('id', ot.id), 'OT anulada', undefined) }} />
        </div>
      )}
      {cerrada && <Aviso tipo={ot.anulado ? 'mal' : 'ok'}>{ot.anulado ? `OT anulada: ${ot.anulado_motivo}` : 'OT cerrada: ya no se puede modificar.'}</Aviso>}

      {/* VENTANAS */}
      {modal && typeof modal === 'object' && 'editar' in modal && <ModalEditarTrabajo t={modal.editar} ctx={ctx} aplicaComplejidad={!!cat.sistemas.find(s => s.id === modal.editar.sistema_id)?.aplica_complejidad}
        onCerrar={() => setModal(null)} onListo={() => { setModal(null); cargar() }} />}
      {modal && typeof modal === 'object' && 'nr' in modal && <ModalNoRealizado trabajos={trabajos} ctx={ctx} titulo={titulo} inicial={modal.nr.id} onCerrar={() => setModal(null)} onListo={() => { setModal(null); cargar() }} />}
      {modal && typeof modal === 'object' && 'anular' in modal && (
        <Modal titulo={`Anular trabajo #${modal.anular.numero_linea}`} icono="fa-ban" onCerrar={() => setModal(null)}>
          <p>{modal.anular.sistema_nombre.toUpperCase()} {'>'} {modal.anular.intervencion_nombre}. Queda anulado con su motivo; no se borra.</p>
          <BotonAnular texto="Anular trabajo" onAnular={async m => { if (await accion(() => supabase.from('ot_trabajos').update({ anulado: true, anulado_motivo: m }).eq('id', modal.anular.id), 'Trabajo anulado')) setModal(null) }} />
        </Modal>
      )}
      {modal && typeof modal === 'object' && 'cerrarSol' in modal && <ModalMotivo titulo={modal.cerrarSol.estado === 'descartada' ? 'Descartar línea del chofer' : 'Línea del chofer no realizada'}
        motivos={modal.cerrarSol.estado === 'descartada' ? ctx.motivosDescarte : ctx.motivosNoRealizado} onCerrar={() => setModal(null)}
        onGuardar={async (motivo, comentario) => { if (await accion(() => supabase.from('ot_solicitudes').update({ estado: modal.cerrarSol.estado, motivo, comentario: comentario || null }).eq('id', modal.cerrarSol.id), 'Solicitud actualizada')) setModal(null) }} />}
      {modal && typeof modal === 'object' && 'descartarH' in modal && <ModalMotivo titulo="Descartar hallazgo" motivos={ctx.motivosDescarte} onCerrar={() => setModal(null)}
        onGuardar={async (motivo, comentario) => { if (await accion(() => supabase.from('ot_hallazgos').update({ estado: 'descartado', motivo, comentario: comentario || null }).eq('id', modal.descartarH), 'Hallazgo descartado')) setModal(null) }} />}
      {(modal === 'hallazgo' || modal === 'solicitud') && <ModalLinea titulo={modal === 'hallazgo' ? 'Registrar hallazgo' : 'Agregar línea de la solicitud del chofer'} onCerrar={() => setModal(null)}
        onGuardar={async (descripcion, taller) => {
          const r = modal === 'hallazgo'
            ? await accion(() => supabase.from('ot_hallazgos').insert({ orden_trabajo_id: ot.id, descripcion, taller }), 'Hallazgo registrado', 'Queda pendiente de aprobar.')
            : await accion(() => supabase.from('ot_solicitudes').insert({ orden_trabajo_id: ot.id, descripcion, taller_sugerido: taller }), 'Línea agregada')
          if (r) setModal(null)
        }} />}
    </section>
  )
}

function ObservacionSupervisor({ valor, editable, etiqueta, onGuardar }: { valor: string; editable: boolean; etiqueta: string; onGuardar: (v: string) => void }) {
  const [v, setV] = useState(valor)
  useEffect(() => setV(valor), [valor])
  return (
    <div className="bg-blue-50/60 p-4 rounded-2xl border border-blue-200 space-y-2 text-xs">
      <p className="font-extrabold text-industrial-blue uppercase">{etiqueta}</p>
      {editable ? <>
        <textarea className="campo-texto" rows={2} value={v} onChange={e => setV(e.target.value)} placeholder="Espacio propio del supervisor / jefe de patio" />
        {v !== valor && <button className="btn-azul" onClick={() => onGuardar(v)}>Guardar observación</button>}
      </> : <p className="text-slate-700">{valor || <span className="italic text-slate-400">Sin observación.</span>}</p>}
    </div>
  )
}

function NuevaObservacion({ codigo, onEnviar }: { codigo: string; onEnviar: (t: string) => Promise<boolean> }) {
  const [t, setT] = useState('')
  return (
    <div className="space-y-2">
      <textarea id="nueva-observacion" className="campo-texto" rows={3} placeholder={`Su observación (queda con su código ${codigo}, la fecha y la hora)`} value={t} onChange={e => setT(e.target.value)} />
      <button className="btn-rojo" disabled={t.trim().length < 3} onClick={async () => { if (await onEnviar(t.trim())) setT('') }}><i className="fa-solid fa-paper-plane" />Guardar observación</button>
    </div>
  )
}

function ModalMotivo({ titulo, motivos, onCerrar, onGuardar }: { titulo: string; motivos: string[]; onCerrar: () => void; onGuardar: (m: string, c: string) => void }) {
  const [m, setM] = useState(motivos[0] || ''); const [c, setC] = useState('')
  return (
    <Modal titulo={titulo} icono="fa-ban" onCerrar={onCerrar} pie={<><button className="btn-gris" onClick={onCerrar}>Cancelar</button><button className="btn-rojo" disabled={!m} onClick={() => onGuardar(m, c)}>Guardar</button></>}>
      <Campo etiqueta="Motivo (obligatorio)"><select className="campo-texto" value={m} onChange={e => setM(e.target.value)}>{motivos.map(x => <option key={x}>{x}</option>)}</select></Campo>
      <Campo etiqueta="Comentario"><textarea className="campo-texto" rows={2} value={c} onChange={e => setC(e.target.value)} /></Campo>
    </Modal>
  )
}

function ModalLinea({ titulo, onCerrar, onGuardar }: { titulo: string; onCerrar: () => void; onGuardar: (d: string, t: string) => void }) {
  const [d, setD] = useState(''); const [t, setT] = useState('mecanica')
  return (
    <Modal titulo={titulo} icono="fa-plus" onCerrar={onCerrar} pie={<><button className="btn-gris" onClick={onCerrar}>Cancelar</button><button className="btn-azul" disabled={d.trim().length < 3} onClick={() => onGuardar(d.trim(), t)}>Guardar</button></>}>
      <Campo etiqueta="Descripción"><input autoFocus className="campo-texto" value={d} onChange={e => setD(e.target.value)} /></Campo>
      <Campo etiqueta="Taller"><div className="flex gap-1.5">{TALLERES.map(x => <button type="button" key={x.k} onClick={() => setT(x.k)}
        className={'flex-1 py-2 border rounded-xl text-xs font-bold ' + (t === x.k ? 'bg-industrial-blue text-white border-industrial-blue' : 'bg-slate-50 text-slate-700 border-slate-200')}>{x.n}</button>)}</div></Campo>
    </Modal>
  )
}
