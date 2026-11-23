import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import * as XLSX from 'xlsx'
import { supabase, ok } from '../lib/supabase'
import { useSesion } from '../lib/sesion'
import { cargarCatalogos, type Catalogos } from '../lib/catalogos'
import { fechaHora, hoyISO, lectura, nombreMotivoActa } from '../lib/formato'
import { Aviso, BotonAnular, Cargando, Pildora } from '../components/ui'
import BotonesPdf from './BotonesPdf'

/** Lista de actas de entrega y de recepción (documentos independientes). */
export default function Actas() {
  const { tiene } = useSesion()
  const [cat, setCat] = useState<Catalogos | null>(null)
  const [filas, setFilas] = useState<any[] | null>(null)
  const [abierta, setAbierta] = useState<string | null>(null)
  const [f, setF] = useState({ tipo: '', texto: '', desde: '', hasta: '', anuladas: false })
  const [error, setError] = useState('')

  async function buscar() {
    setFilas(null)
    try {
      setCat(await cargarCatalogos())
      let q = supabase.from('v_actas').select('*').order('fecha_hora', { ascending: false }).limit(500)
      if (f.tipo) q = q.eq('tipo', f.tipo)
      if (f.desde) q = q.gte('fecha_hora', f.desde + 'T00:00:00-05:00')
      if (f.hasta) q = q.lte('fecha_hora', f.hasta + 'T23:59:59-05:00')
      if (!f.anuladas) q = q.eq('anulado', false)
      if (f.texto.trim()) { const t = f.texto.trim(); q = q.or(`codigo.ilike.%${t}%,placa.ilike.%${t}%,numero.ilike.%${t}%,conductor.ilike.%${t}%`) }
      setFilas(ok(await q))
    } catch (e) { setError((e as Error).message) }
  }
  useEffect(() => { buscar() }, [])

  async function anular(a: any, motivo: string) {
    const r = await supabase.from(a.tipo === 'recepcion' ? 'actas_recepcion' : 'actas_entrega').update({ anulado: true, anulado_motivo: motivo }).eq('id', a.id)
    if (r.error) setError(r.error.message); else buscar()
  }
  function exportar() {
    const datos = (filas || []).map(a => ({ Tipo: a.tipo === 'recepcion' ? 'Recepción' : 'Entrega', Numero: a.numero, Fecha: fechaHora(a.fecha_hora), Codigo: a.codigo, Placa: a.placa,
      Conductor: a.conductor, Responsable: cat?.usuarios.find(u => u.id === a.responsable_id)?.nombre_completo, Lectura: Number(a.lectura), Combustible: a.combustible,
      Motivo: nombreMotivoActa(a.motivo), Estado: a.estado, Anulada: a.anulado ? 'Sí' : 'No' }))
    const libro = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(libro, XLSX.utils.json_to_sheet(datos), 'Actas'); XLSX.writeFile(libro, `actas_${hoyISO()}.xlsx`)
  }

  return (
    <div className="pila">
      <div className="fila-entre"><h1>Actas de entrega y recepción</h1>
        {tiene('operar_ot') && <div className="fila">
          <Link className="boton" to="/actas/entrega">+ Acta de entrega</Link>
          <Link className="boton" to="/actas/recepcion">+ Acta de recepción</Link>
        </div>}
      </div>
      <form className="filtros" onSubmit={e => { e.preventDefault(); buscar() }}>
        <select value={f.tipo} onChange={e => setF({ ...f, tipo: e.target.value })}><option value="">Entregas y recepciones</option><option value="entrega">Solo entregas</option><option value="recepcion">Solo recepciones</option></select>
        <input placeholder="Código, placa, n.º o conductor" value={f.texto} onChange={e => setF({ ...f, texto: e.target.value })} />
        <label className="campo-chico">Desde<input type="date" value={f.desde} onChange={e => setF({ ...f, desde: e.target.value })} /></label>
        <label className="campo-chico">Hasta<input type="date" value={f.hasta} onChange={e => setF({ ...f, hasta: e.target.value })} /></label>
        <label className="interruptor"><input type="checkbox" checked={f.anuladas} onChange={e => setF({ ...f, anuladas: e.target.checked })} /> Incluir anuladas</label>
        <button className="boton">Buscar</button>
        <button type="button" className="boton secundario" onClick={exportar} disabled={!filas?.length}>Exportar a Excel</button>
      </form>
      {error && <Aviso tipo="mal">{error}</Aviso>}
      {!filas ? <Cargando /> : filas.length === 0 ? <p className="ayuda">No hay actas con esos filtros.</p> : filas.map(a => (
        <div key={a.tipo + a.id} className={'tarjeta pila' + (a.anulado ? ' anulada' : '')}>
          <button type="button" className="fila-entre boton-fila" onClick={() => setAbierta(abierta === a.id ? null : a.id)}>
            <span><Pildora tipo={a.tipo === 'entrega' ? 'info' : 'ok'}>{a.tipo === 'entrega' ? 'Entrega' : 'Recepción'}</Pildora> <b>{a.numero}</b> · <span className="codigo">{a.codigo}{a.placa ? ' · ' + a.placa : ''}</span></span>
            <span className="ayuda">{fechaHora(a.fecha_hora)}</span>
          </button>
          <span>{a.tipo === 'entrega' ? 'Recibe' : 'Entrega'}: <b>{a.conductor}</b> · {nombreMotivoActa(a.motivo)} · {lectura(a.lectura)} · combustible {a.combustible}
            {a.estado !== 'firmada' && <> · <Pildora tipo="alerta">Sin firmas</Pildora></>}{a.anulado && <> · <Pildora tipo="mal">Anulada: {a.anulado_motivo}</Pildora></>}</span>
          {abierta === a.id && (
            <div className="pila">
              {a.estado === 'firmada' && <BotonesPdf tipo={a.tipo} id={a.id} numero={a.numero} telefono={a.conductor_telefono} />}
              {tiene('operar_ot') && !a.anulado && <BotonAnular texto="Anular acta" onAnular={m => anular(a, m)} />}
            </div>
          )}
        </div>
      ))}
    </div>
  )
}
