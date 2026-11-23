// Prueba de la Fase 2 (OT por segmentos + ambientes + observaciones) en Chrome, PC y celular,
// contra el entorno local simulado (vite en :5173 y servidor_simulado en :54321).
// Uso: node pruebas/prueba_fase2.cjs   · capturas en $SALIDA (por defecto /tmp/capturas_fase2)
let chromium
try { ({ chromium } = require('playwright')) } catch { ({ chromium } = require('/opt/node-tools/node_modules/playwright')) }
const fs = require('fs')
const zlib = require('zlib')
const SALIDA = process.env.SALIDA || '/tmp/capturas_fase2'
fs.mkdirSync(SALIDA, { recursive: true })
const BASE = 'http://localhost:5173/'
let n = 0
const foto = async (p, nombre) => { n++; await p.screenshot({ path: `${SALIDA}/${String(n).padStart(2, '0')}_${nombre}.png`, fullPage: true }) }
const ok = (cond, texto) => { if (!cond) throw new Error('FALLÓ: ' + texto); console.log('✓ ' + texto) }

// Imagen PNG pequeña para probar la subida de fotos
function png() {
  const w = 64, h = 48, filas = []
  for (let y = 0; y < h; y++) { const f = [0]; for (let x = 0; x < w; x++) f.push(200, 60 + y * 3, 40 + x * 2); filas.push(Buffer.from(f)) }
  const crc = b => { let c, t = []; for (let k = 0; k < 256; k++) { c = k; for (let j = 0; j < 8; j++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[k] = c >>> 0 } let r = 0xffffffff; for (const x of b) r = t[(r ^ x) & 255] ^ (r >>> 8); return (r ^ 0xffffffff) >>> 0 }
  const trozo = (tipo, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(tipo), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]) }
  const ih = Buffer.alloc(13); ih.writeUInt32BE(w, 0); ih.writeUInt32BE(h, 4); ih[8] = 8; ih[9] = 2
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), trozo('IHDR', ih), trozo('IDAT', zlib.deflateSync(Buffer.concat(filas))), trozo('IEND', Buffer.alloc(0))])
}

async function ingresar(p, usuario) {
  await p.goto(BASE); await p.waitForSelector('#usuario')
  await p.fill('#usuario', usuario); await p.fill('#clave', 'prueba123'); await p.click('button:has-text("Ingresar")')
  await p.waitForSelector('text=Cápsulas de navegación', { state: 'attached' })
}
async function salir(p) { await p.evaluate(() => localStorage.clear()); await p.goto(BASE + '#/'); await p.reload(); await p.waitForSelector('#usuario') }
const capsula = (p, nombre) => p.locator(`[data-capsula="${nombre}"]`)

;(async () => {
  const nav = await chromium.launch()
  const errores = []
  const pc = await (await nav.newContext({ viewport: { width: 1366, height: 900 }, deviceScaleFactor: 1 })).newPage()
  pc.on('pageerror', e => errores.push(String(e)))
  fs.writeFileSync(`${SALIDA}/prueba.png`, png())

  // ---------------------------------------------------------------- Supervisor abre la OT
  await ingresar(pc, 'jefe')
  await pc.click('nav a:has-text("Órdenes de trabajo")'); await pc.waitForSelector('text=No hay órdenes abiertas')
  await pc.click('a:has-text("Nueva OT")'); await pc.waitForSelector('text=Nueva orden de trabajo')
  await pc.click('button:has-text("Golpe / siniestro")')
  await pc.fill('#buscar-vehiculo', 'dp176'); await pc.click('button:has-text("DP176")')
  await pc.fill('#lectura', '100'); await pc.waitForSelector('text=No puede ser menor'); ok(true, 'avisa km menor al último')
  await pc.fill('#lectura', '98500')
  await pc.locator('button').filter({ hasText: /^F$/ }).click()
  await pc.click('button:has-text("Marcar todo OK")')
  await pc.fill('[aria-label="Solicitud 1"]', 'La compuerta trasera no cierra'); await pc.locator('[aria-label="Solicitud 1"]').locator('xpath=..').locator('button:has-text("Soldadura")').click()
  await pc.click('button:has-text("Agregar línea")'); await pc.fill('[aria-label="Solicitud 2"]', 'Frenos largos')
  await foto(pc, 'nueva_ot')
  await pc.click('button:has-text("Abrir orden de trabajo")'); await pc.waitForSelector('[data-segmento="1"]')
  ok(await pc.locator('text=GOLPE / SINIESTRO').count() + await pc.locator('text=Golpe / siniestro').count() > 0, 'tipo de OT: golpe / siniestro')
  ok(true, 'OT abierta con segmentos 1 y 2'); await foto(pc, 'ot_abierta')
  // Foto de la recepción
  await pc.click('[data-segmento="1"] summary')
  await pc.locator('[data-segmento="1"] input[type=file]').setInputFiles(`${SALIDA}/prueba.png`)
  await pc.waitForSelector('[data-segmento="1"] img'); ok(true, 'foto de la recepción subida y mostrada')

  // ---------------------------------------------------------------- Ambiente Soldadura
  await pc.click('a:has-text("Soldadura") >> nth=-1'); await pc.waitForSelector('text=Panel de cápsulas independientes de inspección')
  await foto(pc, 'ambiente_soldadura')
  await capsula(pc, 'Compuertas').locator('button:has-text("Inspeccionar")').click()
  await capsula(pc, 'Compuertas').locator('button:has-text("Bisagras")').click()
  await capsula(pc, 'Compuertas').locator('button:has-text("Resoldar")').click()
  await capsula(pc, 'Compuertas').locator('button:has-text("Grave")').click()
  await capsula(pc, 'Compuertas').locator('[aria-label="Más"]').click()
  await capsula(pc, 'Compuertas').locator('button:has-text("S01")').click(); await capsula(pc, 'Compuertas').locator('button:has-text("S02")').click()
  await capsula(pc, 'Compuertas').locator('select[aria-label="Causa"]').selectOption('Golpe')
  await foto(pc, 'capsula_datos')
  await capsula(pc, 'Compuertas').locator('button:has-text("AGREGAR TRABAJO")').click()
  await pc.waitForSelector('td:has-text("Resoldar")'); ok(await pc.locator('td:has-text("1,40 h")').count() > 0, 'trabajo agregado: 0,5 h × 2 × grave 1,4 = 1,40 h')
  ok(await pc.locator('text=0,70 h').count() >= 2, 'reparto en partes iguales: 0,70 h a cada técnico')
  // Tanque (sin complejidad), hallazgo nuevo, reparto 70/30 con el técnico M01 (usuario "tecnico")
  await capsula(pc, 'Tanque de lixiviados').locator('button:has-text("Inspeccionar")').click()
  await capsula(pc, 'Tanque de lixiviados').locator('button:has-text("Válvulas")').click()
  await capsula(pc, 'Tanque de lixiviados').locator('button:has-text("Reparación de válvula")').click()
  ok(await capsula(pc, 'Tanque de lixiviados').locator('button:has-text("Grave")').count() === 0, 'Tanque de lixiviados no pide complejidad')
  await capsula(pc, 'Tanque de lixiviados').locator('label:has-text("Ver todos") input').check()
  await capsula(pc, 'Tanque de lixiviados').locator('button:has-text("S01")').click(); await capsula(pc, 'Tanque de lixiviados').locator('button:has-text("M01")').click()
  await capsula(pc, 'Tanque de lixiviados').locator('label:has-text("Cambiar reparto") input').check()
  await capsula(pc, 'Tanque de lixiviados').locator('[aria-label="Porcentaje de S01"]').fill('70'); await capsula(pc, 'Tanque de lixiviados').locator('[aria-label="Porcentaje de M01"]').fill('30')
  await capsula(pc, 'Tanque de lixiviados').locator('button:has-text("Hallazgo")').click()
  await capsula(pc, 'Tanque de lixiviados').locator('input[placeholder^="¿Qué se encontró"]').fill('Válvula del tanque con fuga')
  await capsula(pc, 'Tanque de lixiviados').locator('button:has-text("AGREGAR TRABAJO")').click()
  await pc.waitForSelector('td:has-text("Reparación de válvula")'); ok(await pc.locator('text=0,84 h').count() > 0, 'reparto 70/30: 0,84 h para S01')
  // Inspeccionado OK en Cabina
  await pc.click('[aria-label="Inspeccionado OK Cabina"]'); await pc.waitForSelector('[data-capsula="Cabina"] >> text=Inspeccionado OK')
  ok(true, 'Cabina marcada Inspeccionado OK')
  // Novedad: imprevisto y su aprobación
  await pc.click('button:has-text("NOVEDADES")'); await pc.click('text=IMPREVISTO DURANTE EL TRABAJO')
  await pc.fill('input[placeholder^="Ej. Falta de pernos"]', 'Faltan pernos'); await pc.click('button:has-text("Guardar imprevisto")')
  await pc.waitForSelector('text=Faltan pernos'); await pc.click('[aria-label="Aprobar imprevisto"]'); await pc.waitForSelector('span:has-text("Aprobado")')
  ok(true, 'imprevisto registrado y aprobado por el supervisor')
  await foto(pc, 'ambiente_con_trabajos')

  // ---------------------------------------------------------------- Ambiente Mecánica (cápsulas vacías)
  await pc.click('nav a:has-text("Mecánica")'); await pc.waitForSelector('text=Panel de cápsulas')
  await capsula(pc, 'Llantas').locator('button:has-text("Inspeccionar")').click()
  ok(await capsula(pc, 'Llantas').locator('text=Sin intervenciones — agregar en Maestros').count() === 1, 'cápsula sin catálogo: aviso')
  await capsula(pc, 'Llantas').locator('button:has-text("Cerrar")').click()
  // Tempario: buscar en Motor y registrar con la línea 2 del chofer
  await capsula(pc, 'Refrigeración').locator('button:has-text("Inspeccionar")').click()
  await capsula(pc, 'Refrigeración').locator('button').filter({ hasText: /^MONTAJE DE BOMBA DE AGUA/ }).click()
  await capsula(pc, 'Refrigeración').locator('button:has-text("M02")').click()
  await capsula(pc, 'Refrigeración').locator('button:has-text("AGREGAR TRABAJO")').click()
  await pc.waitForSelector('td:text-is("MONTAJE DE BOMBA DE AGUA")'); ok(await pc.locator('td:has-text("2,00 h")').count() > 0, 'tempario: montaje de bomba de agua (cápsula Refrigeración) 2 h registrado')
  // Eléctricos: checklist en minutos
  await capsula(pc, 'Sistema eléctrico').locator('button:has-text("Inspeccionar")').click()
  ok(await capsula(pc, 'Sistema eléctrico').locator('text=5 min').count() >= 2, 'eléctricos: tiempos cortos en minutos (5 min)')
  await foto(pc, 'ambiente_mecanica')

  // ---------------------------------------------------------------- La OT por segmentos
  await pc.click('button:has-text("Ver OT")'); await pc.waitForSelector('[data-segmento="3"]')
  ok(await pc.locator('[data-segmento="3"] >> text=Válvula del tanque con fuga').count() === 1, 'el hallazgo quedó en el segmento 3')
  ok(await pc.locator('[data-segmento="2"] >> text=Atendida').count() === 2, 'línea 2 del chofer atendida por el trabajo de mecánica')
  await pc.locator('select[aria-label="Estado del trabajo 1"]').selectOption('terminado'); await pc.waitForSelector('text=Estado actualizado')
  await pc.fill('[data-segmento="5"] textarea', 'Revisar escuadra de la compuerta'); await pc.click('[data-segmento="5"] button:has-text("Guardar observación")')
  await pc.waitForSelector('text=Observación guardada'); ok(true, 'supervisor: trabajo terminado y observación del segmento 5')
  await foto(pc, 'ot_segmentos')
  await salir(pc)

  // ---------------------------------------------------------------- Técnico en celular
  const cel = await (await nav.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 })).newPage()
  cel.on('pageerror', e => errores.push(String(e)))
  await ingresar(cel, 'tecnico')
  await cel.goto(BASE + '#/mis-trabajos'); await cel.waitForSelector('text=Reparación de válvula')
  ok(true, 'el técnico ve su trabajo asignado (sin botón Completar)'); ok(await cel.locator('text=Completar').count() === 0, 'no existe "Completar trabajo"')
  await foto(cel, 'tecnico_trabajos')
  await cel.click('button:has-text("Ver OT y observar")'); await cel.waitForSelector('#nueva-observacion')
  ok(await cel.locator('select[aria-label^="Estado del trabajo"]').count() === 0, 'el técnico no cambia estados')
  await cel.fill('#nueva-observacion', 'Terminé la válvula; quedó sin fuga.'); await cel.click('button:has-text("Guardar observación")')
  await cel.waitForSelector('[data-segmento="8"] p:has-text("Terminé la válvula")')
  ok(await cel.locator('[data-segmento="8"] b', { hasText: 'M01' }).count() > 0, 'observación con el código del técnico')
  await foto(cel, 'tecnico_observacion')

  console.log(errores.length ? 'ERRORES DE PÁGINA:\n' + errores.join('\n') : 'Sin errores de página.')
  await nav.close()
  if (errores.length) process.exit(1)
})().catch(e => { console.error(e.message); process.exit(1) })
