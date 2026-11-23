import { useState } from 'react'
import { NavLink, Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { useSesion } from './lib/sesion'
import { useCola } from './lib/cola'
import { configurado } from './lib/supabase'
import { nombreRol } from './lib/formato'
import { MENU } from './lib/menu'
import { Aviso, Cargando } from './components/ui'
import Ingreso from './paginas/Ingreso'
import Inicio from './paginas/Inicio'
import Maestros from './paginas/Maestros'
import MiPerfil from './paginas/MiPerfil'
import Proximamente from './paginas/Proximamente'
import Ordenes from './paginas/Ordenes'
import NuevaOrden from './paginas/NuevaOrden'
import OrdenDetalle from './paginas/OrdenDetalle'
import Ambiente from './paginas/Ambiente'
import MisTrabajos from './paginas/MisTrabajos'

const iniciales = (n: string) => n.split(/\s+/).filter(Boolean).slice(0, 2).map(p => p[0]).join('').toUpperCase()

export default function App() {
  const { cargando, sesion, perfil, salir, tiene } = useSesion()
  const { pendientes, enLinea } = useCola()
  const [menuAbierto, setMenuAbierto] = useState(false)
  const loc = useLocation()

  if (!configurado) return <div className="p-6"><Aviso tipo="mal">Falta configurar la conexión con Supabase (VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY). Vea el LEEME.</Aviso></div>
  if (cargando) return <Cargando />
  if (!sesion) return <Ingreso />
  if (!perfil) return (
    <div className="min-h-screen bg-slate-100 flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl p-6 border border-slate-200 max-w-md space-y-4">
        <Aviso tipo="alerta">Su usuario existe pero no tiene ficha activa en el sistema. Pida al maestro que lo active.</Aviso>
        <button className="btn-gris" onClick={salir}>Salir</button>
      </div>
    </div>
  )

  const items = MENU.filter(m => m.ver(perfil.rol, tiene))
  const actual = items.find(m => m.ruta !== '/' && loc.pathname.startsWith(m.ruta)) || items.find(m => m.ruta === loc.pathname)
  const inicio = perfil.rol === 'tecnico' ? '/perfil' : '/'

  return (
    <div className="bg-slate-100 text-slate-800 min-h-screen flex flex-col antialiased">
      {/* ENCABEZADO INDUSTRIAL (franja roja) */}
      <header className="bg-industrial-navy text-white shadow-lg border-b-4 border-industrial-red sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-4 py-3 flex justify-between items-center gap-3">
          <div className="flex items-center gap-3 min-w-0">
            <button className="md:hidden bg-slate-800/90 border border-slate-700 rounded-xl w-10 h-10 flex items-center justify-center" aria-label="Menú" onClick={() => setMenuAbierto(!menuAbierto)}>
              <i className={`fa-solid ${menuAbierto ? 'fa-xmark' : 'fa-bars'}`} />
            </button>
            <div className="bg-industrial-red p-2.5 rounded-2xl shadow-md flex items-center justify-center w-11 h-11 shrink-0">
              <i className={`fa-solid ${actual?.icono || 'fa-truck-front'} text-white text-lg`} />
            </div>
            <div className="min-w-0">
              <div className="flex items-center gap-2">
                <span className="text-[10px] uppercase tracking-widest text-slate-400 font-extrabold">DISTRILÓGICO S.A.</span>
                <span className="hidden sm:inline bg-industrial-red/20 text-red-300 text-[10px] font-bold px-2 py-0.5 rounded-full border border-industrial-red/30 uppercase">{nombreRol(perfil.rol)}</span>
              </div>
              <h1 className="text-base md:text-lg font-bold tracking-tight text-white truncate">{actual?.k === 'inicio' || !actual ? 'Sistema de Gestión del Taller' : actual.n}</h1>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <span title={pendientes.length ? `${pendientes.length} registros guardados en este equipo` : ''}
              className={'hidden sm:flex px-3 py-1.5 rounded-xl font-bold text-[11px] items-center gap-1.5 border ' + (enLinea ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/40' : 'bg-amber-500/20 text-amber-400 border-amber-500/40')}>
              <span className={'w-2 h-2 rounded-full ' + (enLinea ? 'bg-emerald-400' : 'bg-amber-400 animate-pulse')} />
              {enLinea ? 'EN LÍNEA' : 'SIN SEÑAL'}{pendientes.length ? ` · ${pendientes.length} POR ENVIAR` : ''}
            </span>
            <div className="hidden sm:block text-right">
              <p className="text-xs font-extrabold text-white">{perfil.nombre_completo}</p>
              <p className="text-[10px] text-slate-400">{nombreRol(perfil.rol)}{perfil.permisos_extra?.length ? ' + permisos extra' : ''}</p>
            </div>
            <div className="w-10 h-10 rounded-2xl bg-industrial-blue border-2 border-industrial-red flex items-center justify-center text-white font-black text-sm shadow">{iniciales(perfil.nombre_completo)}</div>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-4 py-6 flex-1 w-full flex flex-col md:flex-row gap-6">
        {/* MENÚ LATERAL DE CÁPSULAS */}
        <aside className={'w-full md:w-64 shrink-0 ' + (menuAbierto ? '' : 'hidden md:block')}>
          <div className="bg-industrial-navy text-white rounded-3xl p-4 shadow-xl border border-slate-800 md:sticky md:top-24">
            <p className="text-[10px] font-black uppercase tracking-widest text-slate-400 mb-4 px-2">Cápsulas de navegación</p>
            <nav className="space-y-2" onClick={() => setMenuAbierto(false)}>
              {items.map(m => (
                <NavLink key={m.k} to={m.ruta} end={m.ruta === '/'}
                  className={({ isActive }) => 'dock-nav w-full flex items-center justify-between p-3.5 text-xs font-bold text-left ' + (isActive ? 'active' : 'text-slate-300 hover:bg-slate-800')}>
                  <span className="flex items-center gap-3"><i className={`fa-solid ${m.icono} text-base w-5 text-center text-slate-300`} /><span>{m.n}</span></span>
                  {m.fase && <span className="bg-slate-700 text-slate-300 text-[9px] font-black px-2 py-0.5 rounded-full whitespace-nowrap shrink-0">FASE {m.fase}</span>}
                </NavLink>
              ))}
            </nav>
            <div className="border-t border-slate-700 mt-4 pt-3 px-2 flex items-center justify-between gap-2">
              <span className="text-[11px] text-slate-400 truncate sm:hidden">{perfil.nombre_completo}</span>
              <button onClick={salir} className="text-xs font-bold text-slate-300 hover:text-white flex items-center gap-2"><i className="fa-solid fa-right-from-bracket" /> Salir</button>
            </div>
          </div>
        </aside>

        {/* ESPACIO DE TRABAJO */}
        <main className="flex-1 min-w-0 bg-white rounded-3xl p-4 sm:p-6 shadow-sm border border-slate-200" key={loc.pathname.split('/')[1]}>
          <Routes>
            <Route path="/" element={perfil.rol === 'tecnico' ? <Navigate to="/perfil" replace /> : <Inicio />} />
            <Route path="/perfil" element={<MiPerfil />} />
            <Route path="/maestros" element={<Maestros />} />
            <Route path="/maestros/:pestana" element={<Maestros />} />
            <Route path="/ot" element={<Ordenes />} />
            <Route path="/ot/nueva" element={<NuevaOrden />} />
            <Route path="/ot/:id" element={<OrdenDetalle />} />
            <Route path="/ambiente/:taller" element={<Ambiente />} />
            <Route path="/mis-trabajos" element={<MisTrabajos />} />
            <Route path="/proximamente/:modulo" element={<Proximamente />} />
            <Route path="*" element={<Navigate to={inicio} replace />} />
          </Routes>
        </main>
      </div>

      <footer className="bg-slate-900 text-slate-400 text-xs py-4 mt-auto border-t border-slate-800">
        <div className="max-w-7xl mx-auto px-4 flex flex-col sm:flex-row justify-between items-center gap-2">
          <p>DISTRILÓGICO S.A. © 2026 - Sistema Unificado de Talleres (Mecánica y Soldadura)</p>
          <p className="text-slate-500">Fase 2 · OT por segmentos y ambientes de taller</p>
        </div>
      </footer>
    </div>
  )
}
