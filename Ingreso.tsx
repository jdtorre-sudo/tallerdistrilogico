import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useSesion } from '../lib/sesion'
import { Aviso, Campo } from '../components/ui'

/** Pantalla de ingreso con el estilo de las maquetas (cabecera marina y franja roja). */
export default function Ingreso() {
  const { ingresar } = useSesion()
  const nav = useNavigate()
  const [usuario, setUsuario] = useState('')
  const [clave, setClave] = useState('')
  const [error, setError] = useState('')
  const [ocupado, setOcupado] = useState(false)
  return (
    <div className="min-h-screen bg-slate-100 flex flex-col antialiased">
      <header className="bg-industrial-navy border-b-4 border-industrial-red h-3" />
      <div className="flex-1 flex items-center justify-center p-4">
        <form className="bg-white rounded-3xl shadow-2xl w-full max-w-md overflow-hidden border border-slate-200" onSubmit={async e => {
          e.preventDefault(); setError(''); setOcupado(true)
          try { await ingresar(usuario, clave); nav('/') } catch (err) { setError((err as Error).message) } finally { setOcupado(false) }
        }}>
          <div className="bg-industrial-navy text-white px-6 py-5 flex items-center gap-3 border-b-4 border-industrial-red">
            <div className="bg-industrial-red p-2.5 rounded-2xl shadow-md w-12 h-12 flex items-center justify-center"><i className="fa-solid fa-truck-front text-xl" /></div>
            <div>
              <span className="text-[10px] uppercase tracking-widest text-slate-400 font-extrabold">DISTRILÓGICO S.A.</span>
              <h1 className="text-lg font-bold tracking-tight">Sistema de Gestión del Taller</h1>
            </div>
          </div>
          <div className="p-6 space-y-4">
            <p className="text-xs text-slate-500">Mecánica · Soldadura · Bodega · Personal</p>
            <Campo etiqueta="Usuario"><input id="usuario" className="campo-texto" autoComplete="username" autoCapitalize="none" placeholder="Ej. cmora" value={usuario} onChange={e => setUsuario(e.target.value)} required /></Campo>
            <Campo etiqueta="Contraseña"><input id="clave" className="campo-texto" type="password" autoComplete="current-password" value={clave} onChange={e => setClave(e.target.value)} required /></Campo>
            {error && <Aviso tipo="mal">{error}</Aviso>}
            <button className="btn-rojo w-full py-3 text-sm" disabled={ocupado}><i className="fa-solid fa-right-to-bracket" />{ocupado ? 'Ingresando…' : 'Ingresar'}</button>
          </div>
        </form>
      </div>
      <footer className="bg-slate-900 text-slate-400 text-xs py-4 text-center">DISTRILÓGICO S.A. © 2026 - Sistema Unificado de Talleres</footer>
    </div>
  )
}
