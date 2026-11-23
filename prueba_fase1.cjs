// Prueba de la Fase 1 (login, roles, permisos y Maestros) en Chrome, PC y celular,
// contra el entorno local simulado (vite en :5173 y servidor_simulado en :54321).
// Uso: node pruebas/prueba_fase1.cjs   · capturas en $SALIDA (por defecto /tmp/capturas_fase1)
let chromium
try { ({ chromium } = require('playwright')) } catch { ({ chromium } = require('/opt/node-tools/node_modules/playwright')) }
const fs = require('fs')
const SALIDA = process.env.SALIDA || '/tmp/capturas_fase1'
fs.mkdirSync(SALIDA, { recursive: true })
const BASE = 'http://localhost:5173/'
let n = 0
const foto = async (p, nombre) => { n++; await p.screenshot({ path: `${SALIDA}/${String(n).padStart(2, '0')}_${nombre}.png`, fullPage: true }) }
const ok = (cond, texto) => { if (!cond) throw new Error('FALLÓ: ' + texto); console.log('✓ ' + texto) }

async function ingresar(p, usuario) {
  await p.goto(BASE); await p.waitForSelector('#usuario')
  await p.fill('#usuario', usuario); await p.fill('#clave', 'prueba123'); await p.click('button:has-text("Ingresar")')
  await p.waitForSelector('text=Cápsulas de navegación', { state: 'attached' })
}
async function salir(p) {
  await p.evaluate(() => localStorage.clear()); await p.context().clearCookies()
  await p.goto(BASE + '#/'); await p.reload(); await p.waitForSelector('#usuario')
}
const menu = async p => (await p.locator('nav a').allTextContents()).map(t => t.replace(/FASE \d/, '').trim())

;(async () => {
  const nav = await chromium.launch()
  const errores = []
  const pc = await (await nav.newContext({ viewport: { width: 1366, height: 900 }, deviceScaleFactor: 2, acceptDownloads: true })).newPage()
  pc.on('pageerror', e => errores.push(String(e)))

  // ---------------------------------------------------------------- Ingreso
  await pc.goto(BASE); await pc.waitForSelector('#usuario'); await foto(pc, 'ingreso')
  await pc.fill('#usuario', 'admin'); await pc.fill('#clave', 'mal'); await pc.click('button:has-text("Ingresar")')
  await pc.waitForSelector('text=Usuario o contraseña incorrectos'); ok(true, 'contraseña incorrecta rechazada')

  // ---------------------------------------------------------------- Maestro
  await ingresar(pc, 'admin')
  const mMaestro = await menu(pc)
  console.log('Menú maestro:', mMaestro.join(' | '))
  ok(mMaestro.includes('Maestros') && mMaestro.includes('Soldadura'), 'el maestro ve Maestros y los ambientes')
  await foto(pc, 'maestro_inicio')

  // Catálogo de soldadura (cápsulas)
  await pc.click('nav a:has-text("Maestros")'); await pc.click('button:has-text("Catálogo soldadura")')
  await pc.waitForSelector('h4:has-text("Compuertas")')
  ok(await pc.locator('.dock-capsule').count() >= 9, 'grilla con las 8 cápsulas de soldadura + "nueva cápsula"')
  ok(await pc.locator('text=Sin complejidad').count() === 1, 'Tanque de lixiviados sin complejidad')
  await foto(pc, 'catalogo_soldadura')
  await pc.locator('.dock-capsule', { hasText: 'Compuertas' }).locator('button:has-text("Editar")').click()
  await pc.waitForSelector('text=Reponer conjunto'); await foto(pc, 'capsula_compuertas_abierta')
  // Nueva intervención desde la cápsula
  await pc.locator('.dock-capsule', { hasText: 'Compuertas' }).locator('button:has-text("+ Intervención")').click()
  await pc.fill('#f-intervencion input >> nth=0', 'Cambiar bisagra completa'); await pc.fill('#f-intervencion input >> nth=1', '1,8')
  await pc.selectOption('#f-intervencion select', { label: 'Kit de embrague' }).catch(() => undefined)
  await pc.selectOption('#f-intervencion select', { index: 0 })
  await foto(pc, 'modal_intervencion')
  await pc.click('button:has-text("Guardar cambios")')
  await pc.waitForSelector('text=Cambiar bisagra completa'); ok(true, 'intervención agregada desde la cápsula')
  // Ventana "Gestión de catálogo extensible"
  await pc.locator('button').filter({ hasText: /^Catálogo$/ }).click(); await pc.waitForSelector('text=Agregar nueva intervención al catálogo')
  await pc.selectOption('select >> nth=0', { label: 'PORTALLANTAS' })
  await pc.fill('input[placeholder^="Ej. Bisagras"]', 'Portallantas trasero'); await pc.fill('input[placeholder="Ej. Refuerzo especial"]', 'Fabricar portallantas')
  await pc.fill('input[inputmode="decimal"] >> nth=0', '4')
  await pc.click('button:has-text("Agregar al catálogo")'); await pc.waitForSelector('text=Fabricar portallantas: ')
  await foto(pc, 'modal_gestion_catalogo'); ok(true, 'intervención agregada desde la ventana de catálogo (con elemento nuevo)')
  await pc.click('button:has-text("Cerrar") >> nth=-1')

  // Mecánica: cápsulas vacías con aviso
  await pc.click('button:has-text("Catálogo mecánica")'); await pc.waitForSelector('h4:has-text("Motor")')
  ok(await pc.locator('text=Sin intervenciones — agregar en Maestros').count() === 2, 'mecánica: tempario cargado; solo Llantas y Lubricación siguen sin trabajos')
  await pc.locator('.dock-capsule', { hasText: 'Motor' }).first().locator('button:has-text("Editar")').click()
  await pc.fill('[aria-label="Buscar intervención"]', 'turbo')
  ok(await pc.locator('button').filter({ hasText: /^MONTAJE DE TURBO/ }).count() === 1 && await pc.locator('button:has-text("CABEZOTE")').count() === 0, 'buscador de la cápsula Motor (67 trabajos)')
  await foto(pc, 'catalogo_mecanica')

  // Exportar catálogo a Excel
  await pc.click('button:has-text("Catálogo soldadura")'); await pc.waitForSelector('h4:has-text("Compuertas")')
  const [xls] = await Promise.all([pc.waitForEvent('download'), pc.click('button:has-text("Exportar")')])
  await xls.saveAs(`${SALIDA}/catalogo_soldadura.xlsx`); ok(true, 'catálogo exportado a Excel: ' + xls.suggestedFilename())

  // Técnicos
  await pc.click('button:has-text("Técnicos")'); await pc.waitForSelector('td:has-text("Carlos Mora")'); await foto(pc, 'tecnicos')
  await pc.click('button:has-text("Nuevo")')
  const f = pc.locator('#form-catalogo')
  await f.locator('input').nth(0).fill('s03'); await f.locator('input').nth(1).fill('Jhon Córdova')
  await f.locator('select').nth(0).selectOption('soldadura'); await f.locator('input').nth(2).fill('Soldador A')
  await foto(pc, 'tecnico_nuevo')
  await pc.click('button:has-text("Guardar")'); await pc.waitForSelector('td:has-text("S03")'); ok(true, 'técnico creado (código en mayúsculas)')
  // Tarifas
  await pc.click('button:has-text("Tarifas")'); await pc.waitForSelector('td:has-text("M01 · Carlos Mora")'); await foto(pc, 'tarifas')

  // Vehículos: rentado a cliente
  await pc.click('button:has-text("Vehículos")'); await pc.waitForSelector('td:has-text("DP1034")'); await foto(pc, 'vehiculos')
  await pc.click('td:has-text("DP1034")'); await pc.waitForSelector('text=Cliente *'); await foto(pc, 'vehiculo_rentado')
  await pc.click('button:has-text("Cancelar")')

  // Preventivos, listas, parámetros y clave
  await pc.click('button:has-text("Intervalos preventivos")'); await pc.waitForSelector('td:has-text("Caja y corona")'); await foto(pc, 'preventivos')
  await pc.click('button:has-text("Listas")'); await pc.waitForSelector('td:has-text("Corrosión")')
  await pc.click('button:has-text("Motivo cambio de llanta")'); await pc.waitForSelector('td:has-text("REVENTADA")'); await foto(pc, 'listas_kardex')
  await pc.click('button:has-text("Parámetros y clave")'); await pc.waitForSelector('text=NO DEFINIDA')
  await pc.fill('#clave-nueva', 'Taller2026'); await pc.fill('#clave-repetir', 'Taller2026'); await pc.click('button:has-text("Definir clave")')
  await pc.waitForSelector('text=DEFINIDA'); await foto(pc, 'parametros_clave'); ok(true, 'clave de aprobación definida')

  // Usuarios: dar "editar_catalogos" al supervisor
  await pc.click('button:has-text("Usuarios y roles")'); await pc.waitForSelector('td:has-text("Jorge Salazar")')
  await pc.locator('tr', { hasText: 'Jorge Salazar' }).locator('button:has-text("Editar catálogos")').click()
  await pc.waitForSelector('tr:has-text("Jorge Salazar") >> text=✓ Editar catálogos'); await foto(pc, 'usuarios_permisos')
  ok(true, 'permiso extra "Editar catálogos" asignado al supervisor')
  await pc.click('button:has-text("Exportación y bitácora")'); await pc.waitForSelector('text=Bitácora de auditoría'); await foto(pc, 'bitacora')
  await salir(pc)

  // ---------------------------------------------------------------- Supervisor (con editar_catalogos)
  await ingresar(pc, 'jefe')
  const mSup = await menu(pc)
  console.log('Menú supervisor:', mSup.join(' | '))
  await pc.click('nav a:has-text("Maestros")'); await pc.waitForSelector('button:has-text("Vehículos")')
  const pest = await pc.locator('section button').allTextContents()
  ok(!pest.some(t => t.includes('Usuarios')) && !pest.some(t => t.includes('Tarifas')) && !pest.some(t => t.includes('Parámetros')), 'el supervisor no ve Usuarios, Tarifas ni Parámetros')
  await pc.click('button:has-text("Técnicos")'); await pc.waitForSelector('td:has-text("Carlos Mora")')
  ok(await pc.locator('button:has-text("Nuevo")').count() === 0, 'técnicos: solo lectura para el supervisor')
  await pc.click('button:has-text("Choferes")'); await pc.waitForSelector('td:has-text("Mendoza")')
  ok(await pc.locator('button:has-text("Nuevo")').count() === 1, 'choferes: el supervisor con permiso puede editar')
  await foto(pc, 'supervisor_maestros'); await salir(pc)

  // ---------------------------------------------------------------- Bodega
  await ingresar(pc, 'bodega')
  const mBod = await menu(pc)
  console.log('Menú bodega:', mBod.join(' | '))
  ok(!mBod.includes('Maestros') && mBod.includes('Inventarios'), 'bodega ve Inventarios y no Maestros')
  await pc.goto(BASE + '#/maestros/tecnicos'); await pc.waitForSelector('text=Maestros es solo para el maestro')
  ok(true, 'bodega no entra a Maestros ni escribiendo la dirección'); await foto(pc, 'bodega'); await salir(pc)

  // ---------------------------------------------------------------- Técnico en celular
  const cel = await (await nav.newContext({ ...require('playwright').devices?.['Pixel 7'] || { viewport: { width: 412, height: 915 }, isMobile: true, hasTouch: true } })).newPage()
  cel.on('pageerror', e => errores.push(String(e)))
  await ingresar(cel, 'tecnico')
  await cel.waitForSelector('text=Perfil del técnico'); await foto(cel, 'tecnico_perfil_celular')
  await cel.fill('#mi-telefono', '0990000001'); await cel.fill('#mi-contacto', 'Ana Mora (hija) - 0991112222')
  await cel.click('button:has-text("Guardar datos autorizados")'); await cel.waitForSelector('text=Datos guardados')
  ok(true, 'el técnico guarda su teléfono y contacto de emergencia')
  await cel.click('button[aria-label="Menú"]'); await cel.waitForSelector('nav a:has-text("Perfil profesional")')
  const mTec = await menu(cel)
  console.log('Menú técnico:', mTec.join(' | '))
  ok(!mTec.includes('Maestros') && !mTec.includes('Soldadura'), 'el técnico no ve Maestros ni los ambientes')
  await foto(cel, 'tecnico_menu_celular')

  // Maestro en celular
  const cel2 = await (await nav.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 })).newPage()
  cel2.on('pageerror', e => errores.push(String(e)))
  await ingresar(cel2, 'admin'); await cel2.goto(BASE + '#/maestros/soldadura'); await cel2.waitForSelector('h4:has-text("Compuertas")')
  await foto(cel2, 'maestro_catalogo_celular')

  console.log(errores.length ? 'ERRORES DE PÁGINA:\n' + errores.join('\n') : 'Sin errores de página.')
  await nav.close()
  if (errores.length) process.exit(1)
})().catch(e => { console.error(e.message); process.exit(1) })
