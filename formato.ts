export const ZONA = 'America/Guayaquil'

export function fechaHora(t?: string | null): string {
  if (!t) return ''
  return new Date(t).toLocaleString('es-EC', { timeZone: ZONA, day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false })
}

export function fecha(t?: string | null): string {
  if (!t) return ''
  const d = t.length === 10 ? new Date(t + 'T12:00:00') : new Date(t)
  return d.toLocaleDateString('es-EC', { timeZone: ZONA, day: '2-digit', month: '2-digit', year: 'numeric' })
}

/** Año y mes en Guayaquil, para las rutas de archivos: ['2026','10'] */
export function anioMes(t: string | Date = new Date()): [string, string] {
  const p = new Intl.DateTimeFormat('en-CA', { timeZone: ZONA, year: 'numeric', month: '2-digit' }).formatToParts(new Date(t))
  return [p.find(x => x.type === 'year')!.value, p.find(x => x.type === 'month')!.value]
}

export function hoyISO(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: ZONA }).format(new Date())
}

export function numero(n?: number | string | null, dec = 0): string {
  if (n === null || n === undefined || n === '') return ''
  return Number(n).toLocaleString('es-EC', { minimumFractionDigits: dec, maximumFractionDigits: dec })
}

export function lectura(n: number | string | null | undefined, unidad = 'km'): string {
  if (n === null || n === undefined || n === '') return ''
  return `${numero(n, unidad === 'horas' ? 1 : 0)} ${unidad === 'horas' ? 'h' : 'km'}`
}

export function duracion(horas?: number | string | null): string {
  if (horas === null || horas === undefined) return ''
  const h = Number(horas)
  if (h < 1) return `${Math.max(0, Math.round(h * 60))} min`
  const d = Math.floor(h / 24)
  const r = Math.round(h - d * 24)
  return d > 0 ? `${d} d ${r} h` : `${r} h`
}

export function horasDesde(t?: string | null): number {
  if (!t) return 0
  return (Date.now() - new Date(t).getTime()) / 3600000
}

export const ESTADOS_OT: { k: string; n: string }[] = [
  { k: 'recepcion', n: 'Recepción' },
  { k: 'diagnostico', n: 'Diagnóstico' },
  { k: 'cotizando', n: 'Cotizando' },
  { k: 'esperando_repuestos', n: 'Esperando repuestos' },
  { k: 'en_reparacion', n: 'En reparación' },
  { k: 'control_calidad', n: 'Control de calidad' },
  { k: 'listo_entrega', n: 'Listo para entrega' },
  { k: 'entregado', n: 'Entregado / cerrado' }
]
export const nombreEstado = (k: string) => ESTADOS_OT.find(e => e.k === k)?.n || k

export const ESTADOS_LINEA: { k: string; n: string }[] = [
  { k: 'pendiente', n: 'Pendiente' },
  { k: 'en_proceso', n: 'En proceso' },
  { k: 'esperando_repuestos', n: 'Esperando repuestos' },
  { k: 'en_tercero', n: 'En tercero' },
  { k: 'terminada', n: 'Terminada' }
]
export const nombreEstadoLinea = (k: string) => ESTADOS_LINEA.find(e => e.k === k)?.n || k

export const MOTIVOS: { k: string; n: string }[] = [
  { k: 'preventivo', n: 'Preventivo' },
  { k: 'correctivo', n: 'Correctivo' },
  { k: 'llantas', n: 'Llantas' },
  { k: 'siniestro', n: 'Golpe / siniestro' },
  { k: 'inspeccion', n: 'Inspección' }
]
export const nombreMotivo = (k: string) => MOTIVOS.find(e => e.k === k)?.n || k

export const MOTIVOS_ENTREGA: { k: string; n: string }[] = [
  { k: 'asignacion', n: 'Asignación' },
  { k: 'cambio_conductor', n: 'Cambio de conductor' },
  { k: 'reemplazo_temporal', n: 'Reemplazo temporal' },
  { k: 'salida_taller', n: 'Salida de taller' },
  { k: 'otro', n: 'Otro' }
]
export const MOTIVOS_RECEPCION: { k: string; n: string }[] = [
  { k: 'cambio_conductor', n: 'Cambio de conductor' },
  { k: 'vacaciones_permiso', n: 'Vacaciones / permiso' },
  { k: 'fin_relacion', n: 'Fin de relación laboral' },
  { k: 'ingreso_taller', n: 'Ingreso a taller' },
  { k: 'siniestro', n: 'Siniestro' },
  { k: 'otro', n: 'Otro' }
]
export const nombreMotivoActa = (k: string) => [...MOTIVOS_ENTREGA, ...MOTIVOS_RECEPCION].find(e => e.k === k)?.n || k

export const COMBUSTIBLE = ['E', '1/4', '1/2', '3/4', 'F']

export const ROLES: { k: string; n: string; d: string }[] = [
  { k: 'maestro', n: 'Maestro', d: 'Todo: crea, edita y anula en todos los módulos; usuarios, maestros y parámetros.' },
  { k: 'supervisor', n: 'Supervisor', d: 'Asesor de servicios / jefe de patio: abre y cierra OT, hallazgos, trabajos, técnicos, imprevistos y asistencia.' },
  { k: 'bodega', n: 'Bodega', d: 'OT abiertas, repuestos a la OT, devoluciones e inventarios (sin aprobar ajustes).' },
  { k: 'tecnico', n: 'Técnico', d: 'Ve las OT abiertas, escribe su observación donde está asignado, su historial y producción. No ve costos.' }
]
export const PERMISOS_EXTRA: { k: string; n: string; d: string }[] = [
  { k: 'bodega', n: 'Bodega', d: 'Despachar repuestos y usar Inventarios (ej. supervisor de turno el domingo).' },
  { k: 'aprobar_ajustes', n: 'Aprobar ajustes', d: 'Aprobar ajustes del kardex con la clave de aprobación.' },
  { k: 'gestion_personal', n: 'Gestión de personal', d: 'Asistencia, novedades, días libres y vacaciones.' },
  { k: 'ver_costos', n: 'Ver costos', d: 'Ver costos de repuestos, mano de obra, tarifas y terceros.' },
  { k: 'editar_catalogos', n: 'Editar catálogos', d: 'Editar vehículos, choferes, clientes, proveedores, listas y el catálogo de trabajos.' }
]
export const nombrePermiso = (k: string) => PERMISOS_EXTRA.find(e => e.k === k)?.n || k
export const TALLERES: { k: 'mecanica' | 'soldadura'; n: string }[] = [{ k: 'mecanica', n: 'Mecánica' }, { k: 'soldadura', n: 'Soldadura' }]
export const nombreTaller = (k?: string | null) => TALLERES.find(e => e.k === k)?.n || (k === 'ambas' ? 'Ambas' : k || '')
export const ESPECIALIDADES = [{ k: 'mecanica', n: 'Mecánica' }, { k: 'soldadura', n: 'Soldadura' }, { k: 'ambas', n: 'Ambas' }]
export const ESTADOS_VEHICULO = [
  { k: 'activo', n: 'Activo' }, { k: 'parado', n: 'Parado' }, { k: 'venta', n: 'En venta' }, { k: 'tramite', n: 'En trámite' }
]
export const LISTAS: { k: string; n: string; porTaller?: boolean; grupo?: 'kardex'; d: string }[] = [
  { k: 'causa_dano', n: 'Causas de daño', d: 'Se eligen en cada trabajo de soldadura.' },
  { k: 'motivo_imprevisto', n: 'Motivos de imprevisto', d: 'El técnico afectado, un motivo de esta lista, texto libre y minutos.' },
  { k: 'motivo_no_realizado', n: 'Motivos de no realizado', d: 'Obligatorio cuando un trabajo o una solicitud del chofer no se realiza.' },
  { k: 'motivo_descarte', n: 'Motivos de descarte', d: 'Al descartar una solicitud del chofer o un hallazgo.' },
  { k: 'tipo_novedad_personal', n: 'Tipos de novedad de personal', d: 'Permiso, capacitación, calamidad, llamado de atención, reconocimiento…' },
  { k: 'checklist_calidad', n: 'Checklist de control de calidad', porTaller: true, d: 'Puntos que revisa quien aprueba el control de calidad, por taller.' },
  { k: 'motivo_llanta', n: 'Motivo cambio de llanta', grupo: 'kardex', d: 'Lista del kardex. Alimenta el registro de componentes (llantas).' },
  { k: 'kit_embrague', n: 'Cambio de kit de embrague', grupo: 'kardex', d: 'Lista del kardex (embrague).' },
  { k: 'frenos', n: 'Cambio de frenos (zapatas)', grupo: 'kardex', d: 'Lista del kardex (frenos).' },
  { k: 'aceite', n: 'Cambio de aceite', grupo: 'kardex', d: 'Lista del kardex (aceite motor, caja y corona).' },
  { k: 'inyeccion', n: 'Trabajo de inyección', grupo: 'kardex', d: 'Lista del kardex (inyección).' },
  { k: 'criterio', n: 'Criterio a tomar', grupo: 'kardex', d: 'Lista del kardex para conteos y cierre.' },
  { k: 'estado_compra', n: 'Status de compras', grupo: 'kardex', d: 'Lista del kardex (compras).' },
  { k: 'estado_herramienta', n: 'Estado de herramientas', grupo: 'kardex', d: 'Lista del kardex (préstamo de herramientas).' }
]
/** Edad legible a partir del mes de ingreso a la flota (AAAA-MM-DD). */
export function edad(desde?: string | null): string {
  if (!desde) return ''
  const d = new Date(desde + 'T12:00:00'), h = new Date()
  const meses = (h.getFullYear() - d.getFullYear()) * 12 + h.getMonth() - d.getMonth()
  if (meses < 0) return ''
  const a = Math.floor(meses / 12), m = meses % 12
  return a ? `${a} a${m ? ` ${m} m` : ''}` : `${m} m`
}
export const nombreRol = (k: string) => ROLES.find(e => e.k === k)?.n || k

export const TIPOS_DANO: { k: string; n: string }[] = [
  { k: 'golpe', n: 'Golpe' },
  { k: 'rayon', n: 'Rayón' },
  { k: 'rotura', n: 'Rotura' },
  { k: 'oxidacion', n: 'Oxidación' },
  { k: 'otro', n: 'Otro' }
]
export const nombreDano = (k: string) => TIPOS_DANO.find(e => e.k === k)?.n || k

export const ORIGENES: { k: string; n: string }[] = [
  { k: 'bodega_s3', n: 'Bodega (S3)' },
  { k: 'orden_compra', n: 'Orden de compra (OC)' },
  { k: 'tercero', n: 'Tercero' }
]
export const nombreOrigen = (k: string) => ORIGENES.find(e => e.k === k)?.n || k

export const RESULTADOS = [
  { k: 'ok', n: 'OK' },
  { k: 'falta', n: 'Falta' },
  { k: 'danado', n: 'Dañado' }
]
export const nombreResultado = (k?: string) => RESULTADOS.find(e => e.k === k)?.n || '—'

/** Celular ecuatoriano 09XXXXXXXX → 5939XXXXXXXX para WhatsApp */
export function telefonoWhatsApp(t?: string | null): string | null {
  if (!t) return null
  const d = t.replace(/\D/g, '')
  if (d.startsWith('593')) return d
  if (d.startsWith('0') && d.length === 10) return '593' + d.slice(1)
  return d.length >= 9 ? d : null
}

export function uuid(): string {
  return crypto.randomUUID()
}
