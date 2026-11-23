// Piezas visuales comunes. Copian el estilo de las maquetas de referencia:
// referencias/gestion_produccion_soldadura.html y referencias/portal_tecnico.html.
import { createContext, useCallback, useContext, useRef, useState, type ReactNode } from 'react'

type Tono = 'info' | 'ok' | 'alerta' | 'mal'

export function Campo({ etiqueta, children, ayuda, error, bloqueado }: { etiqueta: string; children: ReactNode; ayuda?: ReactNode; error?: string; bloqueado?: boolean }) {
  return (
    <div className="min-w-0">
      <label className="etiqueta">{etiqueta}{bloqueado && <span className="text-slate-400 normal-case"> 🔒</span>}</label>
      {children}
      {ayuda && <p className="text-[11px] text-slate-500 mt-1">{ayuda}</p>}
      {error && <p className="text-[11px] text-industrial-red font-semibold mt-1">{error}</p>}
    </div>
  )
}

/** Selector de opciones tipo "DIARIA / SEMANAL / MENSUAL" del portal del técnico. */
export function Segmentado({ opciones, valor, onChange }: { opciones: { k: string; n: string }[]; valor?: string; onChange: (k: string) => void }) {
  return (
    <div className="bg-slate-100 p-1.5 rounded-2xl flex items-center border border-slate-200 text-xs font-bold gap-1">
      {opciones.map(o => (
        <button type="button" key={o.k} onClick={() => onChange(o.k)}
          className={'flex-1 py-2 px-2 rounded-xl transition ' + (valor === o.k ? 'bg-industrial-navy text-white shadow-md' : 'text-slate-600 hover:text-slate-900')}>{o.n}</button>
      ))}
    </div>
  )
}

/** Botones de elección (como Leve / Moderado / Grave en la maqueta). */
export function Chips({ opciones, valor, onChange }: { opciones: { k: string; n: string }[]; valor?: string; onChange: (k: string) => void }) {
  return (
    <div className="flex flex-wrap gap-1.5">
      {opciones.map(o => (
        <button type="button" key={o.k} onClick={() => onChange(o.k)}
          className={'py-1.5 px-3 border rounded-xl text-xs font-bold transition-all ' + (valor === o.k ? 'bg-industrial-blue text-white border-industrial-blue shadow' : 'bg-slate-50 text-slate-700 border-slate-200 hover:bg-slate-100')}>{o.n}</button>
      ))}
    </div>
  )
}

const TONO_AVISO: Record<Tono, string> = {
  info: 'bg-blue-900/10 border-industrial-blue text-slate-700',
  ok: 'bg-emerald-50 border-emerald-500 text-emerald-900',
  alerta: 'bg-amber-50 border-amber-500 text-amber-900',
  mal: 'bg-red-50 border-industrial-red text-red-900'
}
const ICONO_AVISO: Record<Tono, string> = { info: 'fa-circle-info', ok: 'fa-circle-check', alerta: 'fa-triangle-exclamation', mal: 'fa-circle-xmark' }

/** Franja de aviso con borde izquierdo (banner de la maqueta). */
export function Aviso({ tipo = 'info', children }: { tipo?: Tono; children: ReactNode }) {
  return (
    <div className={`border-l-4 p-3.5 rounded-r-2xl text-xs flex items-start gap-2.5 ${TONO_AVISO[tipo]}`}>
      <i className={`fa-solid ${ICONO_AVISO[tipo]} text-base mt-0.5`} />
      <div className="min-w-0">{children}</div>
    </div>
  )
}

export function Cargando({ texto = 'Cargando…' }: { texto?: string }) {
  return <div className="py-12 text-center text-slate-400 text-xs font-bold"><i className="fa-solid fa-spinner fa-spin mr-2" />{texto}</div>
}

const TONO_INSIGNIA = {
  info: 'bg-blue-50 text-industrial-blue border-blue-200', ok: 'bg-emerald-50 text-emerald-600 border-emerald-200',
  alerta: 'bg-amber-50 text-amber-600 border-amber-200', mal: 'bg-red-50 text-industrial-red border-red-200',
  neutro: 'bg-slate-100 text-slate-500 border-slate-200', marino: 'bg-industrial-navy text-white border-industrial-navy'
}
export type TonoInsignia = keyof typeof TONO_INSIGNIA

/** Insignia de estado redondeada ("Pendiente", "Inspeccionado OK"…). */
export function Pildora({ tipo = 'info', children }: { tipo?: TonoInsignia; children: ReactNode }) {
  return <span className={`inline-block px-2.5 py-0.5 rounded-full text-[10px] font-bold border whitespace-nowrap ${TONO_INSIGNIA[tipo]}`}>{children}</span>
}

/** Título de sección como en el portal: ícono rojo, título marino y subtítulo. */
export function TituloSeccion({ icono, titulo, subtitulo, children }: { icono: string; titulo: ReactNode; subtitulo?: ReactNode; children?: ReactNode }) {
  return (
    <div className="border-b border-slate-200 pb-4 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
      <div className="min-w-0">
        <h2 className="text-lg font-extrabold text-industrial-navy flex items-center gap-2"><i className={`fa-solid ${icono} text-industrial-red`} /><span>{titulo}</span></h2>
        {subtitulo && <p className="text-xs text-slate-500 mt-0.5">{subtitulo}</p>}
      </div>
      {children && <div className="flex flex-wrap items-center gap-2">{children}</div>}
    </div>
  )
}

/** Tarjeta de indicador (KPI) de la maqueta de soldadura. */
export function Kpi({ titulo, valor, icono, tono = 'azul' }: { titulo: string; valor: ReactNode; icono: string; tono?: 'azul' | 'verde' | 'rojo' | 'ambar' }) {
  const c = { azul: 'bg-blue-50 text-industrial-blue', verde: 'bg-emerald-50 text-emerald-600', rojo: 'bg-red-50 text-industrial-red', ambar: 'bg-amber-50 text-amber-600' }[tono]
  return (
    <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-4 flex items-center justify-between">
      <div><p className="text-xs font-semibold text-slate-400 uppercase">{titulo}</p><h4 className="text-2xl font-black text-slate-800 mt-1">{valor}</h4></div>
      <div className={`p-3 rounded-2xl ${c}`}><i className={`fa-solid ${icono} text-xl w-6 text-center`} /></div>
    </div>
  )
}

/** Ventana modal con cabecera marina, como las de la maqueta. */
export function Modal({ titulo, icono = 'fa-pen-to-square', onCerrar, children, pie, ancho = 'max-w-md' }: {
  titulo: ReactNode; icono?: string; onCerrar: () => void; children: ReactNode; pie?: ReactNode; ancho?: string
}) {
  return (
    <div className="fixed inset-0 bg-slate-950/60 backdrop-blur-sm z-50 flex items-start sm:items-center justify-center p-4 overflow-y-auto" onMouseDown={e => { if (e.target === e.currentTarget) onCerrar() }}>
      <div className={`bg-white rounded-3xl shadow-2xl w-full ${ancho} overflow-hidden border border-slate-200 my-auto`} role="dialog">
        <div className="bg-industrial-navy text-white px-6 py-4 flex justify-between items-center">
          <h3 className="font-bold text-sm flex items-center gap-2"><i className={`fa-solid ${icono} text-industrial-red`} /><span>{titulo}</span></h3>
          <button type="button" onClick={onCerrar} className="text-slate-400 hover:text-white" aria-label="Cerrar"><i className="fa-solid fa-xmark" /></button>
        </div>
        <div className="p-6 space-y-4 text-xs max-h-[75vh] overflow-y-auto custom-scrollbar">{children}</div>
        {pie && <div className="bg-slate-50 px-6 py-3 border-t border-slate-200 flex flex-wrap justify-end gap-2">{pie}</div>}
      </div>
    </div>
  )
}

/** Botón que pide un motivo antes de anular (nada se borra). */
export function BotonAnular({ onAnular, texto = 'Anular' }: { onAnular: (motivo: string) => Promise<void> | void; texto?: string }) {
  const [abierto, setAbierto] = useState(false)
  const [motivo, setMotivo] = useState('')
  const [ocupado, setOcupado] = useState(false)
  if (!abierto) return <button type="button" className="btn-peligro" onClick={() => setAbierto(true)}>{texto}</button>
  return (
    <div className="flex flex-wrap gap-2 items-center">
      <input autoFocus className="campo-texto flex-1 min-w-[200px]" placeholder="Motivo de la anulación (obligatorio)" value={motivo} onChange={e => setMotivo(e.target.value)} />
      <button type="button" className="btn-rojo" disabled={motivo.trim().length < 3 || ocupado}
        onClick={async () => { setOcupado(true); try { await onAnular(motivo.trim()); setAbierto(false) } finally { setOcupado(false) } }}>Confirmar</button>
      <button type="button" className="btn-gris" onClick={() => setAbierto(false)}>Cancelar</button>
    </div>
  )
}

/** Mensaje en línea (franja de aviso) para errores o confirmaciones dentro de una pantalla. */
export function useMensaje() {
  const [msg, setMsg] = useState<{ tipo: Tono; texto: string } | null>(null)
  const vista = msg ? <Aviso tipo={msg.tipo}>{msg.texto}</Aviso> : null
  return { vista, ok: (t: string) => setMsg({ tipo: 'ok', texto: t }), mal: (t: string) => setMsg({ tipo: 'mal', texto: t }), limpiar: () => setMsg(null), setMsg }
}

// ------------------------------------------------------------------ Avisos flotantes (toast)
interface Toast { titulo: string; mensaje?: string; tipo: 'ok' | 'alerta' }
const CtxToast = createContext<(titulo: string, mensaje?: string, tipo?: 'ok' | 'alerta') => void>(() => undefined)
export const useToast = () => useContext(CtxToast)

/** Aviso flotante abajo a la derecha, como el de la maqueta (desaparece solo). */
export function ProveedorToast({ children }: { children: ReactNode }) {
  const [t, setT] = useState<Toast | null>(null)
  const [visible, setVisible] = useState(false)
  const temp = useRef<number>()
  const mostrar = useCallback((titulo: string, mensaje?: string, tipo: 'ok' | 'alerta' = 'ok') => {
    setT({ titulo, mensaje, tipo }); setVisible(true)
    window.clearTimeout(temp.current); temp.current = window.setTimeout(() => setVisible(false), 3500)
  }, [])
  return (
    <CtxToast.Provider value={mostrar}>
      {children}
      <div role="status" className={'fixed bottom-6 right-6 bg-slate-900 text-white px-5 py-3 rounded-2xl shadow-2xl z-[60] flex items-center gap-3 transition-all duration-300 border border-slate-700 max-w-sm ' + (visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-24 pointer-events-none')}>
        <i className={`fa-solid text-xl ${t?.tipo === 'alerta' ? 'fa-triangle-exclamation text-amber-400' : 'fa-check text-emerald-400'}`} />
        <div><h5 className="font-bold text-sm">{t?.titulo}</h5>{t?.mensaje && <p className="text-xs text-slate-300">{t.mensaje}</p>}</div>
      </div>
    </CtxToast.Provider>
  )
}
