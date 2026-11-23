import { useEffect, useState } from 'react'
import { supabase, ok, mensajeError } from '../lib/supabase'
import { useSesion } from '../lib/sesion'
import { invalidarCatalogos } from '../lib/catalogos'
import { nombreTaller } from '../lib/formato'
import type { Tecnico } from '../lib/tipos'
import { Aviso, Cargando, TituloSeccion, useToast } from '../components/ui'

type Ficha = Tecnico & { telefono: string | null; contacto_emergencia: string | null }

/** Perfil del técnico (cápsula 1 del portal del técnico). Solo edita teléfono y contacto de emergencia. */
export default function MiPerfil() {
  const { perfil } = useSesion()
  const toast = useToast()
  const [ficha, setFicha] = useState<Ficha | null | undefined>(undefined)
  const [tel, setTel] = useState('')
  const [contacto, setContacto] = useState('')
  const [error, setError] = useState('')

  useEffect(() => {
    supabase.from('tecnicos').select('*').eq('usuario_id', perfil?.id || '').maybeSingle().then(r => {
      const f = r.data as Ficha | null
      setFicha(f); setTel(f?.telefono || ''); setContacto(f?.contacto_emergencia || '')
    })
  }, [perfil?.id])

  if (ficha === undefined) return <Cargando />
  const nombre = ficha?.nombres || perfil?.nombre_completo || ''
  const ini = nombre.split(/\s+/).slice(0, 2).map(p => p[0]).join('').toUpperCase()
  const bloqueado = (etq: string, valor: string) => (
    <div><label className="block font-bold text-slate-600 mb-1">{etq} <span className="text-slate-400">🔒</span></label>
      <input type="text" value={valor} disabled className="w-full bg-slate-100 border border-slate-300 rounded-xl px-3 py-2 font-medium text-slate-500 cursor-not-allowed" /></div>
  )

  return (
    <section className="space-y-6">
      <TituloSeccion icono="fa-id-card" titulo="Perfil del técnico" subtitulo="Información del colaborador y datos de contacto autorizados." />
      {!ficha ? <Aviso tipo="alerta">Su usuario todavía no está vinculado a una ficha de técnico. Pida al maestro que lo vincule en Maestros → Técnicos.</Aviso> : (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="bg-slate-50 p-6 rounded-3xl border border-slate-200 text-center flex flex-col items-center justify-center gap-3">
            <div className="w-24 h-24 rounded-full bg-industrial-navy text-white text-3xl font-black flex items-center justify-center border-4 border-industrial-red shadow-lg">{ini}</div>
            <div>
              <h3 className="font-extrabold text-slate-800 text-base">{nombre}</h3>
              <p className="text-xs text-industrial-blue font-semibold">{ficha.cargo || 'Técnico'}</p>
              <p className="text-[11px] text-slate-500 mt-1">Código de técnico: {ficha.codigo}</p>
            </div>
            <span className={'text-[10px] font-extrabold px-3 py-1 rounded-full border ' + (ficha.activo ? 'bg-emerald-100 text-emerald-800 border-emerald-200' : 'bg-slate-200 text-slate-600 border-slate-300')}>{ficha.activo ? 'ACTIVO' : 'INACTIVO'}</span>
          </div>
          <div className="md:col-span-2 space-y-4">
            <div className="bg-amber-50 border-l-4 border-amber-500 p-3.5 rounded-r-2xl text-xs text-amber-900 flex items-center gap-2.5">
              <i className="fa-solid fa-lock text-amber-600 text-base" />
              <span>Los campos marcados con 🔒 son datos laborales y solo los modifica el maestro en Maestros.</span>
            </div>
            <form className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs" onSubmit={async e => {
              e.preventDefault(); setError('')
              try {
                ok(await supabase.rpc('actualizar_mis_datos', { p_telefono: tel, p_contacto_emergencia: contacto }))
                invalidarCatalogos(); toast('Datos guardados', 'Sus datos de contacto se actualizaron correctamente.')
              } catch (err) { setError(mensajeError(err)) }
            }}>
              {bloqueado('Nombre completo', nombre)}
              {bloqueado('Cargo', ficha.cargo || '')}
              {bloqueado('Especialidad', nombreTaller(ficha.especialidad))}
              {bloqueado('Jornada (horas por día)', String(ficha.jornada_horas ?? ''))}
              <div><label className="block font-bold text-slate-600 mb-1">Teléfono móvil ✏️</label>
                <input id="mi-telefono" type="text" value={tel} onChange={e => setTel(e.target.value)} className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 font-bold text-slate-800 focus:border-industrial-blue focus:outline-none" /></div>
              <div><label className="block font-bold text-slate-600 mb-1">Contacto autorizado de emergencia ✏️</label>
                <input id="mi-contacto" type="text" value={contacto} placeholder="Ej. María Mora (esposa) - 0987654321" onChange={e => setContacto(e.target.value)} className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 font-bold text-slate-800 focus:border-industrial-blue focus:outline-none" /></div>
              {error && <div className="sm:col-span-2"><Aviso tipo="mal">{error}</Aviso></div>}
              <div className="sm:col-span-2 flex justify-end pt-2">
                <button type="submit" className="btn-rojo py-2.5 px-5"><i className="fa-solid fa-floppy-disk" />Guardar datos autorizados</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </section>
  )
}
