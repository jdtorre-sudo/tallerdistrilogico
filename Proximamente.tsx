import { useParams } from 'react-router-dom'
import { MENU } from '../lib/menu'
import { TituloSeccion } from '../components/ui'

/** Módulos de fases futuras: se ven en el menú y explican qué traerán. */
export default function Proximamente() {
  const { modulo } = useParams()
  const m = MENU.find(x => x.k === modulo)
  if (!m) return null
  return (
    <section className="space-y-6">
      <TituloSeccion icono={m.icono} titulo={m.n} subtitulo={`Llega en la Fase ${m.fase}.`} />
      <div className="py-16 text-center bg-slate-50 rounded-3xl border border-dashed border-slate-300 px-6">
        <i className={`fa-solid ${m.icono} text-slate-300 text-4xl mb-3`} />
        <h3 className="font-extrabold text-slate-700 text-sm">Este módulo se construye en la Fase {m.fase}</h3>
        <p className="text-xs text-slate-500 mt-2 max-w-xl mx-auto">{m.descripcion}</p>
      </div>
    </section>
  )
}
