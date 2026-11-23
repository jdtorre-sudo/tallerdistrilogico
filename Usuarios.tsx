import { useEffect, useState } from 'react'
import { supabase, ok, mensajeError } from '../lib/supabase'
import { useSesion, DOMINIO_INTERNO } from '../lib/sesion'
import { invalidarCatalogos } from '../lib/catalogos'
import { PERMISOS_EXTRA, ROLES } from '../lib/formato'
import type { PermisoExtra, Usuario } from '../lib/tipos'
import { Aviso, Campo, Cargando, Modal, Pildora, useToast } from '../components/ui'

async function llamarApi(cuerpo: Record<string, unknown>) {
  const { data } = await supabase.auth.getSession()
  const r = await fetch('/api/usuarios', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${data.session?.access_token}` }, body: JSON.stringify(cuerpo) })
  const j = await r.json().catch(() => ({ mensaje: 'El servidor no respondió. ¿Está configurada la función /api/usuarios en Cloudflare?' }))
  if (!r.ok) throw new Error(j.mensaje)
  return j.mensaje as string
}

/** Usuarios, roles y permisos extra (sección 2). Solo el maestro. */
export default function Usuarios() {
  const { perfil } = useSesion()
  const toast = useToast()
  const [lista, setLista] = useState<Usuario[] | null>(null)
  const [nuevo, setNuevo] = useState<{ usuario: string; nombre_completo: string; rol: string; clave: string; telefono: string } | null>(null)
  const [clave, setClave] = useState<{ u: Usuario; clave: string } | null>(null)
  const [error, setError] = useState('')

  const cargar = async () => setLista(ok(await supabase.from('usuarios').select('*').order('nombre_completo')) as Usuario[])
  useEffect(() => { cargar() }, [])
  if (!lista) return <Cargando />

  async function actualizar(u: Usuario, c: Partial<Usuario>, texto: string) {
    setError('')
    if (u.id === perfil?.id && ((c.rol && c.rol !== 'maestro') || c.activo === false)) { setError('No puede quitarse a sí mismo el rol de maestro ni desactivarse.'); return }
    const r = await supabase.from('usuarios').update(c).eq('id', u.id)
    if (r.error) setError(mensajeError(r.error)); else { toast('Usuario actualizado', texto); invalidarCatalogos(); cargar() }
  }
  const alternarPermiso = (u: Usuario, p: PermisoExtra) => {
    const tiene = (u.permisos_extra || []).includes(p)
    const permisos = tiene ? u.permisos_extra.filter(x => x !== p) : [...(u.permisos_extra || []), p]
    actualizar(u, { permisos_extra: permisos }, `${u.nombre_completo}: ${tiene ? 'se quitó' : 'se agregó'} el permiso “${PERMISOS_EXTRA.find(x => x.k === p)?.n}”.`)
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
        <div><h3 className="font-bold text-slate-800 text-sm md:text-base">Usuarios y roles</h3>
          <p className="text-xs text-slate-500 mt-0.5">Cada persona entra con su usuario y contraseña. El permiso se aplica en la base de datos, no solo en la pantalla.</p></div>
        <button className="btn-rojo" onClick={() => { setError(''); setNuevo({ usuario: '', nombre_completo: '', rol: 'tecnico', clave: '', telefono: '' }) }}><i className="fa-solid fa-user-plus" />Nuevo usuario</button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        {ROLES.map(r => <div key={r.k} className="bg-slate-50 p-3 rounded-2xl border border-slate-200 text-xs"><p className="font-extrabold text-industrial-navy">{r.n}</p><p className="text-slate-500 text-[11px]">{r.d}</p></div>)}
      </div>
      {error && <Aviso tipo="mal">{error}</Aviso>}

      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="overflow-x-auto custom-scrollbar">
          <table className="w-full text-left border-collapse text-xs md:text-sm">
            <thead><tr className="bg-slate-100/80 text-slate-600 uppercase tracking-wider font-semibold border-b border-slate-200 text-[11px]">
              <th className="py-3 px-4">Nombre</th><th className="py-3 px-4">Usuario</th><th className="py-3 px-4">Rol</th><th className="py-3 px-4">Permisos extra</th><th className="py-3 px-4">Estado</th><th className="py-3 px-4 text-center">Acciones</th>
            </tr></thead>
            <tbody className="divide-y divide-slate-100">
              {lista.map(u => (
                <tr key={u.id} className={'hover:bg-slate-50 ' + (u.activo ? '' : 'text-slate-400')}>
                  <td className="py-3 px-4 font-bold">{u.nombre_completo}</td>
                  <td className="py-3 px-4 font-mono text-[11px]">{u.correo.replace('@' + DOMINIO_INTERNO, '')}</td>
                  <td className="py-3 px-4">
                    <select aria-label={`Rol de ${u.nombre_completo}`} className="bg-white border border-slate-300 rounded-xl px-2 py-1.5 text-xs font-bold" value={u.rol}
                      onChange={e => actualizar(u, { rol: e.target.value as Usuario['rol'] }, `${u.nombre_completo} ahora es ${ROLES.find(r => r.k === e.target.value)?.n}.`)}>
                      {ROLES.map(r => <option key={r.k} value={r.k}>{r.n}</option>)}
                    </select>
                  </td>
                  <td className="py-3 px-4">
                    {u.rol === 'maestro' ? <span className="text-[11px] text-slate-400">Todos (maestro)</span> : (
                      <div className="flex flex-wrap gap-1">
                        {PERMISOS_EXTRA.map(p => {
                          const on = (u.permisos_extra || []).includes(p.k as PermisoExtra)
                          return <button key={p.k} title={p.d} onClick={() => alternarPermiso(u, p.k as PermisoExtra)}
                            className={'px-2 py-0.5 rounded-full text-[10px] font-bold border transition ' + (on ? 'bg-industrial-blue text-white border-industrial-blue' : 'bg-white text-slate-400 border-slate-200 hover:border-slate-400')}>
                            {on ? '✓ ' : '+ '}{p.n}</button>
                        })}
                      </div>
                    )}
                  </td>
                  <td className="py-3 px-4"><button onClick={() => actualizar(u, { activo: !u.activo }, `${u.nombre_completo} quedó ${u.activo ? 'inactivo' : 'activo'}.`)}><Pildora tipo={u.activo ? 'ok' : 'neutro'}>{u.activo ? 'Activo' : 'Inactivo'}</Pildora></button></td>
                  <td className="py-3 px-4 text-center">
                    <button className="p-1.5 bg-blue-50 text-industrial-blue hover:bg-blue-100 rounded-lg" title="Cambiar contraseña" onClick={() => setClave({ u, clave: '' })}><i className="fa-solid fa-key" /></button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      <p className="text-[11px] text-slate-500">Toque un permiso para sumarlo o quitarlo. Desactivar un usuario le impide ingresar; su historial se conserva. Si el usuario no lleva “@”, internamente se usa usuario@{DOMINIO_INTERNO}.</p>

      {nuevo && (
        <Modal titulo="Nuevo usuario" icono="fa-user-plus" onCerrar={() => setNuevo(null)}
          pie={<><button className="btn-gris" onClick={() => setNuevo(null)}>Cancelar</button><button className="btn-azul" type="submit" form="form-usuario">Crear usuario</button></>}>
          <form id="form-usuario" className="space-y-3" onSubmit={async e => {
            e.preventDefault(); setError('')
            try { toast('Usuario creado', await llamarApi({ accion: 'crear', ...nuevo })); setNuevo(null); cargar() } catch (err) { setError((err as Error).message) }
          }}>
            <Campo etiqueta="Usuario (ej. cmora) o correo"><input required className="campo-texto" autoCapitalize="none" value={nuevo.usuario} onChange={e => setNuevo({ ...nuevo, usuario: e.target.value })} /></Campo>
            <Campo etiqueta="Nombre completo"><input required className="campo-texto" value={nuevo.nombre_completo} onChange={e => setNuevo({ ...nuevo, nombre_completo: e.target.value })} /></Campo>
            <Campo etiqueta="Rol"><select className="campo-texto" value={nuevo.rol} onChange={e => setNuevo({ ...nuevo, rol: e.target.value })}>{ROLES.map(r => <option key={r.k} value={r.k}>{r.n}</option>)}</select></Campo>
            <Campo etiqueta="Celular"><input className="campo-texto" value={nuevo.telefono} onChange={e => setNuevo({ ...nuevo, telefono: e.target.value })} /></Campo>
            <Campo etiqueta="Contraseña inicial (mínimo 8)" ayuda="Entréguela en persona. Los permisos extra se suman después en la tabla."><input required minLength={8} className="campo-texto" value={nuevo.clave} onChange={e => setNuevo({ ...nuevo, clave: e.target.value })} /></Campo>
            {error && <Aviso tipo="mal">{error}</Aviso>}
          </form>
        </Modal>
      )}
      {clave && (
        <Modal titulo={`Cambiar contraseña · ${clave.u.nombre_completo}`} icono="fa-key" onCerrar={() => setClave(null)}
          pie={<><button className="btn-gris" onClick={() => setClave(null)}>Cancelar</button>
            <button className="btn-azul" disabled={clave.clave.length < 8} onClick={async () => { setError(''); try { toast('Contraseña cambiada', await llamarApi({ accion: 'clave', id: clave.u.id, clave: clave.clave })); setClave(null) } catch (err) { setError((err as Error).message) } }}>Guardar</button></>}>
          <Campo etiqueta="Nueva contraseña (mínimo 8)"><input className="campo-texto" minLength={8} value={clave.clave} onChange={e => setClave({ ...clave, clave: e.target.value })} /></Campo>
          {error && <Aviso tipo="mal">{error}</Aviso>}
        </Modal>
      )}
    </div>
  )
}
