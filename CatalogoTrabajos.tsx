// Catálogo de trabajos por taller (Maestros). Se ve como la grilla de cápsulas de
// referencias/gestion_produccion_soldadura.html: cada componente es una cápsula con sus
// elementos y sus intervenciones (con horas estándar). Agregar una cápsula aquí la hace
// aparecer en el ambiente del taller (Fase 2) sin programar.
import { useEffect, useState } from 'react'
import * as XLSX from 'xlsx'
import { supabase, ok, mensajeError } from '../lib/supabase'
import { useSesion } from '../lib/sesion'
import { invalidarCatalogos } from '../lib/catalogos'
import { hoyISO, nombreTaller } from '../lib/formato'
import type { Elemento, Intervencion, Sistema, SistemaPreventivo, Taller } from '../lib/tipos'
import { Aviso, Campo, Cargando, Modal, Pildora, useToast } from '../components/ui'
import ListaIntervenciones from '../components/ListaIntervenciones'
import { tiempoTxt } from '../lib/ot'

const ICONOS = ['fa-bars-staggered', 'fa-table-cells-large', 'fa-grip-lines', 'fa-box-archive', 'fa-warehouse', 'fa-microchip', 'fa-circle-dot', 'fa-stairs',
  'fa-gears', 'fa-gear', 'fa-cog', 'fa-bolt', 'fa-circle-stop', 'fa-arrows-up-down', 'fa-dharmachakra', 'fa-temperature-low', 'fa-gas-pump', 'fa-wind',
  'fa-oil-can', 'fa-truck-front', 'fa-door-open', 'fa-car-battery', 'fa-fire-flame-curved', 'fa-wrench', 'fa-hammer', 'fa-shield-halved', 'fa-lightbulb', 'fa-cube']

const horas = tiempoTxt

interface Datos { sistemas: Sistema[]; elementos: Elemento[]; intervenciones: Intervencion[]; preventivos: SistemaPreventivo[] }

export default function CatalogoTrabajos({ taller }: { taller: Taller }) {
  const { tiene } = useSesion()
  const toast = useToast()
  const edita = tiene('editar_catalogos')
  const [d, setD] = useState<Datos | null>(null)
  const [abierta, setAbierta] = useState<string | null>(null)
  const [inactivas, setInactivas] = useState(false)
  const [modal, setModal] = useState<null | { tipo: 'catalogo' } | { tipo: 'capsula'; s: Partial<Sistema> } | { tipo: 'intervencion'; i: Partial<Intervencion> } | { tipo: 'elemento'; e: Partial<Elemento> } | { tipo: 'importar'; filas: FilaExcel[] }>(null)
  const [error, setError] = useState('')

  async function cargar() {
    try {
      const sistemas = ok(await supabase.from('sistemas').select('*').eq('taller', taller).order('orden').order('nombre')) as Sistema[]
      const ids = sistemas.map(s => s.id)
      const [elementos, intervenciones, preventivos] = await Promise.all([
        supabase.from('elementos').select('*').in('sistema_id', ids).order('orden').order('nombre'),
        supabase.from('intervenciones').select('*').in('sistema_id', ids).order('orden').order('nombre'),
        supabase.from('sistemas_preventivos').select('*').order('orden')
      ])
      setD({ sistemas, elementos: ok(elementos) as Elemento[], intervenciones: ok(intervenciones) as Intervencion[], preventivos: ok(preventivos) as SistemaPreventivo[] })
    } catch (e) { setError((e as Error).message) }
  }
  useEffect(() => { setD(null); setAbierta(null); cargar() }, [taller])

  /** Guarda en una tabla y recarga. Devuelve true si salió bien. */
  async function guardar(tabla: string, fila: Record<string, unknown>, exito: string) {
    setError('')
    const { id, ...resto } = fila
    const r = id ? await supabase.from(tabla).update(resto).eq('id', id as string).select('id') : await supabase.from(tabla).insert(resto).select('id')
    if (r.error) { setError(mensajeError(r.error)); return false }
    if (!r.data?.length) { setError('Su usuario no tiene permiso para esta acción.'); return false }
    invalidarCatalogos(); toast('Catálogo actualizado', exito); await cargar(); return true
  }

  if (!d) return error ? <Aviso tipo="mal">{error}</Aviso> : <Cargando />
  const caps = d.sistemas.filter(s => inactivas || s.activo)
  const elems = (s: string) => d.elementos.filter(e => e.sistema_id === s)
  const invs = (s: string) => d.intervenciones.filter(i => i.sistema_id === s)
  const activosIntervencion = d.intervenciones.filter(i => i.activo && d.sistemas.find(s => s.id === i.sistema_id)?.activo).length

  // ------------------------------------------------------------ Excel
  function exportar() {
    const filas: FilaExcel[] = []
    for (const s of d!.sistemas) {
      for (const e of elems(s.id)) filas.push({ COMPONENTE: s.nombre, TIPO: 'ELEMENTO', NOMBRE: e.nombre, HORAS: null, PREVENTIVO: '', 'APLICA COMPLEJIDAD': s.aplica_complejidad ? 'SI' : 'NO', ACTIVO: e.activo && s.activo ? 'SI' : 'NO' })
      for (const i of invs(s.id)) filas.push({ COMPONENTE: s.nombre, TIPO: 'INTERVENCION', NOMBRE: i.nombre, HORAS: Number(i.horas_estandar), PREVENTIVO: d!.preventivos.find(p => p.id === i.sistema_preventivo_id)?.codigo || '', GRUPO: i.grupo || '', CODIGO: i.codigo || '', NOTA: i.nota || '', 'APLICA COMPLEJIDAD': s.aplica_complejidad ? 'SI' : 'NO', ACTIVO: i.activo && s.activo ? 'SI' : 'NO' })
      if (!elems(s.id).length && !invs(s.id).length) filas.push({ COMPONENTE: s.nombre, TIPO: 'COMPONENTE', NOMBRE: '', HORAS: null, PREVENTIVO: '', 'APLICA COMPLEJIDAD': s.aplica_complejidad ? 'SI' : 'NO', ACTIVO: s.activo ? 'SI' : 'NO' })
    }
    const libro = XLSX.utils.book_new()
    XLSX.utils.book_append_sheet(libro, XLSX.utils.json_to_sheet(filas, { header: COLUMNAS }), 'CATALOGO')
    XLSX.writeFile(libro, `catalogo_${taller}_${hoyISO()}.xlsx`)
  }
  function leerExcel() {
    const inp = document.createElement('input'); inp.type = 'file'; inp.accept = '.xlsx,.xls,.csv'
    inp.onchange = async () => {
      const f = inp.files?.[0]; if (!f) return
      try {
        const libro = XLSX.read(await f.arrayBuffer(), { type: 'array' })
        const filas = XLSX.utils.sheet_to_json<Record<string, unknown>>(libro.Sheets[libro.SheetNames[0]], { defval: '' })
          .map(normalizarFila).filter((x): x is FilaExcel => !!x)
        if (!filas.length) { setError('El archivo no tiene filas con las columnas COMPONENTE, TIPO y NOMBRE. Exporte primero el catálogo para ver el formato.'); return }
        setModal({ tipo: 'importar', filas })
      } catch (e) { setError('No se pudo leer el archivo: ' + (e as Error).message) }
    }
    inp.click()
  }
  async function importar(filas: FilaExcel[]) {
    setError('')
    try {
      let nuevos = 0, cambiados = 0
      for (const f of filas) {
        let s = d!.sistemas.find(x => x.nombre.toLowerCase() === f.COMPONENTE.toLowerCase())
        const compl = f['APLICA COMPLEJIDAD'] !== 'NO'
        if (!s) {
          s = (ok(await supabase.from('sistemas').insert({ taller, nombre: f.COMPONENTE, icono: 'fa-cube', aplica_complejidad: compl, orden: d!.sistemas.length + 1 }).select('*').single()) as Sistema)
          d!.sistemas.push(s); nuevos++
        }
        if (f.TIPO === 'ELEMENTO' && f.NOMBRE && !d!.elementos.some(e => e.sistema_id === s!.id && e.nombre.toLowerCase() === f.NOMBRE.toLowerCase())) {
          d!.elementos.push(ok(await supabase.from('elementos').insert({ sistema_id: s.id, nombre: f.NOMBRE, orden: elems(s.id).length + 1 }).select('*').single()) as Elemento); nuevos++
        }
        if (f.TIPO === 'INTERVENCION' && f.NOMBRE) {
          const prev = d!.preventivos.find(p => p.codigo === f.PREVENTIVO)?.id || null
          const existe = d!.intervenciones.find(i => i.sistema_id === s!.id && i.nombre.toLowerCase() === f.NOMBRE.toLowerCase())
          if (!existe) { d!.intervenciones.push(ok(await supabase.from('intervenciones').insert({ sistema_id: s.id, nombre: f.NOMBRE, horas_estandar: f.HORAS ?? 0, sistema_preventivo_id: prev, grupo: f.GRUPO || null, codigo: f.CODIGO || null, nota: f.NOTA || null, orden: invs(s.id).length + 1 }).select('*').single()) as Intervencion); nuevos++ }
          else if (Number(existe.horas_estandar) !== Number(f.HORAS ?? existe.horas_estandar) || existe.sistema_preventivo_id !== prev) {
            ok(await supabase.from('intervenciones').update({ horas_estandar: f.HORAS ?? existe.horas_estandar, sistema_preventivo_id: prev }).eq('id', existe.id)); cambiados++
          }
        }
      }
      setModal(null); invalidarCatalogos(); await cargar()
      toast('Catálogo importado', `${nuevos} registros nuevos y ${cambiados} intervenciones actualizadas. Nada se borró.`)
    } catch (e) { setError(mensajeError(e)) ; await cargar() }
  }

  return (
    <div className="space-y-5">
      {/* BANNER DE GUÍA (como la maqueta) */}
      <div className="bg-blue-900/10 border-l-4 border-industrial-blue p-4 rounded-r-2xl flex flex-col md:flex-row justify-between items-start md:items-center gap-3">
        <div className="flex items-start gap-3">
          <i className="fa-solid fa-circle-info text-industrial-blue mt-0.5" />
          <div>
            <h2 className="text-sm font-bold text-slate-900">Catálogo de cápsulas · {nombreTaller(taller)}</h2>
            <p className="text-xs text-slate-600">Cada componente es una cápsula con sus elementos y sus intervenciones con horas estándar (horas-hombre totales). Lo que agregue aquí aparece en el ambiente {nombreTaller(taller)} sin programar.</p>
          </div>
        </div>
        <div className="flex flex-wrap gap-2 shrink-0">
          <button onClick={() => setModal({ tipo: 'catalogo' })} className="bg-slate-700 hover:bg-slate-600 text-white px-3 py-2 rounded-xl text-xs font-bold flex items-center gap-1.5"><i className="fa-solid fa-gear" />Catálogo</button>
          <button onClick={exportar} className="btn-gris"><i className="fa-solid fa-file-excel" />Exportar</button>
          {edita && <button onClick={leerExcel} className="btn-gris"><i className="fa-solid fa-file-import" />Importar Excel</button>}
        </div>
      </div>
      {error && <Aviso tipo="mal">{error}</Aviso>}

      <div className="flex flex-wrap justify-between items-center gap-2">
        <h3 className="text-xs font-bold uppercase tracking-wider text-slate-500">Cápsulas de componentes</h3>
        <div className="flex items-center gap-4 text-xs font-semibold">
          <span className="text-slate-600">{d.sistemas.filter(s => s.activo).length} cápsulas · {activosIntervencion} intervenciones</span>
          <label className="flex items-center gap-1.5 text-slate-500 cursor-pointer"><input type="checkbox" checked={inactivas} onChange={e => setInactivas(e.target.checked)} />Ver inactivas</label>
        </div>
      </div>

      {/* GRILLA DE CÁPSULAS ESTILO DOCK */}
      <div className="grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-3 gap-5 items-start">
        {caps.map(s => {
          const iv = invs(s.id).filter(i => i.activo), el = elems(s.id).filter(e => e.activo)
          const expandida = abierta === s.id
          const borde = expandida ? 'border-industrial-blue ring-2 ring-industrial-blue/30 shadow-xl bg-white'
            : !s.activo ? 'border-slate-200 opacity-60' : iv.length ? 'border-slate-200 hover:border-slate-300 shadow-md hover:shadow-lg' : 'border-dashed border-slate-300 shadow-sm'
          return (
            <div key={s.id} className={`dock-capsule border ${borde} overflow-hidden flex flex-col`}>
              <div className="p-4 flex items-start justify-between gap-2 border-b border-slate-100/60">
                <div className="flex items-center gap-3 min-w-0">
                  <div className="p-2.5 bg-slate-50 rounded-2xl shadow-sm border border-slate-200/80 w-11 h-11 flex items-center justify-center shrink-0">
                    <i className={`fa-solid ${s.icono || 'fa-cube'} text-industrial-blue text-lg`} />
                  </div>
                  <div className="min-w-0">
                    <h4 className="font-extrabold text-slate-800 text-sm tracking-tight uppercase leading-tight">{s.nombre}</h4>
                    <div className="mt-1 flex flex-wrap gap-1">
                      {!s.activo ? <Pildora tipo="neutro">Inactiva</Pildora>
                        : iv.length ? <><Pildora tipo="alerta">{iv.length} {iv.length === 1 ? 'intervención' : 'intervenciones'}</Pildora><Pildora tipo="neutro">{el.length} {el.length === 1 ? 'elemento' : 'elementos'}</Pildora></>
                        : <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-slate-100 text-slate-500 border border-slate-200">Sin intervenciones — agregar en Maestros</span>}
                      {!s.aplica_complejidad && <Pildora tipo="alerta">Sin complejidad</Pildora>}
                    </div>
                  </div>
                </div>
                {!expandida
                  ? <button onClick={() => setAbierta(s.id)} className="bg-industrial-blue hover:bg-blue-900 text-white px-3 py-1.5 rounded-xl text-xs font-bold shadow-md flex items-center gap-1 shrink-0">{edita ? 'Editar' : 'Ver'}<i className="fa-solid fa-chevron-down text-[10px]" /></button>
                  : <button onClick={() => setAbierta(null)} className="bg-slate-200 hover:bg-slate-300 text-slate-700 px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1 shrink-0">Cerrar<i className="fa-solid fa-chevron-up text-[10px]" /></button>}
              </div>

              {expandida && (
                <div className="p-4 bg-white/90 space-y-4 animate-fadeIn">
                  {/* ELEMENTOS */}
                  <div>
                    <div className="flex justify-between items-center border-b border-slate-100 pb-2 mb-2">
                      <span className="text-[11px] font-bold text-industrial-blue uppercase tracking-wider">Elementos</span>
                      {edita && <button onClick={() => setModal({ tipo: 'elemento', e: { sistema_id: s.id, activo: true, orden: elems(s.id).length + 1 } })} className="text-industrial-blue hover:underline text-xs font-bold">+ Elemento</button>}
                    </div>
                    {elems(s.id).length === 0 ? <p className="text-slate-400 italic text-[11px]">Sin elementos registrados.</p> : (
                      <div className="grid grid-cols-2 gap-2">
                        {elems(s.id).map(e => (
                          <button key={e.id} disabled={!edita} onClick={() => setModal({ tipo: 'elemento', e })}
                            className={'p-2.5 text-left bg-slate-50 hover:bg-blue-50 border border-slate-200 hover:border-industrial-blue rounded-xl text-xs font-semibold text-slate-700 transition-all flex items-center justify-between gap-1 ' + (e.activo ? '' : 'line-through opacity-50')}>
                            <span>{e.nombre}</span>{edita && <i className="fa-solid fa-pen text-[10px] text-industrial-blue" />}
                          </button>
                        ))}
                      </div>
                    )}
                  </div>
                  {/* INTERVENCIONES */}
                  <div>
                    <div className="flex justify-between items-center border-b border-slate-100 pb-2 mb-2">
                      <span className="text-[11px] font-bold text-industrial-blue uppercase tracking-wider">Intervenciones (horas estándar)</span>
                      {edita && <button onClick={() => setModal({ tipo: 'intervencion', i: { sistema_id: s.id, activo: true, orden: invs(s.id).length + 1 } })} className="text-industrial-blue hover:underline text-xs font-bold">+ Intervención</button>}
                    </div>
                    {invs(s.id).length === 0 ? <p className="text-slate-400 italic text-[11px]">Sin intervenciones — agregar en Maestros.</p> : (
                      <ListaIntervenciones invs={invs(s.id)} deshabilitado={!edita} conLapiz={edita} onElegir={i => setModal({ tipo: 'intervencion', i })} />
                    )}
                  </div>
                  {edita && <div className="pt-1"><button onClick={() => setModal({ tipo: 'capsula', s })} className="w-full btn-gris py-2.5"><i className="fa-solid fa-sliders" />Datos de la cápsula (nombre, ícono, complejidad, activa)</button></div>}
                </div>
              )}
            </div>
          )
        })}
        {edita && (
          <button onClick={() => setModal({ tipo: 'capsula', s: { taller, activo: true, aplica_complejidad: true, icono: 'fa-cube', orden: d.sistemas.length + 1 } })}
            className="dock-capsule border-2 border-dashed border-slate-300 hover:border-industrial-red text-slate-400 hover:text-industrial-red p-6 flex flex-col items-center justify-center gap-2 min-h-[88px] font-bold text-xs">
            <i className="fa-solid fa-plus text-xl" />Nueva cápsula de {nombreTaller(taller).toLowerCase()}
          </button>
        )}
      </div>

      {/* --------------------------------------------------------------- Modales */}
      {modal?.tipo === 'capsula' && <ModalCapsula s={modal.s} onCerrar={() => setModal(null)} error={error}
        onGuardar={async s => { if (await guardar('sistemas', s, `Cápsula “${s.nombre}” guardada.`)) setModal(null) }} />}
      {modal?.tipo === 'elemento' && <ModalElemento e={modal.e} onCerrar={() => setModal(null)} error={error}
        onGuardar={async e => { if (await guardar('elementos', e, `Elemento “${e.nombre}” guardado.`)) setModal(null) }} />}
      {modal?.tipo === 'intervencion' && <ModalIntervencion i={modal.i} preventivos={d.preventivos} sistemas={d.sistemas} onCerrar={() => setModal(null)} error={error}
        onGuardar={async i => { if (await guardar('intervenciones', i, `Intervención “${i.nombre}” guardada.`)) setModal(null) }} />}
      {modal?.tipo === 'catalogo' && <ModalCatalogo d={d} taller={taller} edita={edita} error={error} onCerrar={() => setModal(null)}
        onAgregar={async (sistema_id, elemento, nombre, h) => {
          setError('')
          try {
            if (elemento && !elems(sistema_id).some(e => e.nombre.toLowerCase() === elemento.toLowerCase()))
              ok(await supabase.from('elementos').insert({ sistema_id, nombre: elemento, orden: elems(sistema_id).length + 1 }))
            ok(await supabase.from('intervenciones').insert({ sistema_id, nombre, horas_estandar: h, orden: invs(sistema_id).length + 1 }))
            invalidarCatalogos(); await cargar()
            toast('Catálogo actualizado', `Nueva intervención “${nombre}” agregada a ${d.sistemas.find(s => s.id === sistema_id)?.nombre}.`)
            return true
          } catch (e) { setError(mensajeError(e)); return false }
        }} />}
      {modal?.tipo === 'importar' && (
        <Modal titulo="Importar catálogo desde Excel" icono="fa-file-import" ancho="max-w-2xl" onCerrar={() => setModal(null)}
          pie={<><button className="btn-gris" onClick={() => setModal(null)}>Cancelar</button><button className="btn-rojo" onClick={() => importar(modal.filas)}>Importar {modal.filas.length} filas</button></>}>
          <Aviso>Se agregan los componentes, elementos e intervenciones que no existan y se actualizan las horas y el sistema preventivo de las intervenciones que ya existen. <b>No se borra ni se desactiva nada.</b></Aviso>
          <div className="max-h-72 overflow-auto custom-scrollbar border border-slate-200 rounded-xl">
            <table className="w-full text-[11px]"><thead className="bg-slate-100 sticky top-0"><tr>{['Componente', 'Tipo', 'Nombre', 'Horas', 'Preventivo'].map(h => <th key={h} className="py-2 px-3 text-left uppercase">{h}</th>)}</tr></thead>
              <tbody className="divide-y divide-slate-100">{modal.filas.map((f, n) => <tr key={n}><td className="py-1.5 px-3 font-bold">{f.COMPONENTE}</td><td className="py-1.5 px-3">{f.TIPO}</td><td className="py-1.5 px-3">{f.NOMBRE}</td><td className="py-1.5 px-3 font-mono">{f.HORAS ?? ''}</td><td className="py-1.5 px-3">{f.PREVENTIVO}</td></tr>)}</tbody></table>
          </div>
          {error && <Aviso tipo="mal">{error}</Aviso>}
        </Modal>
      )}
    </div>
  )
}

// ------------------------------------------------------------------ Excel
const COLUMNAS = ['COMPONENTE', 'TIPO', 'NOMBRE', 'HORAS', 'PREVENTIVO', 'GRUPO', 'CODIGO', 'NOTA', 'APLICA COMPLEJIDAD', 'ACTIVO']
interface FilaExcel { COMPONENTE: string; TIPO: 'ELEMENTO' | 'INTERVENCION' | 'COMPONENTE'; NOMBRE: string; HORAS: number | null; PREVENTIVO: string; GRUPO?: string; CODIGO?: string; NOTA?: string; 'APLICA COMPLEJIDAD': string; ACTIVO: string }
function normalizarFila(r: Record<string, unknown>): FilaExcel | null {
  const g = (k: string) => String(Object.entries(r).find(([c]) => c.trim().toUpperCase().normalize('NFD').replace(/[̀-ͯ]/g, '') === k)?.[1] ?? '').trim()
  const comp = g('COMPONENTE'), tipo = g('TIPO').toUpperCase().normalize('NFD').replace(/[̀-ͯ]/g, '')
  if (!comp || !['ELEMENTO', 'INTERVENCION', 'COMPONENTE'].includes(tipo)) return null
  const h = g('HORAS').replace(',', '.')
  return { COMPONENTE: comp, TIPO: tipo as FilaExcel['TIPO'], NOMBRE: g('NOMBRE'), HORAS: h === '' || isNaN(Number(h)) ? null : Number(h),
    PREVENTIVO: g('PREVENTIVO').toLowerCase(), GRUPO: g('GRUPO'), CODIGO: g('CODIGO'), NOTA: g('NOTA'), 'APLICA COMPLEJIDAD': g('APLICA COMPLEJIDAD').toUpperCase() || 'SI', ACTIVO: g('ACTIVO').toUpperCase() || 'SI' }
}

// ------------------------------------------------------------------ Ventanas de edición
function PieGuardar({ onCerrar, form }: { onCerrar: () => void; form: string }) {
  return <><button type="button" className="btn-gris" onClick={onCerrar}>Cancelar</button><button type="submit" form={form} className="btn-azul"><i className="fa-solid fa-floppy-disk" />Guardar cambios</button></>
}
function Activo({ v, onChange, texto }: { v: boolean; onChange: (b: boolean) => void; texto: string }) {
  return <label className="flex items-center gap-2 font-semibold text-slate-700"><input type="checkbox" className="w-5 h-5 accent-industrial-blue" checked={v} onChange={e => onChange(e.target.checked)} />{texto}</label>
}

function ModalCapsula({ s: inicial, onGuardar, onCerrar, error }: { s: Partial<Sistema>; onGuardar: (s: Partial<Sistema>) => void; onCerrar: () => void; error: string }) {
  const [s, setS] = useState(inicial)
  return (
    <Modal titulo={s.id ? `Cápsula · ${inicial.nombre}` : 'Nueva cápsula'} icono="fa-cubes" onCerrar={onCerrar} pie={<PieGuardar onCerrar={onCerrar} form="f-capsula" />}>
      <form id="f-capsula" className="space-y-4" onSubmit={e => { e.preventDefault(); onGuardar({ id: s.id, taller: s.taller, nombre: s.nombre?.trim(), icono: s.icono, aplica_complejidad: s.aplica_complejidad, activo: s.activo, orden: Number(s.orden) || 0, descripcion: s.descripcion || null }) }}>
        <Campo etiqueta="Nombre del componente / sistema *"><input required className="campo-texto" value={s.nombre || ''} onChange={e => setS({ ...s, nombre: e.target.value })} /></Campo>
        <Campo etiqueta="Ícono de la cápsula">
          <div className="grid grid-cols-7 gap-1.5">{ICONOS.map(i => (
            <button type="button" key={i} onClick={() => setS({ ...s, icono: i })} title={i}
              className={'h-9 rounded-xl border flex items-center justify-center ' + (s.icono === i ? 'bg-industrial-blue text-white border-industrial-blue' : 'bg-slate-50 text-industrial-blue border-slate-200 hover:bg-blue-50')}><i className={`fa-solid ${i}`} /></button>
          ))}</div>
        </Campo>
        <div className="grid grid-cols-2 gap-3">
          <Campo etiqueta="Orden en la grilla"><input className="campo-texto" inputMode="numeric" value={s.orden ?? ''} onChange={e => setS({ ...s, orden: e.target.value as unknown as number })} /></Campo>
          <div className="space-y-2 pt-5">
            <Activo v={!!s.aplica_complejidad} onChange={b => setS({ ...s, aplica_complejidad: b })} texto="Aplica complejidad" />
            <Activo v={!!s.activo} onChange={b => setS({ ...s, activo: b })} texto="Activa" />
          </div>
        </div>
        <Campo etiqueta="Ayuda breve (opcional)"><input className="campo-texto" value={s.descripcion || ''} onChange={e => setS({ ...s, descripcion: e.target.value })} /></Campo>
        <p className="text-[11px] text-slate-500">Complejidad: leve ×0,8, moderado ×1,0, grave ×1,4 (editables en Maestros → Complejidad). Una cápsula con uso no se borra: se desactiva.</p>
        {error && <Aviso tipo="mal">{error}</Aviso>}
      </form>
    </Modal>
  )
}

function ModalElemento({ e: inicial, onGuardar, onCerrar, error }: { e: Partial<Elemento>; onGuardar: (e: Partial<Elemento>) => void; onCerrar: () => void; error: string }) {
  const [e, setE] = useState(inicial)
  return (
    <Modal titulo={e.id ? 'Editar elemento' : 'Nuevo elemento'} icono="fa-puzzle-piece" onCerrar={onCerrar} pie={<PieGuardar onCerrar={onCerrar} form="f-elemento" />}>
      <form id="f-elemento" className="space-y-4" onSubmit={ev => { ev.preventDefault(); onGuardar({ id: e.id, sistema_id: e.sistema_id, nombre: e.nombre?.trim(), orden: Number(e.orden) || 0, activo: e.activo }) }}>
        <Campo etiqueta="Elemento específico *"><input required autoFocus className="campo-texto" placeholder="Ej. Bisagras" value={e.nombre || ''} onChange={x => setE({ ...e, nombre: x.target.value })} /></Campo>
        <div className="grid grid-cols-2 gap-3 items-end">
          <Campo etiqueta="Orden"><input className="campo-texto" inputMode="numeric" value={e.orden ?? ''} onChange={x => setE({ ...e, orden: x.target.value as unknown as number })} /></Campo>
          <Activo v={!!e.activo} onChange={b => setE({ ...e, activo: b })} texto="Activo" />
        </div>
        {error && <Aviso tipo="mal">{error}</Aviso>}
      </form>
    </Modal>
  )
}

function ModalIntervencion({ i: inicial, preventivos, sistemas, onGuardar, onCerrar, error }: { i: Partial<Intervencion>; preventivos: SistemaPreventivo[]; sistemas: Sistema[]; onGuardar: (i: Partial<Intervencion>) => void; onCerrar: () => void; error: string }) {
  const [i, setI] = useState({ ...inicial, horas_estandar: inicial.horas_estandar ?? ('' as unknown as number) })
  return (
    <Modal titulo={i.id ? 'Editar intervención' : 'Nueva intervención'} icono="fa-clock" onCerrar={onCerrar} pie={<PieGuardar onCerrar={onCerrar} form="f-intervencion" />}>
      <form id="f-intervencion" className="space-y-4" onSubmit={ev => {
        ev.preventDefault()
        onGuardar({ id: i.id, sistema_id: i.sistema_id, nombre: i.nombre?.trim(), horas_estandar: Number(String(i.horas_estandar).replace(',', '.')), sistema_preventivo_id: i.sistema_preventivo_id || null, orden: Number(i.orden) || 0, activo: i.activo,
          grupo: i.grupo?.trim() || null, codigo: i.codigo?.trim() || null, nota: i.nota?.trim() || null })
      }}>
        <Campo etiqueta="Nombre de la intervención *"><input required autoFocus className="campo-texto" placeholder="Ej. Resoldar" value={i.nombre || ''} onChange={x => setI({ ...i, nombre: x.target.value })} /></Campo>
        <Campo etiqueta="Tiempo estándar (horas-hombre totales) *" ayuda="Si el trabajo exige dos personas, ponga el tiempo ya multiplicado (ej. 2 h × 2 personas = 4).">
          <input required className="campo-texto font-bold" inputMode="decimal" value={i.horas_estandar ?? ''} onChange={x => setI({ ...i, horas_estandar: x.target.value as unknown as number })} />
        </Campo>
        <div className="grid grid-cols-2 gap-3">
          <Campo etiqueta="Grupo (opcional)" ayuda="Sub-categoría para ordenar la cápsula (ej. Checklist)."><input className="campo-texto" value={i.grupo || ''} onChange={x => setI({ ...i, grupo: x.target.value })} /></Campo>
          <Campo etiqueta="Código (opcional)"><input className="campo-texto" value={i.codigo || ''} onChange={x => setI({ ...i, codigo: x.target.value })} /></Campo>
        </div>
        <Campo etiqueta="Nota (opcional)" ayuda="Se ve al elegir el trabajo. Ej. duración total estimada con esperas."><input className="campo-texto" value={i.nota || ''} onChange={x => setI({ ...i, nota: x.target.value })} /></Campo>
        {i.id && <Campo etiqueta="Cápsula" ayuda="Para mover este trabajo a otra cápsula del mismo taller. Las OT ya registradas no cambian.">
          <select className="campo-texto" value={i.sistema_id} onChange={x => setI({ ...i, sistema_id: x.target.value })}>{sistemas.filter(s => s.activo || s.id === i.sistema_id).map(s => <option key={s.id} value={s.id}>{s.nombre}</option>)}</select>
        </Campo>}
        <Campo etiqueta="Sistema preventivo (opcional)" ayuda="Si se marca, este trabajo alimenta el registro de componentes del kardex.">
          <select className="campo-texto" value={i.sistema_preventivo_id || ''} onChange={x => setI({ ...i, sistema_preventivo_id: x.target.value || null })}>
            <option value="">— No alimenta preventivos —</option>{preventivos.filter(p => p.activo).map(p => <option key={p.id} value={p.id}>{p.nombre}</option>)}
          </select>
        </Campo>
        <div className="grid grid-cols-2 gap-3 items-end">
          <Campo etiqueta="Orden"><input className="campo-texto" inputMode="numeric" value={i.orden ?? ''} onChange={x => setI({ ...i, orden: x.target.value as unknown as number })} /></Campo>
          <Activo v={!!i.activo} onChange={b => setI({ ...i, activo: b })} texto="Activa" />
        </div>
        {error && <Aviso tipo="mal">{error}</Aviso>}
      </form>
    </Modal>
  )
}

/** "Gestión de Catálogo Extensible": la ventana de catálogo de la maqueta del coordinador. */
function ModalCatalogo({ d, taller, edita, error, onCerrar, onAgregar }: {
  d: Datos; taller: Taller; edita: boolean; error: string; onCerrar: () => void
  onAgregar: (sistema_id: string, elemento: string, nombre: string, horas: number) => Promise<boolean>
}) {
  const activos = d.sistemas.filter(s => s.activo)
  const [f, setF] = useState({ sistema_id: activos[0]?.id || '', elemento: '', nombre: '', horas: '1.0' })
  return (
    <Modal titulo="Gestión de catálogo extensible" icono="fa-sliders" ancho="max-w-2xl" onCerrar={onCerrar} pie={<button className="btn-gris" onClick={onCerrar}>Cerrar</button>}>
      <p className="text-xs text-slate-500">Aquí puede ver la estructura de elementos e intervenciones de {nombreTaller(taller).toLowerCase()} y agregar nuevas intervenciones con su tiempo estándar en horas.</p>
      {edita && (
        <form className="bg-slate-50 p-4 rounded-2xl border border-slate-200 space-y-3" onSubmit={async e => {
          e.preventDefault()
          const h = Number(f.horas.replace(',', '.'))
          if (!f.nombre.trim() || isNaN(h)) return
          if (await onAgregar(f.sistema_id, f.elemento.trim(), f.nombre.trim(), h)) setF({ ...f, nombre: '' })
        }}>
          <h4 className="text-xs font-bold uppercase tracking-wider text-slate-700">Agregar nueva intervención al catálogo</h4>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <Campo etiqueta="Componente"><select className="campo-texto" value={f.sistema_id} onChange={e => setF({ ...f, sistema_id: e.target.value })}>{activos.map(s => <option key={s.id} value={s.id}>{s.nombre.toUpperCase()}</option>)}</select></Campo>
            <Campo etiqueta="Elemento específico (opcional)"><input className="campo-texto" placeholder="Ej. Bisagras (si es nuevo, se crea)" value={f.elemento} onChange={e => setF({ ...f, elemento: e.target.value })} /></Campo>
            <Campo etiqueta="Nombre de intervención"><input required className="campo-texto" placeholder="Ej. Refuerzo especial" value={f.nombre} onChange={e => setF({ ...f, nombre: e.target.value })} /></Campo>
            <Campo etiqueta="Tiempo estándar (horas)"><input required className="campo-texto" inputMode="decimal" value={f.horas} onChange={e => setF({ ...f, horas: e.target.value })} /></Campo>
          </div>
          <div className="flex justify-end"><button className="btn-rojo">Agregar al catálogo</button></div>
        </form>
      )}
      {error && <Aviso tipo="mal">{error}</Aviso>}
      <div>
        <h4 className="text-xs font-bold uppercase tracking-wider text-slate-700 mb-2">Catálogo actual configurado</h4>
        <div className="space-y-2">
          {activos.map(s => {
            const iv = d.intervenciones.filter(i => i.sistema_id === s.id && i.activo)
            return (
              <div key={s.id} className="bg-slate-50 p-3 rounded-lg border border-slate-200 space-y-1">
                <h5 className="font-bold text-slate-800 text-xs">{s.nombre.toUpperCase()} <span className="text-slate-400 font-normal">({s.aplica_complejidad ? 'Con complejidad' : 'Sin complejidad'})</span></h5>
                <div className="flex flex-wrap gap-1 mt-1">
                  {iv.length ? iv.map(i => <span key={i.id} className="bg-white border border-slate-200 px-2 py-0.5 rounded text-[11px] text-slate-700 font-medium">{i.nombre}: <strong className="text-industrial-blue">{horas(i.horas_estandar)}</strong></span>)
                    : <span className="text-[11px] text-slate-400 italic">Sin intervenciones — agregar en Maestros</span>}
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </Modal>
  )
}
