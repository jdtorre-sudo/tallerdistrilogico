// Genera los PDF al momento (no se guardan). Formato A4 vertical.
import { jsPDF } from 'jspdf'
import autoTable from 'jspdf-autotable'
import type { DocActa, DocOT, Empresa, VehiculoDoc, FilaChk } from './documentos'
import { fechaHora, lectura, nombreDano, nombreEstado, nombreEstadoLinea, nombreMotivo, nombreMotivoActa, nombreOrigen, nombreResultado, duracion } from './formato'
import { svgAPng, svgCompleto, VISTAS, COLOR_MARCA } from './diagramas'
import type { Dano } from './tipos'

const M = 14          // margen
const ANCHO = 210
const OSCURO: [number, number, number] = [28, 37, 48]
const GRIS: [number, number, number] = [90, 98, 110]

let logoCache: string | null | undefined
async function logo(): Promise<string | null> {
  if (logoCache !== undefined) return logoCache
  try {
    const r = await fetch('/logo.png')
    if (!r.ok) throw new Error()
    const b = await r.blob()
    logoCache = await new Promise(res => { const f = new FileReader(); f.onload = () => res(String(f.result)); f.readAsDataURL(b) })
  } catch { logoCache = null }
  return logoCache ?? null
}

async function encabezado(doc: jsPDF, titulo: string, numero: string, e: Empresa) {
  const l = await logo()
  if (l) {
    const p = doc.getImageProperties(l)
    const h = 12, w = Math.min(44, (p.width / p.height) * h)
    doc.addImage(l, 'PNG', M, 11, w, h, 'logo', 'FAST')
  } else {
    doc.setFont('helvetica', 'bold').setFontSize(16).setTextColor(...OSCURO).text(e.nombre, M, 20)
  }
  doc.setFont('helvetica', 'normal').setFontSize(8).setTextColor(...GRIS)
  doc.text([e.ruc ? `RUC ${e.ruc}` : '', e.direccion, e.telefono].filter(Boolean), M, 30)
  doc.setFont('helvetica', 'bold').setFontSize(12).setTextColor(...OSCURO).text(titulo, (M + 46 + ANCHO - M - 50) / 2, 19, { align: 'center' })
  doc.setDrawColor(...OSCURO).setLineWidth(0.6).roundedRect(ANCHO - M - 48, 9, 48, 16, 2, 2)
  doc.setFontSize(12).text(numero, ANCHO - M - 24, 19.5, { align: 'center' })
  doc.setLineWidth(0.3).line(M, 37, ANCHO - M, 37)
  return 42
}

function pie(doc: jsPDF) {
  const n = doc.getNumberOfPages()
  for (let i = 1; i <= n; i++) {
    doc.setPage(i)
    doc.setFont('helvetica', 'normal').setFontSize(7.5).setTextColor(...GRIS)
    doc.text(`Generado el ${fechaHora(new Date().toISOString())} · Sistema de taller Distrilógico`, M, 290)
    doc.text(`Página ${i} de ${n}`, ANCHO - M, 290, { align: 'right' })
  }
}

function seccion(doc: jsPDF, y: number, texto: string): number {
  if (y > 262) { doc.addPage(); y = 18 }
  doc.setFillColor(...OSCURO).rect(M, y, ANCHO - 2 * M, 6.5, 'F')
  doc.setFont('helvetica', 'bold').setFontSize(9.5).setTextColor(255, 255, 255).text(texto.toUpperCase(), M + 2, y + 4.6)
  doc.setTextColor(0, 0, 0)
  return y + 9
}

/** Cuadrícula de pares etiqueta/valor en N columnas. */
function datos(doc: jsPDF, y: number, pares: [string, string][], cols = 3): number {
  const w = (ANCHO - 2 * M) / cols
  pares.forEach(([k, v], i) => {
    const x = M + (i % cols) * w, yy = y + Math.floor(i / cols) * 10
    doc.setFont('helvetica', 'normal').setFontSize(7).setTextColor(...GRIS).text(k.toUpperCase(), x, yy)
    doc.setFont('helvetica', 'bold').setFontSize(9.5).setTextColor(0, 0, 0).text(doc.splitTextToSize(v || '—', w - 3)[0], x, yy + 4.2)
  })
  return y + Math.ceil(pares.length / cols) * 10 + 1
}

function parrafo(doc: jsPDF, y: number, texto: string): number {
  doc.setFont('helvetica', 'normal').setFontSize(9.5)
  const lineas = doc.splitTextToSize(texto || '—', ANCHO - 2 * M)
  if (y + lineas.length * 4.5 > 280) { doc.addPage(); y = 18 }
  doc.text(lineas, M, y + 3)
  return y + lineas.length * 4.5 + 3
}

const finTabla = (doc: jsPDF) => (doc as unknown as { lastAutoTable: { finalY: number } }).lastAutoTable.finalY + 4

const datosVehiculo = (v: VehiculoDoc): [string, string][] => [
  ['Código', v.codigo], ['Placa', v.placa], ['Tipo', v.tipo],
  ['Marca / modelo', `${v.marca} ${v.modelo}`.trim()], ['Año', v.anio], ['Chasis', v.chasis], ['Motor', v.motor]
]

async function diagramas(doc: jsPDF, y: number, v: VehiculoDoc, grupos: { danos: Dano[]; color: string }[]): Promise<number> {
  const vistas = VISTAS.filter(vi => grupos.some(g => g.danos.some(d => d.vista === vi.k)))
  if (!vistas.length) return parrafo(doc, y, 'Sin daños registrados.')
  const w = (ANCHO - 2 * M - 6) / 2, h = w / 2
  for (let i = 0; i < vistas.length; i++) {
    const x = M + (i % 2) * (w + 6)
    if (i % 2 === 0 && y + h + 8 > 282) { doc.addPage(); y = 18 }
    const marcas = grupos.flatMap(g => g.danos.filter(d => d.vista === vistas[i].k).map(d => ({ n: d.numero_marca, x: Number(d.posicion_x), y: Number(d.posicion_y), color: g.color })))
    const png = await svgAPng(svgCompleto(v.diagrama, vistas[i].k, marcas))
    doc.setDrawColor(200, 205, 212).rect(x, y, w, h)
    doc.addImage(png, 'PNG', x, y, w, h, undefined, 'FAST')
    doc.setFont('helvetica', 'bold').setFontSize(8).setTextColor(...GRIS).text(vistas[i].n, x + 2, y + 4)
    if (i % 2 === 1 || i === vistas.length - 1) y += h + 4
  }
  return y
}

function tablaDanos(doc: jsPDF, y: number, filas: (Dano & { origen?: string })[]): number {
  if (!filas.length) return y
  autoTable(doc, {
    startY: y, margin: { left: M, right: M }, styles: { fontSize: 8.5, cellPadding: 1.5 }, headStyles: { fillColor: [220, 225, 231], textColor: 0 },
    head: [['N.º', 'Vista', 'Tipo', 'Descripción', ...(filas.some(f => f.origen) ? ['Situación'] : [])]],
    body: filas.map(d => [d.numero_marca, VISTAS.find(v => v.k === d.vista)?.n || d.vista, nombreDano(d.tipo_dano), d.descripcion || '', ...(d.origen ? [d.origen] : [])])
  })
  return finTabla(doc)
}

function firmas(doc: jsPDF, y: number, a: { img: string | null; nombre: string; rol: string }, b: { img: string | null; nombre: string; rol: string }) {
  if (y > 240) { doc.addPage(); y = 20 }
  const w = (ANCHO - 2 * M - 20) / 2
  ;[a, b].forEach((f, i) => {
    const x = M + i * (w + 20)
    if (f.img) doc.addImage(f.img, 'PNG', x + 10, y, w - 20, 26, undefined, 'FAST')
    doc.setDrawColor(0).setLineWidth(0.3).line(x, y + 28, x + w, y + 28)
    doc.setTextColor(0, 0, 0).setFont('helvetica', 'bold').setFontSize(9).text(f.nombre || '—', x + w / 2, y + 33, { align: 'center' })
    doc.setFont('helvetica', 'normal').setFontSize(8).setTextColor(...GRIS).text(f.rol, x + w / 2, y + 37.5, { align: 'center' })
    doc.setTextColor(0, 0, 0)
  })
}

function tablaChecklist(doc: jsPDF, y: number, filas: FilaChk[], comparar: boolean) {
  const color = (r?: string): [number, number, number] => (r === 'ok' ? [28, 127, 70] : r === 'falta' ? [168, 111, 0] : r === 'danado' ? [191, 36, 36] : [0, 0, 0])
  autoTable(doc, {
    startY: y, margin: { left: M, right: M }, styles: { fontSize: 8.5, cellPadding: 1.4 }, headStyles: { fillColor: [220, 225, 231], textColor: 0 },
    head: [comparar ? ['Grupo', 'Elemento', 'Ingreso', 'Salida', 'Observación'] : ['Grupo', 'Elemento', 'Estado', 'Observación']],
    body: filas.map(f => comparar
      ? [f.grupo, f.nombre, nombreResultado(f.resultado_ingreso), nombreResultado(f.resultado), [f.observacion_ingreso, f.observacion].filter(Boolean).join(' / ')]
      : [f.grupo, f.nombre, nombreResultado(f.resultado), f.observacion || '']),
    didParseCell: h => {
      if (h.section !== 'body') return
      const f = filas[h.row.index]
      if (comparar) {
        if (h.column.index === 2) h.cell.styles.textColor = color(f.resultado_ingreso)
        if (h.column.index === 3) h.cell.styles.textColor = color(f.resultado)
        if (f.resultado_ingreso === 'ok' && f.resultado && f.resultado !== 'ok') { h.cell.styles.fillColor = [252, 225, 225]; h.cell.styles.fontStyle = 'bold' }
      } else if (h.column.index === 2) { h.cell.styles.textColor = color(f.resultado); h.cell.styles.fontStyle = 'bold' }
    }
  })
  return finTabla(doc)
}

// ======================================================== Actas de entrega y de recepción
export async function pdfActa(d: DocActa): Promise<Blob> {
  const rec = d.tipo === 'recepcion'
  const doc = new jsPDF({ unit: 'mm', format: 'a4' })
  let y = await encabezado(doc, rec ? 'ACTA DE RECEPCIÓN VEHICULAR' : 'ACTA DE ENTREGA VEHICULAR', d.numero, d.empresa)
  y = datos(doc, y, [[rec ? 'Fecha y hora de recepción' : 'Fecha y hora de entrega', fechaHora(d.fecha_hora)], ['Motivo', nombreMotivoActa(d.motivo)],
    [d.vehiculo.unidad === 'horas' ? 'Horómetro' : 'Kilometraje', lectura(d.lectura, d.vehiculo.unidad)]])
  y = seccion(doc, y, 'Vehículo')
  y = datos(doc, y, [...datosVehiculo(d.vehiculo), ['Combustible', d.combustible]], 3)
  y = seccion(doc, y, rec ? 'Conductor que entrega / responsable que recibe' : 'Responsable que entrega / conductor que recibe')
  y = datos(doc, y, [['Conductor', d.conductor.nombre], ['Cédula', d.conductor.cedula], ['Teléfono', d.conductor.telefono], [rec ? 'Recibe' : 'Entrega', d.responsable]])
  if (d.observaciones) { y = seccion(doc, y, rec ? 'Novedades y observaciones' : 'Observaciones'); y = parrafo(doc, y, d.observaciones) }
  y = seccion(doc, y, 'Checklist de elementos y documentos')
  y = tablaChecklist(doc, y, d.checklist, false)
  y = seccion(doc, y, 'Daños registrados')
  y = await diagramas(doc, y, d.vehiculo, [{ danos: d.danos, color: COLOR_MARCA.preexistente }])
  y = tablaDanos(doc, y, d.danos)
  y = seccion(doc, y + 2, 'Firmas')
  doc.setFont('helvetica', 'normal').setFontSize(8).setTextColor(...GRIS)
    .text(rec ? 'El conductor declara que devuelve el vehículo en el estado descrito en esta acta.'
              : 'El conductor declara que recibe el vehículo en el estado descrito en esta acta y queda a su cargo.', M, y + 2)
  const fc = { img: d.firmas.conductor, nombre: d.conductor.nombre, rol: `${rec ? 'Conductor que entrega' : 'Conductor que recibe'} · CI ${d.conductor.cedula}` }
  const fr = { img: d.firmas.responsable, nombre: d.responsable, rol: rec ? 'Recibe por la empresa' : 'Entrega por la empresa' }
  rec ? firmas(doc, y + 6, fc, fr) : firmas(doc, y + 6, fr, fc)
  pie(doc)
  return doc.output('blob')
}

// ======================================================== Orden de trabajo
export async function pdfOT(d: DocOT): Promise<Blob> {
  const doc = new jsPDF({ unit: 'mm', format: 'a4' })
  let y = await encabezado(doc, 'ORDEN DE TRABAJO', d.numero, d.empresa)
  y = datos(doc, y, [
    ['Estado', nombreEstado(d.estado)], ['Prioridad', d.prioridad.toUpperCase() + (d.inmovilizado ? ' · INMOVILIZADO' : '')], ['Conductor que lo trajo', d.conductor],
    ['Apertura', fechaHora(d.fecha_apertura)], ['Cierre', d.fecha_cierre ? fechaHora(d.fecha_cierre) : 'Abierta'], ['Tiempo parado', duracion(d.horas_parado)]
  ])
  y = seccion(doc, y, 'Vehículo')
  y = datos(doc, y, [...datosVehiculo(d.vehiculo), [d.vehiculo.unidad === 'horas' ? 'Horómetro' : 'Kilometraje', lectura(d.lectura, d.vehiculo.unidad)], ['Motivo', nombreMotivo(d.motivo)]], 3)
  y = seccion(doc, y, 'Falla reportada')
  y = parrafo(doc, y, d.falla)
  y = seccion(doc, y, 'Diagnóstico')
  y = parrafo(doc, y, d.diagnostico)
  y = seccion(doc, y, 'Trabajos')
  for (const l of d.lineas) {
    autoTable(doc, {
      startY: y, margin: { left: M, right: M }, styles: { fontSize: 8.5, cellPadding: 1.4 }, headStyles: { fillColor: [220, 225, 231], textColor: 0 },
      head: [[{ content: `${l.numero}. ${l.sistema} — ${l.descripcion}`, colSpan: 4 }]],
      body: [
        ['Tipo', l.tipo === 'preventivo' ? 'Preventivo' : 'Correctivo', 'Área / ejecutor', `${l.area} · ${l.ejecutor === 'tercero' ? 'Tercero' : 'Interno'}`],
        ['Técnico', l.tecnico || '—', 'Horas est. / reales', `${l.horas_estimadas ?? '—'} / ${l.horas_reales}`],
        ['Estado', nombreEstadoLinea(l.estado), 'Categoría', l.categoria]
      ],
      columnStyles: { 0: { textColor: GRIS, cellWidth: 26 }, 2: { textColor: GRIS, cellWidth: 32 } }
    })
    y = finTabla(doc) - 2
    if (l.repuestos.length) {
      autoTable(doc, {
        startY: y, margin: { left: M + 6, right: M }, styles: { fontSize: 8, cellPadding: 1.2 }, headStyles: { fillColor: [240, 242, 245], textColor: 0 },
        head: [['Código', 'Repuesto / insumo', 'Cant.', 'Unidad', 'Origen', 'Documento']],
        body: l.repuestos.map(r => [r.codigo, r.descripcion, r.cantidad, r.unidad, nombreOrigen(r.origen), r.documento])
      })
      y = finTabla(doc)
    } else y += 4
  }
  if (!d.lineas.length) y = parrafo(doc, y, 'Sin trabajos registrados.')
  y = seccion(doc, y, 'Historial de estados')
  autoTable(doc, { startY: y, margin: { left: M, right: M }, styles: { fontSize: 8, cellPadding: 1.2 }, headStyles: { fillColor: [220, 225, 231], textColor: 0 },
    head: [['Fecha y hora', 'De', 'A', 'Usuario', 'Comentario']],
    body: d.historial.map(h => [fechaHora(h.fecha_hora), h.estado_anterior ? nombreEstado(h.estado_anterior) : '—', nombreEstado(h.estado_nuevo), h.usuario, h.comentario]) })
  y = finTabla(doc)
  if (d.comentarios.length) {
    y = seccion(doc, y, 'Comentarios internos')
    autoTable(doc, { startY: y, margin: { left: M, right: M }, styles: { fontSize: 8, cellPadding: 1.2 }, headStyles: { fillColor: [220, 225, 231], textColor: 0 },
      head: [['Fecha y hora', 'Usuario', 'Comentario']], body: d.comentarios.map(c => [fechaHora(c.fecha_hora), c.usuario, c.texto]) })
  }
  pie(doc)
  return doc.output('blob')
}
