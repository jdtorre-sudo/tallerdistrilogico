import { get, set } from 'idb-keyval'
import { supabase, ok } from './supabase'
import type { Area, CentroCosto, Cliente, ConfigEjes, Conductor, ItemChecklist, Repuesto, Sistema, SistemaPreventivo, Tecnico, TipoVehiculo, Usuario, Vehiculo } from './tipos'

export interface Catalogos {
  vehiculos: Vehiculo[]; tipos: TipoVehiculo[]; conductores: Conductor[]; items: ItemChecklist[]
  sistemas: Sistema[]; areas: Area[]; tecnicos: Tecnico[]; repuestos: Repuesto[]; usuarios: Usuario[]
  ejes: ConfigEjes[]; clientes: Cliente[]; centros: CentroCosto[]; preventivos: SistemaPreventivo[]
  config: Record<string, string>; actualizado: string
}

let memoria: Catalogos | null = null
const CLAVE = 'catalogos-v2'

/** Descarga los catálogos y los guarda en el equipo para usarlos sin conexión. */
export async function cargarCatalogos(forzar = false): Promise<Catalogos> {
  if (memoria && !forzar) return memoria
  try {
    const [vehiculos, tipos, conductores, items, sistemas, areas, tecnicos, repuestos, usuarios, ejes, config, clientes, centros, preventivos] = await Promise.all([
      supabase.from('vehiculos').select('*').order('codigo'),
      supabase.from('tipos_vehiculo').select('*').order('prefijo_codigo'),
      supabase.from('conductores').select('*').order('apellidos'),
      supabase.from('items_checklist').select('*').order('orden'),
      supabase.from('sistemas').select('*').order('taller').order('orden'),
      supabase.from('areas_taller').select('*').order('orden'),
      supabase.from('tecnicos').select('*').order('codigo'),
      supabase.from('repuestos').select('*').order('codigo'),
      supabase.from('usuarios').select('*').order('nombre_completo'),
      supabase.from('configuraciones_ejes').select('*').order('nombre'),
      supabase.from('configuracion').select('clave,valor'),
      supabase.from('clientes').select('*').order('nombre'),
      supabase.from('centros_costo').select('*').order('codigo'),
      supabase.from('sistemas_preventivos').select('*').order('orden')
    ])
    memoria = {
      vehiculos: ok(vehiculos) as Vehiculo[], tipos: ok(tipos) as TipoVehiculo[], conductores: ok(conductores) as Conductor[],
      items: ok(items) as ItemChecklist[], sistemas: ok(sistemas) as Sistema[], areas: ok(areas) as Area[],
      tecnicos: ok(tecnicos) as Tecnico[], repuestos: ok(repuestos) as Repuesto[], usuarios: ok(usuarios) as Usuario[],
      ejes: ok(ejes) as ConfigEjes[], clientes: ok(clientes) as Cliente[], centros: ok(centros) as CentroCosto[],
      preventivos: ok(preventivos) as SistemaPreventivo[],
      config: Object.fromEntries((ok(config) as { clave: string; valor: string }[]).map(c => [c.clave, c.valor])),
      actualizado: new Date().toISOString()
    }
    await set(CLAVE, memoria).catch(() => undefined)
    return memoria
  } catch (e) {
    const guardado = await get<Catalogos>(CLAVE).catch(() => undefined)
    if (guardado) { memoria = guardado; return guardado }
    throw e
  }
}

export function invalidarCatalogos() { memoria = null }

export const tipoDe = (c: Catalogos, v?: Vehiculo | null) => c.tipos.find(t => t.id === v?.tipo_vehiculo_id)
export const nombreConductor = (x?: Conductor | null) => (x ? `${x.nombres} ${x.apellidos}` : '')
export const etiquetaVehiculo = (v?: Vehiculo | null) => (v ? `${v.codigo}${v.placa ? ' · ' + v.placa : ''}` : '')
export const etiquetaTecnico = (t?: Tecnico | null) => (t ? `${t.codigo} · ${t.nombres}` : '')
