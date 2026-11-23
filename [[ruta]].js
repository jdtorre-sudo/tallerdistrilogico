// Cloudflare Pages Function: fotos de las OT en Cloudflare R2 (plan gratuito: 10 GB).
// Configuración en Cloudflare Pages > Settings > Bindings: R2 bucket con el nombre de variable FOTOS.
// Variables: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (las mismas de /api/usuarios).
//   POST /api/fotos/<ruta>  (cuerpo = imagen)  → solo usuarios con permiso de operar OT.
//   GET  /api/fotos/<ruta>                     → cualquier usuario activo.
const json = (c, e = 200) => new Response(JSON.stringify(c), { status: e, headers: { 'Content-Type': 'application/json' } })

async function usuario(env, request) {
  const token = (request.headers.get('Authorization') || '').replace('Bearer ', '')
  if (!token) return null
  const u = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, { headers: { apikey: env.SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${token}` } })
  if (!u.ok) return null
  return { ...(await u.json()), token }
}
async function puede(env, u, permiso) {
  // tiene_permiso() se evalúa con el token del propio usuario (mismas reglas que la app)
  const r = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/tiene_permiso`, {
    method: 'POST', headers: { apikey: env.SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${u.token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ p_permiso: permiso })
  })
  return r.ok && (await r.json()) === true
}
async function activo(env, u) {
  const r = await fetch(`${env.SUPABASE_URL}/rest/v1/usuarios?id=eq.${u.id}&select=activo`, { headers: { apikey: env.SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}` } })
  const [p] = r.ok ? await r.json() : []
  return !!p?.activo
}

export async function onRequest({ request, env, params }) {
  if (!env.FOTOS) return json({ mensaje: 'Falta conectar el almacenamiento de fotos (R2) en Cloudflare: Settings > Bindings > R2 bucket con el nombre FOTOS.' }, 500)
  const ruta = (Array.isArray(params.ruta) ? params.ruta.join('/') : params.ruta || '')
  if (!/^ot\/\d{4}\/\d{2}\/[\w.\- ]+\/[\w-]+\/[\w-]+\.jpg$/.test(ruta)) return json({ mensaje: 'Ruta de foto no válida.' }, 400)
  const u = await usuario(env, request)
  if (!u) return json({ mensaje: 'Sesión no válida. Vuelva a ingresar.' }, 401)

  if (request.method === 'POST') {
    if (!(await puede(env, u, 'operar_ot'))) return json({ mensaje: 'Su usuario no puede subir fotos.' }, 403)
    const cuerpo = await request.arrayBuffer()
    if (cuerpo.byteLength > 5 * 1024 * 1024) return json({ mensaje: 'La foto pesa más de 5 MB.' }, 400)
    await env.FOTOS.put(ruta, cuerpo, { httpMetadata: { contentType: 'image/jpeg' }, customMetadata: { usuario: u.id } })
    return json({ ruta })
  }
  if (request.method === 'GET') {
    if (!(await activo(env, u))) return json({ mensaje: 'Usuario inactivo.' }, 403)
    const o = await env.FOTOS.get(ruta)
    if (!o) return json({ mensaje: 'Foto no encontrada.' }, 404)
    return new Response(o.body, { headers: { 'Content-Type': 'image/jpeg', 'Cache-Control': 'private, max-age=86400' } })
  }
  return json({ mensaje: 'Método no permitido.' }, 405)
}
