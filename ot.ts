// Datos y reglas compartidas de la OT por segmentos (Fase 2).
import { supabase, ok } from './supabase'
import type { Taller } from './tipos'

export const TIPOS_OT = [
  { k: 'preventivo', n: 'Preventivo' }, { k: 'correctivo', n: 'Correctivo' }, { k: 'siniestro', n: 'Golpe / siniestro' },
  { k: 'llantas', n: 'Llantas' }, { k: 'fabricacion', n: 'Fabricación' }, { k: 'renovado', n: 'Renovado' }, { k: 'inspeccion', n: 'Inspección' }
]
export const nombreTipoOT = (k?: string | null) => TIPOS_OT.find(t => t.k === k)?.n || k || ''

export const ESTADOS_TRABAJO = [
  { k: 'pendiente', n: 'Pendiente', tono: 'neutro' }, { k: 'en_proceso', n: 'En proceso', tono: 'info' },
  { k: 'terminado', n: 'Terminado', tono: 'ok' }, { k: 'no_realizado', n: 'No realizado', tono: 'mal' }
] as const
export const estadoTrabajo = (k: string) => ESTADOS_TRABAJO.find(e => e.k === k) || ESTADOS_TRABAJO[0]

export const ORIGENES_TRABAJO = [{ k: 'chofer', n: 'Solicitud del chofer' }, { k: 'hallazgo', n: 'Hallazgo' }, { k: 'preventivo', n: 'Preventivo' }]
export const nombreOrigenTrabajo = (k: string) => ORIGENES_TRABAJO.find(o => o.k === k)?.n || k
export const MATERIALES = [{ k: 'hierro_negro', n: 'Hierro negro' }, { k: 'inoxidable', n: 'Inoxidable' }]
export const nombreMaterial = (k?: string | null) => MATERIALES.find(m => m.k === k)?.n || ''

export const ESTADOS_SOLICITUD = { pendiente: 'Pendiente', atendida: 'Atendida', no_realizada: 'No realizada', descartada: 'Descartada' } as Record<string, string>
export const ESTADOS_HALLAZGO = { pendiente: 'Pendiente', aprobado: 'Aprobado', descartado: 'Descartado' } as Record<string, string>

export interface TecnicoTrabajo { tecnico_id: string; codigo: string; nombre: string; porcentaje: number; horas: number }
export interface Trabajo {
  id: string; orden_trabajo_id: string; numero_linea: number; taller: Taller; sistema_id: string; elemento_id: string | null; intervencion_id: string
  sistema_nombre: string; elemento_nombre: string | null; intervencion_nombre: string; horas_unitarias: number; cantidad: number
  complejidad_id: string | null; complejidad_nombre: string | null; multiplicador: number; horas_estandar: number
  estado: string; origen: string; solicitud_id: string | null; hallazgo_id: string | null; causa: string | null; material_base: string | null
  observacion: string | null; motivo_no_realizado: string | null; detalle_no_realizado: string | null; anulado: boolean
  tecnicos: TecnicoTrabajo[]; solicitud_linea: number | null; solicitud_descripcion: string | null; hallazgo_linea: number | null; hallazgo_descripcion: string | null
}
export interface Solicitud { id: string; numero_linea: number; descripcion: string; taller_sugerido: Taller; estado: string; motivo: string | null; comentario: string | null; anulado: boolean }
export interface Hallazgo { id: string; numero_linea: number; descripcion: string; taller: Taller; sistema_id: string | null; estado: string; motivo: string | null; comentario: string | null; anulado: boolean; creado_en: string }
export interface Imprevisto { id: string; trabajo_id: string; tecnico_id: string; motivo: string; detalle: string | null; minutos: number; estado: string; anulado: boolean; creado_en: string }
export interface FilaOT {
  id: string; numero: string; formato: string; estado: string; motivo_ingreso: string; prioridad: string; inmovilizado: boolean
  fecha_apertura: string; fecha_cierre: string | null; lectura: number | null; anulado: boolean; fabricacion_descripcion: string | null
  fabricacion_cantidad: number | null; falla_reportada: string | null; vehiculo_id: string | null; codigo: string | null; placa: string | null
  tipo_vehiculo: string | null; unidad_medida: string | null; propiedad: string | null; cliente: string | null; centro_costo: string | null
  horas_parado_actual: number; trabajos_mecanica: number; trabajos_soldadura: number; trabajos_terminados: number; trabajos_abiertos: number
  horas_estandar: number; solicitudes_pendientes: number; hallazgos_pendientes: number; imprevistos_pendientes: number
}

/** Título corto de la OT: móvil o fabricación. */
export const tituloOT = (o: Pick<FilaOT, 'codigo' | 'placa' | 'fabricacion_descripcion' | 'fabricacion_cantidad'>) =>
  o.codigo ? `${o.codigo}${o.placa ? ' · ' + o.placa : ''}` : `Fabricación: ${o.fabricacion_cantidad ? o.fabricacion_cantidad + ' × ' : ''}${o.fabricacion_descripcion || ''}`

export const horasTxt = (h: number | string | null | undefined) => `${Number(h || 0).toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} h`

/** Lista de opciones editable de Maestros (listas_valores). */
export async function leerLista(lista: string, taller?: Taller): Promise<string[]> {
  const r = ok(await supabase.from('listas_valores').select('valor,taller').eq('lista', lista).eq('activo', true).order('orden')) as { valor: string; taller: string | null }[]
  return r.filter(x => !taller || !x.taller || x.taller === taller).map(x => x.valor)
}

export async function leerOTsAbiertas(): Promise<FilaOT[]> {
  return ok(await supabase.from('v_ot_lista').select('*').eq('formato', 'segmentos').eq('anulado', false).neq('estado', 'entregado').order('fecha_apertura')) as FilaOT[]
}

export async function leerTrabajos(ot: string): Promise<Trabajo[]> {
  return ok(await supabase.from('v_ot_trabajos').select('*').eq('orden_trabajo_id', ot).order('numero_linea')) as Trabajo[]
}

/** Tiempo estándar corto para las cápsulas: "0,5h", "2h", o en minutos cuando no es un décimo de hora (5 min, 15 min, 45 min). */
export function tiempoTxt(h: number | string): string {
  const n = Number(h || 0)
  if (n < 1 && Math.abs(n * 10 - Math.round(n * 10)) > 0.01) return `${Math.round(n * 60)} min`
  return `${n.toLocaleString('es-EC', { maximumFractionDigits: 2 })}h`
}
