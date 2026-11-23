// Servidor que imita las partes de Supabase que usa la app (solo para pruebas locales):
// /auth/v1 (inicio de sesión), /rest/v1 (PostgREST real) y /storage/v1 (archivos en disco).
import http from 'node:http'
import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'

const SECRETO = process.env.JWT_SECRETO || 'secreto-de-pruebas-local-de-al-menos-32-caracteres'
const PGRST = process.env.PGRST || 'http://127.0.0.1:3001'
const DIR = process.env.DIR_ARCHIVOS || '/tmp/archivos_prueba'
const USUARIOS = {
  'admin@taller.local': { id: '00000000-0000-0000-0000-0000000000a1', clave: 'prueba123' },
  'jefe@taller.local': { id: '11111111-1111-1111-1111-111111111111', clave: 'prueba123' },
  'tecnico@taller.local': { id: '22222222-2222-2222-2222-222222222222', clave: 'prueba123' },
  'bodega@taller.local': { id: '33333333-3333-3333-3333-333333333333', clave: 'prueba123' }
}
const b64 = o => Buffer.from(typeof o === 'string' ? o : JSON.stringify(o)).toString('base64url')
export function firmar(carga) {
  const cab = b64({ alg: 'HS256', typ: 'JWT' }), cuerpo = b64(carga)
  return `${cab}.${cuerpo}.${crypto.createHmac('sha256', SECRETO).update(`${cab}.${cuerpo}`).digest('base64url')}`
}
const leerJwt = t => { try { return JSON.parse(Buffer.from(t.split('.')[1], 'base64url').toString()) } catch { return null } }
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': '*', 'Access-Control-Allow-Methods': '*', 'Access-Control-Expose-Headers': '*' }
const enviar = (res, estado, cuerpo, cab = {}) => { res.writeHead(estado, { 'Content-Type': 'application/json', ...cors, ...cab }); res.end(cuerpo === undefined ? '' : JSON.stringify(cuerpo)) }
const leer = req => new Promise(r => { const p = []; req.on('data', c => p.push(c)); req.on('end', () => r(Buffer.concat(p))) })

function sesion(correo) {
  const u = USUARIOS[correo]
  const exp = Math.floor(Date.now() / 1000) + 3600
  const usuario = { id: u.id, email: correo, aud: 'authenticated', role: 'authenticated', app_metadata: {}, user_metadata: {}, created_at: new Date().toISOString() }
  return { access_token: firmar({ sub: u.id, role: 'authenticated', aud: 'authenticated', email: correo, exp }), token_type: 'bearer', expires_in: 3600, expires_at: exp, refresh_token: 'r:' + correo, user: usuario }
}

function extraerArchivo(buf, tipo) {
  const m = /boundary=(.+)$/.exec(tipo || '')
  if (!m) return buf
  const lim = Buffer.from('--' + m[1])
  let i = buf.indexOf(lim)
  while (i >= 0) {
    const sig = buf.indexOf(lim, i + lim.length)
    if (sig < 0) break
    const parte = buf.subarray(i + lim.length, sig)
    const fin = parte.indexOf('\r\n\r\n')
    const cab = parte.subarray(0, fin).toString()
    if (/filename=|Content-Type: (image|application\/pdf)/i.test(cab)) return parte.subarray(fin + 4, parte.length - 2)
    i = sig
  }
  return buf
}

http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') return enviar(res, 204)
  const url = new URL(req.url, 'http://x')
  const cuerpo = await leer(req)
  try {
    if (url.pathname === '/auth/v1/token') {
      const d = JSON.parse(cuerpo.toString() || '{}')
      if (url.searchParams.get('grant_type') === 'refresh_token') {
        const correo = String(d.refresh_token || '').slice(2)
        return USUARIOS[correo] ? enviar(res, 200, sesion(correo)) : enviar(res, 400, { error: 'invalid_grant', error_description: 'Invalid Refresh Token' })
      }
      const u = USUARIOS[d.email]
      if (!u || u.clave !== d.password) return enviar(res, 400, { error: 'invalid_grant', error_description: 'Invalid login credentials', code: 400, msg: 'Invalid login credentials' })
      return enviar(res, 200, sesion(d.email))
    }
    if (url.pathname === '/auth/v1/user') {
      const j = leerJwt((req.headers.authorization || '').slice(7))
      return j?.sub ? enviar(res, 200, { id: j.sub, email: j.email, aud: 'authenticated', role: 'authenticated', app_metadata: {}, user_metadata: {} }) : enviar(res, 401, { msg: 'no' })
    }
    if (url.pathname === '/auth/v1/logout') return enviar(res, 204)
    if (url.pathname.startsWith('/rest/v1/')) {
      const r = await fetch(PGRST + url.pathname.slice(8) + url.search, {
        method: req.method, body: ['GET', 'HEAD'].includes(req.method) ? undefined : cuerpo,
        headers: Object.fromEntries(Object.entries(req.headers).filter(([k]) => !['host', 'content-length', 'connection'].includes(k)))
      })
      const b = Buffer.from(await r.arrayBuffer())
      const cab = { ...cors }
      r.headers.forEach((v, k) => { if (!['content-encoding', 'transfer-encoding', 'connection'].includes(k) && !k.startsWith('access-control')) cab[k] = v })
      res.writeHead(r.status, cab); return res.end(b)
    }
    const st = /^\/storage\/v1\/object\/(?:authenticated\/)?archivos\/(.+)$/.exec(url.pathname)
    if (st) {
      const ruta = path.join(DIR, decodeURIComponent(st[1]))
      if (req.method === 'POST' || req.method === 'PUT') {
        if (fs.existsSync(ruta) && req.method === 'POST') return enviar(res, 400, { statusCode: '409', error: 'Duplicate', message: 'The resource already exists' })
        fs.mkdirSync(path.dirname(ruta), { recursive: true })
        fs.writeFileSync(ruta, extraerArchivo(cuerpo, req.headers['content-type']))
        return enviar(res, 200, { Key: 'archivos/' + st[1], Id: crypto.randomUUID() })
      }
      if (!fs.existsSync(ruta)) return enviar(res, 404, { statusCode: '404', error: 'not_found', message: 'Object not found' })
      res.writeHead(200, { 'Content-Type': 'image/png', ...cors }); return res.end(fs.readFileSync(ruta))
    }
    // Imita la función de fotos (R2) guardando en disco. Exige sesión.
    const ft = /^\/api\/fotos\/(.+)$/.exec(url.pathname)
    if (ft) {
      if (!leerJwt((req.headers.authorization || '').slice(7))?.sub) return enviar(res, 401, { mensaje: 'Sesión no válida.' })
      const ruta = path.join(DIR, 'r2', decodeURIComponent(ft[1]))
      if (req.method === 'POST') { fs.mkdirSync(path.dirname(ruta), { recursive: true }); fs.writeFileSync(ruta, cuerpo); return enviar(res, 200, { ruta: ft[1] }) }
      if (!fs.existsSync(ruta)) return enviar(res, 404, { mensaje: 'Foto no encontrada.' })
      res.writeHead(200, { 'Content-Type': 'image/jpeg', ...cors }); return res.end(fs.readFileSync(ruta))
    }
    if (url.pathname.startsWith('/api/')) return enviar(res, 501, { mensaje: 'En pruebas locales no hay funciones de Cloudflare.' })
    enviar(res, 404, { error: 'no encontrado' })
  } catch (e) { enviar(res, 500, { message: String(e) }) }
}).listen(54321, () => console.log('Supabase simulado en http://localhost:54321 · anon:', firmar({ role: 'anon' })))
