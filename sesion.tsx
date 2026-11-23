import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { get, set, del } from 'idb-keyval'
import type { Session } from '@supabase/supabase-js'
import { supabase, mensajeError } from './supabase'
import type { Permiso, Rol, Usuario } from './tipos'

interface Sesion {
  cargando: boolean
  sesion: Session | null
  perfil: Usuario | null
  ingresar: (usuario: string, clave: string) => Promise<void>
  salir: () => Promise<void>
  /** ¿Tiene uno de estos roles? El maestro siempre puede. */
  puede: (...roles: Rol[]) => boolean
  /** ¿Tiene este permiso? Misma regla que tiene_permiso() en la base de datos. */
  tiene: (p: Permiso) => boolean
  esMaestro: boolean
}

/** Permisos que trae cada rol (igual que la función tiene_permiso de la base). */
const POR_ROL: Record<Rol, Permiso[]> = {
  maestro: [], supervisor: ['operar_ot', 'gestion_personal'], bodega: ['bodega'], tecnico: []
}
export function tienePermiso(u: Usuario | null, p: Permiso): boolean {
  if (!u || !u.activo) return false
  if (u.rol === 'maestro') return true
  return POR_ROL[u.rol]?.includes(p) || (u.permisos_extra || []).includes(p as never)
}

const Ctx = createContext<Sesion>(null as unknown as Sesion)
export const useSesion = () => useContext(Ctx)

/** Permite ingresar con "usuario" (sin @): se completa con el dominio interno. */
export const DOMINIO_INTERNO = 'taller.local'
export const correoDeUsuario = (u: string) => (u.includes('@') ? u.trim().toLowerCase() : `${u.trim().toLowerCase()}@${DOMINIO_INTERNO}`)

export function ProveedorSesion({ children }: { children: ReactNode }) {
  const [cargando, setCargando] = useState(true)
  const [sesion, setSesion] = useState<Session | null>(null)
  const [perfil, setPerfil] = useState<Usuario | null>(null)

  async function cargarPerfil(s: Session | null) {
    if (!s) { setPerfil(null); return }
    const r = await supabase.from('usuarios').select('*').eq('id', s.user.id).maybeSingle()
    if (r.data) { setPerfil(r.data as Usuario); await set('perfil', r.data).catch(() => undefined) }
    else {
      const guardado = await get<Usuario>('perfil').catch(() => undefined)
      setPerfil(guardado && guardado.id === s.user.id ? guardado : null)
    }
  }

  useEffect(() => {
    supabase.auth.getSession().then(async ({ data }) => {
      setSesion(data.session); await cargarPerfil(data.session); setCargando(false)
    })
    const { data } = supabase.auth.onAuthStateChange((_e, s) => {
      setSesion(s)
      if (_e === 'SIGNED_IN' || _e === 'SIGNED_OUT') cargarPerfil(s)
    })
    return () => data.subscription.unsubscribe()
  }, [])

  const valor: Sesion = {
    cargando, sesion, perfil,
    async ingresar(usuario, clave) {
      const r = await supabase.auth.signInWithPassword({ email: correoDeUsuario(usuario), password: clave })
      if (r.error) throw new Error(mensajeError(r.error))
    },
    async salir() {
      await supabase.auth.signOut().catch(() => undefined)
      await del('perfil').catch(() => undefined)
      setPerfil(null)
    },
    puede: (...roles) => !!perfil && perfil.activo && (perfil.rol === 'maestro' || roles.includes(perfil.rol)),
    tiene: p => tienePermiso(perfil, p),
    esMaestro: !!perfil && perfil.activo && perfil.rol === 'maestro'
  }
  return <Ctx.Provider value={valor}>{children}</Ctx.Provider>
}
