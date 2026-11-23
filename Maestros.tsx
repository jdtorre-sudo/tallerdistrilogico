import { Navigate, useNavigate, useParams } from 'react-router-dom'
import { useSesion } from '../lib/sesion'
import type { Permiso } from '../lib/tipos'
import { Aviso, TituloSeccion } from '../components/ui'
import { Clientes, Complejidades, Conductores, ConfiguracionesEjes, CentrosCosto, ItemsChecklist, Proveedores, SistemasPreventivos, Tarifas, Tecnicos, TiposVehiculo, Vehiculos } from './Catalogos'
import CatalogoTrabajos from './CatalogoTrabajos'
import Usuarios from './Usuarios'
import Listas from './Listas'
import Parametros from './Parametros'
import Exportacion from './Exportacion'

interface Pestana { k: string; n: string; icono: string; grupo: string; c: () => JSX.Element; ver?: (tiene: (p: Permiso) => boolean, maestro: boolean) => boolean }

const PESTANAS: Pestana[] = [
  { k: 'usuarios', n: 'Usuarios y roles', icono: 'fa-user-shield', grupo: 'Personas', c: Usuarios, ver: (_, m) => m },
  { k: 'tecnicos', n: 'Técnicos', icono: 'fa-user-gear', grupo: 'Personas', c: Tecnicos },
  { k: 'tarifas', n: 'Tarifas', icono: 'fa-dollar-sign', grupo: 'Personas', c: Tarifas, ver: t => t('ver_costos') },
  { k: 'choferes', n: 'Choferes', icono: 'fa-id-badge', grupo: 'Personas', c: Conductores },
  { k: 'vehiculos', n: 'Vehículos', icono: 'fa-truck-front', grupo: 'Flota', c: Vehiculos },
  { k: 'clientes', n: 'Clientes', icono: 'fa-handshake', grupo: 'Flota', c: Clientes },
  { k: 'centros', n: 'Centros de costo', icono: 'fa-sitemap', grupo: 'Flota', c: CentrosCosto },
  { k: 'tipos', n: 'Tipos de vehículo', icono: 'fa-shapes', grupo: 'Flota', c: TiposVehiculo },
  { k: 'configuraciones', n: 'Configuraciones', icono: 'fa-diagram-project', grupo: 'Flota', c: ConfiguracionesEjes },
  { k: 'soldadura', n: 'Catálogo soldadura', icono: 'fa-fire-flame-curved', grupo: 'Trabajos', c: () => <CatalogoTrabajos taller="soldadura" /> },
  { k: 'mecanica', n: 'Catálogo mecánica', icono: 'fa-screwdriver-wrench', grupo: 'Trabajos', c: () => <CatalogoTrabajos taller="mecanica" /> },
  { k: 'complejidad', n: 'Complejidad', icono: 'fa-gauge-high', grupo: 'Trabajos', c: Complejidades },
  { k: 'preventivos', n: 'Intervalos preventivos', icono: 'fa-calendar-check', grupo: 'Trabajos', c: SistemasPreventivos },
  { k: 'proveedores', n: 'Proveedores', icono: 'fa-store', grupo: 'Otros', c: Proveedores },
  { k: 'listas', n: 'Listas', icono: 'fa-list-ul', grupo: 'Otros', c: Listas },
  { k: 'checklist', n: 'Checklist de recepción', icono: 'fa-clipboard-check', grupo: 'Otros', c: ItemsChecklist },
  { k: 'parametros', n: 'Parámetros y clave', icono: 'fa-sliders', grupo: 'Otros', c: Parametros, ver: (_, m) => m },
  { k: 'exportacion', n: 'Exportación y bitácora', icono: 'fa-file-export', grupo: 'Otros', c: Exportacion, ver: (_, m) => m }
]

/** Módulo Maestros: catálogos, técnicos, vehículos y parámetros (sección 7). */
export default function Maestros() {
  const { pestana } = useParams()
  const nav = useNavigate()
  const { tiene, esMaestro } = useSesion()
  if (!esMaestro && !tiene('editar_catalogos')) return <Aviso tipo="alerta">Maestros es solo para el maestro, o para quien tenga el permiso “Editar catálogos”.</Aviso>
  const visibles = PESTANAS.filter(p => !p.ver || p.ver(tiene, esMaestro))
  const actual = visibles.find(p => p.k === pestana)
  if (!actual) return <Navigate to={`/maestros/${visibles[0].k}`} replace />
  const grupos = [...new Set(visibles.map(p => p.grupo))]
  const Contenido = actual.c

  return (
    <section className="space-y-6">
      <TituloSeccion icono="fa-database" titulo="Maestros" subtitulo={esMaestro ? 'Catálogos, técnicos, vehículos y parámetros. Todo se configura aquí, sin tocar el programa.' : 'Usted puede editar los catálogos marcados; los demás son de solo lectura.'} />
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-3">
        {grupos.map(g => (
          <div key={g} className="bg-slate-100 p-1.5 rounded-2xl border border-slate-200">
            <p className="text-[10px] font-black uppercase tracking-widest text-slate-400 px-2 pt-1 pb-1.5">{g}</p>
            <div className="flex flex-wrap gap-1">
              {visibles.filter(p => p.grupo === g).map(p => (
                <button key={p.k} onClick={() => nav(`/maestros/${p.k}`)}
                  className={'py-2 px-3 rounded-xl text-xs font-bold transition flex items-center gap-1.5 ' + (p.k === actual.k ? 'bg-industrial-navy text-white shadow-md' : 'text-slate-600 hover:text-slate-900 hover:bg-white')}>
                  <i className={`fa-solid ${p.icono}`} />{p.n}
                </button>
              ))}
            </div>
          </div>
        ))}
      </div>
      <div key={actual.k}><Contenido /></div>
    </section>
  )
}
