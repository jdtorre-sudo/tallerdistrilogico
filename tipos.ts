export type Rol = 'maestro' | 'supervisor' | 'bodega' | 'tecnico'
/** Permisos que se pueden sumar a una persona además de su rol. */
export type PermisoExtra = 'bodega' | 'aprobar_ajustes' | 'gestion_personal' | 'ver_costos' | 'editar_catalogos'
/** Todo lo que se puede consultar con tiene(): los permisos extra + operar_ot y maestro. */
export type Permiso = PermisoExtra | 'operar_ot' | 'maestro'
export type Taller = 'mecanica' | 'soldadura'

export interface Usuario { id: string; nombre_completo: string; correo: string; rol: Rol; telefono?: string; activo: boolean; permisos_extra: PermisoExtra[] }
export interface TipoVehiculo { id: string; prefijo_codigo: string; nombre: string; unidad_medida: 'km' | 'horas'; diagrama: Diagrama }
export type Diagrama = 'cabezal' | 'plataforma' | 'recolector' | 'montacargas'
export interface Vehiculo {
  id: string; codigo: string; placa: string | null; tipo_vehiculo_id: string; configuracion_ejes_id: string | null
  marca: string | null; modelo: string | null; anio: number | null; numero_chasis: string | null; numero_motor: string | null
  color: string | null; conductor_asignado_id: string | null; lectura_actual: number; lectura_actual_fecha: string | null
  estado: string; observaciones: string | null; estado_desde: string | null; propiedad: 'propio' | 'rentado'
  cliente_id: string | null; centro_costo_id: string | null; fecha_ingreso_flota: string | null
}
export interface Conductor { id: string; cedula: string; nombres: string; apellidos: string; telefono: string | null; correo: string | null; activo: boolean }
export interface ItemChecklist { id: string; nombre: string; grupo: string; tipo_vehiculo_id: string | null; orden: number; activo: boolean }
export interface Sistema { id: string; nombre: string; orden: number; activo: boolean; taller: Taller; icono: string | null; descripcion: string | null; aplica_complejidad: boolean }
export interface Elemento { id: string; sistema_id: string; nombre: string; orden: number; activo: boolean }
export interface Intervencion {
  id: string; sistema_id: string; nombre: string; horas_estandar: number
  sistema_preventivo_id: string | null; orden: number; activo: boolean
  codigo: string | null; grupo: string | null; nota: string | null
}
export interface SistemaPreventivo { id: string; codigo: string; nombre: string; activo: boolean }
export interface Cliente { id: string; nombre: string; activo: boolean }
export interface CentroCosto { id: string; codigo: string; nombre: string; costo_por_km: boolean; es_clientes: boolean; activo: boolean }
export interface Area { id: string; nombre: string; es_externo: boolean; requiere_cotizacion: boolean; orden: number; activo: boolean }
export interface Tecnico {
  id: string; codigo: string; nombres: string; usuario_id: string | null; area_taller_id: string | null; activo: boolean
  especialidad: 'mecanica' | 'soldadura' | 'ambas'; cargo: string | null; jornada_horas: number
  telefono?: string | null; contacto_emergencia?: string | null
}
export interface Repuesto { id: string; codigo: string; descripcion: string; unidad: string; activo: boolean }
export interface ConfigEjes { id: string; nombre: string }

export type Resultado = 'ok' | 'falta' | 'danado'
export interface FilaChecklist { item_checklist_id: string; resultado?: Resultado; observacion?: string }
export interface Dano {
  numero_marca: number; vista: Vista; posicion_x: number; posicion_y: number
  tipo_dano: string; descripcion?: string; situacion?: string
}
export type Vista = 'frontal' | 'posterior' | 'izquierda' | 'derecha'
