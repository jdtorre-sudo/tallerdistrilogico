# Diccionario de datos · Sistema de taller Distrilógico

Generado desde la base de datos (vista `v_diccionario_datos`). La app genera una versión siempre actualizada en **Maestros → Exportación y bitácora → Descargar diccionario de datos**.

**Convenciones:** todas las tablas tienen `id` (UUID), `creado_en`, `creado_por`, `actualizado_en`, `actualizado_por`. Los documentos y movimientos tienen `anulado`, `anulado_motivo`, `anulado_por`, `anulado_en`: nada se borra. Fechas `timestamptz` (se muestran en America/Guayaquil). Km y horas `numeric(10,1)`. Códigos y placas como texto.

**Permisos:** cada tabla tiene reglas de acceso (Row Level Security) por rol (maestro, supervisor, bodega, técnico) y permisos extra (bodega, aprobar_ajustes, gestion_personal, ver_costos, editar_catalogos). Ver `base_de_datos/007_unificada_fase1.sql`.

## Tablas

- [`actas_entrega`](#actas_entrega) — Acta de entrega: la empresa entrega (asigna) el vehículo a un conductor. Documento independiente.
- [`actas_recepcion`](#actas_recepcion) — Acta de recepción: la empresa recibe el vehículo de un conductor (cambio de conductor, vacaciones, fin de relación, ingreso a taller…). Documento independiente.
- [`archivos`](#archivos) — Índice de firmas y proformas. La base solo guarda la ruta, nunca el archivo.
- [`areas_taller`](#areas_taller) — Áreas que ejecutan trabajos.
- [`bitacora_auditoria`](#bitacora_auditoria) — Registro inalterable de quién hizo qué y cuándo.
- [`categorias_gasto`](#categorias_gasto) — Clasificación de cada trabajo (sin montos), para contar trabajos por categoría.
- [`centros_costo`](#centros_costo) — Centros de costo a los que se carga el gasto de los vehículos.
- [`checklist_entrega`](#checklist_entrega) — Resultado de cada ítem del checklist en el acta de entrega.
- [`checklist_recepcion`](#checklist_recepcion) — Resultado de cada ítem del checklist en el acta de recepción.
- [`clave_aprobacion`](#clave_aprobacion) — Clave de aprobación de ajustes del kardex, cifrada. Nadie la puede leer; se fija y se verifica con funciones.
- [`clientes`](#clientes) — Clientes a quienes se renta unidades o se atiende en el taller; se les factura cada cierto tiempo.
- [`comentarios_ot`](#comentarios_ot) — Segmento 8: observaciones de los técnicos asignados a la OT. No se editan ni se borran.
- [`complejidades`](#complejidades) — Multiplicadores de complejidad del tiempo estándar.
- [`conductores`](#conductores) — Conductores que entregan y reciben vehículos (sin usuario).
- [`configuracion`](#configuracion) — Parámetros ajustables sin tocar el programa.
- [`configuraciones_ejes`](#configuraciones_ejes) — Distribución de ejes y llantas.
- [`contadores_documento`](#contadores_documento) — Lleva la numeración correlativa por tipo y año.
- [`danos_vehiculo`](#danos_vehiculo) — Marcas del diagrama de daños registradas en un acta de entrega o de recepción.
- [`elementos`](#elementos) — Elementos de cada sistema/cápsula (ej. Compuertas → bisagra).
- [`historial_estados_ot`](#historial_estados_ot) — Cada cambio de estado de la OT. Sirve para medir el tiempo en cada estado.
- [`historial_estados_vehiculo`](#historial_estados_vehiculo) — Tramos de cada estado del vehículo (activo, parado, venta, trámite) con sus fechas. Lo llena el sistema.
- [`intervenciones`](#intervenciones) — Intervenciones de cada componente (cápsula), con su tiempo estándar en horas-hombre totales. Sirven para todos los elementos del componente.
- [`items_checklist`](#items_checklist) — Elementos y documentos del checklist de ingreso y salida.
- [`lineas_trabajo`](#lineas_trabajo) — Cada trabajo dentro de una OT.
- [`listas_valores`](#listas_valores) — Listas editables: causas de daño, motivos de imprevisto, de no realizado y de descarte, tipos de novedad de personal y checklists de control de calidad.
- [`ordenes_trabajo`](#ordenes_trabajo) — Orden de trabajo del taller. Se abre directamente al ingresar el vehículo; no depende de las actas.
- [`ot_checklist`](#ot_checklist) — Checklist de recepción de la OT (segmento 1).
- [`ot_hallazgos`](#ot_hallazgos) — Segmento 3: trabajos que se encontraron en la revisión y que el chofer no reportó. Los registra el supervisor.
- [`ot_imprevistos`](#ot_imprevistos) — Imprevistos durante el trabajo. Los aprobados no le restan producción al técnico.
- [`ot_inspecciones`](#ot_inspecciones) — “Inspeccionado OK” de cada cápsula en la OT: se revisó sin novedades.
- [`ot_solicitudes`](#ot_solicitudes) — Segmento 2: lo que reporta el chofer. Cada línea termina atendida, no realizada o descartada.
- [`ot_trabajo_tecnicos`](#ot_trabajo_tecnicos) — Técnicos de cada trabajo y reparto de las horas-hombre (por defecto en partes iguales).
- [`ot_trabajos`](#ot_trabajos) — Segmentos 4 (mecánica) y 5 (soldadura): cada trabajo registrado desde las cápsulas del ambiente.
- [`proveedores`](#proveedores) — Proveedores de repuestos y talleres externos (terceros).
- [`registros_horas`](#registros_horas) — Horas trabajadas por técnico. Base de la productividad.
- [`repuestos`](#repuestos) — Catálogo de repuestos importado desde Excel del otro sistema.
- [`repuestos_linea`](#repuestos_linea) — Repuestos e insumos usados. Sin montos.
- [`respaldos`](#respaldos) — Historial de respaldos semanales y manuales.
- [`sistemas`](#sistemas) — Sistemas o componentes de cada taller. Cada uno es una cápsula en los ambientes Mecánica y Soldadura.
- [`sistemas_preventivos`](#sistemas_preventivos) — Sistemas del registro de componentes y pronóstico del kardex, con sus intervalos. Son los “intervalos preventivos” de Parámetros.
- [`tarifas_tecnico`](#tarifas_tecnico) — Tarifa interna por hora de cada técnico, con su fecha de vigencia. Solo la ve quien tiene el permiso ver_costos.
- [`tecnicos`](#tecnicos) — Personal que ejecuta trabajos, con o sin usuario propio.
- [`tipos_vehiculo`](#tipos_vehiculo) — Cabezal, plataforma, recolector, montacargas.
- [`usuarios`](#usuarios) — Personas que ingresan al sistema (unas 15).
- [`vehiculos`](#vehiculos) — La flota.

## actas_entrega

Acta de entrega: la empresa entrega (asigna) el vehículo a un conductor. Documento independiente.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `numero` | text | sí | AE-2026-00001. |
| `id_local` | uuid | no | Identificador generado en la tablet; evita duplicados al sincronizar sin conexión. |
| `vehiculo_id` | uuid | sí | Vehículo. |
| `fecha_hora` | timestamptz | sí | Fecha y hora de la entrega. |
| `lectura` | numeric(10,1) | sí | Km u horómetro al entregar. |
| `combustible` | text | sí | E / 1/4 / 1/2 / 3/4 / F. |
| `conductor_id` | uuid | sí | Conductor que recibe el vehículo (queda asignado a él). |
| `entregado_por` | uuid | sí | Responsable de la empresa que entrega el vehículo. |
| `motivo` | text | sí | asignacion / cambio_conductor / reemplazo_temporal / salida_taller / otro. |
| `observaciones` | text | no | Observaciones de la entrega. |
| `firma_conductor_id` | uuid | no | PNG de la firma del conductor que recibe. |
| `firma_entrega_id` | uuid | no | PNG de la firma del responsable que entrega. |
| `estado` | text | sí | borrador / firmada. La anulación va en la columna anulado. |
| `anulado` | boolean | sí | Sí = registro anulado (no se borra). |
| `anulado_motivo` | text | no | Motivo de la anulación (obligatorio al anular). |
| `anulado_por` | uuid | no | Usuario que anuló. |
| `anulado_en` | timestamptz | no | Fecha y hora de la anulación. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## actas_recepcion

Acta de recepción: la empresa recibe el vehículo de un conductor (cambio de conductor, vacaciones, fin de relación, ingreso a taller…). Documento independiente.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `numero` | text | sí | AR-2026-00001. |
| `id_local` | uuid | no | Identificador generado en la tablet; evita duplicados al sincronizar sin conexión. |
| `vehiculo_id` | uuid | sí | Vehículo. |
| `conductor_id` | uuid | sí | Conductor que devuelve (entrega) el vehículo a la empresa. |
| `recibido_por` | uuid | sí | Responsable de la empresa que recibe el vehículo. |
| `fecha_hora` | timestamptz | sí | Automática al iniciar. |
| `lectura` | numeric(10,1) | sí | Km u horómetro al recibir. |
| `lectura_hunter` | numeric(10,1) | no | Km estimado por Hunter en ese momento (referencia). |
| `combustible` | text | sí | E / 1/4 / 1/2 / 3/4 / F. |
| `motivo` | text | sí | cambio_conductor / vacaciones_permiso / fin_relacion / ingreso_taller / siniestro / otro. |
| `observaciones` | text | no | Novedades que reporta el conductor y observaciones de quien recibe. |
| `firma_conductor_id` | uuid | no | PNG de la firma. |
| `firma_recibe_id` | uuid | no | PNG de la firma. |
| `estado` | text | sí | borrador / firmada. La anulación va en la columna anulado. |
| `anulado` | boolean | sí | Sí = registro anulado (no se borra). |
| `anulado_motivo` | text | no | Motivo de la anulación (obligatorio al anular). |
| `anulado_por` | uuid | no | Usuario que anuló. |
| `anulado_en` | timestamptz | no | Fecha y hora de la anulación. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## archivos

Índice de firmas y proformas. La base solo guarda la ruta, nunca el archivo.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `tipo` | text | sí | firma / proforma. |
| `categoria` | text | sí | firma_conductor / firma_recibe / firma_entrega / proforma. |
| `ruta` | text | sí | Ruta estándar: 2026/10/GSA-4512/AR-2026-00142/firma_conductor.png |
| `tipo_mime` | text | sí | image/png, image/webp, application/pdf. |
| `bytes` | integer | no | Tamaño. |
| `tabla_origen` | text | sí | Tabla dueña del archivo. |
| `registro_origen_id` | uuid | sí | Registro dueño del archivo. |
| `firmado_en` | timestamptz | sí | Fecha y hora de la firma o de la carga. |
| `usuario_id` | uuid | no | Usuario que registró. |
| `anulado` | boolean | sí | Sí = registro anulado (no se borra). |
| `anulado_motivo` | text | no | Motivo de la anulación (obligatorio al anular). |
| `anulado_por` | uuid | no | Usuario que anuló. |
| `anulado_en` | timestamptz | no | Fecha y hora de la anulación. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## areas_taller

Áreas que ejecutan trabajos.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `nombre` | text | sí | Mecánico, Soldadura (internas); Lavadora, Talleres externos (externas). |
| `es_externo` | boolean | sí | Sí = el trabajo lo hace un proveedor. |
| `requiere_cotizacion` | boolean | sí | Sí = se pide cotización antes de enviar (Talleres externos). No en Lavadora. |
| `orden` | integer | sí | Orden en listas. |
| `activo` | boolean | sí | Visible en listas. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## bitacora_auditoria

Registro inalterable de quién hizo qué y cuándo.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `tabla` | text | sí | Tabla afectada. |
| `registro_id` | uuid | no | Registro afectado. |
| `accion` | text | sí | crear / modificar / anular / cambio_estado / aprobar / exportar. |
| `datos_antes` | jsonb | no | Valores antes del cambio. |
| `datos_despues` | jsonb | no | Valores después del cambio. |
| `usuario_id` | uuid | no | Quién lo hizo. |
| `fecha_hora` | timestamptz | sí | Cuándo. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## categorias_gasto

Clasificación de cada trabajo (sin montos), para contar trabajos por categoría.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `nombre` | text | sí | Mantenimiento Preventivo, Mantenimiento Correctivo, Insumos, Llantas, Otros. |
| `grupo` | text | sí | Mantenimiento / Insumos / Llantas / Otros. |
| `orden` | integer | sí | Orden en reportes. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## centros_costo

Centros de costo a los que se carga el gasto de los vehículos.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `codigo` | text | sí | Código contable, ej. MNTOPL3RAS. |
| `nombre` | text | sí | Nombre descriptivo. |
| `costo_por_km` | boolean | sí | Sí = sus vehículos entran al reporte de costo por km de mecánica. |
| `es_clientes` | boolean | sí | Sí = centro de las unidades rentadas a clientes (se concilia y cobra). |
| `activo` | boolean | sí | No = ya no se usa. Nunca se borra. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## checklist_entrega

Resultado de cada ítem del checklist en el acta de entrega.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `acta_entrega_id` | uuid | sí | Acta. |
| `item_checklist_id` | uuid | sí | Ítem. |
| `resultado` | text | sí | ok / falta / danado. |
| `observacion` | text | no | Obligatoria si no es ok. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## checklist_recepcion

Resultado de cada ítem del checklist en el acta de recepción.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `acta_recepcion_id` | uuid | sí | Acta. |
| `item_checklist_id` | uuid | sí | Ítem. |
| `resultado` | text | sí | ok / falta / danado. |
| `observacion` | text | no | Obligatoria si no es ok. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## clave_aprobacion

Clave de aprobación de ajustes del kardex, cifrada. Nadie la puede leer; se fija y se verifica con funciones.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `clave_cifrada` | text | sí | Clave cifrada con bcrypt (pgcrypto). |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## clientes

Clientes a quienes se renta unidades o se atiende en el taller; se les factura cada cierto tiempo.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `nombre` | text | sí | Razón social o nombre. |
| `ruc` | text | no | RUC o cédula. |
| `contacto` | text | no | Persona de contacto. |
| `telefono` | text | no | Teléfono de contacto. |
| `correo` | text | no | Correo para enviar la conciliación. |
| `observaciones` | text | no | Notas libres. |
| `activo` | boolean | sí | No = ya no se atiende. Nunca se borra. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## comentarios_ot

Segmento 8: observaciones de los técnicos asignados a la OT. No se editan ni se borran.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `orden_trabajo_id` | uuid | sí | OT. |
| `usuario_id` | uuid | no | Autor. |
| `fecha_hora` | timestamptz | sí | Cuándo. |
| `texto` | text | sí | Comentario. |
| `anulado` | boolean | sí | Sí = registro anulado (no se borra). |
| `anulado_motivo` | text | no | Motivo de la anulación (obligatorio al anular). |
| `anulado_por` | uuid | no | Usuario que anuló. |
| `anulado_en` | timestamptz | no | Fecha y hora de la anulación. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |
| `tecnico_id` | uuid | no | Técnico que escribió (se pone solo con su código). |

## complejidades

Multiplicadores de complejidad del tiempo estándar.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `codigo` | text | sí | leve / moderado / grave. |
| `nombre` | text | sí | Nombre visible. |
| `multiplicador` | numeric(4,2) | sí | Factor que multiplica las horas estándar (ej. 0,8 / 1,0 / 1,4). |
| `orden` | integer | sí | Orden en la pantalla. |
| `activo` | boolean | sí | No = no se ofrece. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## conductores

Conductores que entregan y reciben vehículos (sin usuario).

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `cedula` | text | sí | Cédula. |
| `nombres` | text | sí | Nombres. |
| `apellidos` | text | sí | Apellidos. |
| `telefono` | text | no | Celular para enviar el acta por WhatsApp. |
| `correo` | text | no | Opcional. |
| `tipo_licencia` | text | no | C, D, E… |
| `licencia_vence` | date | no | Vencimiento de la licencia. |
| `activo` | boolean | sí | Disponible. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## configuracion

Parámetros ajustables sin tocar el programa.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `clave` | text | sí | Nombre del parámetro: limite_aprobacion_jefe, tolerancia_factura_pct, iva_pct, umbral_labrado_mm, dias_max_llanta, diferencia_max_hunter_km. |
| `valor` | text | sí | Valor actual, por ejemplo 300, 10, 15, 4, 365, 500. |
| `tipo_dato` | text | sí | numero / texto / si_no. Sirve para validar al editar. |
| `descripcion` | text | no | Explicación para el administrador. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## configuraciones_ejes

Distribución de ejes y llantas.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `nombre` | text | sí | Ej.: Cabezal 6x4, Plataforma 4x2, Recolector 6x4. |
| `numero_ejes` | integer | sí | Cantidad de ejes. |
| `numero_llantas` | integer | sí | Llantas montadas, sin contar el repuesto. |
| `descripcion` | text | no | Notas. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## contadores_documento

Lleva la numeración correlativa por tipo y año.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `tipo_documento` | text | sí | AR, AE, OT o SC. |
| `anio` | integer | sí | Año del contador (2026). |
| `ultimo_numero` | integer | sí | Último número usado. El siguiente sale de sumar 1 de forma segura, sin saltos ni repetidos. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## danos_vehiculo

Marcas del diagrama de daños registradas en un acta de entrega o de recepción.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `vehiculo_id` | uuid | sí | Vehículo. |
| `acta_recepcion_id` | uuid | no | Acta de recepción donde se registró (si aplica). |
| `acta_entrega_id` | uuid | no | Acta de entrega donde se registró (si aplica). |
| `numero_marca` | integer | sí | N.º visible en el dibujo. |
| `vista` | text | sí | frontal / posterior / izquierda / derecha. |
| `posicion_x` | numeric(5,4) | sí | Horizontal de 0 a 1 (independiente del tamaño de pantalla). |
| `posicion_y` | numeric(5,4) | sí | Vertical de 0 a 1. |
| `tipo_dano` | text | sí | golpe / rayon / rotura / oxidacion / otro. |
| `descripcion` | text | no | Detalle escrito del daño. |
| `situacion` | text | sí | registrado / reparado. |
| `anulado` | boolean | sí | Sí = registro anulado (no se borra). |
| `anulado_motivo` | text | no | Motivo de la anulación (obligatorio al anular). |
| `anulado_por` | uuid | no | Usuario que anuló. |
| `anulado_en` | timestamptz | no | Fecha y hora de la anulación. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |
| `orden_trabajo_id` | uuid | no | OT en la que se marcó el daño (recepción). |

## elementos

Elementos de cada sistema/cápsula (ej. Compuertas → bisagra).

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `sistema_id` | uuid | sí | Sistema o cápsula al que pertenece. |
| `nombre` | text | sí | Nombre del elemento. |
| `orden` | integer | sí | Orden en la pantalla. |
| `activo` | boolean | sí | No = ya no aparece para nuevos trabajos. Nunca se borra. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## historial_estados_ot

Cada cambio de estado de la OT. Sirve para medir el tiempo en cada estado.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `orden_trabajo_id` | uuid | sí | OT. |
| `estado_anterior` | text | no | Estado de donde sale. |
| `estado_nuevo` | text | sí | Estado al que entra. |
| `fecha_hora` | timestamptz | sí | Cuándo. |
| `usuario_id` | uuid | no | Quién. |
| `comentario` | text | no | Opcional. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## historial_estados_vehiculo

Tramos de cada estado del vehículo (activo, parado, venta, trámite) con sus fechas. Lo llena el sistema.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `vehiculo_id` | uuid | sí | Vehículo. |
| `estado` | text | sí | Estado en ese tramo. |
| `desde` | date | sí | Inicio del tramo. |
| `hasta` | date | no | Fin del tramo (vacío = estado actual). |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## intervenciones

Intervenciones de cada componente (cápsula), con su tiempo estándar en horas-hombre totales. Sirven para todos los elementos del componente.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `sistema_id` | uuid | sí | Componente (cápsula) al que pertenece. |
| `nombre` | text | sí | Nombre de la intervención (ej. Resoldar, Enderezar, Reponer). |
| `horas_estandar` | numeric(7,3) | sí | Horas-hombre totales del trabajo (3 decimales: 5 min = 0,083 h). Si exige dos personas, ya viene multiplicado. |
| `sistema_preventivo_id` | uuid | no | Sistema preventivo que alimenta en el registro de componentes (opcional). |
| `orden` | integer | sí | Orden en la pantalla. |
| `activo` | boolean | sí | No = ya no aparece para nuevos trabajos. Nunca se borra. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |
| `codigo` | text | no | Código del trabajo en el tempario (opcional). |
| `grupo` | text | no | Sub-categoría dentro de la cápsula (ej. Checklist, Eléctricos puntuales, Electrónicos). Ordena y agrupa la lista. |
| `nota` | text | no | Nota visible al elegir el trabajo (ej. duración total estimada con esperas). |

## items_checklist

Elementos y documentos del checklist de ingreso y salida.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `nombre` | text | sí | Extintor vigente, Triángulos, Matrícula, SOAT… |
| `grupo` | text | sí | Seguridad / Documentos / Exterior / Carga. |
| `tipo_vehiculo_id` | uuid | no | Vacío = aplica a todos. |
| `orden` | integer | sí | Orden en pantalla. |
| `activo` | boolean | sí | Visible. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## lineas_trabajo

Cada trabajo dentro de una OT.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `orden_trabajo_id` | uuid | sí | OT. |
| `numero_linea` | integer | sí | 1, 2, 3… |
| `sistema_id` | uuid | sí | Sistema intervenido. |
| `tipo_mantenimiento` | text | sí | preventivo / correctivo. |
| `area_taller_id` | uuid | sí | Mecánico, Soldadura, Lavadora o Externos. |
| `ejecutor` | text | sí | interno / tercero. |
| `descripcion` | text | sí | Qué se hace. |
| `tecnico_id` | uuid | no | Responsable. |
| `horas_estimadas` | numeric(10,1) | no | Estimado. |
| `estado` | text | sí | pendiente / en_proceso / esperando_repuestos / en_tercero / terminada. |
| `categoria_gasto_id` | uuid | no | Automática según sistema y tipo. |
| `categoria_manual` | boolean | sí | Sí = alguien la cambió a mano. |
| `anulado` | boolean | sí | Sí = registro anulado (no se borra). |
| `anulado_motivo` | text | no | Motivo de la anulación (obligatorio al anular). |
| `anulado_por` | uuid | no | Usuario que anuló. |
| `anulado_en` | timestamptz | no | Fecha y hora de la anulación. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## listas_valores

Listas editables: causas de daño, motivos de imprevisto, de no realizado y de descarte, tipos de novedad de personal y checklists de control de calidad.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `lista` | text | sí | causa_dano / motivo_imprevisto / motivo_no_realizado / motivo_descarte / tipo_novedad_personal / checklist_calidad / listas del kardex: motivo_llanta / kit_embrague / frenos / aceite / inyeccion / criterio / estado_compra / estado_herramienta. |
| `valor` | text | sí | Texto que se elige en la pantalla. |
| `descripcion` | text | no | Ayuda opcional. |
| `taller` | text | no | Solo para un taller (mecanica / soldadura); vacío = ambos. |
| `orden` | integer | sí | Orden en la lista. |
| `activo` | boolean | sí | No = ya no se ofrece. Nunca se borra. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## ordenes_trabajo

Orden de trabajo del taller. Se abre directamente al ingresar el vehículo; no depende de las actas.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `numero` | text | sí | OT-2026-00001. |
| `id_local` | uuid | no | Identificador generado en la tablet; evita duplicados al sincronizar sin conexión. |
| `vehiculo_id` | uuid | no | Vehículo. Puede ir vacío solo en fabricación para stock. |
| `conductor_id` | uuid | no | Conductor que trae el vehículo al taller (opcional). |
| `lectura` | numeric(10,1) | no | Km u horómetro al ingresar (vacío en fabricación para stock). |
| `motivo_ingreso` | text | sí | Tipo de OT: preventivo / correctivo / siniestro (golpe/siniestro) / llantas / fabricacion / renovado / inspeccion. |
| `falla_reportada` | text | no | Falla que reporta el conductor al ingresar. |
| `prioridad` | text | sí | alta / media / baja. |
| `inmovilizado` | boolean | sí | El vehículo no puede operar. |
| `estado` | text | sí | recepcion / diagnostico / cotizando / esperando_repuestos / en_reparacion / control_calidad / listo_entrega / entregado. |
| `diagnostico` | text | no | Diagnóstico del jefe de taller. |
| `jefe_taller_id` | uuid | no | Responsable. |
| `fecha_apertura` | timestamptz | sí | Ingreso del vehículo al taller (inicio del tiempo parado). |
| `fecha_cierre` | timestamptz | no | Fecha y hora de cierre (vehículo entregado por el taller). |
| `horas_parado` | numeric(10,1) | no | Apertura → cierre, en horas. Se calcula al cerrar. |
| `total_horas_internas` | numeric(10,1) | no | Suma de horas de técnicos. Se calcula al cerrar. |
| `anulado` | boolean | sí | Sí = registro anulado (no se borra). |
| `anulado_motivo` | text | no | Motivo de la anulación (obligatorio al anular). |
| `anulado_por` | uuid | no | Usuario que anuló. |
| `anulado_en` | timestamptz | no | Fecha y hora de la anulación. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |
| `formato` | text | sí | anterior (OT de la versión anterior, con lineas_trabajo) / segmentos (OT por segmentos de la especificación unificada). |
| `combustible` | text | no | Combustible al ingresar: E / 1/4 / 1/2 / 3/4 / F. |
| `fabricacion_descripcion` | text | no | Fabricación para stock: qué se fabrica (ej. portallantas). |
| `fabricacion_cantidad` | integer | no | Fabricación para stock: cuántas unidades. |
| `centro_costo_id` | uuid | no | Centro de costo del vehículo al abrir la OT (las rentadas van a MNTOPL3RAS). |
| `cliente_id` | uuid | no | Cliente, si la unidad es rentada (para el reporte por cliente). |
| `observaciones_recepcion` | text | no | Observaciones generales de la recepción (segmento 1). |
| `obs_supervisor_mecanica` | text | no | Observación del supervisor en el segmento 4 (trabajos de mecánica). |
| `obs_supervisor_soldadura` | text | no | Observación del supervisor en el segmento 5 (trabajos de soldadura). |

## ot_checklist

Checklist de recepción de la OT (segmento 1).

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `orden_trabajo_id` | uuid | sí | OT. |
| `item_checklist_id` | uuid | sí | Ítem del checklist de recepción (Maestros). |
| `resultado` | text | sí | ok / falta / danado. |
| `observacion` | text | no | Detalle si falta o está dañado. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## ot_hallazgos

Segmento 3: trabajos que se encontraron en la revisión y que el chofer no reportó. Los registra el supervisor.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `orden_trabajo_id` | uuid | sí | OT. |
| `numero_linea` | integer | sí | Número de línea dentro de la OT. |
| `descripcion` | text | sí | Qué se encontró. |
| `taller` | text | sí | mecanica / soldadura. |
| `sistema_id` | uuid | no | Cápsula relacionada (opcional). |
| `estado` | text | sí | pendiente / aprobado (pasa a trabajo con origen hallazgo) / descartado. |
| `motivo` | text | no | Motivo obligatorio si se descarta. |
| `comentario` | text | no | Comentario libre. |
| `resuelto_por` | uuid | no | Quién lo aprobó o descartó. |
| `resuelto_en` | timestamptz | no | Cuándo. |
| `anulado` | boolean | sí | Sí = registro anulado (no se borra). |
| `anulado_motivo` | text | no | Motivo de la anulación (obligatorio al anular). |
| `anulado_por` | uuid | no | Usuario que anuló. |
| `anulado_en` | timestamptz | no | Fecha y hora de la anulación. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## ot_imprevistos

Imprevistos durante el trabajo. Los aprobados no le restan producción al técnico.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `orden_trabajo_id` | uuid | sí | OT. |
| `trabajo_id` | uuid | sí | Trabajo afectado. |
| `tecnico_id` | uuid | sí | Técnico afectado. |
| `motivo` | text | sí | Motivo (lista de Maestros). |
| `detalle` | text | no | Texto libre. |
| `minutos` | integer | sí | Minutos de afectación. |
| `estado` | text | sí | pendiente / aprobado / rechazado (lo decide el supervisor). |
| `resuelto_por` | uuid | no | Quién lo aprobó o rechazó. |
| `resuelto_en` | timestamptz | no | Cuándo. |
| `anulado` | boolean | sí | Sí = registro anulado (no se borra). |
| `anulado_motivo` | text | no | Motivo de la anulación (obligatorio al anular). |
| `anulado_por` | uuid | no | Usuario que anuló. |
| `anulado_en` | timestamptz | no | Fecha y hora de la anulación. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## ot_inspecciones

“Inspeccionado OK” de cada cápsula en la OT: se revisó sin novedades.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `orden_trabajo_id` | uuid | sí | OT. |
| `sistema_id` | uuid | sí | Cápsula inspeccionada. |
| `anulado` | boolean | sí | Sí = registro anulado (no se borra). |
| `anulado_motivo` | text | no | Motivo de la anulación (obligatorio al anular). |
| `anulado_por` | uuid | no | Usuario que anuló. |
| `anulado_en` | timestamptz | no | Fecha y hora de la anulación. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## ot_solicitudes

Segmento 2: lo que reporta el chofer. Cada línea termina atendida, no realizada o descartada.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `orden_trabajo_id` | uuid | sí | OT. |
| `numero_linea` | integer | sí | Número de línea dentro de la OT. |
| `descripcion` | text | sí | Lo que reporta el chofer. |
| `taller_sugerido` | text | sí | mecanica / soldadura. |
| `estado` | text | sí | pendiente / atendida (se convirtió en trabajos) / no_realizada / descartada. |
| `motivo` | text | no | Motivo obligatorio si no se realizó o se descartó (de las listas de Maestros). |
| `comentario` | text | no | Comentario libre. |
| `resuelto_por` | uuid | no | Quién la cerró. |
| `resuelto_en` | timestamptz | no | Cuándo se cerró. |
| `anulado` | boolean | sí | Sí = registro anulado (no se borra). |
| `anulado_motivo` | text | no | Motivo de la anulación (obligatorio al anular). |
| `anulado_por` | uuid | no | Usuario que anuló. |
| `anulado_en` | timestamptz | no | Fecha y hora de la anulación. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## ot_trabajo_tecnicos

Técnicos de cada trabajo y reparto de las horas-hombre (por defecto en partes iguales).

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `trabajo_id` | uuid | sí | Trabajo. |
| `tecnico_id` | uuid | sí | Técnico. |
| `porcentaje` | numeric(5,2) | sí | Parte de las horas que le corresponde (los del trabajo suman 100). |
| `horas` | numeric(8,2) | sí | Horas estándar que se le acreditan = horas del trabajo × porcentaje. |
| `anulado` | boolean | sí | Sí = registro anulado (no se borra). |
| `anulado_motivo` | text | no | Motivo de la anulación (obligatorio al anular). |
| `anulado_por` | uuid | no | Usuario que anuló. |
| `anulado_en` | timestamptz | no | Fecha y hora de la anulación. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## ot_trabajos

Segmentos 4 (mecánica) y 5 (soldadura): cada trabajo registrado desde las cápsulas del ambiente.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `orden_trabajo_id` | uuid | sí | OT. |
| `numero_linea` | integer | sí | Número de línea dentro de la OT. |
| `taller` | text | sí | mecanica (segmento 4) / soldadura (segmento 5). Sale de la cápsula. |
| `sistema_id` | uuid | sí | Cápsula (sistema o componente). |
| `elemento_id` | uuid | no | Elemento atendido. |
| `intervencion_id` | uuid | sí | Intervención del catálogo. |
| `sistema_nombre` | text | sí | Nombre de la cápsula al momento de registrar (no cambia si el catálogo cambia). |
| `elemento_nombre` | text | no | Nombre del elemento al momento de registrar. |
| `intervencion_nombre` | text | sí | Nombre de la intervención al momento de registrar. |
| `horas_unitarias` | numeric(7,3) | sí | Horas estándar del catálogo al momento de registrar (3 decimales). |
| `cantidad` | numeric(8,2) | sí | Cantidad de unidades intervenidas. |
| `complejidad_id` | uuid | no | Complejidad (si la cápsula aplica complejidad). |
| `complejidad_nombre` | text | no | Nombre de la complejidad al registrar. |
| `multiplicador` | numeric(4,2) | sí | Multiplicador de complejidad usado (1 si no aplica). |
| `horas_estandar` | numeric(8,2) | sí | Horas-hombre totales = horas unitarias × cantidad × multiplicador. |
| `estado` | text | sí | pendiente / en_proceso / terminado / no_realizado. Lo cambia el supervisor. |
| `origen` | text | sí | chofer (solicitud) / hallazgo / preventivo. |
| `solicitud_id` | uuid | no | Línea de la solicitud del chofer que atiende. |
| `hallazgo_id` | uuid | no | Hallazgo del que sale. |
| `causa` | text | no | Causa del daño (lista de Maestros). |
| `material_base` | text | no | Soldadura: inoxidable / hierro_negro. |
| `observacion` | text | no | Observación del registro del trabajo. |
| `motivo_no_realizado` | text | no | Motivo obligatorio si el trabajo no se realizó (queda pendiente de la unidad). |
| `detalle_no_realizado` | text | no | Detalle libre del no realizado. |
| `terminado_en` | timestamptz | no | Cuándo se marcó terminado. |
| `terminado_por` | uuid | no | Quién lo marcó terminado (supervisor). |
| `anulado` | boolean | sí | Sí = registro anulado (no se borra). |
| `anulado_motivo` | text | no | Motivo de la anulación (obligatorio al anular). |
| `anulado_por` | uuid | no | Usuario que anuló. |
| `anulado_en` | timestamptz | no | Fecha y hora de la anulación. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## proveedores

Proveedores de repuestos y talleres externos (terceros).

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `nombre` | text | sí | Razón social. |
| `ruc` | text | no | RUC. |
| `tipo` | text | sí | repuestos / taller_externo / ambos. |
| `especialidad` | text | no | Para talleres externos: mecanica / soldadura / ambas. |
| `contacto` | text | no | Persona de contacto. |
| `telefono` | text | no | Teléfono. |
| `correo` | text | no | Correo. |
| `direccion` | text | no | Dirección. |
| `observaciones` | text | no | Notas libres. |
| `activo` | boolean | sí | No = ya no se usa. Nunca se borra. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## registros_horas

Horas trabajadas por técnico. Base de la productividad.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `linea_trabajo_id` | uuid | sí | Línea. |
| `tecnico_id` | uuid | sí | Técnico. |
| `fecha` | date | sí | Día trabajado. |
| `horas` | numeric(10,1) | sí | Horas. |
| `nota` | text | no | Avance. |
| `anulado` | boolean | sí | Sí = registro anulado (no se borra). |
| `anulado_motivo` | text | no | Motivo de la anulación (obligatorio al anular). |
| `anulado_por` | uuid | no | Usuario que anuló. |
| `anulado_en` | timestamptz | no | Fecha y hora de la anulación. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## repuestos

Catálogo de repuestos importado desde Excel del otro sistema.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `codigo` | text | sí | Código del sistema de origen. |
| `descripcion` | text | sí | Descripción. |
| `unidad` | text | sí | UND, GL, LT, M… |
| `categoria_gasto_id` | uuid | no | Categoría sugerida (ej. Insumos). |
| `activo` | boolean | sí | Disponible para seleccionar. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## repuestos_linea

Repuestos e insumos usados. Sin montos.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `linea_trabajo_id` | uuid | sí | Línea. |
| `repuesto_id` | uuid | no | Del catálogo, si existe. |
| `codigo` | text | no | Código (copiado). |
| `descripcion` | text | sí | Descripción (copiada). |
| `cantidad` | numeric(10,2) | sí | Cantidad. |
| `unidad` | text | sí | Unidad. |
| `origen` | text | sí | bodega_s3 / orden_compra / tercero. |
| `numero_documento` | text | no | N.º de S3 u OC. |
| `categoria_gasto_id` | uuid | no | Normalmente la de la línea; Insumos para aceites, filtros, etc. |
| `anulado` | boolean | sí | Sí = registro anulado (no se borra). |
| `anulado_motivo` | text | no | Motivo de la anulación (obligatorio al anular). |
| `anulado_por` | uuid | no | Usuario que anuló. |
| `anulado_en` | timestamptz | no | Fecha y hora de la anulación. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## respaldos

Historial de respaldos semanales y manuales.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `tipo` | text | sí | semanal / manual. |
| `fecha_hora` | timestamptz | sí | Inicio del respaldo. |
| `destino` | text | sí | google_drive / descarga. |
| `nombre_archivo` | text | no | Ej.: respaldo_2026-10-19.sql.gz |
| `bytes` | bigint | no | Tamaño. |
| `estado` | text | sí | ok / error. |
| `detalle` | text | no | Mensaje de error si lo hubo. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## sistemas

Sistemas o componentes de cada taller. Cada uno es una cápsula en los ambientes Mecánica y Soldadura.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `nombre` | text | sí | Motor, Caja, Corona, Embrague, Frenos, Suspensión, Dirección, Eléctrico, Llantas, Carrocería, Plataforma, Lavado, Otros. |
| `categoria_preventivo_id` | uuid | no | Categoría automática cuando el trabajo es preventivo. |
| `categoria_correctivo_id` | uuid | no | Categoría automática cuando es correctivo. |
| `orden` | integer | sí | Orden en listas. |
| `activo` | boolean | sí | Visible. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |
| `taller` | text | sí | mecanica / soldadura. |
| `icono` | text | no | Ícono de la cápsula (nombre de Font Awesome, ej. fa-gears). |
| `descripcion` | text | no | Ayuda breve que se muestra en la cápsula. |
| `aplica_complejidad` | boolean | sí | Sí = sus trabajos se multiplican por la complejidad (leve, moderado, grave). Ej.: Tanque de lixiviados no. |

## sistemas_preventivos

Sistemas del registro de componentes y pronóstico del kardex, con sus intervalos. Son los “intervalos preventivos” de Parámetros.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `codigo` | text | sí | Código corto: aceite, caja, embrague, frenos, llantas, radiador, inyeccion, baterias. |
| `nombre` | text | sí | Nombre visible. |
| `modo` | text | sí | km (por kilometraje) / dias (por tiempo) / falla (frecuencia de daños). |
| `intervalo_cabezal` | numeric(10,1) | no | Intervalo para cabezales (DC): km si el modo es km, días si es dias. |
| `intervalo_plataforma` | numeric(10,1) | no | Intervalo para plataformas (DP/DR). |
| `intervalo_montacarga` | numeric(10,1) | no | Intervalo para montacargas (0 = se calcula por tiempo, no tienen km en Hunter). |
| `dias_sin_km` | integer | no | Días que se usan cuando la unidad no tiene km de Hunter. |
| `pct_prematuro` | integer | sí | Se marca prematuro si el cambio se hizo antes de este % del intervalo (0 = no medir). |
| `registro_automatico` | boolean | sí | Sí = todo despacho con estas palabras cuenta como cambio sin confirmar. |
| `incluye` | text | no | Sugerir como cambio si el artículo incluye estas palabras (separadas por coma). |
| `excluye` | text | no | …y no incluye estas palabras. |
| `km_incluye` | text | no | Registro automático por km: el artículo incluye estas palabras y la salida trae km. |
| `km_excluye` | text | no | …y no incluye estas palabras. |
| `motivos_falla` | text | no | Motivos que cuentan como falla y no como desgaste (llantas). |
| `orden` | integer | sí | Orden en las listas. |
| `activo` | boolean | sí | No = ya no se usa. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## tarifas_tecnico

Tarifa interna por hora de cada técnico, con su fecha de vigencia. Solo la ve quien tiene el permiso ver_costos.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `tecnico_id` | uuid | sí | Técnico. |
| `tarifa_hora` | numeric(10,2) | sí | Costo interno por hora (USD). |
| `vigente_desde` | date | sí | Desde qué fecha rige esta tarifa. |
| `observacion` | text | no | Motivo del cambio de tarifa. |
| `anulado` | boolean | sí | Sí = registro anulado (no se borra). |
| `anulado_motivo` | text | no | Motivo de la anulación (obligatorio al anular). |
| `anulado_por` | uuid | no | Usuario que anuló. |
| `anulado_en` | timestamptz | no | Fecha y hora de la anulación. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## tecnicos

Personal que ejecuta trabajos, con o sin usuario propio.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `usuario_id` | uuid | no | Si el técnico ingresa al sistema. |
| `nombres` | text | sí | Nombre completo. |
| `cedula` | text | no | Cédula. |
| `telefono` | text | no | Celular. |
| `area_taller_id` | uuid | no | Área anterior (Fase 1 antigua). Se reemplaza por especialidad. |
| `activo` | boolean | sí | Disponible para asignar. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |
| `codigo` | text | sí | Código corto del técnico (ej. T01). Aparece en sus observaciones y en la producción. |
| `especialidad` | text | sí | mecanica / soldadura / ambas. |
| `cargo` | text | no | Cargo (ej. mecánico A, soldador, ayudante). |
| `jornada_horas` | numeric(4,1) | sí | Horas de trabajo por día. Base de las horas disponibles. |
| `fecha_ingreso` | date | no | Fecha de ingreso a la empresa (para el saldo de vacaciones). |
| `contacto_emergencia` | text | no | Contacto autorizado para emergencias. Lo puede editar el propio técnico. |

## tipos_vehiculo

Cabezal, plataforma, recolector, montacargas.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `prefijo_codigo` | text | sí | DC, DP, DR, MC. |
| `nombre` | text | sí | Cabezal, Plataforma, Recolector, Montacargas. |
| `unidad_medida` | text | sí | km / horas. |
| `diagrama` | text | sí | Nombre del dibujo usado para marcar daños. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |

## usuarios

Personas que ingresan al sistema (unas 15).

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | El mismo identificador que tiene en el sistema de inicio de sesión. |
| `nombre_completo` | text | sí | Nombre y apellido. |
| `correo` | text | sí | Correo con el que ingresa. |
| `rol` | text | sí | maestro / supervisor (asesor de servicios / jefe de patio) / bodega / tecnico. |
| `telefono` | text | no | Celular. |
| `activo` | boolean | sí | Si está en no, no puede ingresar. Nunca se borra. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |
| `permisos_extra` | text[] | sí | Permisos sumados a la persona además de su rol: bodega, aprobar_ajustes, gestion_personal, ver_costos, editar_catalogos. |

## vehiculos

La flota.

| Campo | Tipo | Obligatorio | Significado |
|---|---|---|---|
| `id` | uuid | sí | Identificador único universal (UUID). |
| `codigo` | text | sí | Código interno: DC001, DP176. |
| `placa` | text | no | Placa: GSA-4512. Vacía en montacargas. |
| `tipo_vehiculo_id` | uuid | sí | Tipo. |
| `configuracion_ejes_id` | uuid | no | Configuración de ejes. |
| `marca` | text | no | Hino, Volvo, Kenworth… |
| `modelo` | text | no | Modelo. |
| `anio` | integer | no | Año de fabricación. |
| `numero_chasis` | text | no | VIN o chasis. |
| `numero_motor` | text | no | N.º de motor. |
| `color` | text | no | Color. |
| `conductor_asignado_id` | uuid | no | Conductor habitual. |
| `lectura_actual` | numeric(10,1) | sí | Último km u horómetro confirmado. |
| `lectura_actual_fecha` | timestamptz | no | Fecha de esa lectura. |
| `estado` | text | sí | activo / parado / venta / tramite (los mismos estados de la flota del kardex). |
| `observaciones` | text | no | Notas. |
| `creado_en` | timestamptz | sí | Fecha y hora de creación. |
| `creado_por` | uuid | no | Usuario que creó el registro. |
| `actualizado_en` | timestamptz | no | Fecha y hora de la última modificación. |
| `actualizado_por` | uuid | no | Usuario que hizo la última modificación. |
| `nombre_hunter` | text | no | Nombre de la columna de esta unidad en el reporte de odómetro de Hunter (ej. DC001--GBP1502). Sirve para cargar los km diarios. |
| `estado_desde` | date | no | Fecha desde la que el vehículo está en el estado actual. |
| `propiedad` | text | sí | propio / rentado (unidad rentada a un cliente). |
| `cliente_id` | uuid | no | Cliente al que está rentada la unidad (obligatorio si es rentada). |
| `centro_costo_id` | uuid | no | Centro de costo del gasto. Las rentadas van siempre al centro de clientes (MNTOPL3RAS). |
| `fecha_ingreso_flota` | date | no | Mes y año en que la unidad ingresó a la flota (día 1). Sirve para calcular la edad. |

