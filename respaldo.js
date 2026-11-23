// Cloudflare Pages Function: pide a GitHub que ejecute el respaldo SQL ahora.
// Variables en Cloudflare Pages: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY,
//   GITHUB_TOKEN (token con permiso "Actions: read and write" sobre el repositorio),
//   GITHUB_REPO  (ej. "juandiego/taller-distrilogico")
const json = (c, e = 200) => new Response(JSON.stringify(c), { status: e, headers: { 'Content-Type': 'application/json' } })

export async function onRequestPost({ request, env }) {
  const token = (request.headers.get('Authorization') || '').replace('Bearer ', '')
  const u = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, { headers: { apikey: env.SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${token}` } })
  if (!u.ok) return json({ mensaje: 'Sesión no válida.' }, 401)
  const { id } = await u.json()
  const p = await fetch(`${env.SUPABASE_URL}/rest/v1/usuarios?id=eq.${id}&select=rol,activo`, { headers: { apikey: env.SUPABASE_SERVICE_ROLE_KEY } })
  const [perfil] = await p.json()
  if (!perfil || perfil.rol !== 'maestro') return json({ mensaje: 'Solo el maestro puede pedir un respaldo.' }, 403)
  if (!env.GITHUB_TOKEN || !env.GITHUB_REPO) return json({ mensaje: 'El respaldo manual no está configurado (faltan GITHUB_TOKEN y GITHUB_REPO en Cloudflare). El respaldo automático de cada domingo sigue funcionando.' }, 500)

  const r = await fetch(`https://api.github.com/repos/${env.GITHUB_REPO}/actions/workflows/respaldo-semanal.yml/dispatches`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${env.GITHUB_TOKEN}`, Accept: 'application/vnd.github+json', 'User-Agent': 'taller-distrilogico', 'Content-Type': 'application/json' },
    body: JSON.stringify({ ref: 'main', inputs: { tipo: 'manual' } })
  })
  if (r.status !== 204) return json({ mensaje: `GitHub rechazó la solicitud (${r.status}). Revise el token.` }, 502)
  return json({ mensaje: 'Respaldo solicitado. En unos 2 minutos aparecerá en su Google Drive y en la lista de respaldos.' })
}
