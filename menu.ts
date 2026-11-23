// Menú principal (cápsulas del menú lateral). Cada rol ve solo lo suyo.
// Los módulos de fases futuras se muestran con la marca "Fase N" y abren una
// pantalla que explica qué traerán.
import type { Permiso, Rol } from './tipos'

export interface ItemMenu {
  k: string; n: string; icono: string; ruta: string
  fase?: number              // si existe, todavía no está construido
  descripcion?: string        // qué traerá (pantalla "próximamente")
  ver: (rol: Rol, tiene: (p: Permiso) => boolean) => boolean
}

const operan = (r: Rol) => r === 'maestro' || r === 'supervisor'

export const MENU: ItemMenu[] = [
  { k: 'inicio', n: 'Inicio', icono: 'fa-house', ruta: '/', ver: r => r !== 'tecnico' },
  { k: 'perfil', n: 'Perfil profesional', icono: 'fa-id-card', ruta: '/perfil', ver: r => r === 'tecnico' },
  { k: 'ot', n: 'Órdenes de trabajo', icono: 'fa-clipboard-list', ruta: '/ot', ver: () => true,
    descripcion: 'La OT por segmentos: vehículo y recepción, solicitud del chofer, hallazgos, trabajos de mecánica y de soldadura, repuestos, terceros y observaciones de técnicos.' },
  { k: 'soldadura', n: 'Soldadura', icono: 'fa-fire-flame-curved', ruta: '/ambiente/soldadura', ver: (r, t) => operan(r) || t('operar_ot'),
    descripcion: 'Cápsulas de componentes estructurales sobre una OT abierta: elemento → intervención con horas → cantidad, complejidad, técnicos y observación; “Inspeccionado OK” y novedades.' },
  { k: 'mecanica', n: 'Mecánica', icono: 'fa-screwdriver-wrench', ruta: '/ambiente/mecanica', ver: (r, t) => operan(r) || t('operar_ot'),
    descripcion: 'El mismo formato de cápsulas que Soldadura, con los sistemas mecánicos del catálogo de Maestros.' },
  { k: 'tareas', n: 'Trabajos asignados', icono: 'fa-list-check', ruta: '/mis-trabajos', ver: r => r === 'tecnico',
    descripcion: 'Sus trabajos activos en las OT donde está asignado, y el espacio para escribir su observación de técnico.' },
  { k: 'bodega', n: 'Bodega · OT abiertas', icono: 'fa-boxes-stacked', ruta: '/proximamente/bodega', fase: 3, ver: (r, t) => r === 'maestro' || t('bodega'),
    descripcion: 'Tablero de OT abiertas para asignar repuestos: cada línea genera la salida en el kardex con la OT, el móvil y el km.' },
  { k: 'inventarios', n: 'Inventarios', icono: 'fa-warehouse', ruta: '/proximamente/inventarios', fase: 3, ver: (r, t) => r === 'maestro' || t('bodega'),
    descripcion: 'El kardex de bodega completo (mismas pestañas) y la importación de inventario_datos.json con verificación de saldos.' },
  { k: 'personal', n: 'Gestión de personal', icono: 'fa-users-gear', ruta: '/proximamente/personal', fase: 5, ver: (r, t) => operan(r) || t('gestion_personal'),
    descripcion: 'Asistencia diaria, novedades, días libres, vacaciones con saldo y calendario del taller, horas disponibles y utilización.' },
  { k: 'calendario', n: 'Calendario y licencias', icono: 'fa-calendar-days', ruta: '/proximamente/calendario', fase: 5, ver: r => r === 'tecnico',
    descripcion: 'Su calendario, su saldo de vacaciones y la solicitud de vacaciones o días libres.' },
  { k: 'historial', n: 'Historial de trabajos', icono: 'fa-clock-rotate-left', ruta: '/proximamente/historial', fase: 6, ver: r => r === 'tecnico',
    descripcion: 'Sus intervenciones realizadas, con filtro de fechas.' },
  { k: 'produccion', n: 'Producción estándar', icono: 'fa-chart-line', ruta: '/proximamente/produccion', fase: 6, ver: r => r === 'tecnico',
    descripcion: 'Horas estándar, trabajos e imprevistos aprobados: diaria, semanal y período 24-24, con gráfico.' },
  { k: 'contactos', n: 'Contactos del taller', icono: 'fa-address-book', ruta: '/proximamente/contactos', fase: 6, ver: () => true,
    descripcion: 'Directorio simple con los técnicos de Maestros.' },
  { k: 'tableros', n: 'Tableros y reportes', icono: 'fa-chart-pie', ruta: '/proximamente/tableros', fase: 6, ver: r => operan(r),
    descripcion: 'Producción, taller, mecánica (costo por km, preventivos), soldadura, bodega y clientes. Todo exportable a Excel y PDF.' },
  { k: 'maestros', n: 'Maestros', icono: 'fa-database', ruta: '/maestros', ver: (r, t) => r === 'maestro' || t('editar_catalogos') }
]
