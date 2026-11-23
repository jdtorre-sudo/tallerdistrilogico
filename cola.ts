// Cola de envíos: las actas se guardan primero en el equipo y se envían
// cuando hay conexión. Si se envían dos veces no se duplican (id_local).
import { get, set } from 'idb-keyval'
import { useEffect, useState } from 'react'
import { supabase, ok, mensajeError } from './supabase'
import { anioMes } from './formato'
import { invalidarCatalogos } from './catalogos'

export interface ItemCola {
  id_local: string
  tipo: 'acta_recepcion' | 'acta_entrega' | 'ot'
  creado: string
  descripcion: string             // "DC001 · GSA-4512"
  carpeta: string                 // placa o código, para la ruta de archivos
  payload: Record<string, unknown>
  firmas?: { a: string; b: string } // PNG en base64 (dataURL): a = conductor, b = responsable
  // progreso
  acta_id?: string
  numero?: string
  error?: string
  resultado?: Record<string, string>
}

const CLAVE = 'cola-envios'
const CLAVE_ENVIADOS = 'cola-enviados'
type Oyente = () => void
const oyentes = new Set<Oyente>()
const avisar = () => oyentes.forEach(f => f())

export const leerCola = async () => (await get<ItemCola[]>(CLAVE).catch(() => undefined)) || []
export const leerEnviados = async () => (await get<ItemCola[]>(CLAVE_ENVIADOS).catch(() => undefined)) || []
async function guardarCola(c: ItemCola[]) { await set(CLAVE, c); avisar() }

export async function agregarACola(item: ItemCola) {
  const c = await leerCola()
  await guardarCola([...c.filter(x => x.id_local !== item.id_local), item])
}

function dataUrlABlob(d: string): Blob {
  const [cab, b64] = d.split(',')
  const mime = cab.match(/:(.*?);/)?.[1] || 'image/png'
  const bin = atob(b64)
  const arr = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i)
  return new Blob([arr], { type: mime })
}

/** Sube un archivo al almacenamiento. Si ya existe (reintento) lo da por bueno. */
export async function subirArchivo(ruta: string, contenido: Blob) {
  const r = await supabase.storage.from('archivos').upload(ruta, contenido, { contentType: contenido.type, upsert: false })
  if (r.error && !/exists|Duplicate|409/i.test(r.error.message + ((r.error as { statusCode?: string }).statusCode || ''))) {
    throw new Error(mensajeError(r.error))
  }
}

async function procesarItem(item: ItemCola): Promise<ItemCola> {
  if (item.tipo === 'ot') {
    const r = ok(await supabase.rpc('abrir_ot', { p: item.payload })) as Record<string, string>
    return { ...item, numero: r.ot_numero, resultado: r, error: undefined }
  }
  const tipo = item.tipo === 'acta_recepcion' ? 'recepcion' : 'entrega'
  if (!item.acta_id) {
    const r = ok(await supabase.rpc('registrar_acta', { p_tipo: tipo, p: item.payload })) as { acta_id: string; numero: string }
    item = { ...item, acta_id: r.acta_id, numero: r.numero }
    await reemplazar(item)
  }
  const [a, m] = anioMes(item.creado)
  const base = `${a}/${m}/${item.carpeta}/${item.numero}`
  const rutaA = `${base}/firma_conductor.png`
  const rutaB = `${base}/${tipo === 'recepcion' ? 'firma_recibe' : 'firma_entrega'}.png`
  await subirArchivo(rutaA, dataUrlABlob(item.firmas!.a))
  await subirArchivo(rutaB, dataUrlABlob(item.firmas!.b))
  const res = ok(await supabase.rpc('firmar_acta', { p_tipo: tipo, p_acta: item.acta_id, p_ruta_firma_conductor: rutaA, p_ruta_firma_responsable: rutaB })) as Record<string, string>
  return { ...item, resultado: { ...res, acta_id: item.acta_id! }, error: undefined }
}

async function reemplazar(item: ItemCola) {
  const c = await leerCola()
  await guardarCola(c.map(x => (x.id_local === item.id_local ? item : x)))
}

let procesando: Promise<void> | null = null

/** Envía todo lo pendiente. Devuelve los ítems que se enviaron bien en esta pasada. */
export function procesarCola(): Promise<void> {
  if (procesando) return procesando
  const tarea = (async () => {
      if (!navigator.onLine) return
      const { data } = await supabase.auth.getSession()
      if (!data.session) return
      for (const original of await leerCola()) {
        try {
          const listo = await procesarItem(original)
          const c = await leerCola()
          await guardarCola(c.filter(x => x.id_local !== original.id_local))
          const env = await leerEnviados()
          await set(CLAVE_ENVIADOS, [{ ...listo, firmas: undefined }, ...env].slice(0, 30))
          invalidarCatalogos() // cambió la lectura o el conductor asignado del vehículo
          avisar()
        } catch (e) {
          const msg = mensajeError(e)
          const actual = (await leerCola()).find(x => x.id_local === original.id_local) || original
          await reemplazar({ ...actual, error: msg })
          if (/Sin conexión/.test(msg)) break
        }
      }
  })()
  // Se limpia después de asignar: si la tarea termina de inmediato (sin señal) no queda trabada.
  procesando = tarea.finally(() => { procesando = null })
  return procesando
}

/** Espera a que un ítem concreto se envíe (o falle). */
export async function enviarAhora(id_local: string): Promise<ItemCola | undefined> {
  await procesarCola()
  const enCola = (await leerCola()).find(x => x.id_local === id_local)
  if (enCola) return enCola
  return (await leerEnviados()).find(x => x.id_local === id_local)
}

export function useCola() {
  const [pendientes, setPendientes] = useState<ItemCola[]>([])
  const [enLinea, setEnLinea] = useState(navigator.onLine)
  useEffect(() => {
    const refrescar = () => leerCola().then(setPendientes)
    const on = () => { setEnLinea(true); procesarCola() }
    const off = () => setEnLinea(false)
    oyentes.add(refrescar); refrescar()
    window.addEventListener('online', on); window.addEventListener('offline', off)
    const t = setInterval(() => { setEnLinea(navigator.onLine); if (navigator.onLine) procesarCola() }, 20000)
    return () => { oyentes.delete(refrescar); window.removeEventListener('online', on); window.removeEventListener('offline', off); clearInterval(t) }
  }, [])
  return { pendientes, enLinea }
}

// ------------------------------------------------------------ Borradores
export const guardarBorrador = (clave: string, datos: unknown) => set('borrador:' + clave, datos).catch(() => undefined)
export const leerBorrador = <T,>(clave: string) => get<T>('borrador:' + clave).catch(() => undefined)
export const borrarBorrador = (clave: string) => set('borrador:' + clave, undefined).catch(() => undefined)

// ------------------------------------------------------------ Descarga de firmas
export async function archivoComoDataUrl(ruta?: string | null): Promise<string | null> {
  if (!ruta) return null
  const r = await supabase.storage.from('archivos').download(ruta)
  if (r.error || !r.data) return null
  return await new Promise(res => { const f = new FileReader(); f.onload = () => res(String(f.result)); f.readAsDataURL(r.data!) })
}
