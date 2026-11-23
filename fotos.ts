// Fotos en Cloudflare R2 a través de la función /api/fotos (functions/api/fotos/[[ruta]].js).
// La base solo guarda el índice (tabla "archivos"); la imagen vive en R2.
import { supabase, ok, mensajeError } from './supabase'
import { anioMes, uuid } from './formato'

export interface Foto { id: string; ruta: string; categoria: string; registro_origen_id: string; creado_en: string }

async function token() {
  const { data } = await supabase.auth.getSession()
  return data.session?.access_token || ''
}

/** Achica la foto (máx. 1600 px, JPEG) para que suba rápido desde el patio. */
async function comprimir(archivo: File): Promise<Blob> {
  if (!archivo.type.startsWith('image/')) throw new Error('Solo se aceptan fotos.')
  const img = await createImageBitmap(archivo).catch(() => null)
  if (!img) return archivo
  const escala = Math.min(1, 1600 / Math.max(img.width, img.height))
  const c = document.createElement('canvas'); c.width = Math.round(img.width * escala); c.height = Math.round(img.height * escala)
  c.getContext('2d')!.drawImage(img, 0, 0, c.width, c.height)
  return await new Promise<Blob>((res, rej) => c.toBlob(b => (b ? res(b) : rej(new Error('No se pudo procesar la foto.'))), 'image/jpeg', 0.8))
}

/** Sube una foto y la registra en "archivos". carpeta: ej. "OT-2026-00001". */
export async function subirFoto(archivo: File, o: { carpeta: string; categoria: string; tabla: string; registro: string }): Promise<void> {
  const blob = await comprimir(archivo)
  const [a, m] = anioMes()
  const ruta = `ot/${a}/${m}/${o.carpeta}/${o.categoria}/${uuid()}.jpg`
  let r: Response
  try {
    r = await fetch(`/api/fotos/${ruta}`, { method: 'POST', headers: { 'Content-Type': 'image/jpeg', Authorization: `Bearer ${await token()}` }, body: blob })
  } catch (e) { throw new Error(mensajeError(e)) }
  if (!r.ok) throw new Error((await r.json().catch(() => null))?.mensaje || 'No se pudo subir la foto. ¿Está configurado el almacenamiento de fotos (R2) en Cloudflare?')
  ok(await supabase.from('archivos').insert({ tipo: 'foto', categoria: o.categoria, ruta, tipo_mime: 'image/jpeg', bytes: blob.size, tabla_origen: o.tabla, registro_origen_id: o.registro }))
}

const cache = new Map<string, string>()
/** Devuelve una dirección local (blob:) para mostrar la foto. */
export async function urlFoto(ruta: string): Promise<string> {
  if (cache.has(ruta)) return cache.get(ruta)!
  const r = await fetch(`/api/fotos/${ruta}`, { headers: { Authorization: `Bearer ${await token()}` } })
  if (!r.ok) throw new Error('No se pudo cargar la foto.')
  const url = URL.createObjectURL(await r.blob())
  cache.set(ruta, url)
  return url
}

export async function leerFotos(tabla: string, registros: string[]): Promise<Foto[]> {
  if (!registros.length) return []
  return ok(await supabase.from('archivos').select('id,ruta,categoria,registro_origen_id,creado_en').eq('tipo', 'foto').eq('tabla_origen', tabla)
    .in('registro_origen_id', registros).eq('anulado', false).order('creado_en')) as Foto[]
}
