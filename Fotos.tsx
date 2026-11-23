import { useEffect, useRef, useState } from 'react'
import { leerFotos, subirFoto, urlFoto, type Foto } from '../lib/fotos'
import { useToast } from './ui'

function Miniatura({ f }: { f: Foto }) {
  const [url, setUrl] = useState<string | null>(null)
  const [mal, setMal] = useState(false)
  useEffect(() => { urlFoto(f.ruta).then(setUrl).catch(() => setMal(true)) }, [f.ruta])
  return (
    <a href={url || undefined} target="_blank" rel="noreferrer" className="block w-24 h-24 rounded-xl border border-slate-200 bg-slate-100 overflow-hidden flex items-center justify-center">
      {url ? <img src={url} alt={f.categoria} className="w-full h-full object-cover" /> : <i className={`fa-solid ${mal ? 'fa-image text-slate-300' : 'fa-spinner fa-spin text-slate-400'}`} />}
    </a>
  )
}

/** Fotos de un registro (recepción de la OT, o antes/después de un trabajo de soldadura). */
export default function Fotos({ tabla, registro, categoria, carpeta, puedeSubir, titulo }: {
  tabla: string; registro: string; categoria: string; carpeta: string; puedeSubir: boolean; titulo?: string
}) {
  const toast = useToast()
  const [fotos, setFotos] = useState<Foto[] | null>(null)
  const [subiendo, setSubiendo] = useState(false)
  const input = useRef<HTMLInputElement>(null)
  const cargar = () => leerFotos(tabla, [registro]).then(l => setFotos(l.filter(x => x.categoria === categoria))).catch(() => setFotos([]))
  useEffect(() => { cargar() }, [registro, categoria])

  return (
    <div className="space-y-2">
      {titulo && <p className="text-[11px] font-bold uppercase tracking-wider text-slate-500">{titulo}</p>}
      <div className="flex flex-wrap gap-2 items-center">
        {fotos?.map(f => <Miniatura key={f.id} f={f} />)}
        {fotos && !fotos.length && !puedeSubir && <span className="text-[11px] text-slate-400 italic">Sin fotos.</span>}
        {puedeSubir && (
          <button type="button" disabled={subiendo} onClick={() => input.current?.click()}
            className="w-24 h-24 rounded-xl border-2 border-dashed border-slate-300 hover:border-industrial-red text-slate-400 hover:text-industrial-red flex flex-col items-center justify-center gap-1 text-[10px] font-bold">
            <i className={`fa-solid ${subiendo ? 'fa-spinner fa-spin' : 'fa-camera'} text-lg`} />{subiendo ? 'Subiendo…' : 'Agregar foto'}
          </button>
        )}
      </div>
      <input ref={input} type="file" accept="image/*" capture="environment" multiple className="hidden" onChange={async e => {
        const archivos = [...(e.target.files || [])]; e.target.value = ''
        if (!archivos.length) return
        setSubiendo(true)
        try { for (const a of archivos) await subirFoto(a, { carpeta, categoria, tabla, registro }); toast('Foto guardada', `${archivos.length} foto(s) subidas.`); cargar() }
        catch (err) { toast('No se pudo subir', (err as Error).message, 'alerta') }
        finally { setSubiendo(false) }
      }} />
    </div>
  )
}
