import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { useSesion } from '../lib/sesion'
import { exportacionCompleta, solicitarRespaldoSql, diccionarioMarkdown } from '../lib/exportar'
import { descargar } from '../lib/compartir'
import { fechaHora, hoyISO, numero } from '../lib/formato'
import { Aviso, Cargando, useMensaje } from '../components/ui'

const TABLAS_BITACORA = ['usuarios', 'tecnicos', 'tarifas_tecnico', 'vehiculos', 'conductores', 'clientes', 'centros_costo', 'proveedores',
  'sistemas', 'elementos', 'intervenciones', 'complejidades', 'sistemas_preventivos', 'listas_valores', 'configuracion', 'clave_aprobacion']

/** Exportación completa, respaldos y bitácora de auditoría (solo el maestro). */
export default function Exportacion() {
  const { esMaestro } = useSesion()
  const [progreso, setProgreso] = useState('')
  const [ocupado, setOcupado] = useState(false)
  const [respaldos, setRespaldos] = useState<any[] | null>(null)
  const [bitacora, setBitacora] = useState<any[] | null>(null)
  const [usuarios, setUsuarios] = useState<Record<string, string>>({})
  const [tabla, setTabla] = useState('')
  const msg = useMensaje()

  useEffect(() => {
    supabase.from('respaldos').select('*').order('fecha_hora', { ascending: false }).limit(20).then(r => setRespaldos((r.data as any[]) || []))
    supabase.from('usuarios').select('id,nombre_completo').then(r => setUsuarios(Object.fromEntries(((r.data as any[]) || []).map(u => [u.id, u.nombre_completo]))))
  }, [])
  useEffect(() => {
    let q = supabase.from('bitacora_auditoria').select('*').order('fecha_hora', { ascending: false }).limit(100)
    if (tabla) q = q.eq('tabla', tabla)
    q.then(r => setBitacora((r.data as any[]) || []))
  }, [tabla])

  if (!esMaestro) return <Aviso tipo="alerta">Solo el maestro puede exportar la base completa.</Aviso>
  const th = 'py-3 px-4 text-left'
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-slate-50 p-5 rounded-3xl border border-slate-200 space-y-3 text-xs">
          <h4 className="font-bold text-slate-800 text-sm flex items-center gap-2"><i className="fa-solid fa-file-zipper text-industrial-red" />Exportación completa</h4>
          <p className="text-slate-600">ZIP con todas las tablas en CSV y Excel, el diccionario de datos y el índice de archivos. Sirve para migrar a otro sistema.</p>
          <button className="btn-rojo" disabled={ocupado} onClick={async () => {
            setOcupado(true); msg.limpiar()
            try { await exportacionCompleta(setProgreso) } catch (e) { msg.mal((e as Error).message) } finally { setOcupado(false) }
          }}><i className="fa-solid fa-download" />Descargar exportación completa (ZIP)</button>
          {progreso && <p className="text-[11px] text-slate-500">{progreso}</p>}
        </div>
        <div className="bg-slate-50 p-5 rounded-3xl border border-slate-200 space-y-3 text-xs">
          <h4 className="font-bold text-slate-800 text-sm flex items-center gap-2"><i className="fa-solid fa-database text-industrial-red" />Respaldo SQL completo</h4>
          <p className="text-slate-600">Se genera en GitHub y se guarda en su Google Drive (carpeta “Respaldos Taller Distrilogico”). Además se hace solo cada domingo.</p>
          <div className="flex flex-wrap gap-2">
            <button className="btn-azul" disabled={ocupado} onClick={async () => { msg.limpiar(); try { msg.ok(await solicitarRespaldoSql()) } catch (e) { msg.mal((e as Error).message) } }}>Hacer respaldo SQL ahora</button>
            <button className="btn-gris" onClick={async () => descargar(new Blob([await diccionarioMarkdown()], { type: 'text/markdown' }), `DICCIONARIO_DATOS_${hoyISO()}.md`)}>Descargar diccionario de datos</button>
          </div>
        </div>
      </div>
      {msg.vista}
      <div>
        <h4 className="text-xs font-bold uppercase tracking-wider text-slate-500 mb-2">Últimos respaldos</h4>
        {!respaldos ? <Cargando /> : respaldos.length === 0 ? <p className="text-slate-400 italic text-[11px]">Todavía no hay respaldos registrados.</p> : (
          <div className="bg-white rounded-2xl border border-slate-200 overflow-x-auto custom-scrollbar"><table className="w-full text-xs">
            <thead><tr className="bg-slate-100/80 text-slate-600 uppercase tracking-wider text-[11px]"><th className={th}>Fecha</th><th className={th}>Tipo</th><th className={th}>Archivo</th><th className={th}>Tamaño</th><th className={th}>Estado</th></tr></thead>
            <tbody className="divide-y divide-slate-100">{respaldos.map(r => <tr key={r.id}><td className="py-2 px-4">{fechaHora(r.fecha_hora)}</td><td className="py-2 px-4">{r.tipo}</td><td className="py-2 px-4">{r.nombre_archivo}</td><td className="py-2 px-4">{r.bytes ? numero(r.bytes / 1024) + ' KB' : ''}</td><td className="py-2 px-4">{r.estado}{r.detalle ? ' · ' + r.detalle : ''}</td></tr>)}</tbody></table></div>
        )}
      </div>
      <div className="space-y-2">
        <div className="flex flex-wrap justify-between items-center gap-2">
          <h4 className="text-xs font-bold uppercase tracking-wider text-slate-500">Bitácora de auditoría (quién cambió qué y cuándo)</h4>
          <select className="campo-texto max-w-xs" value={tabla} onChange={e => setTabla(e.target.value)}>
            <option value="">Todas las tablas</option>{TABLAS_BITACORA.map(t => <option key={t}>{t}</option>)}
          </select>
        </div>
        {!bitacora ? <Cargando /> : (
          <div className="bg-white rounded-2xl border border-slate-200 overflow-x-auto custom-scrollbar"><table className="w-full text-xs">
            <thead><tr className="bg-slate-100/80 text-slate-600 uppercase tracking-wider text-[11px]"><th className={th}>Fecha</th><th className={th}>Tabla</th><th className={th}>Acción</th><th className={th}>Usuario</th><th className={th}>Registro</th></tr></thead>
            <tbody className="divide-y divide-slate-100">{bitacora.map(b => <tr key={b.id}><td className="py-2 px-4 whitespace-nowrap">{fechaHora(b.fecha_hora)}</td><td className="py-2 px-4 font-mono">{b.tabla}</td><td className="py-2 px-4">{b.accion}</td><td className="py-2 px-4">{usuarios[b.usuario_id] || 'sistema'}</td>
              <td className="py-2 px-4 text-slate-500 max-w-xs truncate">{b.tabla === 'clave_aprobacion' ? '(clave cifrada)' : b.datos_despues?.numero || b.datos_despues?.codigo || b.datos_despues?.nombre || b.datos_despues?.nombres || b.datos_despues?.valor || b.datos_despues?.clave || ''}{b.accion === 'anular' ? ' · ' + b.datos_despues?.anulado_motivo : ''}</td></tr>)}</tbody></table></div>
        )}
        <p className="text-[11px] text-slate-500">La bitácora no se puede modificar ni borrar.</p>
      </div>
    </div>
  )
}
