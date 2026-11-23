import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { set } from 'idb-keyval'
import { leerCola, leerEnviados, procesarCola, useCola, type ItemCola } from '../lib/cola'
import { fechaHora } from '../lib/formato'
import { Aviso } from '../components/ui'

export default function Pendientes() {
  const { pendientes, enLinea } = useCola()
  const [enviados, setEnviados] = useState<ItemCola[]>([])
  const [ocupado, setOcupado] = useState(false)
  const [borrar, setBorrar] = useState<string | null>(null)
  useEffect(() => { leerEnviados().then(setEnviados) }, [pendientes.length])

  return (
    <div className="pila">
      <h1>Por enviar</h1>
      <Aviso tipo={enLinea ? 'ok' : 'alerta'}>{enLinea ? 'Hay conexión. Lo pendiente se envía automáticamente cada 20 segundos.' : 'Sin señal. Las actas quedan guardadas en este equipo y se enviarán solas al volver la conexión.'}</Aviso>
      {pendientes.length === 0 ? <p>No hay nada pendiente en este equipo.</p> : (
        <>
          <button className="boton grande" disabled={ocupado || !enLinea} onClick={async () => { setOcupado(true); await procesarCola(); setOcupado(false) }}>{ocupado ? 'Enviando…' : 'Enviar ahora'}</button>
          {pendientes.map(p => (
            <div key={p.id_local} className="tarjeta pila">
              <strong>{p.tipo === 'acta_recepcion' ? 'Acta de recepción' : p.tipo === 'acta_entrega' ? 'Acta de entrega' : 'Orden de trabajo'} · {p.descripcion}</strong>
              <span className="ayuda">Creada {fechaHora(p.creado)}{p.numero && p.tipo !== 'ot' ? ` · número asignado ${p.numero}, faltan las firmas` : ''}</span>
              {p.error && <Aviso tipo={/conexión/.test(p.error) ? 'alerta' : 'mal'}>{p.error}</Aviso>}
              {p.error && !/conexión/.test(p.error) && (borrar === p.id_local ? (
                <div className="fila"><span>¿Descartar esta acta? Se pierde lo registrado en el equipo.</span>
                  <button className="boton chico peligro" onClick={async () => { await set('cola-envios', (await leerCola()).filter(x => x.id_local !== p.id_local)); setBorrar(null); window.location.reload() }}>Sí, descartar</button>
                  <button className="boton chico" onClick={() => setBorrar(null)}>No</button></div>
              ) : <button className="boton chico peligro" onClick={() => setBorrar(p.id_local)}>Descartar</button>)}
            </div>
          ))}
        </>
      )}
      {enviados.length > 0 && <>
        <h2>Enviados recientemente desde este equipo</h2>
        {enviados.map(e => (
          <div key={e.id_local} className="tarjeta">
            <strong>{e.resultado?.acta_numero || e.resultado?.ot_numero}</strong> · {e.descripcion} · {fechaHora(e.creado)}
            {e.resultado?.ot_id && <> · <Link to={`/ot/${e.resultado.ot_id}`}>{e.resultado.ot_numero}</Link></>}
          </div>
        ))}
      </>}
    </div>
  )
}
