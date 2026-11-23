import { useEffect, useState } from 'react'
import { supabase, ok, mensajeError } from '../lib/supabase'
import { fechaHora } from '../lib/formato'
import { Aviso, Campo, Pildora, useToast } from '../components/ui'
import { PantallaCatalogo } from './Catalogos'

/** Parámetros del sistema y clave de aprobación de ajustes (solo el maestro). */
export default function Parametros() {
  return (
    <div className="space-y-8">
      <ClaveAprobacion />
      <PantallaCatalogo tabla="configuracion" titulo="Parámetros" orden="clave" permiso="maestro" campoActivo="__"
        subtitulo="Días de retrabajo, umbral renovado/nuevo, montos de aprobación de cotizaciones, corte del período de producción, centro de costo de clientes, alertas de ausencias, preventivos y datos de la empresa para los PDF."
        campos={[{ k: 'clave', n: 'Parámetro', requerido: true }, { k: 'valor', n: 'Valor', requerido: true }, { k: 'descripcion', n: 'Descripción', tipo: 'parrafo' }]} />
    </div>
  )
}

function ClaveAprobacion() {
  const toast = useToast()
  const [estado, setEstado] = useState<{ definida: boolean; por?: string; en?: string } | null>(null)
  const [n1, setN1] = useState('')
  const [n2, setN2] = useState('')
  const [error, setError] = useState('')
  const cargar = () => supabase.rpc('estado_clave_aprobacion').then(r => setEstado(r.data as any))
  useEffect(() => { cargar() }, [])

  return (
    <div className="bg-slate-50 p-5 rounded-3xl border border-slate-200 space-y-4">
      <div className="flex flex-wrap justify-between items-center gap-2">
        <h4 className="font-bold text-slate-800 text-sm flex items-center gap-2"><i className="fa-solid fa-lock text-industrial-red" />Clave de aprobación de ajustes</h4>
        {estado && (estado.definida ? <Pildora tipo="ok">DEFINIDA</Pildora> : <Pildora tipo="mal">NO DEFINIDA</Pildora>)}
      </div>
      <p className="text-xs text-slate-600">La pide el kardex para aprobar conteos, ajustar el kardex al físico, cerrar o reabrir meses y modificar ajustes. Solo pueden usarla quienes tengan el permiso “Aprobar ajustes”. Se guarda cifrada: nadie puede verla, ni siquiera el maestro.</p>
      {estado?.definida && <p className="text-[11px] text-slate-500">Última vez definida por {estado.por || '—'} el {fechaHora(estado.en)}.</p>}
      <form className="grid grid-cols-1 sm:grid-cols-3 gap-3 items-end" onSubmit={async e => {
        e.preventDefault(); setError('')
        if (n1.length < 4) return setError('Use al menos 4 caracteres.')
        if (n1 !== n2) return setError('Las claves no coinciden.')
        try { ok(await supabase.rpc('fijar_clave_aprobacion', { p_nueva: n1 })); setN1(''); setN2(''); cargar(); toast('Clave guardada', 'La clave de aprobación de ajustes quedó definida.') }
        catch (err) { setError(mensajeError(err)) }
      }}>
        <Campo etiqueta={estado?.definida ? 'Nueva clave' : 'Clave'}><input id="clave-nueva" type="password" autoComplete="new-password" className="campo-texto" value={n1} onChange={e => setN1(e.target.value)} /></Campo>
        <Campo etiqueta="Repetir la clave"><input id="clave-repetir" type="password" autoComplete="new-password" className="campo-texto" value={n2} onChange={e => setN2(e.target.value)} /></Campo>
        <button className="btn-rojo py-2.5"><i className="fa-solid fa-key" />{estado?.definida ? 'Cambiar clave' : 'Definir clave'}</button>
      </form>
      {error && <Aviso tipo="mal">{error}</Aviso>}
    </div>
  )
}
