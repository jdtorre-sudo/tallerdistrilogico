import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { cargarCatalogos, etiquetaVehiculo, nombreConductor, tipoDe, type Catalogos } from '../lib/catalogos'
import { agregarACola, borrarBorrador, enviarAhora, guardarBorrador, leerBorrador, type ItemCola } from '../lib/cola'
import { useSesion } from '../lib/sesion'
import { COMBUSTIBLE, MOTIVOS_ENTREGA, MOTIVOS_RECEPCION, fechaHora, lectura as fmtLectura, nombreMotivoActa, numero, uuid } from '../lib/formato'
import type { Dano, FilaChecklist, Vehiculo } from '../lib/tipos'
import BuscadorVehiculo from '../components/BuscadorVehiculo'
import Checklist, { checklistCompleto } from '../components/Checklist'
import DiagramaDanos from '../components/Diagrama'
import FirmaPad from '../components/FirmaPad'
import { Aviso, Campo, Cargando, Chips, Segmentado } from '../components/ui'
import BotonesPdf from './BotonesPdf'

type Tipo = 'entrega' | 'recepcion'
interface Borrador {
  id_local: string; fecha_hora: string; paso: number
  vehiculo_id?: string; conductor_id?: string; lectura?: string; combustible?: string; motivo?: string; observaciones?: string
  checklist: FilaChecklist[]; danos: Dano[]; firmaConductor: string; firmaResponsable: string
}
const nuevo = (): Borrador => ({ id_local: uuid(), fecha_hora: new Date().toISOString(), paso: 1, checklist: [], danos: [], firmaConductor: '', firmaResponsable: '' })
const PASOS = ['Vehículo', 'Checklist', 'Daños', 'Firmas']

/**
 * Acta de entrega (la empresa entrega el vehículo a un conductor) o acta de
 * recepción (la empresa recibe el vehículo de un conductor). Cada una es un
 * documento independiente: no depende de la otra ni de las órdenes de trabajo.
 */
export default function Acta({ tipo }: { tipo: Tipo }) {
  const { perfil, tiene } = useSesion()
  const rec = tipo === 'recepcion'
  const clave = 'acta-' + tipo
  const [cat, setCat] = useState<Catalogos | null>(null)
  const [b, setB] = useState<Borrador | null>(null)
  const [recuperado, setRecuperado] = useState(false)
  const [error, setError] = useState('')
  const [errorCarga, setErrorCarga] = useState('')
  const [enviando, setEnviando] = useState(false)
  const [final, setFinal] = useState<ItemCola | null>(null)

  useEffect(() => {
    cargarCatalogos().then(setCat).catch(e => setErrorCarga(e.message))
    leerBorrador<Borrador>(clave).then(d => { if (d) { setB(d); setRecuperado(true) } else setB(nuevo()) })
  }, [tipo])
  const cambiar = (c: Partial<Borrador>) => setB(prev => { const n = { ...prev!, ...c }; guardarBorrador(clave, n); return n })

  const veh: Vehiculo | undefined = cat?.vehiculos.find(v => v.id === b?.vehiculo_id)
  const tv = cat ? tipoDe(cat, veh) : undefined
  const items = useMemo(() => cat?.items.filter(i => i.activo && (!i.tipo_vehiculo_id || i.tipo_vehiculo_id === veh?.tipo_vehiculo_id)) || [], [cat, veh])

  if (!tiene('operar_ot')) return <Aviso tipo="alerta">Su usuario no puede registrar actas.</Aviso>
  if (errorCarga) return <Aviso tipo="mal">{errorCarga}</Aviso>
  if (!cat || !b) return <Cargando />
  if (final) return <Resultado item={final} tipo={tipo} reiniciar={() => { setFinal(null); setB(nuevo()) }} />

  const titulo = rec ? 'Acta de recepción' : 'Acta de entrega'
  const lect = Number(b.lectura)
  const asignado = cat.conductores.find(c => c.id === veh?.conductor_asignado_id)
  const conductor = cat.conductores.find(c => c.id === b.conductor_id)

  function validar(paso: number): string | null {
    if (paso === 1) {
      if (!veh) return 'Elija el vehículo.'
      if (!b!.conductor_id) return rec ? 'Elija el conductor que entrega el vehículo.' : 'Elija el conductor que recibe el vehículo.'
      if (!b!.lectura || isNaN(lect)) return `Escriba el ${tv?.unidad_medida === 'horas' ? 'horómetro' : 'kilometraje'}.`
      if (lect < Number(veh.lectura_actual)) return `La lectura no puede ser menor a la última registrada (${fmtLectura(veh.lectura_actual, tv?.unidad_medida)}).`
      if (!b!.combustible) return 'Elija el nivel de combustible.'
      if (!b!.motivo) return 'Elija el motivo.'
    }
    if (paso === 2) return checklistCompleto(items, b!.checklist)
    if (paso === 3 && b!.danos.some(d => !d.descripcion?.trim())) return 'Escriba la descripción de cada daño marcado.'
    if (paso === 4) {
      if (!b!.firmaConductor) return 'Falta la firma del conductor.'
      if (!b!.firmaResponsable) return 'Falta la firma del responsable de la empresa.'
    }
    return null
  }
  const avanzar = () => { const e = validar(b.paso); if (e) { setError(e); return } setError(''); cambiar({ paso: b.paso + 1 }); window.scrollTo(0, 0) }

  async function finalizar() {
    const e = validar(1) || validar(2) || validar(3) || validar(4); if (e) { setError(e); return }
    setEnviando(true); setError('')
    const item: ItemCola = {
      id_local: b!.id_local, tipo: rec ? 'acta_recepcion' : 'acta_entrega', creado: b!.fecha_hora, descripcion: etiquetaVehiculo(veh),
      carpeta: (veh!.placa || veh!.codigo).replace(/[^A-Za-z0-9-]/g, ''),
      payload: {
        id_local: b!.id_local, vehiculo_id: veh!.id, conductor_id: b!.conductor_id, fecha_hora: b!.fecha_hora, lectura: lect,
        combustible: b!.combustible, motivo: b!.motivo, observaciones: b!.observaciones || null, checklist: b!.checklist, danos: b!.danos
      },
      firmas: { a: b!.firmaConductor, b: b!.firmaResponsable }
    }
    await agregarACola(item)
    await borrarBorrador(clave)
    const r = await enviarAhora(item.id_local)
    setEnviando(false)
    setFinal(r || item)
  }

  const firmaConductor = <FirmaPad titulo={`${rec ? 'Conductor que entrega' : 'Conductor que recibe'} · ${nombreConductor(conductor)}`} valor={b.firmaConductor} onChange={v => cambiar({ firmaConductor: v })} />
  const firmaResponsable = <FirmaPad titulo={`${rec ? 'Recibe por la empresa' : 'Entrega por la empresa'} · ${perfil?.nombre_completo}`} valor={b.firmaResponsable} onChange={v => cambiar({ firmaResponsable: v })} />

  return (
    <div className="pila asistente">
      <div className="fila-entre">
        <h1>{titulo}</h1>
        <span className="ayuda">{fechaHora(b.fecha_hora)}</span>
      </div>
      <p className="ayuda">{rec ? 'La empresa recibe el vehículo que devuelve un conductor.' : 'La empresa entrega el vehículo a un conductor, que queda a su cargo.'}</p>
      <div className="pasos">{PASOS.map((p, i) => <button type="button" key={p} className={i + 1 <= b.paso ? 'hecho' : ''} onClick={() => i + 1 < b.paso && cambiar({ paso: i + 1 })}>{i + 1}. {p}</button>)}</div>
      {recuperado && b.vehiculo_id && (
        <Aviso tipo="info">Se recuperó el borrador de {etiquetaVehiculo(veh)}.{' '}
          <button type="button" className="boton chico" onClick={() => { borrarBorrador(clave); setB(nuevo()); setRecuperado(false) }}>Empezar de nuevo</button></Aviso>
      )}

      {b.paso === 1 && (
        <div className="pila">
          <Campo etiqueta="Vehículo (código o placa)">
            <BuscadorVehiculo cat={cat} valor={veh} onChange={v => cambiar({ vehiculo_id: v?.id, conductor_id: rec ? v?.conductor_asignado_id || undefined : undefined, checklist: [], danos: [] })} />
          </Campo>
          {veh && <span className="ayuda">Conductor asignado actualmente: <b>{asignado ? nombreConductor(asignado) : 'ninguno'}</b></span>}
          <Campo etiqueta={rec ? 'Conductor que entrega el vehículo' : 'Conductor que recibe el vehículo'}>
            <select id="conductor" value={b.conductor_id || ''} onChange={e => cambiar({ conductor_id: e.target.value })}>
              <option value="">— Elija —</option>
              {cat.conductores.filter(c => c.activo).map(c => <option key={c.id} value={c.id}>{nombreConductor(c)} · {c.cedula}</option>)}
            </select>
          </Campo>
          {!rec && asignado && b.conductor_id && asignado.id !== b.conductor_id && (
            <Aviso tipo="alerta">El vehículo está asignado a {nombreConductor(asignado)}. Al firmar esta acta quedará asignado a {nombreConductor(conductor)}.</Aviso>
          )}
          <Campo etiqueta={tv?.unidad_medida === 'horas' ? 'Horómetro (horas)' : 'Kilometraje'}
            ayuda={veh ? `Última lectura: ${fmtLectura(veh.lectura_actual, tv?.unidad_medida)}` : undefined}
            error={veh && b.lectura && lect < Number(veh.lectura_actual) ? 'Es menor a la última lectura registrada.' : undefined}>
            <input id="lectura" className="numero-grande" inputMode="decimal" value={b.lectura || ''} onChange={e => cambiar({ lectura: e.target.value.replace(',', '.').replace(/[^\d.]/g, '') })} placeholder={veh ? numero(veh.lectura_actual) : ''} />
          </Campo>
          {veh && b.lectura && lect - Number(veh.lectura_actual) > (tv?.unidad_medida === 'horas' ? 500 : 15000) && <Aviso tipo="alerta">La diferencia con la última lectura es de {numero(lect - Number(veh.lectura_actual))}. Verifique que esté bien escrita.</Aviso>}
          <Campo etiqueta="Combustible"><Segmentado opciones={COMBUSTIBLE.map(c => ({ k: c, n: c }))} valor={b.combustible} onChange={k => cambiar({ combustible: k })} /></Campo>
          <Campo etiqueta="Motivo"><Chips opciones={rec ? MOTIVOS_RECEPCION : MOTIVOS_ENTREGA} valor={b.motivo} onChange={k => cambiar({ motivo: k })} /></Campo>
          <Campo etiqueta={rec ? 'Novedades que reporta el conductor y observaciones (opcional)' : 'Observaciones (opcional)'}>
            <textarea id="obs" rows={3} value={b.observaciones || ''} onChange={e => cambiar({ observaciones: e.target.value })} />
          </Campo>
        </div>
      )}

      {b.paso === 2 && <Checklist items={items} valores={b.checklist} onChange={v => cambiar({ checklist: v })} />}

      {b.paso === 3 && tv && <DiagramaDanos diagrama={tv.diagrama} danos={b.danos} onChange={d => cambiar({ danos: d })} />}

      {b.paso === 4 && (
        <div className="pila">
          <div className="tarjeta">
            <strong>{etiquetaVehiculo(veh)}</strong> · {fmtLectura(lect, tv?.unidad_medida)} · combustible {b.combustible} · {nombreMotivoActa(b.motivo || '')}<br />
            <span className="ayuda">{rec ? 'Entrega' : 'Recibe'}: {nombreConductor(conductor)} · {b.checklist.filter(c => c.resultado !== 'ok').length} ítems con novedad · {b.danos.length} daños marcados</span>
          </div>
          {rec ? <>{firmaConductor}{firmaResponsable}</> : <>{firmaResponsable}{firmaConductor}</>}
          <span className="ayuda">{rec ? 'Al firmar, el conductor deja de tener asignado este vehículo.' : 'Al firmar, el vehículo queda asignado a este conductor.'}</span>
        </div>
      )}

      {error && <Aviso tipo="mal">{error}</Aviso>}
      <div className="acciones-fijas">
        {b.paso > 1 && <button type="button" className="boton secundario" onClick={() => { setError(''); cambiar({ paso: b.paso - 1 }) }}>← Atrás</button>}
        {b.paso < 4 && <button type="button" className="boton grande" onClick={avanzar}>Siguiente: {PASOS[b.paso]} →</button>}
        {b.paso === 4 && <button type="button" className="boton grande" disabled={enviando} onClick={finalizar}>{enviando ? 'Guardando…' : `Firmar ${titulo.toLowerCase()}`}</button>}
      </div>
    </div>
  )
}

function Resultado({ item, tipo, reiniciar }: { item: ItemCola; tipo: Tipo; reiniciar: () => void }) {
  const r = item.resultado
  const sinRed = !item.error || /conexión/.test(item.error)
  return (
    <div className="pila">
      {r ? (
        <>
          <Aviso tipo="ok"><b>{r.acta_numero}</b> firmada para {item.descripcion}.</Aviso>
          <BotonesPdf tipo={tipo} id={r.acta_id} numero={r.acta_numero} />
        </>
      ) : (
        <>
          <Aviso tipo={sinRed ? 'alerta' : 'mal'}>
            {sinRed
              ? <>El acta de {item.descripcion} quedó <b>guardada en este equipo</b>. Se enviará sola cuando haya señal; ahí recibirá su número.</>
              : <>No se pudo registrar el acta: <b>{item.error}</b>. Revise el detalle en “Por enviar”.</>}
          </Aviso>
          <Link className="boton" to="/pendientes">Ver pendientes por enviar</Link>
        </>
      )}
      <Link className="boton secundario" to="/actas">Ver todas las actas</Link>
      <button className="boton secundario" onClick={reiniciar}>Registrar otra acta de {tipo === 'recepcion' ? 'recepción' : 'entrega'}</button>
    </div>
  )
}
