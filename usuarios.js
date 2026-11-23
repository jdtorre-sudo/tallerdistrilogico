// Cloudflare Pages Function: crea usuarios y cambia contraseñas.
// Usa la clave "service_role" de Supabase, que vive SOLO aquí (variable
// secreta de Cloudflare) y nunca llega al navegador.
// Variables necesarias en Cloudflare Pages > Settings > Variables:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

const DOMINIO = 'taller.local'
const ROLES = ['maestro', 'supervisor', 'bodega', 'tecnico']
const json = (cuerpo, estado = 200) => new Response(JSON.stringify(cuerpo), { status: estado, headers: { 'Content-Type': 'application/json' } })

async function esMaestro(env, token) {
  const u = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, { headers: { apikey: env.SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${token}` } })
  if (!u.ok) return null
  const usuario = await u.json()
  const p = await fetch(`${env.SUPABASE_URL}/rest/v1/usuarios?id=eq.${usuario.id}&select=rol,activo`, {
    headers: { apikey: env.SUPABASE_SERVICE_ROLE_KEY }
  })
  const [perfil] = await p.json()
  return perfil && perfil.activo && perfil.rol === 'maestro' ? usuario : null
}

export async function onRequestPost({ request, env }) {
  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) return json({ mensaje: 'Falta configurar SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY en Cloudflare.' }, 500)
  const token = (request.headers.get('Authorization') || '').replace('Bearer ', '')
  if (!token || !(await esMaestro(env, token))) return json({ mensaje: 'Solo el maestro puede hacer esto.' }, 403)

  const d = await request.json().catch(() => ({}))
  const cab = { apikey: env.SUPABASE_SERVICE_ROLE_KEY, 'Content-Type': 'application/json' }

  if (d.accion === 'crear') {
    const usuario = String(d.usuario || '').trim().toLowerCase()
    if (!usuario || !d.nombre_completo || !ROLES.includes(d.rol)) return json({ mensaje: 'Complete usuario, nombre y rol.' }, 400)
    if (String(d.clave || '').length < 8) return json({ mensaje: 'La contraseña debe tener al menos 8 caracteres.' }, 400)
    const correo = usuario.includes('@') ? usuario : `${usuario}@${DOMINIO}`
    const r = await fetch(`${env.SUPABASE_URL}/auth/v1/admin/users`, {
      method: 'POST', headers: cab,
      body: JSON.stringify({ email: correo, password: d.clave, email_confirm: true, user_metadata: { nombre_completo: d.nombre_completo, rol: d.rol, telefono: d.telefono || null } })
    })
    const j = await r.json()
    if (!r.ok) return json({ mensaje: /already/i.test(j.msg || j.message || '') ? 'Ese usuario ya existe.' : (j.msg || j.message || 'No se pudo crear el usuario.') }, 400)
    // La ficha nace inactiva (ver 005_supabase.sql): aquí se activa con el rol elegido.
    const a = await fetch(`${env.SUPABASE_URL}/rest/v1/usuarios?id=eq.${j.id}`, {
      method: 'PATCH', headers: { ...cab, Prefer: 'return=minimal' },
      body: JSON.stringify({ rol: d.rol, activo: true, nombre_completo: d.nombre_completo, telefono: d.telefono || null })
    })
    if (!a.ok) return json({ mensaje: 'El usuario se creó pero no se pudo activar. Actívelo en la lista de usuarios.' }, 500)
    return json({ mensaje: `Usuario "${usuario}" creado. Ya puede ingresar con la contraseña indicada.` })
  }

  if (d.accion === 'clave') {
    if (String(d.clave || '').length < 8) return json({ mensaje: 'La contraseña debe tener al menos 8 caracteres.' }, 400)
    const r = await fetch(`${env.SUPABASE_URL}/auth/v1/admin/users/${d.id}`, { method: 'PUT', headers: cab, body: JSON.stringify({ password: d.clave }) })
    if (!r.ok) return json({ mensaje: 'No se pudo cambiar la contraseña.' }, 400)
    return json({ mensaje: 'Contraseña cambiada.' })
  }
  return json({ mensaje: 'Acción no válida.' }, 400)
}
