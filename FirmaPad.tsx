import { useEffect, useRef } from 'react'
import SignaturePad from 'signature_pad'

/** Recuadro para firmar con el dedo. Devuelve la firma como PNG (dataURL) o '' si está vacía. */
export default function FirmaPad({ titulo, valor, onChange }: { titulo: string; valor: string; onChange: (png: string) => void }) {
  const lienzo = useRef<HTMLCanvasElement>(null)
  const pad = useRef<SignaturePad | null>(null)

  useEffect(() => {
    const c = lienzo.current!
    const ajustar = () => {
      const r = window.devicePixelRatio || 1
      const datos = pad.current && !pad.current.isEmpty() ? pad.current.toDataURL() : valor
      c.width = c.offsetWidth * r; c.height = c.offsetHeight * r
      c.getContext('2d')!.scale(r, r)
      pad.current?.clear()
      if (datos) pad.current?.fromDataURL(datos, { width: c.offsetWidth, height: c.offsetHeight })
    }
    pad.current = new SignaturePad(c, { penColor: '#0b1f4d', minWidth: 1.2, maxWidth: 3, backgroundColor: 'rgba(255,255,255,0)' })
    pad.current.addEventListener('endStroke', () => onChange(pad.current!.toDataURL('image/png')))
    ajustar()
    window.addEventListener('resize', ajustar)
    return () => { window.removeEventListener('resize', ajustar); pad.current?.off() }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return (
    <div className="firma">
      <div className="firma-cab"><span className="etiqueta">{titulo}</span>
        <button type="button" className="boton chico" onClick={() => { pad.current?.clear(); onChange('') }}>Borrar</button>
      </div>
      <canvas ref={lienzo} className={valor ? 'firmado' : ''} />
      {!valor && <span className="ayuda">Firme con el dedo dentro del recuadro.</span>}
    </div>
  )
}
