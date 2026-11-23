import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL as string
const clave = import.meta.env.VITE_SUPABASE_ANON_KEY as string

export const configurado = Boolean(url && clave)

export const supabase = createClient(url || 'https://sin-configurar.supabase.co', clave || 'sin-clave', {
  auth: { persistSession: true, autoRefreshToken: true }
})

/** Convierte errores técnicos en mensajes claros en español. */
export function mensajeError(e: unknown): string {
  const m = (e as { message?: string })?.message || String(e)
  if (/Failed to fetch|NetworkError|Load failed/i.test(m)) return 'Sin conexión a internet. Intente de nuevo cuando haya señal.'
  if (/Invalid login credentials/i.test(m)) return 'Usuario o contraseña incorrectos.'
  if (/row-level security/i.test(m)) return 'Su usuario no tiene permiso para esta acción.'
  if (/duplicate key.*codigo/i.test(m)) return 'Ya existe un registro con ese código.'
  if (/duplicate key.*placa/i.test(m)) return 'Ya existe un vehículo con esa placa.'
  if (/duplicate key.*cedula/i.test(m)) return 'Ya existe un registro con esa cédula.'
  if (/duplicate key/i.test(m)) return 'Ese registro ya existe.'
  const nulo = /null value in column "(\w+)"/.exec(m)
  if (nulo) return `Falta llenar un campo obligatorio (${nulo[1].replace(/_/g, ' ')}).`
  if (/Could not find the function|schema cache/i.test(m)) return 'La base de datos no está actualizada. El administrador debe ejecutar el último archivo SQL (ver LEEME).'
  if (/JWT expired/i.test(m)) return 'La sesión expiró. Vuelva a ingresar.'
  return m
}

/** Lanza una excepción si la respuesta de Supabase trae error. */
export function ok<T>(r: { data: T; error: unknown }): T {
  if (r.error) throw new Error(mensajeError(r.error))
  return r.data
}

/** Lee todas las filas de una tabla en páginas de 1000. */
export async function leerTodo<T = Record<string, unknown>>(tabla: string, orden = 'id'): Promise<T[]> {
  const filas: T[] = []
  for (let desde = 0; ; desde += 1000) {
    const r = await supabase.from(tabla).select('*').order(orden).range(desde, desde + 999)
    const datos = ok(r) as T[]
    filas.push(...datos)
    if (datos.length < 1000) break
  }
  return filas
}
