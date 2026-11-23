import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase, ok, mensajeError } from '../lib/supabase'
import { horasTxt, estadoTrabajo, nombreTipoOT } from '../lib/ot'
import { nombreTaller } from '../lib/formato'
import { Aviso, Cargando, Pildora, TituloSeccion } from '../components/ui'

interface MiTrabajo {
  id: string; orden_trabajo_id: string; numero: string; estado_ot: string; codigo: string | null; placa: string | null; motivo_ingreso: string; prioridad: string
  taller: string; sistema_nombre: string; elemento_nombre: string | null; intervencion_nombre: string; cantidad: number; estado: string; observacion: string | null
  porcentaje: number; horas: number
}

/** Trabajos asignados (cápsula 2 del portal del técnico). Sin "Completar": el técnico lo escribe en su observación y el supervisor lo marca terminado. */
export default function MisTrabajos() {
  const nav = useNavigate()
  const [lista, setLista] = useState<MiTrabajo[] | null>(null)
  const [error, setError] = useState('')
  useEffect(() => {
    supabase.from('v_mis_trabajos').select('*').neq('estado_ot', 'entregado').in('estado', ['pendiente', 'en_proceso']).order('creado_en')
      .then(r => setLista(ok(r) as MiTrabajo[]), e => setError(mensajeError(e)))
  }, [])
  if (error) return <Aviso tipo="mal">{error}</Aviso>
  if (!lista) return <Cargando />
  return (
    <section className="space-y-6">
      <TituloSeccion icono="fa-list-check" titulo="Trabajos asignados" subtitulo="Muestra solo sus asignaciones activas. Cuando termine, escríbalo en su observación de la OT: el supervisor marca el trabajo como terminado.">
        <span className="bg-industrial-blue text-white text-xs font-extrabold px-3 py-1 rounded-full">{lista.length} asignadas</span>
      </TituloSeccion>
      {!lista.length ? (
        <div className="py-16 text-center bg-slate-50 rounded-3xl border border-dashed border-slate-300">
          <i className="fa-solid fa-circle-check text-slate-300 text-4xl mb-3" /><h3 className="font-extrabold text-slate-700 text-sm">Actualmente no tiene trabajos asignados</h3>
          <p className="text-xs text-slate-400 mt-1">Todas las órdenes de trabajo asignadas a su perfil han sido ejecutadas.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {lista.map(t => {
            const e = estadoTrabajo(t.estado)
            return (
              <div key={t.id} className="bg-slate-50 p-4 rounded-3xl border border-slate-200 hover:border-industrial-blue transition-all space-y-3 text-xs">
                <div className="flex justify-between items-center border-b border-slate-200 pb-2">
                  <span className="font-black text-industrial-blue text-sm"><i className="fa-solid fa-truck-front mr-1" />{t.codigo || 'Fabricación'}{t.placa ? ' · ' + t.placa : ''}</span>
                  <span className="bg-slate-200 text-slate-700 text-[10px] font-extrabold px-2 py-0.5 rounded-full font-mono">{t.numero}</span>
                </div>
                <div className="space-y-1">
                  <p><strong className="text-slate-600">Componente:</strong> {t.sistema_nombre.toUpperCase()} ({nombreTaller(t.taller)})</p>
                  <p><strong className="text-slate-600">Elemento:</strong> {t.elemento_nombre || '—'}</p>
                  <p><strong className="text-industrial-navy font-bold">Intervención:</strong> {t.intervencion_nombre} × {Number(t.cantidad).toLocaleString('es-EC')}</p>
                  {t.observacion && <p className="text-slate-500 italic">{t.observacion}</p>}
                </div>
                <div className="flex justify-between items-center pt-2 border-t border-slate-200 gap-2">
                  <span className="flex gap-1 flex-wrap"><span className="bg-amber-100 text-amber-800 px-2.5 py-1 rounded-lg font-bold text-[10px]">Prioridad: {t.prioridad.toUpperCase()}</span><Pildora tipo={e.tono}>{e.n}</Pildora></span>
                  <button onClick={() => nav(`/ot/${t.orden_trabajo_id}`)} className="btn-marino py-1.5"><i className="fa-solid fa-user-pen" />Ver OT y observar</button>
                </div>
                <p className="text-[10px] text-slate-400">{nombreTipoOT(t.motivo_ingreso)} · su parte: {Number(t.porcentaje).toLocaleString('es-EC')} % = {horasTxt(t.horas)} estándar</p>
              </div>
            )
          })}
        </div>
      )}
    </section>
  )
}
