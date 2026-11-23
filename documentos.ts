// Arma los datos de cada documento (acta de recepción, OT, acta de entrega)
// leyendo la base. Los PDF se generan desde aquí; nunca se guardan.
import { supabase, ok } from './supabase'
import { cargarCatalogos, nombreConductor, tipoDe } from './catalogos'
import { archivoComoDataUrl } from './cola'
import type { Dano, Diagrama, Vehiculo } from './tipos'

export interface Empresa { nombre: string; ruc: string; direccion: string; telefono: string }
export interface VehiculoDoc { codigo: string; placa: string; tipo: string; marca: string; modelo: string; anio: string; chasis: string; motor: string; unidad: string; diagrama: Diagrama }
export interface FilaChk { nombre: string; grupo: string; resultado?: string; observacion?: string; resultado_ingreso?: string; observacion_ingreso?: string }

export interface DocActa {
  tipo: 'recepcion' | 'entrega'
  numero: string; fecha_hora: string; empresa: Empresa; vehiculo: VehiculoDoc
  conductor: { nombre: string; cedula: string; telefono: string }; responsable: string
  lectura: number; combustible: string; motivo: string; observaciones: string
  checklist: FilaChk[]; danos: Dano[]; firmas: { conductor: string | null; responsable: string | null }
}
export interface DocOT {
  numero: string; empresa: Empresa; vehiculo: VehiculoDoc; estado: string; prioridad: string; inmovilizado: boolean
  fecha_apertura: string; fecha_cierre: string | null; horas_parado: number; lectura: number; motivo: string
  conductor: string; falla: string; diagnostico: string
  lineas: { numero: number; sistema: string; tipo: string; area: string; ejecutor: string; descripcion: string; tecnico: string; horas_estimadas: number | null; horas_reales: number; estado: string; categoria: string;
            repuestos: { codigo: string; descripcion: string; cantidad: number; unidad: string; origen: string; documento: string }[] }[]
  historial: { fecha_hora: string; estado_anterior: string | null; estado_nuevo: string; usuario: string; comentario: string }[]
  comentarios: { fecha_hora: string; usuario: string; texto: string }[]
}

async function empresa(): Promise<Empresa> {
  const c = (await cargarCatalogos()).config
  return { nombre: c.nombre_empresa || 'DISTRILÓGICO', ruc: c.ruc_empresa || '', direccion: c.direccion_empresa || '', telefono: c.telefono_empresa || '' }
}

async function vehiculoDoc(id: string): Promise<VehiculoDoc> {
  const cat = await cargarCatalogos()
  const v = cat.vehiculos.find(x => x.id === id) || (ok(await supabase.from('vehiculos').select('*').eq('id', id).single()) as Vehiculo)
  const t = tipoDe(cat, v)
  return { codigo: v!.codigo, placa: v!.placa || '', tipo: t?.nombre || '', marca: v!.marca || '', modelo: v!.modelo || '', anio: v!.anio ? String(v!.anio) : '',
           chasis: v!.numero_chasis || '', motor: v!.numero_motor || '', unidad: t?.unidad_medida || 'km', diagrama: t?.diagrama || 'cabezal' }
}

const nombreUsuario = async (id?: string | null) => (await cargarCatalogos()).usuarios.find(u => u.id === id)?.nombre_completo || ''

async function rutaArchivo(id?: string | null) {
  if (!id) return null
  const r = await supabase.from('archivos').select('ruta').eq('id', id).maybeSingle()
  return (r.data as { ruta: string } | null)?.ruta || null
}

export async function cargarDocActa(tipo: 'recepcion' | 'entrega', actaId: string): Promise<DocActa> {
  const cat = await cargarCatalogos()
  const rec = tipo === 'recepcion'
  const a = ok(await supabase.from(rec ? 'actas_recepcion' : 'actas_entrega').select('*').eq('id', actaId).single()) as Record<string, any>
  const [chk, danos] = await Promise.all([
    supabase.from(rec ? 'checklist_recepcion' : 'checklist_entrega').select('*').eq(rec ? 'acta_recepcion_id' : 'acta_entrega_id', actaId),
    supabase.from('danos_vehiculo').select('*').eq(rec ? 'acta_recepcion_id' : 'acta_entrega_id', actaId).eq('anulado', false).order('numero_marca')
  ])
  const cond = cat.conductores.find(c => c.id === a.conductor_id)
  const [f1, f2] = await Promise.all([
    rutaArchivo(a.firma_conductor_id).then(archivoComoDataUrl),
    rutaArchivo(rec ? a.firma_recibe_id : a.firma_entrega_id).then(archivoComoDataUrl)
  ])
  return {
    tipo, numero: a.numero, fecha_hora: a.fecha_hora, empresa: await empresa(), vehiculo: await vehiculoDoc(a.vehiculo_id),
    conductor: { nombre: nombreConductor(cond), cedula: cond?.cedula || '', telefono: cond?.telefono || '' },
    responsable: await nombreUsuario(rec ? a.recibido_por : a.entregado_por),
    lectura: a.lectura, combustible: a.combustible, motivo: a.motivo, observaciones: a.observaciones || '',
    checklist: cat.items.map(i => {
      const f = (ok(chk) as any[]).find(x => x.item_checklist_id === i.id)
      return f ? { nombre: i.nombre, grupo: i.grupo, resultado: f.resultado, observacion: f.observacion || '' } : null
    }).filter(Boolean) as FilaChk[],
    danos: ok(danos) as Dano[], firmas: { conductor: f1, responsable: f2 }
  }
}

export async function cargarDocOT(otId: string): Promise<DocOT> {
  const cat = await cargarCatalogos()
  const o = ok(await supabase.from('v_tablero_ot').select('*').eq('id', otId).single()) as Record<string, any>
  const [lineas, hist, com] = await Promise.all([
    supabase.from('v_lineas_trabajo').select('*').eq('orden_trabajo_id', otId).eq('anulado', false).order('numero_linea'),
    supabase.from('historial_estados_ot').select('*').eq('orden_trabajo_id', otId).order('fecha_hora'),
    supabase.from('comentarios_ot').select('*').eq('orden_trabajo_id', otId).eq('anulado', false).order('fecha_hora')
  ])
  const ls = ok(lineas) as any[]
  const reps = ls.length ? ok(await supabase.from('repuestos_linea').select('*').in('linea_trabajo_id', ls.map(l => l.id)).eq('anulado', false).order('creado_en')) as any[] : []
  const usu = (id: string) => cat.usuarios.find(u => u.id === id)?.nombre_completo || ''
  return {
    numero: o.numero, empresa: await empresa(), vehiculo: await vehiculoDoc(o.vehiculo_id), estado: o.estado, prioridad: o.prioridad, inmovilizado: o.inmovilizado,
    fecha_apertura: o.fecha_apertura, fecha_cierre: o.fecha_cierre, horas_parado: o.horas_parado_actual, lectura: o.lectura, motivo: o.motivo_ingreso,
    conductor: nombreConductor(cat.conductores.find(c => c.id === o.conductor_id)), falla: o.falla_reportada || '', diagnostico: o.diagnostico || '',
    lineas: ls.map(l => ({
      numero: l.numero_linea, sistema: l.sistema, tipo: l.tipo_mantenimiento, area: l.area, ejecutor: l.ejecutor, descripcion: l.descripcion, tecnico: l.tecnico || '',
      horas_estimadas: l.horas_estimadas, horas_reales: Number(l.horas_reales), estado: l.estado, categoria: l.categoria_gasto || '',
      repuestos: reps.filter(r => r.linea_trabajo_id === l.id).map(r => ({ codigo: r.codigo || '', descripcion: r.descripcion, cantidad: Number(r.cantidad), unidad: r.unidad, origen: r.origen, documento: r.numero_documento || '' }))
    })),
    historial: (ok(hist) as any[]).map(h => ({ fecha_hora: h.fecha_hora, estado_anterior: h.estado_anterior, estado_nuevo: h.estado_nuevo, usuario: usu(h.usuario_id), comentario: h.comentario || '' })),
    comentarios: (ok(com) as any[]).map(c => ({ fecha_hora: c.fecha_hora, usuario: usu(c.usuario_id), texto: c.texto }))
  }
}
