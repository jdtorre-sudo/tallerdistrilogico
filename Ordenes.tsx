import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { supabase, ok, mensajeError } from '../lib/supabase'
import { useSesion } from '../lib/sesion'
import { duracion, fecha, nombreEstado } from '../lib/formato'
import { horasTxt, nombreTipoOT, tituloOT, type FilaOT } from '../lib/ot'
import { Aviso, Cargando, Kpi, Pildora, Segmentado, TituloSeccion } from '../components/ui'

/** Lista de órdenes de trabajo: tarjetas de OT abiertas y búsqueda (técnicos, bodega y supervisores). */
export default function Ordenes() {
  const { tiene } = useSesion()
  const nav = useNavigate()
  const [vista, setVista] = useState('abiertas')
  const [ots, setOts] = useState<FilaOT[] | null>(null)
  const [texto, setTexto] = useState('')
  const [error, setError] = useState('')

  useEffect(() => {
    setOts(null)
    let q = supabase.from('v_ot_lista').select('*').eq('formato', 'segmentos')
    q = vista === 'abiertas' ? q.eq('anulado', false).neq('estado', 'entregado').order('fecha_apertura') : q.or('estado.eq.entregado,anulado.eq.true').order('fecha_apertura', { ascending: false }).limit(200)
    q.then(r => setOts(ok(r) as FilaOT[]), e => setError(mensajeError(e)))
  }, [vista])

  const t = texto.trim().toUpperCase()
  const visibles = (ots || []).filter(o => !t || o.numero.includes(t) || (o.codigo || '').toUpperCase().includes(t) || (o.placa || '').toUpperCase().replace(/-/g, '').includes(t.replace(/-/g, '')) || (o.fabricacion_descripcion || '').toUpperCase().includes(t))
  const abiertas = vista === 'abiertas' ? ots || [] : []

  return (
    <section className="space-y-6">
      <TituloSeccion icono="fa-clipboard-list" titulo="Órdenes de trabajo" subtitulo="Busque por número de OT, código o placa. Toque una tarjeta para ver la OT completa por segmentos.">
        {tiene('operar_ot') && <Link to="/ot/nueva" className="btn-rojo"><i className="fa-solid fa-plus" />Nueva OT</Link>}
      </TituloSeccion>
      {vista === 'abiertas' && ots && (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <Kpi titulo="OT abiertas" valor={abiertas.length} icono="fa-clipboard-list" />
          <Kpi titulo="Inmovilizados" valor={abiertas.filter(o => o.inmovilizado).length} icono="fa-triangle-exclamation" tono="rojo" />
          <Kpi titulo="Trabajos abiertos" valor={abiertas.reduce((a, o) => a + o.trabajos_abiertos, 0)} icono="fa-screwdriver-wrench" tono="ambar" />
          <Kpi titulo="Imprevistos por validar" valor={abiertas.reduce((a, o) => a + o.imprevistos_pendientes, 0)} icono="fa-clock" tono="verde" />
        </div>
      )}
      <div className="flex flex-col sm:flex-row gap-3 sm:items-center">
        <div className="w-full sm:w-72"><Segmentado opciones={[{ k: 'abiertas', n: 'ABIERTAS' }, { k: 'cerradas', n: 'CERRADAS / ANULADAS' }]} valor={vista} onChange={setVista} /></div>
        <div className="relative flex-1 max-w-sm"><i className="fa-solid fa-magnifying-glass absolute left-3 top-3 text-slate-400 text-xs" />
          <input className="campo-texto pl-8" placeholder="OT, código o placa…" value={texto} onChange={e => setTexto(e.target.value)} /></div>
      </div>
      {error && <Aviso tipo="mal">{error}</Aviso>}
      {!ots ? <Cargando /> : !visibles.length ? (
        <div className="py-16 text-center bg-slate-50 rounded-3xl border border-dashed border-slate-300">
          <i className="fa-solid fa-circle-check text-slate-300 text-4xl mb-3" /><h3 className="font-extrabold text-slate-700 text-sm">No hay órdenes {vista === 'abiertas' ? 'abiertas' : 'cerradas'}{t ? ` con “${texto}”` : ''}</h3>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {visibles.map(o => (
            <button key={o.id} onClick={() => nav(`/ot/${o.id}`)} className={'text-left bg-slate-50 p-4 rounded-3xl border hover:border-industrial-blue transition-all space-y-3 text-xs ' + (o.inmovilizado && vista === 'abiertas' ? 'border-l-4 border-l-industrial-red border-slate-200' : 'border-slate-200')}>
              <div className="flex justify-between items-center border-b border-slate-200 pb-2 gap-2">
                <span className="font-black text-industrial-blue text-sm truncate"><i className="fa-solid fa-truck-front mr-1" />{tituloOT(o)}</span>
                <span className="bg-slate-200 text-slate-700 text-[10px] font-extrabold px-2 py-0.5 rounded-full font-mono shrink-0">{o.numero}</span>
              </div>
              <div className="space-y-1">
                <p><strong className="text-slate-600">Tipo:</strong> {nombreTipoOT(o.motivo_ingreso)}{o.propiedad === 'rentado' ? ` · cliente ${o.cliente}` : ''}</p>
                <p><strong className="text-slate-600">Ingreso:</strong> {fecha(o.fecha_apertura)} · {o.anulado ? 'anulada' : o.estado === 'entregado' ? `cerrada ${fecha(o.fecha_cierre)}` : `parada ${duracion(o.horas_parado_actual)}`}</p>
                <p><strong className="text-industrial-navy">Trabajos:</strong> {o.trabajos_mecanica} mecánica · {o.trabajos_soldadura} soldadura · {horasTxt(o.horas_estandar)}</p>
              </div>
              <div className="flex flex-wrap gap-1 pt-2 border-t border-slate-200">
                <Pildora tipo={o.anulado ? 'neutro' : o.estado === 'entregado' ? 'ok' : 'info'}>{o.anulado ? 'Anulada' : nombreEstado(o.estado)}</Pildora>
                {o.prioridad === 'alta' && <Pildora tipo="mal">Prioridad alta</Pildora>}
                {o.solicitudes_pendientes > 0 && <Pildora tipo="alerta">{o.solicitudes_pendientes} solicitudes pendientes</Pildora>}
                {o.hallazgos_pendientes > 0 && <Pildora tipo="alerta">{o.hallazgos_pendientes} hallazgos por aprobar</Pildora>}
                {o.imprevistos_pendientes > 0 && <Pildora tipo="alerta">{o.imprevistos_pendientes} imprevistos</Pildora>}
              </div>
            </button>
          ))}
        </div>
      )}
    </section>
  )
}
