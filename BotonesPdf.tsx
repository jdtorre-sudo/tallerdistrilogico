import { useState } from 'react'
import { cargarDocActa, cargarDocOT } from '../lib/documentos'
import { pdfActa, pdfOT } from '../lib/pdf'
import { abrir, compartir } from '../lib/compartir'
import { Aviso } from '../components/ui'

/** Botones para ver o compartir el PDF de un documento. El PDF se genera al momento. */
export default function BotonesPdf({ tipo, id, numero, telefono, correo }: { tipo: 'recepcion' | 'entrega' | 'ot'; id: string; numero: string; telefono?: string | null; correo?: string | null }) {
  const [ocupado, setOcupado] = useState(false)
  const [error, setError] = useState('')
  async function generar() {
    if (tipo === 'ot') { const d = await cargarDocOT(id); return { blob: await pdfOT(d), tel: telefono, texto: `Orden de trabajo ${d.numero} · ${d.vehiculo.codigo} ${d.vehiculo.placa}` } }
    const d = await cargarDocActa(tipo, id)
    return { blob: await pdfActa(d), tel: telefono ?? d.conductor.telefono, texto: `Acta de ${tipo === 'recepcion' ? 'recepción' : 'entrega'} ${d.numero} · ${d.vehiculo.codigo} ${d.vehiculo.placa}` }
  }
  async function hacer(accion: 'ver' | 'whatsapp' | 'correo') {
    setOcupado(true); setError('')
    try {
      const g = await generar()
      if (accion === 'ver') abrir(g.blob)
      else await compartir(g.blob, `${numero}.pdf`, accion, g.texto, g.tel, correo)
    } catch (e) { setError((e as Error).message) } finally { setOcupado(false) }
  }
  return (
    <div className="pila">
      <div className="botones-pdf">
        <button className="boton secundario" disabled={ocupado} onClick={() => hacer('ver')}>{ocupado ? 'Generando…' : `Ver PDF ${numero}`}</button>
        <button className="boton secundario" disabled={ocupado} onClick={() => hacer('whatsapp')}>WhatsApp</button>
        <button className="boton secundario" disabled={ocupado} onClick={() => hacer('correo')}>Correo</button>
      </div>
      {error && <Aviso tipo="mal">{error}</Aviso>}
    </div>
  )
}
