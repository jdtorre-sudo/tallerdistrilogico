// Ambientes Soldadura y Mecánica (sección 3.1): mismo motor, distinto catálogo.
// Copia la forma de trabajo de referencias/gestion_produccion_soldadura.html:
// grilla de cápsulas "dock", flujo elemento → intervención (horas) → datos, "Inspeccionado OK",
// menú de Novedades, indicadores, novedades y tabla resumen de trabajos.
import { useEffect, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { supabase, ok, mensajeError } from '../lib/supabase'
import { cargarCatalogos } from '../lib/catalogos'
import { useSesion } from '../lib/sesion'
import { fecha, nombreTaller } from '../lib/formato'
import { horasTxt, leerLista, leerOTsAbiertas, leerTrabajos, nombreTipoOT, tituloOT, type FilaOT, type Imprevisto, type Trabajo } from '../lib/ot'
import type { Elemento, Intervencion, Sistema, Taller } from '../lib/tipos'
import { Aviso, BotonAnular, Cargando, Kpi, Modal, Pildora, useToast } from '../components/ui'
import ListaIntervenciones from '../components/ListaIntervenciones'
import { FormTrabajo, ModalEditarTrabajo, ModalImprevisto, ModalNoRealizado, Novedades, TablaTrabajos, cargarContextoOT, datosIniciales, paraGuardar,
  type ContextoOT, type DatosTrabajo } from '../components/ot/Trabajos'

interface Catalogo { sistemas: Sistema[]; elementos: Elemento[]; intervenciones: Intervencion[] }
interface Flujo { paso: 'elemento' | 'intervencion' | 'datos'; elemento: Elemento | null; intervencion: Intervencion | null; d: DatosTrabajo }

export default function Ambiente() {
  const { taller = 'soldadura' } = useParams() as { taller: Taller }
  const [params, setParams] = useSearchParams()
  const otId = params.get('ot')
  const { tiene } = useSesion()
  const puedeOperar = tiene('operar_ot')
  const [ots, setOts] = useState<FilaOT[] | null>(null)
  const [cat, setCat] = useState<Catalogo | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    leerOTsAbiertas().then(setOts).catch(e => setError(mensajeError(e)))
    ;(async () => {
      const sistemas = ok(await supabase.from('sistemas').select('*').eq('taller', taller).eq('activo', true).order('orden').order('nombre')) as Sistema[]
      const ids = sistemas.map(s => s.id)
      const [el, iv] = await Promise.all([
        supabase.from('elementos').select('*').in('sistema_id', ids).eq('activo', true).order('orden').order('nombre'),
        supabase.from('intervenciones').select('*').in('sistema_id', ids).eq('activo', true).order('orden').order('nombre')
      ])
      setCat({ sistemas, elementos: ok(el) as Elemento[], intervenciones: ok(iv) as Intervencion[] })
    })().catch(e => setError(mensajeError(e)))
  }, [taller])

  if (!puedeOperar) return <Aviso tipo="alerta">Los ambientes de taller son para el supervisor (asesor de servicios / jefe de patio) y el maestro.</Aviso>
  if (error) return <Aviso tipo="mal">{error}</Aviso>
  if (!ots || !cat) return <Cargando />
  // Recuerda la última OT usada para pasar de Soldadura a Mecánica sin volver a elegirla.
  let recordada: string | null = null
  try { recordada = sessionStorage.getItem('ot_ambiente') } catch { /* sin almacenamiento */ }
  const ot = ots.find(o => o.id === otId) || (!otId ? ots.find(o => o.id === recordada) : undefined)
  if (ot) { try { sessionStorage.setItem('ot_ambiente', ot.id) } catch { /* sin almacenamiento */ } }
  if (!ot) return <ElegirOT ots={ots} taller={taller} onElegir={id => setParams({ ot: id })} />
  return <Panel key={ot.id + taller} ot={ot} ots={ots} taller={taller} cat={cat} onCambiarOT={id => setParams({ ot: id })} />
}

function ElegirOT({ ots, taller, onElegir }: { ots: FilaOT[]; taller: Taller; onElegir: (id: string) => void }) {
  return (
    <section className="space-y-5">
      <div className="bg-blue-900/10 border-l-4 border-industrial-blue p-4 rounded-r-2xl flex items-start gap-3">
        <i className="fa-solid fa-circle-info text-industrial-blue mt-0.5" />
        <div><h2 className="text-sm font-bold text-slate-900">Ambiente {nombreTaller(taller)}: elija una OT abierta</h2>
          <p className="text-xs text-slate-600">Cada componente tiene su propia cápsula. Elija la orden de trabajo para registrar las intervenciones de {nombreTaller(taller).toLowerCase()}.</p></div>
      </div>
      {!ots.length ? (
        <div className="py-16 text-center bg-slate-50 rounded-3xl border border-dashed border-slate-300">
          <i className="fa-solid fa-clipboard-list text-slate-300 text-4xl mb-3" /><h3 className="font-extrabold text-slate-700 text-sm">No hay OT abiertas</h3>
          <Link to="/ot/nueva" className="btn-rojo mt-3"><i className="fa-solid fa-plus" />Abrir una OT</Link>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {ots.map(o => (
            <button key={o.id} onClick={() => onElegir(o.id)} className="text-left bg-slate-50 p-4 rounded-3xl border border-slate-200 hover:border-industrial-blue transition-all space-y-2 text-xs">
              <div className="flex justify-between items-center border-b border-slate-200 pb-2">
                <span className="font-black text-industrial-blue text-sm"><i className="fa-solid fa-truck-front mr-1" />{tituloOT(o)}</span>
                <span className="bg-slate-200 text-slate-700 text-[10px] font-extrabold px-2 py-0.5 rounded-full font-mono">{o.numero}</span>
              </div>
              <p><b className="text-slate-600">Tipo:</b> {nombreTipoOT(o.motivo_ingreso)} · <b className="text-slate-600">Ingreso:</b> {fecha(o.fecha_apertura)}</p>
              <p className="text-slate-500">{taller === 'soldadura' ? o.trabajos_soldadura : o.trabajos_mecanica} trabajos de {nombreTaller(taller).toLowerCase()} · {o.solicitudes_pendientes} solicitudes pendientes</p>
            </button>
          ))}
        </div>
      )}
    </section>
  )
}

function Panel({ ot, ots, taller, cat, onCambiarOT }: { ot: FilaOT; ots: FilaOT[]; taller: Taller; cat: Catalogo; onCambiarOT: (id: string) => void }) {
  const toast = useToast()
  const nav = useNavigate()
  const { tiene } = useSesion()
  const [ctx, setCtx] = useState<ContextoOT | null>(null)
  const [trabajos, setTrabajos] = useState<Trabajo[]>([])
  const [imprevistos, setImprevistos] = useState<Imprevisto[]>([])
  const [inspecciones, setInspecciones] = useState<{ id: string; sistema_id: string }[]>([])
  const [flujos, setFlujos] = useState<Record<string, Flujo>>({})
  const [menuNov, setMenuNov] = useState(false)
  const [modal, setModal] = useState<null | 'imprevisto' | 'no_realizado' | { editar: Trabajo } | { nr: Trabajo } | { anular: Trabajo }>(null)
  const [error, setError] = useState('')
  const titulo = `${tituloOT(ot)} · ${ot.numero}`

  async function cargar() {
    try {
      const c = await cargarCatalogos()
      const [ctx2, tr, im, ins] = await Promise.all([
        cargarContextoOT(ot.id, c.tecnicos, leerLista, taller), leerTrabajos(ot.id),
        supabase.from('ot_imprevistos').select('*').eq('orden_trabajo_id', ot.id).order('creado_en').then(r => ok(r) as Imprevisto[]),
        supabase.from('ot_inspecciones').select('id,sistema_id').eq('orden_trabajo_id', ot.id).eq('anulado', false).then(r => ok(r) as { id: string; sistema_id: string }[])
      ])
      setCtx(ctx2); setTrabajos(tr); setImprevistos(im); setInspecciones(ins)
    } catch (e) { setError(mensajeError(e)) }
  }
  useEffect(() => { cargar() }, [])
  if (!ctx) return error ? <Aviso tipo="mal">{error}</Aviso> : <Cargando />

  const propios = trabajos.filter(t => t.taller === taller)
  const activos = propios.filter(t => !t.anulado)
  const imps = imprevistos.filter(i => propios.some(t => t.id === i.trabajo_id))
  const intervenidas = cat.sistemas.filter(s => activos.some(t => t.sistema_id === s.id) || inspecciones.some(i => i.sistema_id === s.id)).length

  const abrir = (s: Sistema) => {
    const els = cat.elementos.filter(e => e.sistema_id === s.id)
    setFlujos({ [s.id]: { paso: els.length ? 'elemento' : 'intervencion', elemento: null, intervencion: null, d: datosIniciales(ctx, taller) } })
  }
  const cerrar = (s: Sistema) => setFlujos(f => { const n = { ...f }; delete n[s.id]; return n })
  const setFlujo = (s: Sistema, c: Partial<Flujo>) => setFlujos(f => ({ ...f, [s.id]: { ...f[s.id], ...c } }))

  async function inspeccionadoOK(s: Sistema) {
    try { ok(await supabase.from('ot_inspecciones').insert({ orden_trabajo_id: ot.id, sistema_id: s.id })); toast('Inspección registrada', `${s.nombre.toUpperCase()} marcado como Inspeccionado OK sin novedades.`); cargar() }
    catch (e) { toast('No se pudo', mensajeError(e), 'alerta') }
  }
  async function desmarcar(s: Sistema) {
    const i = inspecciones.find(x => x.sistema_id === s.id); if (!i) return
    try { ok(await supabase.from('ot_inspecciones').update({ anulado: true, anulado_motivo: 'Desmarcado en el ambiente' }).eq('id', i.id)); cargar() } catch (e) { toast('No se pudo', mensajeError(e), 'alerta') }
  }
  async function agregar(s: Sistema, f: Flujo) {
    const r = paraGuardar(f.d, taller)
    if (r.error) { toast('Faltan datos', r.error, 'alerta'); return }
    try {
      ok(await supabase.rpc('guardar_trabajo', { p: { ...r.p, orden_trabajo_id: ot.id, intervencion_id: f.intervencion!.id, elemento_id: f.elemento?.id || null } }))
      cerrar(s); await cargar()
      toast('Trabajo agregado', `Se registró “${f.intervencion!.nombre}” en ${s.nombre.toUpperCase()} exitosamente.`)
    } catch (e) { toast('No se pudo agregar', mensajeError(e), 'alerta') }
  }
  async function cambiarEstado(t: Trabajo, estado: string) {
    try { ok(await supabase.from('ot_trabajos').update({ estado }).eq('id', t.id)); toast('Estado actualizado', `Trabajo #${t.numero_linea}: ${estado.replace('_', ' ')}.`); cargar() } catch (e) { toast('No se pudo', mensajeError(e), 'alerta') }
  }

  return (
    <div className="space-y-6">
      {/* BARRA DE LA OT (como la barra de controles de la maqueta) */}
      <div className="bg-industrial-navy text-white rounded-2xl px-4 py-3 flex flex-wrap items-center gap-3 text-sm">
        <div className="bg-slate-800/90 border border-slate-700 rounded-xl px-3 py-1.5 flex items-center gap-2 shadow-inner">
          <span className="text-xs text-slate-400 font-medium">OT:</span>
          <select aria-label="OT abierta" className="bg-transparent text-white font-bold focus:outline-none cursor-pointer text-xs" value={ot.id} onChange={e => onCambiarOT(e.target.value)}>
            {ots.map(o => <option key={o.id} value={o.id} className="bg-slate-800">{o.numero} · {tituloOT(o)}</option>)}
          </select>
        </div>
        <div className="bg-slate-800/90 border border-slate-700 rounded-xl px-3 py-1.5 flex items-center gap-2 text-xs"><span className="text-slate-400">Tipo:</span><span className="font-semibold">{nombreTipoOT(ot.motivo_ingreso)}</span></div>
        <div className="bg-slate-800/90 border border-slate-700 rounded-xl px-3 py-1.5 flex items-center gap-2 text-xs"><span className="text-slate-400">Ingreso:</span><span className="font-semibold">{fecha(ot.fecha_apertura)}</span></div>
        <div className="px-3 py-1.5 rounded-xl font-bold text-xs bg-amber-500/20 text-amber-400 border border-amber-500/40 flex items-center gap-1.5"><span className="w-2 h-2 rounded-full bg-amber-400 animate-pulse" />EN INSPECCIÓN</div>
        <span className="flex-1" />
        <button onClick={() => nav(`/ot/${ot.id}`)} className="bg-slate-700 hover:bg-slate-600 text-white px-3 py-1.5 rounded-xl text-xs font-bold border border-slate-600"><i className="fa-solid fa-clipboard-list mr-1" />Ver OT</button>
        {tiene('editar_catalogos') && <button onClick={() => nav(`/maestros/${taller}`)} className="bg-slate-700 hover:bg-slate-600 text-white px-3 py-1.5 rounded-xl text-xs font-bold border border-slate-600" title="Gestionar catálogo"><i className="fa-solid fa-gear mr-1" />Catálogo</button>}
      </div>

      {/* BANNER + MINI CÁPSULA DE NOVEDADES */}
      <div className="bg-blue-900/10 border-l-4 border-industrial-blue p-4 rounded-r-2xl flex flex-col md:flex-row justify-between items-start md:items-center gap-3">
        <div className="flex items-start gap-3">
          <i className="fa-solid fa-circle-info text-industrial-blue mt-0.5" />
          <div><h2 className="text-sm font-bold text-slate-900">Panel de cápsulas independientes de inspección</h2>
            <p className="text-xs text-slate-600">Cada componente posee su propia cápsula. Seleccione una cápsula para desplegar su flujo interno de registro.</p></div>
        </div>
        <div className="flex items-center gap-3 w-full md:w-auto justify-between md:justify-end">
          <div className="hidden sm:flex items-center gap-2 text-xs font-semibold">
            <span className="flex items-center gap-1 text-slate-500"><span className="w-3 h-3 bg-slate-300 rounded-full" />Pendiente</span>
            <span className="flex items-center gap-1 text-emerald-600"><span className="w-3 h-3 bg-emerald-500 rounded-full" />Inspeccionado OK</span>
            <span className="flex items-center gap-1 text-amber-600"><span className="w-3 h-3 bg-amber-500 rounded-full" />Con trabajos</span>
          </div>
          <div className="relative">
            <button onClick={() => setMenuNov(!menuNov)} className="bg-amber-500 hover:bg-amber-600 text-slate-950 px-3.5 py-1.5 rounded-xl text-xs font-bold shadow flex items-center gap-1.5 border border-amber-400">
              <i className="fa-solid fa-triangle-exclamation" /><span>NOVEDADES ▾</span>
            </button>
            {menuNov && (
              <div className="absolute right-0 mt-2 w-72 bg-white rounded-2xl shadow-2xl border border-slate-200 z-30 p-2 space-y-1">
                <div className="px-3 py-1.5 border-b border-slate-100 flex justify-between items-center"><span className="text-[10px] font-extrabold uppercase text-slate-400">Registrar novedad</span>
                  <button onClick={() => setMenuNov(false)} className="text-slate-400 hover:text-slate-600 text-xs">✕</button></div>
                <button onClick={() => { setMenuNov(false); setModal('imprevisto') }} className="w-full text-left p-2.5 hover:bg-amber-50 rounded-xl flex items-start gap-2.5">
                  <div className="p-1.5 bg-amber-100 text-amber-700 rounded-lg mt-0.5"><i className="fa-regular fa-clock" /></div>
                  <div><p className="text-xs font-bold text-slate-800">🕒 IMPREVISTO DURANTE EL TRABAJO</p><p className="text-[11px] text-slate-500">Registrar demora, falta de pernos o interrupción.</p></div>
                </button>
                <div className="border-t border-slate-100 my-1" />
                <button onClick={() => { setMenuNov(false); setModal('no_realizado') }} className="w-full text-left p-2.5 hover:bg-red-50 rounded-xl flex items-start gap-2.5">
                  <div className="p-1.5 bg-red-100 text-industrial-red rounded-lg mt-0.5"><i className="fa-solid fa-ban" /></div>
                  <div><p className="text-xs font-bold text-slate-800">🚫 TRABAJO NO REALIZADO</p><p className="text-[11px] text-slate-500">Registrar reparación solicitada no ejecutada.</p></div>
                </button>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* GRILLA DE CÁPSULAS */}
      <div>
        <div className="flex justify-between items-center mb-3">
          <h3 className="text-xs font-bold uppercase tracking-wider text-slate-500">Cápsulas de componentes · {nombreTaller(taller)}</h3>
          <span className="text-xs font-medium text-slate-600">{intervenidas} de {cat.sistemas.length} cápsulas inspeccionadas/intervenidas</span>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-3 gap-5 items-start">
          {cat.sistemas.map(s => {
            const n = activos.filter(t => t.sistema_id === s.id).length
            const okInsp = inspecciones.some(i => i.sistema_id === s.id)
            const f = flujos[s.id]
            const invs = cat.intervenciones.filter(i => i.sistema_id === s.id)
            const els = cat.elementos.filter(e => e.sistema_id === s.id)
            const borde = f ? 'border-industrial-blue ring-2 ring-industrial-blue/30 shadow-xl bg-white'
              : n ? 'border-amber-300 shadow-lg bg-amber-50/10 hover:border-amber-400' : okInsp ? 'border-emerald-300 shadow-lg bg-emerald-50/10 hover:border-emerald-400' : 'border-slate-200 hover:border-slate-300 shadow-md hover:shadow-lg'
            return (
              <div key={s.id} className={`dock-capsule border ${borde} overflow-hidden flex flex-col`} data-capsula={s.nombre}>
                <div className="p-4 flex items-start justify-between gap-2 border-b border-slate-100/60">
                  <div className="flex items-center gap-3 min-w-0">
                    <div className="p-2.5 bg-slate-50 rounded-2xl shadow-sm border border-slate-200/80 w-11 h-11 flex items-center justify-center shrink-0"><i className={`fa-solid ${s.icono || 'fa-cube'} text-industrial-blue text-lg`} /></div>
                    <div className="min-w-0">
                      <h4 className="font-extrabold text-slate-800 text-sm tracking-tight uppercase leading-tight">{s.nombre}</h4>
                      <div className="mt-1">
                        {n ? <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-amber-50 text-amber-600 border border-amber-200">{n} trabajo{n > 1 ? 's' : ''}</span>
                          : okInsp ? <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-emerald-50 text-emerald-600 border border-emerald-200">Inspeccionado OK</span>
                          : <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-slate-100 text-slate-500 border border-slate-200">Pendiente</span>}
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center gap-1 shrink-0">
                    {!f ? <>
                      {okInsp && !n ? <button onClick={() => desmarcar(s)} title="Quitar “Inspeccionado OK”" className="p-2 hover:bg-slate-100 text-slate-400 rounded-xl text-xs"><i className="fa-solid fa-rotate-left" /></button>
                        : !n && <button onClick={() => inspeccionadoOK(s)} title="Marcar Inspeccionado sin novedades" aria-label={`Inspeccionado OK ${s.nombre}`} className="p-2 hover:bg-emerald-100 text-emerald-600 rounded-xl text-xs font-semibold"><i className="fa-solid fa-check" /></button>}
                      <button onClick={() => abrir(s)} className="bg-industrial-blue hover:bg-blue-900 text-white px-3 py-1.5 rounded-xl text-xs font-bold shadow-md flex items-center gap-1">Inspeccionar<i className="fa-solid fa-chevron-down text-[10px]" /></button>
                    </> : <button onClick={() => cerrar(s)} className="bg-slate-200 hover:bg-slate-300 text-slate-700 px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1">Cerrar<i className="fa-solid fa-chevron-up text-[10px]" /></button>}
                  </div>
                </div>

                {f && (
                  <div className="p-4 bg-white/90 space-y-4 animate-fadeIn">
                    {!invs.length ? (
                      <div className="text-center py-4 space-y-2">
                        <p className="text-xs text-slate-500">Sin intervenciones — agregar en Maestros.</p>
                        {tiene('editar_catalogos') && <button onClick={() => nav(`/maestros/${taller}`)} className="btn-gris"><i className="fa-solid fa-gear" />Ir al catálogo</button>}
                      </div>
                    ) : f.paso === 'elemento' ? <>
                      <div className="flex justify-between items-center border-b border-slate-100 pb-2">
                        <span className="text-[11px] font-bold text-industrial-blue uppercase tracking-wider">¿Qué elemento necesita atención?</span>
                        <button onClick={() => cerrar(s)} className="text-slate-400 hover:text-slate-600 text-[11px] font-medium">[ ✕ Cancelar ]</button>
                      </div>
                      <div className="grid grid-cols-2 gap-2">
                        {els.map(e => (
                          <button key={e.id} onClick={() => setFlujo(s, { paso: 'intervencion', elemento: e })} className="p-2.5 text-left bg-slate-50 hover:bg-blue-50 border border-slate-200 hover:border-industrial-blue rounded-xl text-xs font-semibold text-slate-700 transition-all flex items-center justify-between gap-1">
                            <span>{e.nombre}</span><i className="fa-solid fa-chevron-right text-[10px] text-industrial-blue" />
                          </button>
                        ))}
                      </div>
                    </> : f.paso === 'intervencion' ? <>
                      <div className="flex justify-between items-center border-b border-slate-100 pb-2 gap-2">
                        <div className="flex items-center gap-2 min-w-0">
                          {els.length > 0 && <button onClick={() => setFlujo(s, { paso: 'elemento' })} className="text-industrial-blue hover:underline text-xs font-bold whitespace-nowrap">[ ← Volver ]</button>}
                          <span className="text-xs font-bold text-slate-700 truncate">{f.elemento?.nombre || 'Sin elemento'}</span>
                        </div>
                        <span className="text-[11px] font-bold text-industrial-blue uppercase tracking-wider">Intervención</span>
                      </div>
                      <ListaIntervenciones invs={invs} onElegir={i => setFlujo(s, { paso: 'datos', intervencion: i })} />
                    </> : <>
                      <div className="flex justify-between items-center border-b border-slate-100 pb-2 gap-2">
                        <div className="flex items-center gap-1.5 min-w-0">
                          <button onClick={() => setFlujo(s, { paso: 'intervencion' })} className="text-industrial-blue hover:underline text-xs font-bold whitespace-nowrap">[ ← Volver ]</button>
                          <span className="text-[11px] font-bold text-slate-700 truncate">{f.elemento?.nombre || '—'} {'>'} {f.intervencion!.nombre}</span>
                        </div>
                        <span className="text-[11px] font-bold text-industrial-blue uppercase tracking-wider">Datos</span>
                      </div>
                      <FormTrabajo d={f.d} set={d => setFlujo(s, { d })} ctx={ctx} taller={taller} aplicaComplejidad={s.aplica_complejidad} horasUnitarias={Number(f.intervencion!.horas_estandar)} />
                      <button onClick={() => agregar(s, f)} className="w-full bg-industrial-red hover:bg-industrial-darkred text-white py-2.5 rounded-xl font-bold text-xs shadow-md flex items-center justify-center gap-2"><i className="fa-solid fa-plus" />AGREGAR TRABAJO</button>
                    </>}
                  </div>
                )}
              </div>
            )
          })}
        </div>
      </div>

      {/* INDICADORES */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <Kpi titulo="Total intervenciones" valor={activos.length} icono="fa-clipboard-check" />
        <Kpi titulo="Unidades totales" valor={activos.reduce((a, t) => a + Number(t.cantidad), 0).toLocaleString('es-EC')} icono="fa-hashtag" tono="verde" />
        <Kpi titulo="Producción estándar" valor={<span className="text-industrial-red">{horasTxt(activos.filter(t => t.estado !== 'no_realizado').reduce((a, t) => a + Number(t.horas_estandar), 0))}</span>} icono="fa-clock" tono="rojo" />
        <Kpi titulo="Estado OT" valor={<span className="text-sm font-bold text-amber-600 bg-amber-50 px-2 py-1 rounded inline-block">EN INSPECCIÓN</span>} icono="fa-shield-halved" tono="ambar" />
      </div>

      <Novedades trabajos={propios} imprevistos={imps} ctx={ctx} puedeOperar onCambio={cargar} />

      {/* TABLA RESUMEN */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="px-6 py-4 border-b border-slate-200 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 bg-slate-50/70">
          <div><h3 className="font-bold text-slate-800 text-sm md:text-base flex items-center gap-2"><i className="fa-solid fa-box-archive text-industrial-blue" />
            <span>Resumen de trabajos registrados — {tituloOT(ot)}</span></h3>
            <p className="text-xs text-slate-500 mt-0.5">Segmento {taller === 'mecanica' ? 4 : 5} de la OT {ot.numero}: trabajos de {nombreTaller(taller).toLowerCase()}.</p></div>
          <Pildora tipo="marino">{ot.numero}</Pildora>
        </div>
        <TablaTrabajos trabajos={propios} puedeOperar onEditar={t => setModal({ editar: t })} onEstado={cambiarEstado} onNoRealizado={t => setModal({ nr: t })} onAnular={t => setModal({ anular: t })} />
      </div>

      {modal === 'imprevisto' && <ModalImprevisto ot={ot.id} trabajos={propios} ctx={ctx} titulo={titulo} onCerrar={() => setModal(null)} onListo={() => { setModal(null); cargar() }} />}
      {modal === 'no_realizado' && <ModalNoRealizado trabajos={propios} ctx={ctx} titulo={titulo} onCerrar={() => setModal(null)} onListo={() => { setModal(null); cargar() }} />}
      {modal && typeof modal === 'object' && 'nr' in modal && <ModalNoRealizado trabajos={propios} ctx={ctx} titulo={titulo} inicial={modal.nr.id} onCerrar={() => setModal(null)} onListo={() => { setModal(null); cargar() }} />}
      {modal && typeof modal === 'object' && 'editar' in modal && <ModalEditarTrabajo t={modal.editar} ctx={ctx} aplicaComplejidad={!!cat.sistemas.find(s => s.id === modal.editar.sistema_id)?.aplica_complejidad}
        onCerrar={() => setModal(null)} onListo={() => { setModal(null); cargar() }} />}
      {modal && typeof modal === 'object' && 'anular' in modal && (
        <Modal titulo={`Anular trabajo #${modal.anular.numero_linea}`} icono="fa-ban" onCerrar={() => setModal(null)}>
          <p>{modal.anular.sistema_nombre.toUpperCase()} {'>'} {modal.anular.elemento_nombre || '—'} {'>'} {modal.anular.intervencion_nombre}. Los registros no se borran: queda anulado con su motivo.</p>
          <BotonAnular texto="Anular trabajo" onAnular={async m => { try { ok(await supabase.from('ot_trabajos').update({ anulado: true, anulado_motivo: m }).eq('id', modal.anular.id)); toast('Trabajo anulado', 'El registro quedó anulado.', 'alerta'); setModal(null); cargar() } catch (e) { toast('No se pudo', mensajeError(e), 'alerta') } }} />
        </Modal>
      )}
    </div>
  )
}
