import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { useSesion } from '../lib/sesion'
import { PERMISOS_EXTRA, ROLES, nombrePermiso } from '../lib/formato'
import { Kpi, Pildora, TituloSeccion } from '../components/ui'

const FASES = [
  { n: 1, t: 'Login, roles y permisos + Maestros', d: 'Técnicos, vehículos, choferes, catálogos de mecánica y soldadura, listas y parámetros.' },
  { n: 2, t: 'OT por segmentos + ambientes Mecánica y Soldadura', d: 'Cápsulas, novedades y observaciones de técnicos.' },
  { n: 3, t: 'Inventarios', d: 'Importar el kardex, verificar saldos, pantalla de bodega, salida automática desde la OT y costos.' },
  { n: 4, t: 'Terceros, control de calidad y cierre', d: 'Cotizaciones, acta de entrega y cierre de OT.' },
  { n: 5, t: 'Gestión de personal', d: 'Asistencia, novedades, días libres y vacaciones.' },
  { n: 6, t: 'Tableros, reportes y portal del técnico', d: 'Producción, indicadores y directorio de contactos.' }
]

const contar = async (tabla: string, filtro?: (q: any) => any) => {
  let q = supabase.from(tabla).select('id', { count: 'exact', head: true })
  if (filtro) q = filtro(q)
  return (await q).count ?? 0
}

export default function Inicio() {
  const { perfil, tiene } = useSesion()
  const [n, setN] = useState<Record<string, number>>({})
  useEffect(() => {
    Promise.all([
      contar('tecnicos', q => q.eq('activo', true)), contar('vehiculos', q => q.eq('estado', 'activo')),
      contar('sistemas', q => q.eq('activo', true).eq('taller', 'soldadura')), contar('sistemas', q => q.eq('activo', true).eq('taller', 'mecanica')),
      contar('intervenciones', q => q.eq('activo', true))
    ]).then(([tec, veh, sol, mec, int]) => setN({ tec, veh, sol, mec, int })).catch(() => undefined)
  }, [])
  if (!perfil) return null
  const extras = perfil.permisos_extra || []
  return (
    <section className="space-y-6">
      <TituloSeccion icono="fa-house" titulo={`Bienvenido, ${perfil.nombre_completo.split(' ')[0]}`}
        subtitulo={ROLES.find(r => r.k === perfil.rol)?.d}>
        {(perfil.rol === 'maestro' || tiene('editar_catalogos')) && <Link to="/maestros" className="btn-rojo"><i className="fa-solid fa-database" />Ir a Maestros</Link>}
      </TituloSeccion>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <Kpi titulo="Técnicos activos" valor={n.tec ?? '—'} icono="fa-user-gear" />
        <Kpi titulo="Vehículos activos" valor={n.veh ?? '—'} icono="fa-truck-front" tono="verde" />
        <Kpi titulo="Cápsulas sold. / mec." valor={n.sol === undefined ? '—' : `${n.sol} / ${n.mec}`} icono="fa-cubes" tono="rojo" />
        <Kpi titulo="Intervenciones en catálogo" valor={n.int ?? '—'} icono="fa-clock" tono="ambar" />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="md:col-span-2 bg-slate-50 p-5 rounded-3xl border border-slate-200 space-y-3">
          <h4 className="text-xs font-extrabold text-slate-700 uppercase">Plan de construcción</h4>
          {FASES.map(f => (
            <div key={f.n} className="bg-white p-3.5 rounded-2xl border border-slate-200 flex justify-between items-center gap-3 text-xs">
              <div><p className="font-bold text-slate-800">Fase {f.n}. {f.t}</p><p className="text-[11px] text-slate-500">{f.d}</p></div>
              {f.n === 1 ? <Pildora tipo="ok">LISTA</Pildora> : f.n === 2 ? <Pildora tipo="info">EN REVISIÓN</Pildora> : <Pildora tipo="neutro">PENDIENTE</Pildora>}
            </div>
          ))}
        </div>
        <div className="bg-blue-50/60 p-5 rounded-3xl border border-blue-200 space-y-3 text-xs">
          <h4 className="text-xs font-extrabold text-industrial-blue uppercase">Sus permisos</h4>
          <p><b>Rol:</b> {ROLES.find(r => r.k === perfil.rol)?.n}</p>
          <p className="font-bold text-slate-600">Permisos extra:</p>
          {perfil.rol === 'maestro' ? <p className="text-slate-500">El maestro tiene todos los permisos.</p>
            : extras.length ? <div className="flex flex-wrap gap-1">{extras.map(p => <Pildora key={p} tipo="info">{nombrePermiso(p)}</Pildora>)}</div>
            : <p className="text-slate-500">Ninguno.</p>}
          <p className="text-[11px] text-slate-500">Los permisos se aplican en la base de datos. Los asigna el maestro en Maestros → Usuarios. Disponibles: {PERMISOS_EXTRA.map(p => p.n).join(', ')}.</p>
        </div>
      </div>
    </section>
  )
}
