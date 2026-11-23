# SISTEMA DE GESTIÓN DEL TALLER — DISTRILÓGICO
Especificación unificada v1 (noviembre 2026). Reemplaza y amplía las especificaciones anteriores (sistema de OT y módulo de soldadura).

## 0. CONTEXTO Y PUNTO DE PARTIDA
- Taller interno de una flota de transporte pesado: cabezales (código DC), plataformas (DP/DR) y montacargas. También atiende unidades de clientes/terceros (centro de costo MNTOPL3RAS), a quienes se les factura cada cierto tiempo.
- Hay dos talleres: mecánica y soldadura (estructuras de carrocería). Comparten la orden de trabajo, pero se miden por separado.
- Hoy existen tres piezas que este sistema absorbe:
  1. Kardex de bodega (HTML + archivo inventario_datos.json en OneDrive). Ya está en uso. Su lógica (contables/extracontables, saldo inicial, movimientos, conteos a ciegas con aprobación por clave, cierre mensual, carga del kardex del sistema contable con costo promedio, preventivos con km de Hunter, compras, herramientas, pérdidas, reportes) se conserva tal cual y pasa a vivir en la base de datos. Hay que importar su JSON sin perder nada.
  2. Módulo de producción de soldadura diseñado por el coordinador (maqueta HTML). Se conserva su forma de trabajo: cápsulas por componente → elemento → intervención con tiempo estándar → cantidad, complejidad, técnicos y observación. También se conservan los imprevistos validados por el jefe de patio y los trabajos no realizados.
  3. Portal del técnico (maqueta HTML). Se conservan su historial y su producción estándar, con los alcances del rol Técnico (sección 2).
- El usuario no programa: todo debe configurarse desde pantallas (módulo Maestros), sin tocar código.

## 0.1 FORMATO VISUAL OBLIGATORIO: USAR LOS HTML DE REFERENCIA
En la carpeta referencias/ del repositorio están los tres archivos que definen cómo se ve y cómo se usa el sistema. No inventar otro diseño: replicar estos. Leerlos completos antes de construir cualquier pantalla.
- referencias/gestion_produccion_soldadura.html → base de los ambientes Soldadura y Mecánica y de la vista de trabajos de la OT. Copiar su diseño (colores, tipografía, encabezado con la franja roja, insignias de estado, tarjetas de indicadores, modales y avisos) y su forma de trabajo: grilla de cápsulas estilo "dock", flujo dentro de la cápsula (elemento → intervención con horas → datos), "Inspeccionado OK", menú de Novedades (imprevisto / no realizado), tabla resumen de trabajos y catálogo editable.
- referencias/portal_tecnico.html → lo que ve el Técnico: menú lateral de cápsulas, trabajos asignados, historial, producción estándar con selector diario/semanal/período 24-24 y gráfico, calendario y solicitud de vacaciones, contactos. Ajustar a los permisos del rol Técnico (sección 2).
- referencias/kardex_bodega.html → el módulo Inventarios completo y la pantalla de bodega. Mantener sus pestañas, tablas, ingreso rápido tipo Excel, filtros, tarjetas de indicadores y reportes. Su lógica de cálculo (saldos, cierre, conteos, costos, preventivos, Hunter) se traslada tal cual a la base de datos.
- Los módulos nuevos (OT por segmentos, Maestros, Gestión de personal) siguen el mismo estilo visual del archivo de soldadura, para que todo se vea como un solo sistema.
- Los datos de ejemplo que traen las maquetas (técnicos, plataformas, horas) son solo de muestra: en el sistema real todo sale de la base de datos y de Maestros.

## 1. TECNOLOGÍA
- Web, pensada para celular/tablet en el patio y PC en oficina y bodega.
- Base de datos Supabase (PostgreSQL estándar), fotos en Cloudflare R2, hosting en Cloudflare Pages. Todo en planes gratuitos.
- Login real con Supabase Auth. Los permisos se aplican en la base de datos (Row Level Security), no solo ocultando botones.
- Identificadores UUID, diccionario de datos actualizado y exportación completa (CSV, Excel, volcado SQL) para poder migrar a futuro.
- Auditoría: cada registro guarda quién lo creó o modificó y cuándo. Nada se borra físicamente: se marca como anulado.

## 2. USUARIOS Y PERMISOS
Los permisos van por rol y se pueden sumar permisos extra a una persona (ej. el domingo el supervisor de turno también hace de bodeguero).
- Maestro: todo. Crear, editar y anular en todos los módulos, gestionar usuarios y roles, maestros, parámetros, clave de aprobación de ajustes.
- Supervisor (asesor de servicios / jefe de patio): abrir OT, registrar la solicitud del chofer, registrar hallazgos, agregar trabajos de mecánica y soldadura, asignar técnicos, validar imprevistos, registrar trabajos no realizados, gestionar terceros, cerrar OT. Registrar asistencia y novedades del personal a su cargo.
- Bodega: ver la pantalla de OT abiertas, asignar repuestos a una OT (genera la salida en el kardex), devoluciones, y todo el módulo de Inventarios excepto aprobar ajustes.
- Técnico: buscar y ver las OT abiertas. Escribir observación de técnico solo en las OT donde está asignado su código. Ver su propio historial y producción estándar. Solicitar vacaciones y días libres. No ve costos.
- Permisos extra asignables a cualquier usuario: bodega, aprobar_ajustes (clave de aprobación del kardex), gestion_personal, ver_costos.
- El técnico no ve costos de repuestos, mano de obra ni terceros en ninguna pantalla.

## 3. LOS CINCO AMBIENTES (menú principal)
1. Soldadura: cápsulas de componentes estructurales.
2. Mecánica: el mismo formato de cápsulas, con sistemas mecánicos.
3. Inventarios: el kardex actual, integrado.
4. Maestros: catálogos, técnicos, vehículos, parámetros.
5. Gestión de personal: asistencia, novedades, días libres, vacaciones.
Además: Órdenes de trabajo (la lista y la OT completa por segmentos) y Tableros/Reportes.

### 3.1 Ambientes Soldadura y Mecánica (mismo motor, distinto catálogo)
- Se elige una OT abierta. La pantalla muestra las cápsulas del taller en una grilla.
  - Soldadura: compuertas, perfiles, travesaños, UPN, cabina, tanque de lixiviados, portallantas, escalerillas…
  - Mecánica: motor, sistema eléctrico, frenos, suspensión, dirección, embrague y caja, corona/diferencial, refrigeración, inyección y combustible, sistema neumático (aire), llantas, lubricación/preventivo…
- Clic en una cápsula abre su flujo: elemento → intervención (con horas estándar) → datos.
  - Datos: cantidad, complejidad (leve ×0,8, moderado ×1,0, grave ×1,4; multiplicadores editables en Maestros), técnicos asignados (uno o varios, de la lista de técnicos del taller), observación.
  - Reparto de horas entre técnicos: el tiempo estándar del catálogo son horas-hombre totales del trabajo. Si lo hacen varios técnicos, las horas se reparten en partes iguales por defecto (ej. trabajo de 2 h con 2 técnicos = 1 h a cada uno). El supervisor puede cambiar el reparto (ej. 70/30). Si un trabajo exige dos personas, su tiempo estándar se define en el catálogo ya multiplicado (ej. 4 horas-hombre).
  - Al agregar, el trabajo cae en el segmento de ese taller dentro de la OT (segmento 4 o 5).
- Botón "Inspeccionado OK" por cápsula: deja constancia de que se revisó sin novedades.
- Las cápsulas, elementos e intervenciones salen del catálogo de Maestros. Agregar un sistema nuevo en Maestros lo hace aparecer como cápsula, sin programar.
- Novedades de cada trabajo:
  - Imprevisto: técnico afectado, motivo de una lista editable más texto libre, minutos. Lo aprueba o rechaza el supervisor. Los imprevistos aprobados no le restan producción al técnico.
  - Trabajo no realizado: motivo obligatorio. Queda como pendiente de la unidad.

## 4. LA ORDEN DE TRABAJO (OT) POR SEGMENTOS
Numeración única OT-AAAA-00001. Una OT puede tener trabajos de mecánica, de soldadura o de ambos. Cada segmento se muestra como bloque plegable y con su propio estado.

Segmento 1. Vehículo y recepción
- Vehículo por código o placa: autocompleta tipo, marca, modelo, centro de costo, propio o rentado a cliente, y edad.
- Chofer (de Maestros), fecha y hora de ingreso, kilometraje (u horómetro en montacargas). Valida que no sea menor al último registrado y avisa si difiere mucho del km de Hunter.
- Combustible, checklist de recepción, diagrama de daños y fotos.
- Tipo de OT: Preventivo / Correctivo / Golpe-siniestro / Llantas / Fabricación / Renovado / Inspección.
- Si es fabricación para stock (ej. 5 portallantas), el vehículo es opcional.

Segmento 2. Solicitud del chofer
- Lo que el chofer reporta y el asesor de servicios recibe. Cada línea lleva su descripción y el taller sugerido (mecánica o soldadura).
- Cada línea termina atendida (se convierte en uno o más trabajos de los segmentos 4/5), no realizada (con motivo) o descartada (con motivo).

Segmento 3. Hallazgos en la revisión
- Trabajos que encontró el técnico en la revisión y que el chofer no había reportado.
- Los registra el supervisor. El técnico los anota en su propio espacio (segmento 8), sin modificar los trabajos.
- Cada hallazgo se aprueba o se descarta. Si se aprueba, pasa a trabajo del segmento 4 o 5 y queda marcado con origen "hallazgo".
- Indicador: cuántos trabajos salen de hallazgos frente a la solicitud del chofer.

Segmento 4. Trabajos de mecánica (gestión del jefe de patio con el técnico)
- Líneas creadas desde el ambiente Mecánica.
- Cada línea: sistema, elemento, intervención, cantidad, complejidad, técnicos, horas estándar calculadas, estado (pendiente / en proceso / terminado / no realizado), origen (chofer / hallazgo / preventivo) y causa.
- Observación del supervisor del segmento: espacio propio del supervisor/jefe de patio, separado de la observación del técnico (segmento 8). Lo mismo en el segmento 5.

Segmento 5. Trabajos de soldadura
- Igual que el 4, desde el ambiente Soldadura.
- Agrega: causa del daño (corrosión, golpe, fatiga, sobrecarga, desgaste, fabricación nueva, mejora), material base (inoxidable o hierro negro), fotos de antes y después en reparaciones y renovados.

Segmento 6. Repuestos e insumos (sección 5)

Segmento 7. Trabajos de terceros
- Trabajos enviados a talleres externos: proveedor (de Maestros), descripción, taller al que se carga (mecánica o soldadura), cotizaciones con cuadro comparativo y aprobación por monto, costo aprobado, n.º de OC, n.º de factura, garantía, fechas de salida y retorno.

Segmento 8. Observaciones de técnicos
- Solo los técnicos asignados a la OT pueden escribir aquí, con fecha, hora y código de técnico automáticos.
- No se editan ni se borran: si hay que corregir algo, se agrega otra observación.

Cierre de la OT
- Control de calidad: lo aprueba un usuario distinto al técnico.
- Acta de entrega.
- No se puede cerrar con trabajos en proceso ni con líneas del segmento 2 sin resolver.
- Calcula el tiempo de vehículo parado y el tiempo en cada estado.

Costos en la OT (solo para quien tenga ver_costos)
- Totales por segmento: repuestos de mecánica, repuestos de soldadura, terceros de mecánica, terceros de soldadura, mano de obra interna (horas estándar × tarifa de Maestros) y total de la OT.
- Las categorías de gasto de mecánica y soldadura nunca se mezclan. Mecánica alimenta el costo por km. Soldadura se mide por causa, edad de la plataforma y fabricar o comprar.

## 5. REPUESTOS: DE LA OT AL KARDEX SIN DOBLE TIPEO
Pantalla de bodega
- Tablero visual de OT abiertas: tarjetas con n.º de OT, móvil, tipo, antigüedad y si tiene repuestos pendientes.
- Flujo: el técnico pide el repuesto en ventanilla, el bodeguero lo registra y despacha. El técnico no registra nada en el sistema.
- El bodeguero abre la OT y agrega líneas:
  - artículo por código o nombre (mismo buscador del kardex actual, que muestra el saldo y si es contable o extracontable);
  - cantidad;
  - técnico que retira (lista de los técnicos asignados a la OT);
  - trabajo de la OT al que va el repuesto (lista de los trabajos de los segmentos 4 y 5). El taller (mecánica o soldadura) sale de ese trabajo.
- Si el repuesto no corresponde a un trabajo concreto, el bodeguero elige el taller a mano.

Cada línea asignada genera automáticamente la salida en el kardex, con:
- fecha, artículo, cantidad;
- OT, móvil y km tomados del segmento 1, para que el registro de componentes y preventivos (aceite, embrague, frenos, llantas, inyección, baterías) se alimente solo con el km correcto;
- usuario que despachó, y S3 vacío para completarlo después (el kardex ya controla las "salidas contables sin S3").
- Para los campos de componentes del kardex (motivo de cambio de llanta, kit de embrague, frenos, aceite, inyección): si el trabajo vinculado de la OT es de ese sistema, se llenan solos; si no, el bodeguero los elige.

Reglas de las líneas
- Si se corrige la cantidad, se actualiza la misma línea del kardex. Si se anula, la salida se anula.
- Devolución a bodega: genera una entrada vinculada a la misma OT y resta en la OT.
- Si el mes está cerrado en el kardex, no se permite modificar. Se respetan las mismas reglas de cierre y clave de aprobación del kardex actual.
- Aviso si la salida deja el saldo en negativo.

Costo en la OT
- Contables: cantidad × costo promedio ponderado vigente del artículo, que viene de la carga mensual del kardex del sistema contable (función que el kardex actual ya tiene: lee no_parte, costopmd, saldo).
- Cada línea guarda el costo usado. Cuando se carga el kardex del sistema de un mes, las líneas de OT de ese mes se recalculan con el nuevo costo promedio. Al cerrar el mes en el kardex, el costo queda fijo.
- Extracontables: no llevan costo. En la OT aparecen con la cantidad y la etiqueta "sin costo (extracontable)", y no suman al total.

## 6. MÓDULO INVENTARIOS
- Todo lo que hace hoy el kardex, con las mismas pestañas: resumen e indicadores; saldo inicial 1-ago (bloqueado); movimientos con ingreso rápido tipo Excel; saldo actual; registro de componentes y pronóstico; conteos a ciegas con aprobación; comparación mensual y cierre; compras, herramientas, pérdida de insumos, listas y ajustes.
- Diferencia: las salidas a vehículos nacen en la OT (sección 5). El ingreso manual de salidas queda solo para despachos sin OT (insumos de taller, consumibles generales) y exige motivo.
- Migración: botón para importar inventario_datos.json (todas sus colecciones: items, inicial, movs, compras, herr, perdidas, cierres, conteos, cambios, flota, recorrido, planes, tomas, tomaLineas, listas). Debe mantener los mismos saldos al centavo y mostrar un reporte de verificación (saldo por artículo antes y después).
- Se mantiene la carga del reporte de Hunter para los km diarios.
- La flota pasa a Maestros y la usan todos los módulos.

## 7. MÓDULO MAESTROS (solo Maestro; algunos catálogos editables por Supervisor si se le da permiso)
- Usuarios y roles (sección 2).
- Técnicos: código, nombre, especialidad (mecánica, soldadura o ambas), cargo, tarifa interna por hora, jornada (horas por día), estado (activo o inactivo), usuario vinculado.
- Vehículos: código, placa, tipo (cabezal, plataforma, montacarga), configuración, marca y modelo, mes y año de ingreso (para la edad), centro de costo, estado (activo, parado, venta, trámite) con fechas de parada.
  - Propiedad: propio o rentado a cliente (con el cliente; ej. DP1034).
  - Las OT de unidades rentadas usan el mismo formato, pero su gasto se carga al centro de costo MNTOPL3RAS, no entra al costo por km de la flota propia y sale en el reporte por cliente para conciliar y cobrar.
- Choferes.
- Catálogo de trabajos por taller: sistema/componente → elemento → intervención → horas estándar, si aplica complejidad, y el sistema preventivo al que pertenece (para alimentar el registro de componentes). Se puede agregar, editar y desactivar; nunca borrar si tiene uso.
- Multiplicadores de complejidad.
- Proveedores y talleres externos.
- Listas: causas de daño, motivos de imprevisto, motivos de no realizado, tipos de novedad de personal, checklist de recepción, checklists de control de calidad.
- Parámetros: intervalos preventivos (ya definidos en el kardex); días para considerar retrabajo (90); umbral renovado/nuevo (55 %); montos de aprobación de cotizaciones; período de producción (corte del 24 al 24).

## 8. MÓDULO GESTIÓN DE PERSONAL
- Asistencia diaria por técnico: estado del día (presente, falta, atraso, permiso, día libre, vacaciones, licencia médica, feriado); hora de entrada y salida opcionales; pantalla rápida por grupo y día para que el supervisor marque a todos en un minuto.
- Novedades de la jornada: tipo de una lista editable (permiso, capacitación, calamidad, llamado de atención, reconocimiento…), horas afectadas y comentario. Los imprevistos aprobados en las OT aparecen aquí también.
- Días libres y vacaciones:
  - se registran de dos formas: el técnico las solicita desde el sistema, o el supervisor/maestro las registra directamente (ya aprobadas);
  - lo que solicita el técnico queda pendiente hasta que lo apruebe o rechace el supervisor o el maestro;
  - registro con fechas, estado (solicitado, aprobado, rechazado) y quién aprobó;
  - saldo de vacaciones por técnico;
  - calendario compartido del taller con alerta si en un día se ausenta más de X técnicos del mismo taller.
- Horas disponibles: la asistencia da las horas presentes de cada técnico. Con eso se calcula la utilización = horas estándar producidas ÷ horas presentes, por técnico, taller y período.
- Los técnicos ven solo su propio calendario y saldo.

## 9. TABLEROS Y REPORTES
- Producción por técnico (portal del técnico): horas estándar, trabajos, imprevistos aprobados, utilización. Diario, semanal y período del 24 al 24.
- Taller: OT abiertas, atrasadas, tiempo de vehículo parado, trabajos no realizados, % de hallazgos, retrabajo, cumplimiento de fecha.
- Mecánica: costo por km (solo vehículos marcados para costo por km en el centro de costo), preventivos vencidos y próximos.
- Soldadura: gasto por causa, por zona y por edad de la plataforma, plataformas problema, fabricar o comprar.
- Bodega: los indicadores actuales del kardex.
- Clientes: insumos y trabajos por unidad rentada para la conciliación y el cobro.
- Todo exportable a Excel y PDF.

## 10. ORDEN DE CONSTRUCCIÓN (por fases, cada una usable sola)
1. Login, roles y permisos + Maestros (técnicos, vehículos, choferes, catálogos de mecánica y soldadura).
2. OT por segmentos + ambientes Mecánica y Soldadura (cápsulas) + observaciones de técnicos.
3. Inventarios: importar el JSON del kardex, verificar saldos, pantalla de bodega y salida automática desde la OT, costos en la OT.
4. Terceros con cotizaciones, control de calidad, acta de entrega, cierre de OT.
5. Gestión de personal.
6. Tableros y reportes; portal del técnico; directorio de contactos.
Antes de pasar de fase: datos de prueba, revisión con el usuario y respaldo exportado.

## 11. DECISIONES TOMADAS (23-nov-2026)
1. Hallazgos: los registra el supervisor (segmento 3, con su observación en los segmentos 4/5). El técnico escribe solo en su espacio (segmento 8).
2. Repuestos: el técnico pide en ventanilla; el bodeguero registra y despacha, indicando quién retira y a qué trabajo va.
3. Extracontables: aparecen sin costo en la OT.
4. Vacaciones: las puede solicitar el técnico y también registrarlas el supervisor/maestro.
5. Varios técnicos en un trabajo: el tiempo estándar son horas-hombre totales y se reparte entre ellos (por defecto en partes iguales).
6. Unidades rentadas a clientes: misma OT, marcadas como rentadas, con gasto al centro de costo MNTOPL3RAS y reporte por cliente.
7. Supervisor y jefe de patio son un solo rol.
8. El técnico no marca trabajos como terminados; lo hace el supervisor.
9. Reconocimientos: fuera del alcance por ahora.

## 12. DECISIONES DE LA FASE 1 (23-nov-2026)
- Se agrega el permiso extra `editar_catalogos` para cumplir la sección 7 ("algunos catálogos editables por Supervisor si se le da permiso").
- Catálogo: las intervenciones y la complejidad son del componente (cápsula), como en la maqueta del coordinador. Se cargó el catálogo de soldadura de la maqueta; Portallantas y Escalerillas, y las 12 cápsulas de mecánica, quedan vacías con el aviso "Sin intervenciones — agregar en Maestros".
- Preventivos: los 8 sistemas del kardex con sus intervalos actuales.
- Técnico: puede editar solo su teléfono y su contacto de emergencia.
- Las pantallas anteriores de OT y actas quedan fuera del menú hasta la Fase 2 (sus datos se conservan).
- Directorio de contactos: simple, con los técnicos de Maestros, en la Fase 6.
