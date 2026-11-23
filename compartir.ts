import { telefonoWhatsApp } from './formato'

export function descargar(blob: Blob, nombre: string) {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = nombre; document.body.appendChild(a); a.click(); a.remove()
  setTimeout(() => URL.revokeObjectURL(url), 30000)
}

export function abrir(blob: Blob) {
  const url = URL.createObjectURL(blob)
  window.open(url, '_blank')
  setTimeout(() => URL.revokeObjectURL(url), 120000)
}

/**
 * Comparte el PDF. En celular/tablet abre el menú del sistema (WhatsApp, correo…)
 * con el archivo adjunto. En PC descarga el PDF y abre WhatsApp Web o el correo
 * con el mensaje listo para adjuntarlo.
 */
export async function compartir(blob: Blob, nombre: string, medio: 'whatsapp' | 'correo', texto: string, telefono?: string | null, correo?: string | null) {
  const archivo = new File([blob], nombre, { type: 'application/pdf' })
  const nav = navigator as Navigator & { canShare?: (d: unknown) => boolean }
  if (nav.canShare?.({ files: [archivo] })) {
    try { await navigator.share({ files: [archivo], title: nombre, text: texto }); return 'compartido' }
    catch (e) { if ((e as Error).name === 'AbortError') return 'cancelado' }
  }
  descargar(blob, nombre)
  if (medio === 'whatsapp') {
    const t = telefonoWhatsApp(telefono)
    window.open(`https://wa.me/${t || ''}?text=${encodeURIComponent(texto + ' (adjunto el PDF descargado)')}`, '_blank')
  } else {
    window.location.href = `mailto:${correo || ''}?subject=${encodeURIComponent(nombre.replace('.pdf', ''))}&body=${encodeURIComponent(texto + '\n\nAdjunto el PDF.')}`
  }
  return 'descargado'
}
