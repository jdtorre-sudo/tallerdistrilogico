// Exportación completa: todas las tablas en CSV y Excel, el diccionario de
// datos y el índice de archivos, dentro de un ZIP.
import JSZip from 'jszip'
import * as XLSX from 'xlsx'
import { supabase, ok, leerTodo } from './supabase'
import { hoyISO } from './formato'
import { descargar } from './compartir'

interface Campo { tabla: string; descripcion_tabla: string | null; orden: number; campo: string; tipo: string; obligatorio: boolean; significado: string | null }

function aCsv(filas: Record<string, unknown>[], columnas: string[]): string {
  const esc = (v: unknown) => {
    if (v === null || v === undefined) return ''
    const s = typeof v === 'object' ? JSON.stringify(v) : String(v)
    return /[",\n\r;]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
  }
  return '﻿' + [columnas.join(','), ...filas.map(f => columnas.map(c => esc(f[c])).join(','))].join('\r\n')
}

export async function diccionarioMarkdown(campos?: Campo[]): Promise<string> {
  campos ??= ok(await supabase.from('v_diccionario_datos').select('*')) as Campo[]
  const tablas = [...new Set(campos.map(c => c.tabla))]
  let md = `# Diccionario de datos · Sistema de taller Distrilógico\n\nGenerado automáticamente desde la base de datos el ${hoyISO()}.\n\n` +
    `Convenciones: todas las tablas tienen \`id\` (UUID), \`creado_en\`, \`creado_por\`, \`actualizado_en\`, \`actualizado_por\`. ` +
    `Fechas en zona America/Guayaquil (timestamptz). Km y horas numeric(10,1). Montos (solo cotizaciones) numeric(12,2) en USD. Códigos y placas como texto.\n\n`
  md += '## Tablas\n\n' + tablas.map(t => `- [\`${t}\`](#${t}) — ${campos!.find(c => c.tabla === t)?.descripcion_tabla || ''}`).join('\n') + '\n\n'
  for (const t of tablas) {
    const cs = campos.filter(c => c.tabla === t)
    md += `## ${t}\n\n${cs[0]?.descripcion_tabla || ''}\n\n| Campo | Tipo | Obligatorio | Significado |\n|---|---|---|---|\n`
    md += cs.map(c => `| \`${c.campo}\` | ${c.tipo} | ${c.obligatorio ? 'sí' : 'no'} | ${(c.significado || '').replace(/\|/g, '/')} |`).join('\n') + '\n\n'
  }
  return md
}

export async function exportacionCompleta(progreso: (t: string) => void): Promise<void> {
  progreso('Leyendo el diccionario de datos…')
  const campos = ok(await supabase.from('v_diccionario_datos').select('*')) as Campo[]
  const tablas = [...new Set(campos.map(c => c.tabla))]
  const zip = new JSZip()
  const libro = XLSX.utils.book_new()
  for (const [i, t] of tablas.entries()) {
    progreso(`Exportando ${t} (${i + 1} de ${tablas.length})…`)
    const cols = campos.filter(c => c.tabla === t).map(c => c.campo)
    let filas: Record<string, unknown>[] = []
    try { filas = await leerTodo(t, 'id') } catch { filas = [] }
    zip.file(`csv/${t}.csv`, aCsv(filas, cols))
    const hoja = XLSX.utils.json_to_sheet(filas.map(f => Object.fromEntries(cols.map(c => [c, typeof f[c] === 'object' && f[c] !== null ? JSON.stringify(f[c]) : f[c]]))), { header: cols })
    XLSX.utils.book_append_sheet(libro, hoja, t.slice(0, 31))
  }
  progreso('Armando el Excel…')
  zip.file('excel/base_completa.xlsx', XLSX.write(libro, { type: 'array', bookType: 'xlsx' }))
  zip.file('DICCIONARIO_DATOS.md', await diccionarioMarkdown(campos))
  zip.file('diccionario_datos.csv', aCsv(campos as unknown as Record<string, unknown>[], ['tabla', 'descripcion_tabla', 'orden', 'campo', 'tipo', 'obligatorio', 'significado']))
  const arch = await leerTodo<Record<string, unknown>>('archivos', 'ruta')
  zip.file('indice_archivos.csv', aCsv(arch, ['id', 'tipo', 'categoria', 'ruta', 'tipo_mime', 'bytes', 'tabla_origen', 'registro_origen_id', 'firmado_en', 'usuario_id', 'anulado']))
  zip.file('LEAME.txt', [
    'Exportación completa del sistema de taller Distrilógico',
    `Fecha: ${new Date().toISOString()}`, '',
    'csv/            Una tabla por archivo (UTF-8, separado por comas). Se abre en Excel o se importa en cualquier base de datos.',
    'excel/          Todas las tablas en un solo libro de Excel, una hoja por tabla.',
    'DICCIONARIO_DATOS.md  Qué significa cada tabla y cada campo.',
    'indice_archivos.csv   Ruta de cada firma o proforma dentro del almacenamiento ("archivos").', '',
    'El respaldo SQL completo (pg_dump), restaurable en cualquier PostgreSQL, se genera aparte y llega a la',
    'carpeta "Respaldos Taller Distrilogico" de Google Drive. Vea LEEME.md del repositorio para restaurarlo.'
  ].join('\r\n'))
  progreso('Comprimiendo…')
  const blob = await zip.generateAsync({ type: 'blob', compression: 'DEFLATE' })
  descargar(blob, `exportacion_taller_${hoyISO()}.zip`)
  progreso('Listo. El ZIP se descargó en su equipo.')
}

/** Pide a GitHub que haga el respaldo SQL (pg_dump) y lo suba a Google Drive. */
export async function solicitarRespaldoSql(): Promise<string> {
  const { data } = await supabase.auth.getSession()
  const r = await fetch('/api/respaldo', { method: 'POST', headers: { Authorization: `Bearer ${data.session?.access_token}` } })
  const j = await r.json().catch(() => ({ mensaje: 'Respuesta no válida del servidor.' }))
  if (!r.ok) throw new Error(j.mensaje || 'No se pudo solicitar el respaldo.')
  return j.mensaje
}
