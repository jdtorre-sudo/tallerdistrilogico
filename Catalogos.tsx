import { useEffect, useState } from 'react'
import * as XLSX from 'xlsx'
import { supabase, ok, mensajeError } from '../lib/supabase'
import { cargarCatalogos, invalidarCatalogos, type Catalogos } from '../lib/catalogos'
import { useSesion } from '../lib/sesion'
import { ESPECIALIDADES, ESTADOS_VEHICULO, edad, fecha, hoyISO, lectura, nombreTaller } from '../lib/formato'
import { Aviso, Campo, Cargando, Modal, Pildora, useToast } from '../components/ui'

type Fila = Record<string, any>

export interface DefCampo {
  k: string; n: string; tipo?: 'texto' | 'numero' | 'fecha' | 'mes' | 'si_no' | 'seleccion' | 'parrafo'
  opciones?: (c: Catalogos) => { k: string; n: string }[]; requerido?: boolean; mayusculas?: boolean; enLista?: boolean
  mostrar?: (fila: Fila, c: Catalogos) => string
  /** Solo se muestra en el formulario cuando esta función devuelve verdadero. */
  si?: (fila: Fila) => boolean
  ayuda?: string
  /** Ocupa las dos columnas del formulario. */
  ancho?: boolean
}

/** Pantalla genérica de catálogo: tabla con búsqueda, alta y edición en ventana. No se borra: se desactiva. */
export function PantallaCatalogo({ tabla, titulo, subtitulo, campos, orden, permiso = 'editar_catalogos', campoActivo = 'activo', ayuda, filtro, validar, nuevo }: {
  tabla: string; titulo: string; subtitulo?: string; campos: DefCampo[]; orden: string
  /** Quién edita: solo el maestro, o también quien tenga el permiso extra "editar_catalogos". */
  permiso?: 'maestro' | 'editar_catalogos'
  campoActivo?: string; ayuda?: string
  /** Filtro fijo (se aplica al leer y se agrega al crear), ej. { lista: 'causa_dano' }. */
  filtro?: Record<string, string>
  /** Validación antes de guardar: devuelve un mensaje si hay un error. */
  validar?: (fila: Fila) => string | null
  /** Valores iniciales de un registro nuevo. */
  nuevo?: Fila
}) {
  const { tiene, esMaestro } = useSesion()
  const toast = useToast()
  const [cat, setCat] = useState<Catalogos | null>(null)
  const [filas, setFilas] = useState<Fila[] | null>(null)
  const [edit, setEdit] = useState<Fila | null>(null)
  const [texto, setTexto] = useState('')
  const [error, setError] = useState('')
  const puedeEditar = permiso === 'maestro' ? esMaestro : tiene('editar_catalogos')
  const claveFiltro = JSON.stringify(filtro || {})

  async function cargar() {
    try {
      setCat(await cargarCatalogos())
      const todas: Fila[] = []
      for (let desde = 0; ; desde += 1000) {
        let q = supabase.from(tabla).select('*')
        for (const [k, v] of Object.entries(filtro || {})) q = q.eq(k, v)
        const datos = ok(await q.order(orden).range(desde, desde + 999)) as Fila[]
        todas.push(...datos)
        if (datos.length < 1000) break
      }
      setFilas(todas)
    } catch (e) { setError((e as Error).message) }
  }
  useEffect(() => { setFilas(null); setEdit(null); cargar() }, [tabla, claveFiltro])

  async function guardar(e: React.FormEvent) {
    e.preventDefault(); setError('')
    if (!edit) return
    const err = validar?.(edit)
    if (err) { setError(err); return }
    const datos: Fila = { ...(edit.id ? {} : filtro) }
    for (const c of campos) {
      if (c.k.startsWith('_')) continue // columna calculada, solo para mostrar
      if (c.si && !c.si(edit)) { if (edit.id) datos[c.k] = null; continue } // campo oculto = vacío
      let v = edit[c.k]
      if (c.tipo === 'numero') v = v === '' || v === null || v === undefined ? null : Number(String(v).replace(',', '.'))
      else if (c.tipo === 'si_no') v = !!v
      else if (c.tipo === 'mes') v = v ? String(v).slice(0, 7) + '-01' : null
      else if (typeof v === 'string') { v = v.trim(); if (c.mayusculas) v = v.toUpperCase(); if (v === '') v = null }
      if (v === null || v === undefined) { if (edit.id) datos[c.k] = null } // en altas, vacío = valor por defecto de la base
      else datos[c.k] = v
    }
    const r = edit.id ? await supabase.from(tabla).update(datos).eq('id', edit.id).select('id') : await supabase.from(tabla).insert(datos).select('id')
    if (r.error) { setError(mensajeError(r.error)); return }
    if (!r.data?.length) { setError('Su usuario no tiene permiso para esta acción.'); return }
    toast('Guardado', `${titulo}: el registro se guardó correctamente.`); setEdit(null); invalidarCatalogos(); cargar()
  }

  if (!filas || !cat) return error ? <Aviso tipo="mal">{error}</Aviso> : <Cargando />
  const valor = (f: Fila, c: DefCampo): string => c.mostrar ? c.mostrar(f, cat)
    : c.tipo === 'seleccion' ? c.opciones!(cat).find(o => o.k === f[c.k])?.n || ''
    : c.tipo === 'si_no' ? (f[c.k] ? 'Sí' : 'No')
    : c.tipo === 'fecha' ? fecha(f[c.k])
    : c.tipo === 'mes' ? (f[c.k] ? String(f[c.k]).slice(5, 7) + '/' + String(f[c.k]).slice(0, 4) : '')
    : String(f[c.k] ?? '')

  function exportar() {
    const libro = XLSX.utils.book_new()
    XLSX.utils.book_append_sheet(libro, XLSX.utils.json_to_sheet((filas || []).map(f => Object.fromEntries(campos.map(c => [c.n, valor(f, c)])))), titulo.slice(0, 31))
    XLSX.writeFile(libro, `${tabla}_${hoyISO()}.xlsx`)
  }

  const t = texto.trim().toLowerCase()
  const visibles = filas.filter(f => !t || campos.some(c => valor(f, c).toLowerCase().includes(t)))
  const enLista = campos.filter(c => c.enLista !== false)

  return (
    <div className="space-y-4">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
        <div><h3 className="font-bold text-slate-800 text-sm md:text-base">{titulo}</h3>{subtitulo && <p className="text-xs text-slate-500 mt-0.5">{subtitulo}</p>}</div>
        <div className="flex flex-wrap gap-2">
          <button className="btn-gris" onClick={exportar}><i className="fa-solid fa-file-excel" />Exportar a Excel</button>
          {puedeEditar && <button className="btn-rojo" onClick={() => { setError(''); setEdit({ ...Object.fromEntries(campos.map(c => [c.k, c.tipo === 'si_no' ? c.k === campoActivo : ''])), ...nuevo }) }}><i className="fa-solid fa-plus" />Nuevo</button>}
        </div>
      </div>
      {ayuda && <Aviso>{ayuda}</Aviso>}
      {error && !edit && <Aviso tipo="mal">{error}</Aviso>}
      <div className="relative max-w-sm">
        <i className="fa-solid fa-magnifying-glass absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-xs" />
        <input className="campo-texto pl-8" placeholder="Buscar…" value={texto} onChange={e => setTexto(e.target.value)} />
      </div>
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="overflow-x-auto custom-scrollbar">
          <table className="w-full text-left border-collapse text-xs md:text-sm">
            <thead><tr className="bg-slate-100/80 text-slate-600 uppercase tracking-wider font-semibold border-b border-slate-200 text-[11px]">
              {enLista.map(c => <th key={c.k} className="py-3 px-4 whitespace-nowrap">{c.n}</th>)}
            </tr></thead>
            <tbody className="divide-y divide-slate-100">
              {visibles.map(f => {
                const inactiva = f[campoActivo] === false || f.anulado
                return (
                  <tr key={f.id} className={'transition-colors ' + (puedeEditar ? 'cursor-pointer hover:bg-slate-50 ' : '') + (inactiva ? 'text-slate-400' : '')} onClick={() => { if (puedeEditar) { setError(''); setEdit({ ...f }) } }}>
                    {enLista.map((c, i) => <td key={c.k} className={'py-3 px-4 ' + (i === 0 ? 'font-bold ' + (inactiva ? '' : 'text-slate-800') : 'text-slate-600')}>
                      {c.k === campoActivo ? <Pildora tipo={f[c.k] ? 'ok' : 'neutro'}>{f[c.k] ? 'Activo' : 'Inactivo'}</Pildora> : valor(f, c)}
                    </td>)}
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
        {visibles.length === 0 && <div className="py-12 text-center"><i className="fa-solid fa-inbox text-slate-300 text-4xl mb-3" /><h4 className="text-slate-600 font-semibold text-sm">Sin registros</h4></div>}
      </div>
      <p className="text-[11px] text-slate-500">{visibles.length} registros. {puedeEditar ? 'Toque una fila para editarla. Para dar de baja, desmarque “Activo” o cambie el estado: los registros no se borran.' : 'Solo lectura.'}</p>

      {edit && (
        <Modal titulo={edit.id ? `Editar · ${titulo}` : `Nuevo · ${titulo}`} icono={edit.id ? 'fa-pen-to-square' : 'fa-plus'} ancho="max-w-2xl" onCerrar={() => setEdit(null)}
          pie={<><button type="button" className="btn-gris" onClick={() => setEdit(null)}>Cancelar</button><button type="submit" form="form-catalogo" className="btn-azul"><i className="fa-solid fa-floppy-disk" />Guardar</button></>}>
          <form id="form-catalogo" onSubmit={guardar} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {campos.filter(c => !c.si || c.si(edit)).map(c => (
              <div key={c.k} className={c.ancho || c.tipo === 'parrafo' ? 'sm:col-span-2' : ''}>
                <Campo etiqueta={c.n + (c.requerido ? ' *' : '')} ayuda={c.ayuda}>
                  {c.tipo === 'seleccion' ? (
                    <select className="campo-texto" required={c.requerido} value={edit[c.k] ?? ''} onChange={e => setEdit({ ...edit, [c.k]: e.target.value })}>
                      <option value="">—</option>{c.opciones!(cat).map(o => <option key={o.k} value={o.k}>{o.n}</option>)}
                    </select>
                  ) : c.tipo === 'si_no' ? (
                    <label className="flex items-center gap-2 font-semibold text-slate-700 py-2"><input type="checkbox" className="w-5 h-5 accent-industrial-blue" checked={!!edit[c.k]} onChange={e => setEdit({ ...edit, [c.k]: e.target.checked })} /> {edit[c.k] ? 'Sí' : 'No'}</label>
                  ) : c.tipo === 'parrafo' ? (
                    <textarea className="campo-texto" rows={2} required={c.requerido} value={edit[c.k] ?? ''} onChange={e => setEdit({ ...edit, [c.k]: e.target.value })} />
                  ) : (
                    <input className="campo-texto" required={c.requerido} type={c.tipo === 'fecha' ? 'date' : c.tipo === 'mes' ? 'month' : 'text'} inputMode={c.tipo === 'numero' ? 'decimal' : undefined}
                      value={c.tipo === 'mes' ? String(edit[c.k] ?? '').slice(0, 7) : edit[c.k] ?? ''} onChange={e => setEdit({ ...edit, [c.k]: e.target.value })}
                      style={c.mayusculas ? { textTransform: 'uppercase' } : undefined} />
                  )}
                </Campo>
              </div>
            ))}
            {error && <div className="sm:col-span-2"><Aviso tipo="mal">{error}</Aviso></div>}
          </form>
        </Modal>
      )}
    </div>
  )
}

const opcionesTipos = (c: Catalogos) => c.tipos.map(t => ({ k: t.id, n: `${t.prefijo_codigo} · ${t.nombre}` }))
const opcionesEjes = (c: Catalogos) => c.ejes.map(t => ({ k: t.id, n: t.nombre }))
const opcionesConductores = (c: Catalogos) => c.conductores.filter(t => t.activo).map(t => ({ k: t.id, n: `${t.nombres} ${t.apellidos}` }))
const opcionesUsuarios = (c: Catalogos) => c.usuarios.filter(u => u.activo).map(t => ({ k: t.id, n: t.nombre_completo }))
const opcionesClientes = (c: Catalogos) => c.clientes.filter(x => x.activo).map(x => ({ k: x.id, n: x.nombre }))
const opcionesCentros = (c: Catalogos) => c.centros.filter(x => x.activo).map(x => ({ k: x.id, n: `${x.codigo} · ${x.nombre}` }))
const opcionesTecnicos = (c: Catalogos) => c.tecnicos.map(x => ({ k: x.id, n: `${x.codigo} · ${x.nombres}` }))
const opcionesFijas = (l: { k: string; n: string }[]) => () => l

export const Vehiculos = () => <PantallaCatalogo tabla="vehiculos" titulo="Vehículos (flota)" orden="codigo" campoActivo="__"
  subtitulo="La flota la usan todos los módulos: OT, bodega, preventivos y reportes."
  nuevo={{ propiedad: 'propio', estado: 'activo' }}
  validar={f => f.propiedad === 'rentado' && !f.cliente_id ? 'Una unidad rentada debe tener su cliente.' : null}
  campos={[
    { k: 'codigo', n: 'Código', requerido: true, mayusculas: true },
    { k: 'placa', n: 'Placa', mayusculas: true },
    { k: 'tipo_vehiculo_id', n: 'Tipo', tipo: 'seleccion', opciones: opcionesTipos, requerido: true },
    { k: 'configuracion_ejes_id', n: 'Configuración', tipo: 'seleccion', opciones: opcionesEjes, enLista: false },
    { k: 'marca', n: 'Marca' }, { k: 'modelo', n: 'Modelo' }, { k: 'anio', n: 'Año modelo', tipo: 'numero', enLista: false },
    { k: 'fecha_ingreso_flota', n: 'Ingreso a la flota (mes y año)', tipo: 'mes', ayuda: 'Sirve para calcular la edad de la unidad.' },
    { k: '_edad', n: 'Edad', si: () => false, mostrar: f => edad(f.fecha_ingreso_flota) },
    { k: 'propiedad', n: 'Propiedad', tipo: 'seleccion', requerido: true, opciones: opcionesFijas([{ k: 'propio', n: 'Propio' }, { k: 'rentado', n: 'Rentado a cliente' }]) },
    { k: 'cliente_id', n: 'Cliente', tipo: 'seleccion', opciones: opcionesClientes, si: f => f.propiedad === 'rentado', requerido: true,
      ayuda: 'El gasto de las unidades rentadas va al centro de costo MNTOPL3RAS y no entra al costo por km.' },
    { k: 'centro_costo_id', n: 'Centro de costo', tipo: 'seleccion', opciones: opcionesCentros, si: f => f.propiedad !== 'rentado' },
    { k: 'nombre_hunter', n: 'Nombre en Hunter', enLista: false, ayuda: 'Como aparece la columna de esta unidad en el reporte de odómetro de Hunter (ej. DC001--GBP1502).' },
    { k: 'numero_chasis', n: 'Chasis', enLista: false }, { k: 'numero_motor', n: 'Motor', enLista: false }, { k: 'color', n: 'Color', enLista: false },
    { k: 'conductor_asignado_id', n: 'Chofer asignado', tipo: 'seleccion', opciones: opcionesConductores, enLista: false },
    { k: 'lectura_actual', n: 'Km / horómetro actual', tipo: 'numero', mostrar: (f, c) => lectura(f.lectura_actual, c.tipos.find(t => t.id === f.tipo_vehiculo_id)?.unidad_medida) },
    { k: 'estado', n: 'Estado', tipo: 'seleccion', requerido: true, opciones: opcionesFijas(ESTADOS_VEHICULO) },
    { k: 'estado_desde', n: 'En ese estado desde', tipo: 'fecha', ayuda: 'Al cambiar el estado, ponga la fecha del cambio (vacío = hoy). Las fechas de parada quedan en el historial.' },
    { k: 'observaciones', n: 'Observaciones', tipo: 'parrafo', enLista: false }
  ]} />

export const Conductores = () => <PantallaCatalogo tabla="conductores" titulo="Choferes" orden="apellidos"
  campos={[
    { k: 'cedula', n: 'Cédula', requerido: true }, { k: 'nombres', n: 'Nombres', requerido: true }, { k: 'apellidos', n: 'Apellidos', requerido: true },
    { k: 'telefono', n: 'Celular (WhatsApp)' }, { k: 'correo', n: 'Correo', enLista: false }, { k: 'tipo_licencia', n: 'Licencia' },
    { k: 'licencia_vence', n: 'Licencia vence', tipo: 'fecha' }, { k: 'activo', n: 'Activo', tipo: 'si_no' }
  ]} />

export const Tecnicos = () => <PantallaCatalogo tabla="tecnicos" titulo="Técnicos" orden="codigo" permiso="maestro"
  subtitulo="Vincule cada técnico con su usuario para que vea su perfil, sus OT, su historial y su producción."
  nuevo={{ especialidad: 'mecanica', jornada_horas: '8' }}
  campos={[
    { k: 'codigo', n: 'Código', requerido: true, mayusculas: true, ayuda: 'Corto y único, ej. M01 o S03. Sale en sus observaciones y en la producción.' },
    { k: 'nombres', n: 'Nombre completo', requerido: true },
    { k: 'especialidad', n: 'Especialidad', tipo: 'seleccion', requerido: true, opciones: opcionesFijas(ESPECIALIDADES) },
    { k: 'cargo', n: 'Cargo' },
    { k: 'jornada_horas', n: 'Jornada (horas/día)', tipo: 'numero', requerido: true },
    { k: 'cedula', n: 'Cédula', enLista: false }, { k: 'telefono', n: 'Celular' },
    { k: 'contacto_emergencia', n: 'Contacto de emergencia', enLista: false, ayuda: 'El técnico también puede actualizarlo desde su perfil.' },
    { k: 'fecha_ingreso', n: 'Fecha de ingreso', tipo: 'fecha', enLista: false, ayuda: 'Para el saldo de vacaciones (Fase 5).' },
    { k: 'usuario_id', n: 'Usuario vinculado', tipo: 'seleccion', opciones: opcionesUsuarios, mostrar: (f, c) => c.usuarios.find(u => u.id === f.usuario_id)?.nombre_completo || '—' },
    { k: 'activo', n: 'Activo', tipo: 'si_no' }
  ]}
  ayuda="La tarifa interna por hora está en la pestaña Tarifas: solo la ve quien tiene el permiso de ver costos." />

export const Tarifas = () => <PantallaCatalogo tabla="tarifas_tecnico" titulo="Tarifas internas por hora" orden="vigente_desde" permiso="maestro" campoActivo="__"
  nuevo={{ vigente_desde: hoyISO() }}
  campos={[
    { k: 'tecnico_id', n: 'Técnico', tipo: 'seleccion', requerido: true, opciones: opcionesTecnicos },
    { k: 'tarifa_hora', n: 'Tarifa por hora (USD)', tipo: 'numero', requerido: true },
    { k: 'vigente_desde', n: 'Vigente desde', tipo: 'fecha', requerido: true },
    { k: 'observacion', n: 'Observación' }
  ]}
  ayuda="Cada cambio de tarifa es un registro nuevo con su fecha: así la mano de obra de OT anteriores no cambia. Los técnicos no ven esta pantalla." />

export const Clientes = () => <PantallaCatalogo tabla="clientes" titulo="Clientes" orden="nombre"
  subtitulo="Clientes a los que se rentan unidades. Sus OT salen en el reporte por cliente para conciliar y cobrar."
  campos={[
    { k: 'nombre', n: 'Nombre o razón social', requerido: true }, { k: 'ruc', n: 'RUC' }, { k: 'contacto', n: 'Contacto' },
    { k: 'telefono', n: 'Teléfono' }, { k: 'correo', n: 'Correo', enLista: false }, { k: 'observaciones', n: 'Observaciones', tipo: 'parrafo', enLista: false },
    { k: 'activo', n: 'Activo', tipo: 'si_no' }
  ]} />

export const CentrosCosto = () => <PantallaCatalogo tabla="centros_costo" titulo="Centros de costo" orden="codigo" permiso="maestro"
  subtitulo="Solo los vehículos de centros marcados “Entra al costo por km” aparecen en el costo por km de mecánica."
  campos={[
    { k: 'codigo', n: 'Código', requerido: true, mayusculas: true }, { k: 'nombre', n: 'Nombre', requerido: true },
    { k: 'costo_por_km', n: 'Entra al costo por km', tipo: 'si_no' },
    { k: 'es_clientes', n: 'Es el centro de clientes', tipo: 'si_no' },
    { k: 'activo', n: 'Activo', tipo: 'si_no' }
  ]} />

export const Proveedores = () => <PantallaCatalogo tabla="proveedores" titulo="Proveedores y talleres externos" orden="nombre"
  nuevo={{ tipo: 'repuestos' }}
  campos={[
    { k: 'nombre', n: 'Razón social', requerido: true }, { k: 'ruc', n: 'RUC' },
    { k: 'tipo', n: 'Tipo', tipo: 'seleccion', requerido: true, opciones: opcionesFijas([{ k: 'repuestos', n: 'Repuestos' }, { k: 'taller_externo', n: 'Taller externo' }, { k: 'ambos', n: 'Ambos' }]) },
    { k: 'especialidad', n: 'Especialidad', tipo: 'seleccion', opciones: opcionesFijas(ESPECIALIDADES), si: f => f.tipo !== 'repuestos', mostrar: f => nombreTaller(f.especialidad) },
    { k: 'contacto', n: 'Contacto' }, { k: 'telefono', n: 'Teléfono' }, { k: 'correo', n: 'Correo', enLista: false },
    { k: 'direccion', n: 'Dirección', enLista: false }, { k: 'observaciones', n: 'Observaciones', tipo: 'parrafo', enLista: false },
    { k: 'activo', n: 'Activo', tipo: 'si_no' }
  ]} />

export const Complejidades = () => <PantallaCatalogo tabla="complejidades" titulo="Multiplicadores de complejidad" orden="orden" permiso="maestro"
  subtitulo="Horas del trabajo = horas estándar × cantidad × multiplicador (si el componente aplica complejidad)."
  campos={[
    { k: 'codigo', n: 'Código', requerido: true }, { k: 'nombre', n: 'Nombre', requerido: true },
    { k: 'multiplicador', n: 'Multiplicador', tipo: 'numero', requerido: true, ayuda: 'Ej. 0,8 = el trabajo toma el 80 % del tiempo estándar.' },
    { k: 'orden', n: 'Orden', tipo: 'numero' }, { k: 'activo', n: 'Activo', tipo: 'si_no' }
  ]} />

const MODOS = [{ k: 'km', n: 'Por km' }, { k: 'dias', n: 'Por tiempo (días)' }, { k: 'falla', n: 'Frecuencia de daños' }]
export const SistemasPreventivos = () => <PantallaCatalogo tabla="sistemas_preventivos" titulo="Intervalos preventivos" orden="orden" permiso="maestro"
  subtitulo="Los mismos sistemas y valores del registro de componentes del kardex. Montacarga en 0 = se calcula por tiempo."
  campos={[
    { k: 'nombre', n: 'Sistema', requerido: true }, { k: 'codigo', n: 'Código', requerido: true, enLista: false },
    { k: 'modo', n: 'Se mide', tipo: 'seleccion', requerido: true, opciones: opcionesFijas(MODOS) },
    { k: 'intervalo_cabezal', n: 'Cabezal (DC)', tipo: 'numero', si: f => f.modo !== 'falla' },
    { k: 'intervalo_plataforma', n: 'Plataforma (DP/DR)', tipo: 'numero', si: f => f.modo !== 'falla' },
    { k: 'intervalo_montacarga', n: 'Montacarga', tipo: 'numero', si: f => f.modo !== 'falla' },
    { k: 'dias_sin_km', n: 'Días si no hay km', tipo: 'numero', si: f => f.modo === 'km' },
    { k: 'pct_prematuro', n: '% prematuro', tipo: 'numero', si: f => f.modo !== 'falla', ayuda: 'Se marca prematuro si el cambio se hizo antes de este % del intervalo (0 = no medir).' },
    { k: 'registro_automatico', n: 'Registrar solo al despachar', tipo: 'si_no' },
    { k: 'incluye', n: 'Sugerir si el artículo incluye', tipo: 'parrafo', enLista: false },
    { k: 'excluye', n: '…y no incluye', tipo: 'parrafo', enLista: false },
    { k: 'km_incluye', n: 'Con km, el artículo incluye', tipo: 'parrafo', enLista: false, si: f => f.modo === 'km' },
    { k: 'km_excluye', n: 'Con km, …y no incluye', tipo: 'parrafo', enLista: false, si: f => f.modo === 'km' },
    { k: 'motivos_falla', n: 'Motivos = falla', tipo: 'parrafo', enLista: false, si: f => f.modo === 'dias' },
    { k: 'orden', n: 'Orden', tipo: 'numero', enLista: false }, { k: 'activo', n: 'Activo', tipo: 'si_no' }
  ]} />

export const ItemsChecklist = () => <PantallaCatalogo tabla="items_checklist" titulo="Checklist de recepción" orden="orden" permiso="maestro"
  campos={[{ k: 'nombre', n: 'Elemento', requerido: true },
    { k: 'grupo', n: 'Grupo', tipo: 'seleccion', requerido: true, opciones: () => ['Seguridad', 'Documentos', 'Exterior', 'Carga'].map(g => ({ k: g, n: g })) },
    { k: 'tipo_vehiculo_id', n: 'Solo para tipo (vacío = todos)', tipo: 'seleccion', opciones: c => c.tipos.map(t => ({ k: t.id, n: t.nombre })) },
    { k: 'orden', n: 'Orden', tipo: 'numero' }, { k: 'activo', n: 'Activo', tipo: 'si_no' }]} />

export const TiposVehiculo = () => <PantallaCatalogo tabla="tipos_vehiculo" titulo="Tipos de vehículo" orden="prefijo_codigo" permiso="maestro" campoActivo="__"
  campos={[{ k: 'prefijo_codigo', n: 'Prefijo', requerido: true, mayusculas: true }, { k: 'nombre', n: 'Nombre', requerido: true },
    { k: 'unidad_medida', n: 'Se mide en', tipo: 'seleccion', requerido: true, opciones: () => [{ k: 'km', n: 'Kilómetros' }, { k: 'horas', n: 'Horas (horómetro)' }] },
    { k: 'diagrama', n: 'Dibujo de daños', tipo: 'seleccion', requerido: true, opciones: () => ['cabezal', 'plataforma', 'recolector', 'montacargas'].map(d => ({ k: d, n: d })) }]} />

export const ConfiguracionesEjes = () => <PantallaCatalogo tabla="configuraciones_ejes" titulo="Configuraciones" orden="nombre" permiso="maestro" campoActivo="__"
  campos={[{ k: 'nombre', n: 'Nombre', requerido: true }, { k: 'numero_ejes', n: 'Ejes', tipo: 'numero', requerido: true },
    { k: 'numero_llantas', n: 'Llantas (sin repuesto)', tipo: 'numero', requerido: true }, { k: 'descripcion', n: 'Descripción' }]} />
