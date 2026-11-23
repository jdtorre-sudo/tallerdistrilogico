-- =====================================================================
-- INSTALAR_TODO.sql · Generado uniendo 001 a 899 en orden. Pegar completo en el
-- SQL Editor de Supabase y presionar RUN. (Los datos de ejemplo van aparte.)
-- Para actualizar una base que YA está en uso, NO use este archivo: pegue solo
-- los archivos nuevos (vea LEEME.md, sección "Actualizar una base en uso").
-- =====================================================================

-- >>>>>>>>>>>>>>>>>>>> 001_esquema.sql
-- =====================================================================
-- Sistema de Órdenes de Trabajo y Actas · Flota Distrilógico
-- 001 · Esquema (Fase 1)
-- PostgreSQL estándar (versión 15 o superior). No depende de Supabase.
-- Convenciones:
--   * Todas las tablas tienen id uuid, creado_en, creado_por,
--     actualizado_en, actualizado_por.
--   * Los documentos y movimientos tienen anulado / anulado_motivo /
--     anulado_por / anulado_en. Nada se borra.
--   * Fechas: timestamptz (se muestran en America/Guayaquil).
--   * Km y horas: numeric(10,1). Códigos y placas: text.
-- =====================================================================

create extension if not exists pgcrypto;  -- gen_random_uuid() en versiones antiguas

-- Usuario que está operando. En Supabase lo pone la API; en otro servidor
-- basta con ejecutar: set request.jwt.claim.sub = '<uuid del usuario>';
create or replace function usuario_actual() returns uuid
language sql stable as $$
  select nullif(coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::json ->> 'sub')
  ), '')::uuid
$$;

-- ------------------------------------------------------------------ Seguridad
create table usuarios (
  id               uuid primary key,
  nombre_completo  text not null,
  correo           text not null unique,
  rol              text not null default 'consulta'
                   check (rol in ('administrador','jefe_taller','tecnico','gerencia','consulta')),
  telefono         text,
  activo           boolean not null default true,
  creado_en        timestamptz not null default now(),
  creado_por       uuid,
  actualizado_en   timestamptz,
  actualizado_por  uuid
);

create table configuracion (
  id               uuid primary key default gen_random_uuid(),
  clave            text not null unique,
  valor            text not null,
  tipo_dato        text not null default 'texto' check (tipo_dato in ('numero','texto','si_no')),
  descripcion      text,
  creado_en        timestamptz not null default now(),
  creado_por       uuid references usuarios(id),
  actualizado_en   timestamptz,
  actualizado_por  uuid references usuarios(id)
);

create table contadores_documento (
  id               uuid primary key default gen_random_uuid(),
  tipo_documento   text not null check (tipo_documento in ('AR','AE','OT','SC')),
  anio             integer not null,
  ultimo_numero    integer not null default 0,
  creado_en        timestamptz not null default now(),
  creado_por       uuid references usuarios(id),
  actualizado_en   timestamptz,
  actualizado_por  uuid references usuarios(id),
  unique (tipo_documento, anio)
);

create table bitacora_auditoria (
  id               uuid primary key default gen_random_uuid(),
  tabla            text not null,
  registro_id      uuid,
  accion           text not null,
  datos_antes      jsonb,
  datos_despues    jsonb,
  usuario_id       uuid,
  fecha_hora       timestamptz not null default now(),
  creado_en        timestamptz not null default now(),
  creado_por       uuid,
  actualizado_en   timestamptz,
  actualizado_por  uuid
);
create index on bitacora_auditoria (tabla, registro_id);

create table respaldos (
  id               uuid primary key default gen_random_uuid(),
  tipo             text not null check (tipo in ('semanal','manual')),
  fecha_hora       timestamptz not null default now(),
  destino          text not null,
  nombre_archivo   text,
  bytes            bigint,
  estado           text not null check (estado in ('ok','error')),
  detalle          text,
  creado_en        timestamptz not null default now(),
  creado_por       uuid,
  actualizado_en   timestamptz,
  actualizado_por  uuid
);

-- ------------------------------------------------------------------ Catálogos
create table areas_taller (
  id                   uuid primary key default gen_random_uuid(),
  nombre               text not null unique,
  es_externo           boolean not null default false,
  requiere_cotizacion  boolean not null default false,
  orden                integer not null default 0,
  activo               boolean not null default true,
  creado_en            timestamptz not null default now(),
  creado_por           uuid references usuarios(id),
  actualizado_en       timestamptz,
  actualizado_por      uuid references usuarios(id)
);

create table tecnicos (
  id               uuid primary key default gen_random_uuid(),
  usuario_id       uuid references usuarios(id),
  nombres          text not null,
  cedula           text unique,
  telefono         text,
  area_taller_id   uuid references areas_taller(id),
  activo           boolean not null default true,
  creado_en        timestamptz not null default now(),
  creado_por       uuid references usuarios(id),
  actualizado_en   timestamptz,
  actualizado_por  uuid references usuarios(id)
);

create table tipos_vehiculo (
  id               uuid primary key default gen_random_uuid(),
  prefijo_codigo   text not null unique,
  nombre           text not null,
  unidad_medida    text not null default 'km' check (unidad_medida in ('km','horas')),
  diagrama         text not null check (diagrama in ('cabezal','plataforma','recolector','montacargas')),
  creado_en        timestamptz not null default now(),
  creado_por       uuid references usuarios(id),
  actualizado_en   timestamptz,
  actualizado_por  uuid references usuarios(id)
);

create table configuraciones_ejes (
  id               uuid primary key default gen_random_uuid(),
  nombre           text not null unique,
  numero_ejes      integer not null,
  numero_llantas   integer not null,
  descripcion      text,
  creado_en        timestamptz not null default now(),
  creado_por       uuid references usuarios(id),
  actualizado_en   timestamptz,
  actualizado_por  uuid references usuarios(id)
);

create table conductores (
  id               uuid primary key default gen_random_uuid(),
  cedula           text not null unique,
  nombres          text not null,
  apellidos        text not null,
  telefono         text,
  correo           text,
  tipo_licencia    text,
  licencia_vence   date,
  activo           boolean not null default true,
  creado_en        timestamptz not null default now(),
  creado_por       uuid references usuarios(id),
  actualizado_en   timestamptz,
  actualizado_por  uuid references usuarios(id)
);

create table vehiculos (
  id                     uuid primary key default gen_random_uuid(),
  codigo                 text not null unique,
  placa                  text unique,
  tipo_vehiculo_id       uuid not null references tipos_vehiculo(id),
  configuracion_ejes_id  uuid references configuraciones_ejes(id),
  marca                  text,
  modelo                 text,
  anio                   integer,
  numero_chasis          text,
  numero_motor           text,
  color                  text,
  conductor_asignado_id  uuid references conductores(id),
  lectura_actual         numeric(10,1) not null default 0,
  lectura_actual_fecha   timestamptz,
  estado                 text not null default 'activo' check (estado in ('activo','inactivo','baja')),
  observaciones          text,
  creado_en              timestamptz not null default now(),
  creado_por             uuid references usuarios(id),
  actualizado_en         timestamptz,
  actualizado_por        uuid references usuarios(id)
);

create table categorias_gasto (
  id               uuid primary key default gen_random_uuid(),
  nombre           text not null unique,
  grupo            text not null check (grupo in ('Mantenimiento','Insumos','Llantas','Otros')),
  orden            integer not null default 0,
  creado_en        timestamptz not null default now(),
  creado_por       uuid references usuarios(id),
  actualizado_en   timestamptz,
  actualizado_por  uuid references usuarios(id)
);

create table sistemas (
  id                       uuid primary key default gen_random_uuid(),
  nombre                   text not null unique,
  categoria_preventivo_id  uuid references categorias_gasto(id),
  categoria_correctivo_id  uuid references categorias_gasto(id),
  orden                    integer not null default 0,
  activo                   boolean not null default true,
  creado_en                timestamptz not null default now(),
  creado_por               uuid references usuarios(id),
  actualizado_en           timestamptz,
  actualizado_por          uuid references usuarios(id)
);

create table items_checklist (
  id                uuid primary key default gen_random_uuid(),
  nombre            text not null,
  grupo             text not null check (grupo in ('Seguridad','Documentos','Exterior','Carga')),
  tipo_vehiculo_id  uuid references tipos_vehiculo(id),
  orden             integer not null default 0,
  activo            boolean not null default true,
  creado_en         timestamptz not null default now(),
  creado_por        uuid references usuarios(id),
  actualizado_en    timestamptz,
  actualizado_por   uuid references usuarios(id)
);

create table repuestos (
  id                  uuid primary key default gen_random_uuid(),
  codigo              text not null unique,
  descripcion         text not null,
  unidad              text not null default 'UND',
  categoria_gasto_id  uuid references categorias_gasto(id),
  activo              boolean not null default true,
  creado_en           timestamptz not null default now(),
  creado_por          uuid references usuarios(id),
  actualizado_en      timestamptz,
  actualizado_por     uuid references usuarios(id)
);

-- ------------------------------------------------------------------ Archivos
create table archivos (
  id                  uuid primary key default gen_random_uuid(),
  tipo                text not null check (tipo in ('firma','proforma')),
  categoria           text not null,
  ruta                text not null unique,
  tipo_mime           text not null,
  bytes               integer,
  tabla_origen        text not null,
  registro_origen_id  uuid not null,
  firmado_en          timestamptz not null default now(),
  usuario_id          uuid references usuarios(id),
  anulado             boolean not null default false,
  anulado_motivo      text,
  anulado_por         uuid references usuarios(id),
  anulado_en          timestamptz,
  creado_en           timestamptz not null default now(),
  creado_por          uuid references usuarios(id),
  actualizado_en      timestamptz,
  actualizado_por     uuid references usuarios(id),
  check (not anulado or coalesce(length(trim(anulado_motivo)),0) > 0)
);
create index on archivos (tabla_origen, registro_origen_id);

-- ------------------------------------------------------------------ Actas de asignación
-- Acta de entrega: la empresa entrega el vehículo a un conductor.
-- Acta de recepción: la empresa recibe el vehículo del conductor.
-- Son documentos independientes entre sí y de las órdenes de trabajo.
create table actas_recepcion (
  id                  uuid primary key default gen_random_uuid(),
  numero              text not null unique,
  id_local            uuid unique,
  vehiculo_id         uuid not null references vehiculos(id),
  conductor_id        uuid not null references conductores(id),
  recibido_por        uuid not null references usuarios(id),
  fecha_hora          timestamptz not null default now(),
  lectura             numeric(10,1) not null check (lectura >= 0),
  lectura_hunter      numeric(10,1),
  combustible         text not null check (combustible in ('E','1/4','1/2','3/4','F')),
  motivo              text not null check (motivo in ('cambio_conductor','vacaciones_permiso','fin_relacion','ingreso_taller','siniestro','otro')),
  observaciones       text,
  firma_conductor_id  uuid references archivos(id),
  firma_recibe_id     uuid references archivos(id),
  estado              text not null default 'borrador' check (estado in ('borrador','firmada')),
  anulado             boolean not null default false,
  anulado_motivo      text,
  anulado_por         uuid references usuarios(id),
  anulado_en          timestamptz,
  creado_en           timestamptz not null default now(),
  creado_por          uuid references usuarios(id),
  actualizado_en      timestamptz,
  actualizado_por     uuid references usuarios(id),
  check (not anulado or coalesce(length(trim(anulado_motivo)),0) > 0)
);
create index on actas_recepcion (vehiculo_id, fecha_hora);

create table checklist_recepcion (
  id                 uuid primary key default gen_random_uuid(),
  acta_recepcion_id  uuid not null references actas_recepcion(id),
  item_checklist_id  uuid not null references items_checklist(id),
  resultado          text not null check (resultado in ('ok','falta','danado')),
  observacion        text,
  creado_en          timestamptz not null default now(),
  creado_por         uuid references usuarios(id),
  actualizado_en     timestamptz,
  actualizado_por    uuid references usuarios(id),
  unique (acta_recepcion_id, item_checklist_id)
);

-- ------------------------------------------------------------------ Orden de trabajo
create table ordenes_trabajo (
  id                     uuid primary key default gen_random_uuid(),
  numero                 text not null unique,
  id_local               uuid unique,
  vehiculo_id            uuid not null references vehiculos(id),
  conductor_id           uuid references conductores(id),
  lectura                numeric(10,1) not null check (lectura >= 0),
  motivo_ingreso         text not null check (motivo_ingreso in ('preventivo','correctivo','llantas','siniestro','inspeccion')),
  falla_reportada        text,
  prioridad              text not null default 'media' check (prioridad in ('alta','media','baja')),
  inmovilizado           boolean not null default false,
  estado                 text not null default 'recepcion'
                         check (estado in ('recepcion','diagnostico','cotizando','esperando_repuestos',
                                           'en_reparacion','control_calidad','listo_entrega','entregado')),
  diagnostico            text,
  jefe_taller_id         uuid references usuarios(id),
  fecha_apertura         timestamptz not null default now(),
  fecha_cierre           timestamptz,
  horas_parado           numeric(10,1),
  total_horas_internas   numeric(10,1),
  anulado                boolean not null default false,
  anulado_motivo         text,
  anulado_por            uuid references usuarios(id),
  anulado_en             timestamptz,
  creado_en              timestamptz not null default now(),
  creado_por             uuid references usuarios(id),
  actualizado_en         timestamptz,
  actualizado_por        uuid references usuarios(id),
  check (not anulado or coalesce(length(trim(anulado_motivo)),0) > 0)
);
create index on ordenes_trabajo (estado);
create index on ordenes_trabajo (vehiculo_id);

create table historial_estados_ot (
  id                uuid primary key default gen_random_uuid(),
  orden_trabajo_id  uuid not null references ordenes_trabajo(id),
  estado_anterior   text,
  estado_nuevo      text not null,
  fecha_hora        timestamptz not null default now(),
  usuario_id        uuid references usuarios(id) default usuario_actual(),
  comentario        text,
  creado_en         timestamptz not null default now(),
  creado_por        uuid references usuarios(id),
  actualizado_en    timestamptz,
  actualizado_por   uuid references usuarios(id)
);
create index on historial_estados_ot (orden_trabajo_id, fecha_hora);

create table lineas_trabajo (
  id                  uuid primary key default gen_random_uuid(),
  orden_trabajo_id    uuid not null references ordenes_trabajo(id),
  numero_linea        integer not null,
  sistema_id          uuid not null references sistemas(id),
  tipo_mantenimiento  text not null check (tipo_mantenimiento in ('preventivo','correctivo')),
  area_taller_id      uuid not null references areas_taller(id),
  ejecutor            text not null default 'interno' check (ejecutor in ('interno','tercero')),
  descripcion         text not null,
  tecnico_id          uuid references tecnicos(id),
  horas_estimadas     numeric(10,1),
  estado              text not null default 'pendiente'
                      check (estado in ('pendiente','en_proceso','esperando_repuestos','en_tercero','terminada')),
  categoria_gasto_id  uuid references categorias_gasto(id),
  categoria_manual    boolean not null default false,
  anulado             boolean not null default false,
  anulado_motivo      text,
  anulado_por         uuid references usuarios(id),
  anulado_en          timestamptz,
  creado_en           timestamptz not null default now(),
  creado_por          uuid references usuarios(id),
  actualizado_en      timestamptz,
  actualizado_por     uuid references usuarios(id),
  unique (orden_trabajo_id, numero_linea),
  check (not anulado or coalesce(length(trim(anulado_motivo)),0) > 0)
);

create table registros_horas (
  id                uuid primary key default gen_random_uuid(),
  linea_trabajo_id  uuid not null references lineas_trabajo(id),
  tecnico_id        uuid not null references tecnicos(id),
  fecha             date not null default current_date,
  horas             numeric(10,1) not null check (horas > 0 and horas <= 24),
  nota              text,
  anulado           boolean not null default false,
  anulado_motivo    text,
  anulado_por       uuid references usuarios(id),
  anulado_en        timestamptz,
  creado_en         timestamptz not null default now(),
  creado_por        uuid references usuarios(id),
  actualizado_en    timestamptz,
  actualizado_por   uuid references usuarios(id),
  check (not anulado or coalesce(length(trim(anulado_motivo)),0) > 0)
);

create table repuestos_linea (
  id                  uuid primary key default gen_random_uuid(),
  linea_trabajo_id    uuid not null references lineas_trabajo(id),
  repuesto_id         uuid references repuestos(id),
  codigo              text,
  descripcion         text not null,
  cantidad            numeric(10,2) not null check (cantidad > 0),
  unidad              text not null default 'UND',
  origen              text not null check (origen in ('bodega_s3','orden_compra','tercero')),
  numero_documento    text,
  categoria_gasto_id  uuid references categorias_gasto(id),
  anulado             boolean not null default false,
  anulado_motivo      text,
  anulado_por         uuid references usuarios(id),
  anulado_en          timestamptz,
  creado_en           timestamptz not null default now(),
  creado_por          uuid references usuarios(id),
  actualizado_en      timestamptz,
  actualizado_por     uuid references usuarios(id),
  check (not anulado or coalesce(length(trim(anulado_motivo)),0) > 0)
);

create table comentarios_ot (
  id                uuid primary key default gen_random_uuid(),
  orden_trabajo_id  uuid not null references ordenes_trabajo(id),
  usuario_id        uuid references usuarios(id) default usuario_actual(),
  fecha_hora        timestamptz not null default now(),
  texto             text not null,
  anulado           boolean not null default false,
  anulado_motivo    text,
  anulado_por       uuid references usuarios(id),
  anulado_en        timestamptz,
  creado_en         timestamptz not null default now(),
  creado_por        uuid references usuarios(id),
  actualizado_en    timestamptz,
  actualizado_por   uuid references usuarios(id),
  check (not anulado or coalesce(length(trim(anulado_motivo)),0) > 0)
);

create table actas_entrega (
  id                  uuid primary key default gen_random_uuid(),
  numero              text not null unique,
  id_local            uuid unique,
  vehiculo_id         uuid not null references vehiculos(id),
  fecha_hora          timestamptz not null default now(),
  lectura             numeric(10,1) not null,
  combustible         text not null check (combustible in ('E','1/4','1/2','3/4','F')),
  conductor_id        uuid not null references conductores(id),
  entregado_por       uuid not null references usuarios(id),
  motivo              text not null check (motivo in ('asignacion','cambio_conductor','reemplazo_temporal','salida_taller','otro')),
  observaciones       text,
  firma_conductor_id  uuid references archivos(id),
  firma_entrega_id    uuid references archivos(id),
  estado              text not null default 'borrador' check (estado in ('borrador','firmada')),
  anulado             boolean not null default false,
  anulado_motivo      text,
  anulado_por         uuid references usuarios(id),
  anulado_en          timestamptz,
  creado_en           timestamptz not null default now(),
  creado_por          uuid references usuarios(id),
  actualizado_en      timestamptz,
  actualizado_por     uuid references usuarios(id),
  check (not anulado or coalesce(length(trim(anulado_motivo)),0) > 0)
);

create table checklist_entrega (
  id                 uuid primary key default gen_random_uuid(),
  acta_entrega_id    uuid not null references actas_entrega(id),
  item_checklist_id  uuid not null references items_checklist(id),
  resultado          text not null check (resultado in ('ok','falta','danado')),
  observacion        text,
  creado_en          timestamptz not null default now(),
  creado_por         uuid references usuarios(id),
  actualizado_en     timestamptz,
  actualizado_por    uuid references usuarios(id),
  unique (acta_entrega_id, item_checklist_id)
);

create table danos_vehiculo (
  id                 uuid primary key default gen_random_uuid(),
  vehiculo_id        uuid not null references vehiculos(id),
  acta_recepcion_id  uuid references actas_recepcion(id),
  acta_entrega_id    uuid references actas_entrega(id),
  numero_marca       integer not null,
  vista              text not null check (vista in ('frontal','posterior','izquierda','derecha')),
  posicion_x         numeric(5,4) not null check (posicion_x between 0 and 1),
  posicion_y         numeric(5,4) not null check (posicion_y between 0 and 1),
  tipo_dano          text not null check (tipo_dano in ('golpe','rayon','rotura','oxidacion','otro')),
  descripcion        text,
  situacion          text not null default 'registrado' check (situacion in ('registrado','reparado')),
  anulado            boolean not null default false,
  anulado_motivo     text,
  anulado_por        uuid references usuarios(id),
  anulado_en         timestamptz,
  creado_en          timestamptz not null default now(),
  creado_por         uuid references usuarios(id),
  actualizado_en     timestamptz,
  actualizado_por    uuid references usuarios(id),
  check (acta_recepcion_id is not null or acta_entrega_id is not null),
  check (not anulado or coalesce(length(trim(anulado_motivo)),0) > 0)
);
create index on danos_vehiculo (vehiculo_id);

-- >>>>>>>>>>>>>>>>>>>> 002_comentarios.sql
-- =====================================================================
-- 002 · Descripción de tablas y campos (alimenta el diccionario de datos)
-- =====================================================================

comment on table usuarios is 'Personas que ingresan al sistema (unas 15).';
comment on column usuarios.id is 'El mismo identificador que tiene en el sistema de inicio de sesión.';
comment on column usuarios.nombre_completo is 'Nombre y apellido.';
comment on column usuarios.correo is 'Correo con el que ingresa.';
comment on column usuarios.rol is 'administrador | jefe_taller | tecnico | gerencia | consulta.';
comment on column usuarios.telefono is 'Celular.';
comment on column usuarios.activo is 'Si está en no, no puede ingresar. Nunca se borra.';
comment on column usuarios.creado_en is 'Fecha y hora de creación.';
comment on column usuarios.creado_por is 'Usuario que creó el registro.';
comment on column usuarios.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column usuarios.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table configuracion is 'Parámetros ajustables sin tocar el programa.';
comment on column configuracion.id is 'Identificador único universal (UUID).';
comment on column configuracion.clave is 'Nombre del parámetro: limite_aprobacion_jefe, tolerancia_factura_pct, iva_pct, umbral_labrado_mm, dias_max_llanta, diferencia_max_hunter_km.';
comment on column configuracion.valor is 'Valor actual, por ejemplo 300, 10, 15, 4, 365, 500.';
comment on column configuracion.tipo_dato is 'numero | texto | si_no. Sirve para validar al editar.';
comment on column configuracion.descripcion is 'Explicación para el administrador.';
comment on column configuracion.creado_en is 'Fecha y hora de creación.';
comment on column configuracion.creado_por is 'Usuario que creó el registro.';
comment on column configuracion.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column configuracion.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table contadores_documento is 'Lleva la numeración correlativa por tipo y año.';
comment on column contadores_documento.id is 'Identificador único universal (UUID).';
comment on column contadores_documento.tipo_documento is 'AR, AE, OT o SC.';
comment on column contadores_documento.anio is 'Año del contador (2026).';
comment on column contadores_documento.ultimo_numero is 'Último número usado. El siguiente sale de sumar 1 de forma segura, sin saltos ni repetidos.';
comment on column contadores_documento.creado_en is 'Fecha y hora de creación.';
comment on column contadores_documento.creado_por is 'Usuario que creó el registro.';
comment on column contadores_documento.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column contadores_documento.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table bitacora_auditoria is 'Registro inalterable de quién hizo qué y cuándo.';
comment on column bitacora_auditoria.id is 'Identificador único universal (UUID).';
comment on column bitacora_auditoria.tabla is 'Tabla afectada.';
comment on column bitacora_auditoria.registro_id is 'Registro afectado.';
comment on column bitacora_auditoria.accion is 'crear | modificar | anular | cambio_estado | aprobar | exportar.';
comment on column bitacora_auditoria.datos_antes is 'Valores antes del cambio.';
comment on column bitacora_auditoria.datos_despues is 'Valores después del cambio.';
comment on column bitacora_auditoria.usuario_id is 'Quién lo hizo.';
comment on column bitacora_auditoria.fecha_hora is 'Cuándo.';
comment on column bitacora_auditoria.creado_en is 'Fecha y hora de creación.';
comment on column bitacora_auditoria.creado_por is 'Usuario que creó el registro.';
comment on column bitacora_auditoria.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column bitacora_auditoria.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table respaldos is 'Historial de respaldos semanales y manuales.';
comment on column respaldos.id is 'Identificador único universal (UUID).';
comment on column respaldos.tipo is 'semanal | manual.';
comment on column respaldos.fecha_hora is 'Inicio del respaldo.';
comment on column respaldos.destino is 'google_drive | descarga.';
comment on column respaldos.nombre_archivo is 'Ej.: respaldo_2026-10-19.sql.gz';
comment on column respaldos.bytes is 'Tamaño.';
comment on column respaldos.estado is 'ok | error.';
comment on column respaldos.detalle is 'Mensaje de error si lo hubo.';
comment on column respaldos.creado_en is 'Fecha y hora de creación.';
comment on column respaldos.creado_por is 'Usuario que creó el registro.';
comment on column respaldos.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column respaldos.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table areas_taller is 'Áreas que ejecutan trabajos.';
comment on column areas_taller.id is 'Identificador único universal (UUID).';
comment on column areas_taller.nombre is 'Mecánico, Soldadura (internas); Lavadora, Talleres externos (externas).';
comment on column areas_taller.es_externo is 'Sí = el trabajo lo hace un proveedor.';
comment on column areas_taller.requiere_cotizacion is 'Sí = se pide cotización antes de enviar (Talleres externos). No en Lavadora.';
comment on column areas_taller.orden is 'Orden en listas.';
comment on column areas_taller.activo is 'Visible en listas.';
comment on column areas_taller.creado_en is 'Fecha y hora de creación.';
comment on column areas_taller.creado_por is 'Usuario que creó el registro.';
comment on column areas_taller.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column areas_taller.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table tecnicos is 'Personal que ejecuta trabajos, con o sin usuario propio.';
comment on column tecnicos.id is 'Identificador único universal (UUID).';
comment on column tecnicos.usuario_id is 'Si el técnico ingresa al sistema.';
comment on column tecnicos.nombres is 'Nombre completo.';
comment on column tecnicos.cedula is 'Cédula.';
comment on column tecnicos.telefono is 'Celular.';
comment on column tecnicos.area_taller_id is 'Área principal.';
comment on column tecnicos.activo is 'Disponible para asignar.';
comment on column tecnicos.creado_en is 'Fecha y hora de creación.';
comment on column tecnicos.creado_por is 'Usuario que creó el registro.';
comment on column tecnicos.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column tecnicos.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table tipos_vehiculo is 'Cabezal, plataforma, recolector, montacargas.';
comment on column tipos_vehiculo.id is 'Identificador único universal (UUID).';
comment on column tipos_vehiculo.prefijo_codigo is 'DC, DP, DR, MC.';
comment on column tipos_vehiculo.nombre is 'Cabezal, Plataforma, Recolector, Montacargas.';
comment on column tipos_vehiculo.unidad_medida is 'km | horas.';
comment on column tipos_vehiculo.diagrama is 'Nombre del dibujo usado para marcar daños.';
comment on column tipos_vehiculo.creado_en is 'Fecha y hora de creación.';
comment on column tipos_vehiculo.creado_por is 'Usuario que creó el registro.';
comment on column tipos_vehiculo.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column tipos_vehiculo.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table configuraciones_ejes is 'Distribución de ejes y llantas.';
comment on column configuraciones_ejes.id is 'Identificador único universal (UUID).';
comment on column configuraciones_ejes.nombre is 'Ej.: Cabezal 6x4, Plataforma 4x2, Recolector 6x4.';
comment on column configuraciones_ejes.numero_ejes is 'Cantidad de ejes.';
comment on column configuraciones_ejes.numero_llantas is 'Llantas montadas, sin contar el repuesto.';
comment on column configuraciones_ejes.descripcion is 'Notas.';
comment on column configuraciones_ejes.creado_en is 'Fecha y hora de creación.';
comment on column configuraciones_ejes.creado_por is 'Usuario que creó el registro.';
comment on column configuraciones_ejes.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column configuraciones_ejes.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table conductores is 'Conductores que entregan y reciben vehículos (sin usuario).';
comment on column conductores.id is 'Identificador único universal (UUID).';
comment on column conductores.cedula is 'Cédula.';
comment on column conductores.nombres is 'Nombres.';
comment on column conductores.apellidos is 'Apellidos.';
comment on column conductores.telefono is 'Celular para enviar el acta por WhatsApp.';
comment on column conductores.correo is 'Opcional.';
comment on column conductores.tipo_licencia is 'C, D, E…';
comment on column conductores.licencia_vence is 'Vencimiento de la licencia.';
comment on column conductores.activo is 'Disponible.';
comment on column conductores.creado_en is 'Fecha y hora de creación.';
comment on column conductores.creado_por is 'Usuario que creó el registro.';
comment on column conductores.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column conductores.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table vehiculos is 'La flota.';
comment on column vehiculos.id is 'Identificador único universal (UUID).';
comment on column vehiculos.codigo is 'Código interno: DC001, DP176.';
comment on column vehiculos.placa is 'Placa: GSA-4512. Vacía en montacargas.';
comment on column vehiculos.tipo_vehiculo_id is 'Tipo.';
comment on column vehiculos.configuracion_ejes_id is 'Configuración de ejes.';
comment on column vehiculos.marca is 'Hino, Volvo, Kenworth…';
comment on column vehiculos.modelo is 'Modelo.';
comment on column vehiculos.anio is 'Año de fabricación.';
comment on column vehiculos.numero_chasis is 'VIN o chasis.';
comment on column vehiculos.numero_motor is 'N.º de motor.';
comment on column vehiculos.color is 'Color.';
comment on column vehiculos.conductor_asignado_id is 'Conductor habitual.';
comment on column vehiculos.lectura_actual is 'Último km u horómetro confirmado.';
comment on column vehiculos.lectura_actual_fecha is 'Fecha de esa lectura.';
comment on column vehiculos.estado is 'activo | inactivo | baja.';
comment on column vehiculos.observaciones is 'Notas.';
comment on column vehiculos.creado_en is 'Fecha y hora de creación.';
comment on column vehiculos.creado_por is 'Usuario que creó el registro.';
comment on column vehiculos.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column vehiculos.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table categorias_gasto is 'Clasificación de cada trabajo (sin montos), para contar trabajos por categoría.';
comment on column categorias_gasto.id is 'Identificador único universal (UUID).';
comment on column categorias_gasto.nombre is 'Mantenimiento Preventivo, Mantenimiento Correctivo, Insumos, Llantas, Otros.';
comment on column categorias_gasto.grupo is 'Mantenimiento | Insumos | Llantas | Otros.';
comment on column categorias_gasto.orden is 'Orden en reportes.';
comment on column categorias_gasto.creado_en is 'Fecha y hora de creación.';
comment on column categorias_gasto.creado_por is 'Usuario que creó el registro.';
comment on column categorias_gasto.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column categorias_gasto.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table sistemas is 'Sistemas del vehículo.';
comment on column sistemas.id is 'Identificador único universal (UUID).';
comment on column sistemas.nombre is 'Motor, Caja, Corona, Embrague, Frenos, Suspensión, Dirección, Eléctrico, Llantas, Carrocería, Plataforma, Lavado, Otros.';
comment on column sistemas.categoria_preventivo_id is 'Categoría automática cuando el trabajo es preventivo.';
comment on column sistemas.categoria_correctivo_id is 'Categoría automática cuando es correctivo.';
comment on column sistemas.orden is 'Orden en listas.';
comment on column sistemas.activo is 'Visible.';
comment on column sistemas.creado_en is 'Fecha y hora de creación.';
comment on column sistemas.creado_por is 'Usuario que creó el registro.';
comment on column sistemas.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column sistemas.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table items_checklist is 'Elementos y documentos del checklist de ingreso y salida.';
comment on column items_checklist.id is 'Identificador único universal (UUID).';
comment on column items_checklist.nombre is 'Extintor vigente, Triángulos, Matrícula, SOAT…';
comment on column items_checklist.grupo is 'Seguridad | Documentos | Exterior | Carga.';
comment on column items_checklist.tipo_vehiculo_id is 'Vacío = aplica a todos.';
comment on column items_checklist.orden is 'Orden en pantalla.';
comment on column items_checklist.activo is 'Visible.';
comment on column items_checklist.creado_en is 'Fecha y hora de creación.';
comment on column items_checklist.creado_por is 'Usuario que creó el registro.';
comment on column items_checklist.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column items_checklist.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table repuestos is 'Catálogo de repuestos importado desde Excel del otro sistema.';
comment on column repuestos.id is 'Identificador único universal (UUID).';
comment on column repuestos.codigo is 'Código del sistema de origen.';
comment on column repuestos.descripcion is 'Descripción.';
comment on column repuestos.unidad is 'UND, GL, LT, M…';
comment on column repuestos.categoria_gasto_id is 'Categoría sugerida (ej. Insumos).';
comment on column repuestos.activo is 'Disponible para seleccionar.';
comment on column repuestos.creado_en is 'Fecha y hora de creación.';
comment on column repuestos.creado_por is 'Usuario que creó el registro.';
comment on column repuestos.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column repuestos.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table archivos is 'Índice de firmas y proformas. La base solo guarda la ruta, nunca el archivo.';
comment on column archivos.id is 'Identificador único universal (UUID).';
comment on column archivos.tipo is 'firma | proforma.';
comment on column archivos.categoria is 'firma_conductor | firma_recibe | firma_entrega | proforma.';
comment on column archivos.ruta is 'Ruta estándar: 2026/10/GSA-4512/AR-2026-00142/firma_conductor.png';
comment on column archivos.tipo_mime is 'image/png, image/webp, application/pdf.';
comment on column archivos.bytes is 'Tamaño.';
comment on column archivos.tabla_origen is 'Tabla dueña del archivo.';
comment on column archivos.registro_origen_id is 'Registro dueño del archivo.';
comment on column archivos.firmado_en is 'Fecha y hora de la firma o de la carga.';
comment on column archivos.usuario_id is 'Usuario que registró.';
comment on column archivos.anulado is 'Sí = registro anulado (no se borra).';
comment on column archivos.anulado_motivo is 'Motivo de la anulación (obligatorio al anular).';
comment on column archivos.anulado_por is 'Usuario que anuló.';
comment on column archivos.anulado_en is 'Fecha y hora de la anulación.';
comment on column archivos.creado_en is 'Fecha y hora de creación.';
comment on column archivos.creado_por is 'Usuario que creó el registro.';
comment on column archivos.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column archivos.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table actas_recepcion is 'Acta de recepción: la empresa recibe el vehículo de un conductor (cambio de conductor, vacaciones, fin de relación, ingreso a taller…). Documento independiente.';
comment on column actas_recepcion.id is 'Identificador único universal (UUID).';
comment on column actas_recepcion.numero is 'AR-2026-00001.';
comment on column actas_recepcion.id_local is 'Identificador generado en la tablet; evita duplicados al sincronizar sin conexión.';
comment on column actas_recepcion.vehiculo_id is 'Vehículo.';
comment on column actas_recepcion.conductor_id is 'Conductor que devuelve (entrega) el vehículo a la empresa.';
comment on column actas_recepcion.recibido_por is 'Responsable de la empresa que recibe el vehículo.';
comment on column actas_recepcion.fecha_hora is 'Automática al iniciar.';
comment on column actas_recepcion.lectura is 'Km u horómetro al recibir.';
comment on column actas_recepcion.lectura_hunter is 'Km estimado por Hunter en ese momento (referencia).';
comment on column actas_recepcion.combustible is 'E | 1/4 | 1/2 | 3/4 | F.';
comment on column actas_recepcion.motivo is 'cambio_conductor | vacaciones_permiso | fin_relacion | ingreso_taller | siniestro | otro.';
comment on column actas_recepcion.observaciones is 'Novedades que reporta el conductor y observaciones de quien recibe.';
comment on column actas_recepcion.firma_conductor_id is 'PNG de la firma.';
comment on column actas_recepcion.firma_recibe_id is 'PNG de la firma.';
comment on column actas_recepcion.estado is 'borrador | firmada. La anulación va en la columna anulado.';
comment on column actas_recepcion.anulado is 'Sí = registro anulado (no se borra).';
comment on column actas_recepcion.anulado_motivo is 'Motivo de la anulación (obligatorio al anular).';
comment on column actas_recepcion.anulado_por is 'Usuario que anuló.';
comment on column actas_recepcion.anulado_en is 'Fecha y hora de la anulación.';
comment on column actas_recepcion.creado_en is 'Fecha y hora de creación.';
comment on column actas_recepcion.creado_por is 'Usuario que creó el registro.';
comment on column actas_recepcion.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column actas_recepcion.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table checklist_recepcion is 'Resultado de cada ítem del checklist en el acta de recepción.';
comment on column checklist_recepcion.id is 'Identificador único universal (UUID).';
comment on column checklist_recepcion.acta_recepcion_id is 'Acta.';
comment on column checklist_recepcion.item_checklist_id is 'Ítem.';
comment on column checklist_recepcion.resultado is 'ok | falta | danado.';
comment on column checklist_recepcion.observacion is 'Obligatoria si no es ok.';
comment on column checklist_recepcion.creado_en is 'Fecha y hora de creación.';
comment on column checklist_recepcion.creado_por is 'Usuario que creó el registro.';
comment on column checklist_recepcion.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column checklist_recepcion.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table ordenes_trabajo is 'Orden de trabajo del taller. Se abre directamente al ingresar el vehículo; no depende de las actas.';
comment on column ordenes_trabajo.id is 'Identificador único universal (UUID).';
comment on column ordenes_trabajo.numero is 'OT-2026-00001.';
comment on column ordenes_trabajo.id_local is 'Identificador generado en la tablet; evita duplicados al sincronizar sin conexión.';
comment on column ordenes_trabajo.vehiculo_id is 'Heredado del acta.';
comment on column ordenes_trabajo.conductor_id is 'Conductor que trae el vehículo al taller (opcional).';
comment on column ordenes_trabajo.lectura is 'Km u horómetro al ingresar al taller.';
comment on column ordenes_trabajo.motivo_ingreso is 'preventivo | correctivo | llantas | siniestro | inspeccion.';
comment on column ordenes_trabajo.falla_reportada is 'Falla que reporta el conductor al ingresar.';
comment on column ordenes_trabajo.prioridad is 'alta | media | baja.';
comment on column ordenes_trabajo.inmovilizado is 'El vehículo no puede operar.';
comment on column ordenes_trabajo.estado is 'recepcion | diagnostico | cotizando | esperando_repuestos | en_reparacion | control_calidad | listo_entrega | entregado.';
comment on column ordenes_trabajo.diagnostico is 'Diagnóstico del jefe de taller.';
comment on column ordenes_trabajo.jefe_taller_id is 'Responsable.';
comment on column ordenes_trabajo.fecha_apertura is 'Ingreso del vehículo al taller (inicio del tiempo parado).';
comment on column ordenes_trabajo.fecha_cierre is 'Fecha y hora de cierre (vehículo entregado por el taller).';
comment on column ordenes_trabajo.horas_parado is 'Apertura → cierre, en horas. Se calcula al cerrar.';
comment on column ordenes_trabajo.total_horas_internas is 'Suma de horas de técnicos. Se calcula al cerrar.';
comment on column ordenes_trabajo.anulado is 'Sí = registro anulado (no se borra).';
comment on column ordenes_trabajo.anulado_motivo is 'Motivo de la anulación (obligatorio al anular).';
comment on column ordenes_trabajo.anulado_por is 'Usuario que anuló.';
comment on column ordenes_trabajo.anulado_en is 'Fecha y hora de la anulación.';
comment on column ordenes_trabajo.creado_en is 'Fecha y hora de creación.';
comment on column ordenes_trabajo.creado_por is 'Usuario que creó el registro.';
comment on column ordenes_trabajo.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column ordenes_trabajo.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table historial_estados_ot is 'Cada cambio de estado de la OT. Sirve para medir el tiempo en cada estado.';
comment on column historial_estados_ot.id is 'Identificador único universal (UUID).';
comment on column historial_estados_ot.orden_trabajo_id is 'OT.';
comment on column historial_estados_ot.estado_anterior is 'Estado de donde sale.';
comment on column historial_estados_ot.estado_nuevo is 'Estado al que entra.';
comment on column historial_estados_ot.fecha_hora is 'Cuándo.';
comment on column historial_estados_ot.usuario_id is 'Quién.';
comment on column historial_estados_ot.comentario is 'Opcional.';
comment on column historial_estados_ot.creado_en is 'Fecha y hora de creación.';
comment on column historial_estados_ot.creado_por is 'Usuario que creó el registro.';
comment on column historial_estados_ot.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column historial_estados_ot.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table lineas_trabajo is 'Cada trabajo dentro de una OT.';
comment on column lineas_trabajo.id is 'Identificador único universal (UUID).';
comment on column lineas_trabajo.orden_trabajo_id is 'OT.';
comment on column lineas_trabajo.numero_linea is '1, 2, 3…';
comment on column lineas_trabajo.sistema_id is 'Sistema intervenido.';
comment on column lineas_trabajo.tipo_mantenimiento is 'preventivo | correctivo.';
comment on column lineas_trabajo.area_taller_id is 'Mecánico, Soldadura, Lavadora o Externos.';
comment on column lineas_trabajo.ejecutor is 'interno | tercero.';
comment on column lineas_trabajo.descripcion is 'Qué se hace.';
comment on column lineas_trabajo.tecnico_id is 'Responsable.';
comment on column lineas_trabajo.horas_estimadas is 'Estimado.';
comment on column lineas_trabajo.estado is 'pendiente | en_proceso | esperando_repuestos | en_tercero | terminada.';
comment on column lineas_trabajo.categoria_gasto_id is 'Automática según sistema y tipo.';
comment on column lineas_trabajo.categoria_manual is 'Sí = alguien la cambió a mano.';
comment on column lineas_trabajo.anulado is 'Sí = registro anulado (no se borra).';
comment on column lineas_trabajo.anulado_motivo is 'Motivo de la anulación (obligatorio al anular).';
comment on column lineas_trabajo.anulado_por is 'Usuario que anuló.';
comment on column lineas_trabajo.anulado_en is 'Fecha y hora de la anulación.';
comment on column lineas_trabajo.creado_en is 'Fecha y hora de creación.';
comment on column lineas_trabajo.creado_por is 'Usuario que creó el registro.';
comment on column lineas_trabajo.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column lineas_trabajo.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table registros_horas is 'Horas trabajadas por técnico. Base de la productividad.';
comment on column registros_horas.id is 'Identificador único universal (UUID).';
comment on column registros_horas.linea_trabajo_id is 'Línea.';
comment on column registros_horas.tecnico_id is 'Técnico.';
comment on column registros_horas.fecha is 'Día trabajado.';
comment on column registros_horas.horas is 'Horas.';
comment on column registros_horas.nota is 'Avance.';
comment on column registros_horas.anulado is 'Sí = registro anulado (no se borra).';
comment on column registros_horas.anulado_motivo is 'Motivo de la anulación (obligatorio al anular).';
comment on column registros_horas.anulado_por is 'Usuario que anuló.';
comment on column registros_horas.anulado_en is 'Fecha y hora de la anulación.';
comment on column registros_horas.creado_en is 'Fecha y hora de creación.';
comment on column registros_horas.creado_por is 'Usuario que creó el registro.';
comment on column registros_horas.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column registros_horas.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table repuestos_linea is 'Repuestos e insumos usados. Sin montos.';
comment on column repuestos_linea.id is 'Identificador único universal (UUID).';
comment on column repuestos_linea.linea_trabajo_id is 'Línea.';
comment on column repuestos_linea.repuesto_id is 'Del catálogo, si existe.';
comment on column repuestos_linea.codigo is 'Código (copiado).';
comment on column repuestos_linea.descripcion is 'Descripción (copiada).';
comment on column repuestos_linea.cantidad is 'Cantidad.';
comment on column repuestos_linea.unidad is 'Unidad.';
comment on column repuestos_linea.origen is 'bodega_s3 | orden_compra | tercero.';
comment on column repuestos_linea.numero_documento is 'N.º de S3 u OC.';
comment on column repuestos_linea.categoria_gasto_id is 'Normalmente la de la línea; Insumos para aceites, filtros, etc.';
comment on column repuestos_linea.anulado is 'Sí = registro anulado (no se borra).';
comment on column repuestos_linea.anulado_motivo is 'Motivo de la anulación (obligatorio al anular).';
comment on column repuestos_linea.anulado_por is 'Usuario que anuló.';
comment on column repuestos_linea.anulado_en is 'Fecha y hora de la anulación.';
comment on column repuestos_linea.creado_en is 'Fecha y hora de creación.';
comment on column repuestos_linea.creado_por is 'Usuario que creó el registro.';
comment on column repuestos_linea.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column repuestos_linea.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table comentarios_ot is 'Comentarios internos.';
comment on column comentarios_ot.id is 'Identificador único universal (UUID).';
comment on column comentarios_ot.orden_trabajo_id is 'OT.';
comment on column comentarios_ot.usuario_id is 'Autor.';
comment on column comentarios_ot.fecha_hora is 'Cuándo.';
comment on column comentarios_ot.texto is 'Comentario.';
comment on column comentarios_ot.anulado is 'Sí = registro anulado (no se borra).';
comment on column comentarios_ot.anulado_motivo is 'Motivo de la anulación (obligatorio al anular).';
comment on column comentarios_ot.anulado_por is 'Usuario que anuló.';
comment on column comentarios_ot.anulado_en is 'Fecha y hora de la anulación.';
comment on column comentarios_ot.creado_en is 'Fecha y hora de creación.';
comment on column comentarios_ot.creado_por is 'Usuario que creó el registro.';
comment on column comentarios_ot.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column comentarios_ot.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table actas_entrega is 'Acta de entrega: la empresa entrega (asigna) el vehículo a un conductor. Documento independiente.';
comment on column actas_entrega.id is 'Identificador único universal (UUID).';
comment on column actas_entrega.numero is 'AE-2026-00001.';
comment on column actas_entrega.id_local is 'Identificador generado en la tablet; evita duplicados al sincronizar sin conexión.';
comment on column actas_entrega.vehiculo_id is 'Vehículo.';
comment on column actas_entrega.fecha_hora is 'Fecha y hora de la entrega.';
comment on column actas_entrega.lectura is 'Km u horómetro al entregar.';
comment on column actas_entrega.combustible is 'E | 1/4 | 1/2 | 3/4 | F.';
comment on column actas_entrega.conductor_id is 'Conductor que recibe el vehículo (queda asignado a él).';
comment on column actas_entrega.entregado_por is 'Responsable de la empresa que entrega el vehículo.';
comment on column actas_entrega.motivo is 'asignacion | cambio_conductor | reemplazo_temporal | salida_taller | otro.';
comment on column actas_entrega.observaciones is 'Observaciones de la entrega.';
comment on column actas_entrega.firma_conductor_id is 'PNG de la firma del conductor que recibe.';
comment on column actas_entrega.firma_entrega_id is 'PNG de la firma del responsable que entrega.';
comment on column actas_entrega.estado is 'borrador | firmada. La anulación va en la columna anulado.';
comment on column actas_entrega.anulado is 'Sí = registro anulado (no se borra).';
comment on column actas_entrega.anulado_motivo is 'Motivo de la anulación (obligatorio al anular).';
comment on column actas_entrega.anulado_por is 'Usuario que anuló.';
comment on column actas_entrega.anulado_en is 'Fecha y hora de la anulación.';
comment on column actas_entrega.creado_en is 'Fecha y hora de creación.';
comment on column actas_entrega.creado_por is 'Usuario que creó el registro.';
comment on column actas_entrega.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column actas_entrega.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table checklist_entrega is 'Resultado de cada ítem del checklist en el acta de entrega.';
comment on column checklist_entrega.id is 'Identificador único universal (UUID).';
comment on column checklist_entrega.acta_entrega_id is 'Acta.';
comment on column checklist_entrega.item_checklist_id is 'Ítem.';
comment on column checklist_entrega.resultado is 'ok | falta | danado.';
comment on column checklist_entrega.observacion is 'Obligatoria si no es ok.';
comment on column checklist_entrega.creado_en is 'Fecha y hora de creación.';
comment on column checklist_entrega.creado_por is 'Usuario que creó el registro.';
comment on column checklist_entrega.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column checklist_entrega.actualizado_por is 'Usuario que hizo la última modificación.';

comment on table danos_vehiculo is 'Marcas del diagrama de daños registradas en un acta de entrega o de recepción.';
comment on column danos_vehiculo.id is 'Identificador único universal (UUID).';
comment on column danos_vehiculo.vehiculo_id is 'Vehículo.';
comment on column danos_vehiculo.acta_recepcion_id is 'Acta de recepción donde se registró (si aplica).';
comment on column danos_vehiculo.acta_entrega_id is 'Acta de entrega donde se registró (si aplica).';
comment on column danos_vehiculo.numero_marca is 'N.º visible en el dibujo.';
comment on column danos_vehiculo.vista is 'frontal | posterior | izquierda | derecha.';
comment on column danos_vehiculo.posicion_x is 'Horizontal de 0 a 1 (independiente del tamaño de pantalla).';
comment on column danos_vehiculo.posicion_y is 'Vertical de 0 a 1.';
comment on column danos_vehiculo.tipo_dano is 'golpe | rayon | rotura | oxidacion | otro.';
comment on column danos_vehiculo.descripcion is 'Detalle escrito del daño.';
comment on column danos_vehiculo.situacion is 'registrado | reparado.';
comment on column danos_vehiculo.anulado is 'Sí = registro anulado (no se borra).';
comment on column danos_vehiculo.anulado_motivo is 'Motivo de la anulación (obligatorio al anular).';
comment on column danos_vehiculo.anulado_por is 'Usuario que anuló.';
comment on column danos_vehiculo.anulado_en is 'Fecha y hora de la anulación.';
comment on column danos_vehiculo.creado_en is 'Fecha y hora de creación.';
comment on column danos_vehiculo.creado_por is 'Usuario que creó el registro.';
comment on column danos_vehiculo.actualizado_en is 'Fecha y hora de la última modificación.';
comment on column danos_vehiculo.actualizado_por is 'Usuario que hizo la última modificación.';


-- >>>>>>>>>>>>>>>>>>>> 003_funciones.sql
set client_min_messages = warning;
-- =====================================================================
-- 003 · Funciones, reglas y auditoría (PL/pgSQL estándar)
-- =====================================================================

-- --------------------------------------------------------------- Rol actual
create or replace function rol_actual() returns text
language sql stable security definer set search_path = public as $$
  select rol from usuarios where id = usuario_actual() and activo
$$;

-- ---------------------------------------------- Columnas comunes automáticas
create or replace function tg_columnas_comunes() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    new.creado_en := coalesce(new.creado_en, now());
    new.creado_por := coalesce(new.creado_por, usuario_actual());
  else
    new.creado_en := old.creado_en;
    new.creado_por := old.creado_por;
    new.actualizado_en := now();
    new.actualizado_por := usuario_actual();
  end if;
  return new;
end $$;

-- -------------------------------------------------------- Anulación con datos
create or replace function tg_anulacion() returns trigger
language plpgsql as $$
begin
  if new.anulado and not old.anulado then
    new.anulado_en := now();
    new.anulado_por := usuario_actual();
  elsif old.anulado and not new.anulado then
    raise exception 'Un registro anulado no se puede reactivar.';
  end if;
  return new;
end $$;

-- ---------------------------------------------------------- Nadie borra nada
create or replace function tg_prohibir_borrado() returns trigger
language plpgsql as $$
begin
  raise exception 'No se permite borrar registros de %. Use "anular" con un motivo.', tg_table_name;
end $$;

-- -------------------------------------------------------- Bitácora auditoría
create or replace function tg_auditoria() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_accion text;
begin
  if tg_op = 'INSERT' then
    v_accion := 'crear';
  elsif to_jsonb(new) ? 'anulado' and (to_jsonb(new)->>'anulado')::boolean
        and not (to_jsonb(old)->>'anulado')::boolean then
    v_accion := 'anular';
  else
    v_accion := 'modificar';
  end if;
  insert into bitacora_auditoria (tabla, registro_id, accion, datos_antes, datos_despues, usuario_id)
  values (tg_table_name, (to_jsonb(new)->>'id')::uuid, v_accion,
          case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new), usuario_actual());
  return null;
end $$;

-- Aplica los disparadores a todas las tablas del esquema (excepto bitácora)
do $$
declare t record;
begin
  for t in select table_name from information_schema.tables
           where table_schema = 'public' and table_type = 'BASE TABLE'
             and table_name not in ('bitacora_auditoria')
  loop
    execute format('drop trigger if exists t1_columnas_comunes on %I', t.table_name);
    execute format('create trigger t1_columnas_comunes before insert or update on %I
                    for each row execute function tg_columnas_comunes()', t.table_name);
    execute format('drop trigger if exists t9_auditoria on %I', t.table_name);
    if t.table_name not in ('contadores_documento') then
      execute format('create trigger t9_auditoria after insert or update on %I
                      for each row execute function tg_auditoria()', t.table_name);
    end if;
    if exists (select 1 from information_schema.columns
               where table_schema='public' and table_name=t.table_name and column_name='anulado') then
      execute format('drop trigger if exists t2_anulacion on %I', t.table_name);
      execute format('create trigger t2_anulacion before update on %I
                      for each row execute function tg_anulacion()', t.table_name);
    end if;
  end loop;
  for t in select table_name from information_schema.tables
           where table_schema = 'public' and table_type = 'BASE TABLE'
  loop
    execute format('drop trigger if exists t0_sin_borrar on %I', t.table_name);
    execute format('create trigger t0_sin_borrar before delete on %I
                    for each row execute function tg_prohibir_borrado()', t.table_name);
  end loop;
end $$;

-- ------------------------------------------------------ Numeración correlativa
-- Devuelve por ejemplo 'OT-2026-00001'. Sin saltos ni repetidos aunque dos
-- personas guarden al mismo tiempo.
create or replace function siguiente_numero(p_tipo text) returns text
language plpgsql security definer set search_path = public as $$
declare v_anio int := extract(year from (now() at time zone 'America/Guayaquil'));
        v_num int;
begin
  insert into contadores_documento (tipo_documento, anio, ultimo_numero)
  values (p_tipo, v_anio, 1)
  on conflict (tipo_documento, anio)
  do update set ultimo_numero = contadores_documento.ultimo_numero + 1
  returning ultimo_numero into v_num;
  return p_tipo || '-' || v_anio || '-' || lpad(v_num::text, 5, '0');
end $$;
revoke all on function siguiente_numero(text) from public;

-- ------------------------------------------------- Línea de trabajo: número y categoría
create or replace function tg_linea_trabajo() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    select coalesce(max(numero_linea), 0) + 1 into new.numero_linea
      from lineas_trabajo where orden_trabajo_id = new.orden_trabajo_id;
  end if;
  if exists (select 1 from areas_taller where id = new.area_taller_id and es_externo) then
    new.ejecutor := 'tercero';
  end if;
  if not new.categoria_manual then
    select case when new.tipo_mantenimiento = 'preventivo'
                then categoria_preventivo_id else categoria_correctivo_id end
      into new.categoria_gasto_id from sistemas where id = new.sistema_id;
  end if;
  if exists (select 1 from ordenes_trabajo where id = new.orden_trabajo_id and estado = 'entregado')
     and (tg_op = 'INSERT' or new.estado is distinct from old.estado) then
    raise exception 'La OT ya está cerrada; no se pueden agregar ni cambiar trabajos.';
  end if;
  return new;
end $$;
create trigger t3_linea_trabajo before insert or update on lineas_trabajo
  for each row execute function tg_linea_trabajo();

-- ============================================ Actas de asignación (independientes)
-- Las funciones de actas y de apertura de OT validan el rol y luego actúan con
-- permisos del sistema (security definer) para poder actualizar el vehículo
-- (lectura y conductor asignado) aunque las registre un técnico.
-- Cada acta se registra en 2 pasos: (1) datos + número, (2) firmas.
-- Ambos pasos son idempotentes (se pueden repetir sin duplicar).

create or replace function registrar_acta(p_tipo text, p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_veh vehiculos; v_id uuid; v_num text; v_estado text; v_item jsonb; v_dano jsonb;
begin
  if p_tipo not in ('recepcion','entrega') then raise exception 'Tipo de acta no válido.'; end if;
  if coalesce(rol_actual(), '') not in ('administrador','jefe_taller','tecnico') then
    raise exception 'Su usuario no puede registrar actas.';
  end if;
  if p_tipo = 'recepcion' then
    select id, numero, estado into v_id, v_num, v_estado from actas_recepcion where id_local = (p->>'id_local')::uuid;
  else
    select id, numero, estado into v_id, v_num, v_estado from actas_entrega where id_local = (p->>'id_local')::uuid;
  end if;
  if v_id is not null then
    return jsonb_build_object('acta_id', v_id, 'numero', v_num, 'estado', v_estado);
  end if;

  select * into v_veh from vehiculos where id = (p->>'vehiculo_id')::uuid;
  if not found then raise exception 'Vehículo no encontrado.'; end if;
  if (p->>'lectura')::numeric < v_veh.lectura_actual then
    raise exception 'La lectura (%) es menor a la última registrada para % (%).',
      p->>'lectura', v_veh.codigo, v_veh.lectura_actual;
  end if;

  if p_tipo = 'recepcion' then
    insert into actas_recepcion (numero, id_local, vehiculo_id, conductor_id, recibido_por, fecha_hora,
           lectura, lectura_hunter, combustible, motivo, observaciones)
    values (siguiente_numero('AR'), (p->>'id_local')::uuid, v_veh.id, (p->>'conductor_id')::uuid,
            usuario_actual(), coalesce((p->>'fecha_hora')::timestamptz, now()),
            (p->>'lectura')::numeric, (p->>'lectura_hunter')::numeric, p->>'combustible',
            p->>'motivo', p->>'observaciones')
    returning id, numero, estado into v_id, v_num, v_estado;
  else
    insert into actas_entrega (numero, id_local, vehiculo_id, conductor_id, entregado_por, fecha_hora,
           lectura, combustible, motivo, observaciones)
    values (siguiente_numero('AE'), (p->>'id_local')::uuid, v_veh.id, (p->>'conductor_id')::uuid,
            usuario_actual(), coalesce((p->>'fecha_hora')::timestamptz, now()),
            (p->>'lectura')::numeric, p->>'combustible', p->>'motivo', p->>'observaciones')
    returning id, numero, estado into v_id, v_num, v_estado;
  end if;

  for v_item in select * from jsonb_array_elements(coalesce(p->'checklist','[]'::jsonb)) loop
    if p_tipo = 'recepcion' then
      insert into checklist_recepcion (acta_recepcion_id, item_checklist_id, resultado, observacion)
      values (v_id, (v_item->>'item_checklist_id')::uuid, v_item->>'resultado', v_item->>'observacion');
    else
      insert into checklist_entrega (acta_entrega_id, item_checklist_id, resultado, observacion)
      values (v_id, (v_item->>'item_checklist_id')::uuid, v_item->>'resultado', v_item->>'observacion');
    end if;
  end loop;
  for v_dano in select * from jsonb_array_elements(coalesce(p->'danos','[]'::jsonb)) loop
    insert into danos_vehiculo (vehiculo_id, acta_recepcion_id, acta_entrega_id, numero_marca, vista,
           posicion_x, posicion_y, tipo_dano, descripcion)
    values (v_veh.id, case when p_tipo = 'recepcion' then v_id end, case when p_tipo = 'entrega' then v_id end,
            (v_dano->>'numero_marca')::int, v_dano->>'vista', (v_dano->>'posicion_x')::numeric,
            (v_dano->>'posicion_y')::numeric, v_dano->>'tipo_dano', v_dano->>'descripcion');
  end loop;
  return jsonb_build_object('acta_id', v_id, 'numero', v_num, 'estado', v_estado);
end $$;

-- Paso 2: guarda las firmas (PNG ya subidos), marca el acta como firmada,
-- actualiza la lectura del vehículo y su conductor asignado.
create or replace function firmar_acta(p_tipo text, p_acta uuid, p_ruta_firma_conductor text, p_ruta_firma_responsable text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_num text; v_estado text; v_veh uuid; v_cond uuid; v_lect numeric; v_fecha timestamptz;
        v_tabla text := case when p_tipo = 'recepcion' then 'actas_recepcion' else 'actas_entrega' end;
        v_f1 uuid; v_f2 uuid;
begin
  if coalesce(rol_actual(), '') not in ('administrador','jefe_taller','tecnico') then
    raise exception 'Su usuario no puede firmar actas.';
  end if;
  if p_tipo = 'recepcion' then
    select numero, estado, vehiculo_id, conductor_id, lectura, fecha_hora into v_num, v_estado, v_veh, v_cond, v_lect, v_fecha
      from actas_recepcion where id = p_acta for update;
  elsif p_tipo = 'entrega' then
    select numero, estado, vehiculo_id, conductor_id, lectura, fecha_hora into v_num, v_estado, v_veh, v_cond, v_lect, v_fecha
      from actas_entrega where id = p_acta for update;
  else raise exception 'Tipo de acta no válido.';
  end if;
  if v_num is null then raise exception 'Acta no encontrada.'; end if;
  if v_estado = 'firmada' then return jsonb_build_object('acta_numero', v_num); end if;
  if coalesce(p_ruta_firma_conductor,'') = '' or coalesce(p_ruta_firma_responsable,'') = '' then
    raise exception 'Faltan las firmas del conductor y del responsable.';
  end if;

  insert into archivos (tipo, categoria, ruta, tipo_mime, tabla_origen, registro_origen_id, usuario_id)
  values ('firma','firma_conductor', p_ruta_firma_conductor, 'image/png', v_tabla, p_acta, usuario_actual())
  on conflict (ruta) do update set ruta = excluded.ruta returning id into v_f1;
  insert into archivos (tipo, categoria, ruta, tipo_mime, tabla_origen, registro_origen_id, usuario_id)
  values ('firma', case when p_tipo = 'recepcion' then 'firma_recibe' else 'firma_entrega' end,
          p_ruta_firma_responsable, 'image/png', v_tabla, p_acta, usuario_actual())
  on conflict (ruta) do update set ruta = excluded.ruta returning id into v_f2;

  if p_tipo = 'recepcion' then
    update actas_recepcion set estado = 'firmada', firma_conductor_id = v_f1, firma_recibe_id = v_f2 where id = p_acta;
    -- El conductor deja de tener asignado el vehículo
    update vehiculos set conductor_asignado_id = null where id = v_veh and conductor_asignado_id = v_cond;
  else
    update actas_entrega set estado = 'firmada', firma_conductor_id = v_f1, firma_entrega_id = v_f2 where id = p_acta;
    -- El vehículo queda asignado al conductor que lo recibe
    update vehiculos set conductor_asignado_id = v_cond where id = v_veh;
  end if;
  update vehiculos set lectura_actual = v_lect, lectura_actual_fecha = v_fecha
   where id = v_veh and lectura_actual <= v_lect;
  return jsonb_build_object('acta_numero', v_num);
end $$;

-- ============================================ Orden de trabajo
-- Se abre directamente al ingresar el vehículo al taller. Idempotente por id_local.
create or replace function abrir_ot(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_ot ordenes_trabajo; v_veh vehiculos; v_abierta text;
begin
  if coalesce(rol_actual(), '') not in ('administrador','jefe_taller','tecnico') then
    raise exception 'Su usuario no puede abrir órdenes de trabajo.';
  end if;
  select * into v_ot from ordenes_trabajo where id_local = (p->>'id_local')::uuid;
  if found then return jsonb_build_object('ot_id', v_ot.id, 'ot_numero', v_ot.numero); end if;
  select * into v_veh from vehiculos where id = (p->>'vehiculo_id')::uuid;
  if not found then raise exception 'Vehículo no encontrado.'; end if;
  if (p->>'lectura')::numeric < v_veh.lectura_actual then
    raise exception 'La lectura (%) es menor a la última registrada para % (%).',
      p->>'lectura', v_veh.codigo, v_veh.lectura_actual;
  end if;
  select numero into v_abierta from ordenes_trabajo
   where vehiculo_id = v_veh.id and estado <> 'entregado' and not anulado limit 1;
  if v_abierta is not null then
    raise exception 'El vehículo % ya tiene la orden % abierta. Ciérrela o anúlela antes de abrir otra.', v_veh.codigo, v_abierta;
  end if;
  insert into ordenes_trabajo (numero, id_local, vehiculo_id, conductor_id, lectura, motivo_ingreso, falla_reportada,
         prioridad, inmovilizado, estado, jefe_taller_id, fecha_apertura)
  values (siguiente_numero('OT'), (p->>'id_local')::uuid, v_veh.id, (p->>'conductor_id')::uuid, (p->>'lectura')::numeric,
          p->>'motivo_ingreso', p->>'falla_reportada', coalesce(p->>'prioridad','media'),
          coalesce((p->>'inmovilizado')::boolean, false), 'recepcion',
          case when rol_actual() = 'jefe_taller' then usuario_actual() end,
          coalesce((p->>'fecha_hora')::timestamptz, now()))
  returning * into v_ot;
  insert into historial_estados_ot (orden_trabajo_id, estado_anterior, estado_nuevo, fecha_hora, usuario_id, comentario)
  values (v_ot.id, null, 'recepcion', v_ot.fecha_apertura, usuario_actual(), 'Ingreso al taller');
  update vehiculos set lectura_actual = v_ot.lectura, lectura_actual_fecha = v_ot.fecha_apertura
   where id = v_veh.id and lectura_actual <= v_ot.lectura;
  return jsonb_build_object('ot_id', v_ot.id, 'ot_numero', v_ot.numero);
end $$;

-- Cambio de estado. Pasar a "entregado" cierra la OT (todos los trabajos
-- deben estar terminados o anulados) y calcula el tiempo de vehículo parado.
create or replace function cambiar_estado_ot(p_ot uuid, p_estado text, p_comentario text default null)
returns void language plpgsql set search_path = public as $$
declare v_ot ordenes_trabajo;
begin
  if coalesce(rol_actual(), '') not in ('administrador','jefe_taller') then
    raise exception 'Solo el jefe de taller puede cambiar el estado de la OT.';
  end if;
  select * into v_ot from ordenes_trabajo where id = p_ot for update;
  if not found then raise exception 'OT no encontrada.'; end if;
  if v_ot.anulado then raise exception 'La OT está anulada.'; end if;
  if v_ot.estado = 'entregado' then raise exception 'La OT ya está cerrada.'; end if;
  if p_estado = v_ot.estado then return; end if;
  if p_estado in ('listo_entrega','entregado') and exists (
       select 1 from lineas_trabajo where orden_trabajo_id = p_ot and not anulado and estado <> 'terminada') then
    raise exception 'Hay trabajos sin terminar. Termínelos o anúlelos antes de pasar a "%".',
      case when p_estado = 'entregado' then 'Entregado / cerrado' else 'Listo para entrega' end;
  end if;
  if p_estado = 'entregado' and not exists (
       select 1 from lineas_trabajo where orden_trabajo_id = p_ot and not anulado) then
    raise exception 'La OT no tiene trabajos registrados. Agregue al menos uno o anule la OT.';
  end if;
  if p_estado = 'entregado' then
    update ordenes_trabajo set
       estado = 'entregado', fecha_cierre = now(),
       horas_parado = round((extract(epoch from (now() - fecha_apertura)) / 3600)::numeric, 1),
       total_horas_internas = (select coalesce(sum(h.horas),0) from registros_horas h
                                 join lineas_trabajo l on l.id = h.linea_trabajo_id
                                where l.orden_trabajo_id = p_ot and not h.anulado and not l.anulado)
     where id = p_ot;
  else
    update ordenes_trabajo set estado = p_estado where id = p_ot;
  end if;
  insert into historial_estados_ot (orden_trabajo_id, estado_anterior, estado_nuevo, usuario_id, comentario)
  values (p_ot, v_ot.estado, p_estado, usuario_actual(), p_comentario);
end $$;

-- ============================================ Vistas de consulta
create or replace view v_tablero_ot with (security_invoker = true) as
select o.id, o.numero, o.estado, o.prioridad, o.inmovilizado, o.fecha_apertura, o.fecha_cierre,
       o.lectura, o.motivo_ingreso, o.falla_reportada, o.diagnostico, o.anulado, o.conductor_id,
       v.id as vehiculo_id, v.codigo, v.placa, t.nombre as tipo_vehiculo, t.unidad_medida,
       round((extract(epoch from (coalesce(o.fecha_cierre, now()) - o.fecha_apertura)) / 3600)::numeric, 1) as horas_parado_actual,
       (select max(h.fecha_hora) from historial_estados_ot h where h.orden_trabajo_id = o.id) as desde_estado,
       (select count(*) from lineas_trabajo l where l.orden_trabajo_id = o.id and not l.anulado) as lineas,
       (select count(*) from lineas_trabajo l where l.orden_trabajo_id = o.id and not l.anulado and l.estado = 'terminada') as lineas_terminadas
  from ordenes_trabajo o
  join vehiculos v on v.id = o.vehiculo_id
  join tipos_vehiculo t on t.id = v.tipo_vehiculo_id;

-- Todas las actas (entrega y recepción) en una sola lista
create or replace view v_actas with (security_invoker = true) as
select 'recepcion'::text as tipo, a.id, a.numero, a.fecha_hora, a.vehiculo_id, v.codigo, v.placa,
       a.conductor_id, c.nombres || ' ' || c.apellidos as conductor, c.telefono as conductor_telefono,
       a.recibido_por as responsable_id, a.lectura, a.combustible, a.motivo, a.estado, a.anulado, a.anulado_motivo
  from actas_recepcion a join vehiculos v on v.id = a.vehiculo_id join conductores c on c.id = a.conductor_id
union all
select 'entrega', e.id, e.numero, e.fecha_hora, e.vehiculo_id, v.codigo, v.placa,
       e.conductor_id, c.nombres || ' ' || c.apellidos, c.telefono,
       e.entregado_por, e.lectura, e.combustible, e.motivo, e.estado, e.anulado, e.anulado_motivo
  from actas_entrega e join vehiculos v on v.id = e.vehiculo_id join conductores c on c.id = e.conductor_id;

create or replace view v_lineas_trabajo with (security_invoker = true) as
select l.*, s.nombre as sistema, ar.nombre as area, ar.es_externo, te.nombres as tecnico,
       te.usuario_id as tecnico_usuario_id, c.nombre as categoria_gasto,
       (select coalesce(sum(h.horas),0) from registros_horas h where h.linea_trabajo_id = l.id and not h.anulado) as horas_reales
  from lineas_trabajo l
  join sistemas s on s.id = l.sistema_id
  join areas_taller ar on ar.id = l.area_taller_id
  left join tecnicos te on te.id = l.tecnico_id
  left join categorias_gasto c on c.id = l.categoria_gasto_id;

-- Diccionario de datos siempre actualizado, leído del propio catálogo de PostgreSQL.
create or replace view v_diccionario_datos with (security_invoker = true) as
select c.relname::text as tabla,
       obj_description(c.oid, 'pg_class') as descripcion_tabla,
       a.attnum::int as orden,
       a.attname::text as campo,
       replace(format_type(a.atttypid, a.atttypmod), 'timestamp with time zone', 'timestamptz') as tipo,
       a.attnotnull as obligatorio,
       col_description(c.oid, a.attnum) as significado
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  join pg_attribute a on a.attrelid = c.oid
 where n.nspname = 'public' and c.relkind = 'r' and a.attnum > 0 and not a.attisdropped
 order by 1, 3;

-- >>>>>>>>>>>>>>>>>>>> 004_seguridad.sql
set client_min_messages = warning;
-- =====================================================================
-- 004 · Permisos por rol (Row Level Security de PostgreSQL)
-- Requiere los roles "authenticated" y "anon" (Supabase ya los trae).
-- Nadie tiene permiso de borrar: los registros se anulan.
-- =====================================================================

do $$
declare t record;
  -- Catálogos que solo modifica el administrador
  solo_admin text[] := array['configuracion','areas_taller','tipos_vehiculo','configuraciones_ejes',
                             'categorias_gasto','sistemas','items_checklist'];
  -- Catálogos que modifican administrador y jefe de taller
  admin_jefe text[] := array['vehiculos','conductores','tecnicos','repuestos'];
  -- Movimientos del taller (administrador, jefe de taller y técnico)
  operativas text[] := array['actas_recepcion','checklist_recepcion','actas_entrega','checklist_entrega','danos_vehiculo','archivos',
                             'lineas_trabajo','registros_horas','repuestos_linea','comentarios_ot',
                             'historial_estados_ot'];
  -- Solo administrador y jefe de taller
  jefe text[] := array['ordenes_trabajo'];
begin
  for t in select table_name from information_schema.tables
           where table_schema='public' and table_type='BASE TABLE' loop
    execute format('alter table %I enable row level security', t.table_name);
    execute format('drop policy if exists leer on %I', t.table_name);
    execute format('drop policy if exists crear on %I', t.table_name);
    execute format('drop policy if exists modificar on %I', t.table_name);

    if t.table_name in ('bitacora_auditoria','respaldos') then
      execute format($p$create policy leer on %I for select to authenticated
                        using (rol_actual() = 'administrador')$p$, t.table_name);
      continue;
    end if;
    if t.table_name = 'contadores_documento' then
      continue;  -- solo a través de siguiente_numero()
    end if;

    execute format($p$create policy leer on %I for select to authenticated
                      using (rol_actual() is not null)$p$, t.table_name);

    if t.table_name = 'usuarios' then
      execute $p$create policy modificar on usuarios for update to authenticated
                 using (rol_actual() = 'administrador') with check (rol_actual() = 'administrador')$p$;
    elsif t.table_name = any(solo_admin) then
      execute format($p$create policy crear on %I for insert to authenticated
                        with check (rol_actual() = 'administrador')$p$, t.table_name);
      execute format($p$create policy modificar on %I for update to authenticated
                        using (rol_actual() = 'administrador')$p$, t.table_name);
    elsif t.table_name = any(admin_jefe) or t.table_name = any(jefe) then
      execute format($p$create policy crear on %I for insert to authenticated
                        with check (rol_actual() in ('administrador','jefe_taller'))$p$, t.table_name);
      execute format($p$create policy modificar on %I for update to authenticated
                        using (rol_actual() in ('administrador','jefe_taller'))$p$, t.table_name);
    elsif t.table_name = any(operativas) then
      execute format($p$create policy crear on %I for insert to authenticated
                        with check (rol_actual() in ('administrador','jefe_taller','tecnico'))$p$, t.table_name);
      execute format($p$create policy modificar on %I for update to authenticated
                        using (rol_actual() in ('administrador','jefe_taller','tecnico'))$p$, t.table_name);
    end if;
  end loop;
end $$;

-- Las funciones de negocio corren con los permisos del usuario que las llama
grant execute on function registrar_acta(text,jsonb), firmar_acta(text,uuid,text,text), abrir_ot(jsonb),
      cambiar_estado_ot(uuid,text,text), rol_actual(), usuario_actual() to authenticated;
grant execute on function siguiente_numero(text) to authenticated;
grant select on v_tablero_ot, v_lineas_trabajo, v_actas to authenticated;
revoke all on v_diccionario_datos from anon, authenticated;
grant select on v_diccionario_datos to authenticated;
revoke all on all tables in schema public from anon;

-- Las funciones de negocio no se pueden llamar sin iniciar sesión
revoke execute on function registrar_acta(text,jsonb), firmar_acta(text,uuid,text,text), abrir_ot(jsonb),
       cambiar_estado_ot(uuid,text,text), siguiente_numero(text) from public, anon;

-- >>>>>>>>>>>>>>>>>>>> 005_supabase.sql
set client_min_messages = warning;
-- =====================================================================
-- 005 · Ajustes propios de Supabase (inicio de sesión y almacenamiento)
-- Es el ÚNICO archivo que depende de Supabase. Si se migra a otro
-- servidor, este archivo se reemplaza por el equivalente del nuevo
-- sistema de usuarios y de archivos (ver LEEME.md).
-- =====================================================================

-- Al crear un usuario en Supabase Auth se crea su ficha en "usuarios",
-- SIEMPRE inactiva y con rol "consulta". Solo un administrador la activa y le
-- da rol (desde la pantalla Usuarios o la función /api/usuarios). Así nadie
-- puede darse permisos a sí mismo aunque logre registrarse.
create or replace function public.tg_nuevo_usuario_auth() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.usuarios (id, nombre_completo, correo, rol, telefono, activo)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'nombre_completo', split_part(new.email, '@', 1)),
          new.email, 'consulta', new.raw_user_meta_data->>'telefono', false)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists al_crear_usuario on auth.users;
create trigger al_crear_usuario after insert on auth.users
  for each row execute function public.tg_nuevo_usuario_auth();

-- Carpeta privada para firmas (PNG) y proformas.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('archivos', 'archivos', false, 512000, array['image/png','image/webp','image/jpeg','application/pdf'])
on conflict (id) do nothing;

drop policy if exists "archivos_leer" on storage.objects;
create policy "archivos_leer" on storage.objects for select to authenticated
  using (bucket_id = 'archivos' and public.rol_actual() is not null);

drop policy if exists "archivos_subir" on storage.objects;
create policy "archivos_subir" on storage.objects for insert to authenticated
  with check (bucket_id = 'archivos' and public.rol_actual() in ('administrador','jefe_taller','tecnico'));

-- >>>>>>>>>>>>>>>>>>>> 006_datos_iniciales.sql
-- =====================================================================
-- 006 · Catálogos iniciales (se pueden editar después desde la app)
-- =====================================================================

insert into configuracion (clave, valor, tipo_dato, descripcion) values
 ('nombre_empresa','DISTRILÓGICO','texto','Nombre que aparece en el encabezado de los PDF.'),
 ('ruc_empresa','0990000000001','texto','RUC que aparece en los PDF.'),
 ('direccion_empresa','Guayaquil, Ecuador','texto','Dirección para los PDF.'),
 ('telefono_empresa','','texto','Teléfono para los PDF.'),
 ('diferencia_max_hunter_km','500','numero','Aviso si el km del acta difiere más que esto del km estimado por Hunter.'),
 ('limite_aprobacion_jefe','300','numero','Cotizaciones con subtotal hasta este valor las aprueba el jefe de taller; más, gerencia.'),
 ('tolerancia_factura_pct','10','numero','Alerta si la factura supera lo cotizado en más de este porcentaje.'),
 ('iva_pct','15','numero','Porcentaje de IVA para cotizaciones de terceros.');

insert into areas_taller (nombre, es_externo, requiere_cotizacion, orden) values
 ('Mecánico', false, false, 1),
 ('Soldadura', false, false, 2),
 ('Lavadora', true, false, 3),
 ('Talleres externos', true, true, 4);

insert into tipos_vehiculo (prefijo_codigo, nombre, unidad_medida, diagrama) values
 ('DC','Cabezal','km','cabezal'),
 ('DP','Plataforma','km','plataforma'),
 ('DR','Recolector','km','recolector'),
 ('MC','Montacargas','horas','montacargas');

insert into configuraciones_ejes (nombre, numero_ejes, numero_llantas, descripcion) values
 ('Cabezal 6x4', 3, 10, '1 eje direccional + 2 ejes de tracción con llanta doble'),
 ('Cabezal 4x2', 2, 6, '1 eje direccional + 1 eje de tracción con llanta doble'),
 ('Plataforma 4x2', 2, 6, '1 eje direccional + 1 eje trasero con llanta doble'),
 ('Plataforma 6x4', 3, 10, '1 eje direccional + 2 ejes traseros con llanta doble'),
 ('Recolector 4x2', 2, 6, '1 eje direccional + 1 eje trasero con llanta doble'),
 ('Recolector 6x4', 3, 10, '1 eje direccional + 2 ejes traseros con llanta doble'),
 ('Montacargas', 2, 4, '2 ejes con llanta simple');

insert into categorias_gasto (nombre, grupo, orden) values
 ('Mantenimiento Preventivo','Mantenimiento',1),
 ('Mantenimiento Correctivo','Mantenimiento',2),
 ('Insumos','Insumos',3),
 ('Llantas','Llantas',4),
 ('Otros','Otros',5);

insert into sistemas (nombre, orden, categoria_preventivo_id, categoria_correctivo_id)
select s.nombre, s.orden,
       (select id from categorias_gasto where nombre = s.prev),
       (select id from categorias_gasto where nombre = s.corr)
from (values
 ('Motor',1,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Caja',2,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Corona',3,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Embrague',4,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Frenos',5,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Suspensión',6,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Dirección',7,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Eléctrico',8,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Llantas',9,'Llantas','Llantas'),
 ('Carrocería',10,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Plataforma',11,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Lavado',12,'Otros','Otros'),
 ('Otros',13,'Otros','Otros')
) as s(nombre, orden, prev, corr);

insert into items_checklist (nombre, grupo, orden) values
 ('Extintor vigente','Seguridad',1),
 ('Triángulos de seguridad','Seguridad',2),
 ('Botiquín','Seguridad',3),
 ('Gata','Seguridad',4),
 ('Llave de ruedas','Seguridad',5),
 ('Llanta(s) de emergencia','Seguridad',6),
 ('Conos','Seguridad',7),
 ('Cintas reflectivas','Seguridad',8),
 ('Matrícula','Documentos',10),
 ('SOAT','Documentos',11),
 ('Permiso de operación','Documentos',12),
 ('Tacógrafo / GPS','Documentos',13),
 ('Tapa de combustible','Exterior',20),
 ('Espejos','Exterior',21),
 ('Plumas (limpiaparabrisas)','Exterior',22),
 ('Luces','Exterior',23),
 ('Cadenas / fajas / chicotes de amarre','Carga',30);

-- Pide a la API de Supabase que relea las tablas y funciones nuevas.
notify pgrst, 'reload schema';

-- >>>>>>>>>>>>>>>>>>>> 007_unificada_fase1.sql
set client_min_messages = warning;
-- =====================================================================
-- 007 · Especificación unificada v1 · FASE 1
--       Roles nuevos (Maestro, Supervisor, Bodega, Técnico) + permisos
--       extra, y módulo Maestros (técnicos, tarifas, vehículos, clientes,
--       centros de costo, choferes, catálogo de trabajos por taller,
--       complejidad, sistemas preventivos, proveedores, listas, parámetros).
--
-- Sirve para las dos situaciones:
--   * Instalación nueva: va incluido en INSTALAR_TODO.sql.
--   * Base que ya está en uso: pegar SOLO 007 y luego 008 en el SQL Editor.
--     No borra nada. Convierte los roles anteriores así:
--       administrador → maestro · jefe_taller → supervisor · tecnico → tecnico
--       gerencia / consulta → supervisor INACTIVO (el maestro decide si lo activa).
-- PostgreSQL estándar. Lo propio de Supabase está en 008_supabase_v2.sql.
-- =====================================================================

-- ============================================================ 1. Roles y permisos
alter table usuarios drop constraint if exists usuarios_rol_check;
update usuarios set activo = false where rol in ('gerencia','consulta');
update usuarios set rol = case rol
    when 'administrador' then 'maestro'
    when 'jefe_taller'   then 'supervisor'
    when 'gerencia'      then 'supervisor'
    when 'consulta'      then 'supervisor'
    else rol end
 where rol in ('administrador','jefe_taller','gerencia','consulta');
alter table usuarios alter column rol set default 'tecnico';
alter table usuarios add constraint usuarios_rol_check check (rol in ('maestro','supervisor','bodega','tecnico'));

alter table usuarios add column if not exists permisos_extra text[] not null default '{}';
alter table usuarios drop constraint if exists usuarios_permisos_extra_check;
alter table usuarios add constraint usuarios_permisos_extra_check
  check (permisos_extra <@ array['bodega','aprobar_ajustes','gestion_personal','ver_costos','editar_catalogos']::text[]);

-- ¿El usuario que opera tiene este permiso?
-- Permisos: operar_ot, bodega, aprobar_ajustes, gestion_personal, ver_costos, editar_catalogos, maestro.
--   Maestro    → todos.
--   Supervisor → operar_ot, gestion_personal.
--   Bodega     → bodega.
--   Técnico    → ninguno (solo lectura, sus observaciones y lo suyo).
--   + los permisos extra que el maestro le sume a cada persona.
create or replace function tiene_permiso(p_permiso text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((
    select u.rol = 'maestro'
        or p_permiso = any(u.permisos_extra)
        or (u.rol = 'supervisor' and p_permiso in ('operar_ot','gestion_personal'))
        or (u.rol = 'bodega' and p_permiso in ('bodega'))
      from usuarios u where u.id = usuario_actual() and u.activo), false)
$$;

create or replace function es_maestro() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select rol = 'maestro' from usuarios where id = usuario_actual() and activo), false)
$$;

-- Técnico (ficha) vinculado al usuario que opera, si existe.
create or replace function tecnico_actual() returns uuid
language sql stable security definer set search_path = public as $$
  select id from tecnicos where usuario_id = usuario_actual() and activo limit 1
$$;

-- ============================================================ 2. Centros de costo y clientes
create table if not exists centros_costo (
  id               uuid primary key default gen_random_uuid(),
  codigo           text not null unique,
  nombre           text not null,
  costo_por_km     boolean not null default true,
  es_clientes      boolean not null default false,
  activo           boolean not null default true,
  creado_en        timestamptz not null default now(),
  creado_por       uuid references usuarios(id),
  actualizado_en   timestamptz,
  actualizado_por  uuid references usuarios(id)
);

create table if not exists clientes (
  id               uuid primary key default gen_random_uuid(),
  nombre           text not null unique,
  ruc              text unique,
  contacto         text,
  telefono         text,
  correo           text,
  observaciones    text,
  activo           boolean not null default true,
  creado_en        timestamptz not null default now(),
  creado_por       uuid references usuarios(id),
  actualizado_en   timestamptz,
  actualizado_por  uuid references usuarios(id)
);

-- ============================================================ 3. Vehículos
alter table vehiculos drop constraint if exists vehiculos_estado_check;
update vehiculos set estado = 'parado' where estado in ('inactivo','baja');
alter table vehiculos add constraint vehiculos_estado_check
  check (estado in ('activo','parado','venta','tramite'));
alter table vehiculos add column if not exists nombre_hunter text;
alter table vehiculos add column if not exists estado_desde date;
alter table vehiculos add column if not exists propiedad text not null default 'propio';
alter table vehiculos add column if not exists cliente_id uuid references clientes(id);
alter table vehiculos add column if not exists centro_costo_id uuid references centros_costo(id);
alter table vehiculos add column if not exists fecha_ingreso_flota date;
alter table vehiculos drop constraint if exists vehiculos_propiedad_check;
alter table vehiculos add constraint vehiculos_propiedad_check check (propiedad in ('propio','rentado'));
alter table vehiculos drop constraint if exists vehiculos_rentado_cliente_check;
alter table vehiculos add constraint vehiculos_rentado_cliente_check check (propiedad = 'propio' or cliente_id is not null);
update vehiculos set fecha_ingreso_flota = make_date(anio, 1, 1) where fecha_ingreso_flota is null and anio between 1980 and 2100;
update vehiculos set estado_desde = coalesce(actualizado_en, creado_en)::date where estado_desde is null;

-- Historial de estados del vehículo (fechas de parada, venta, trámite).
create table if not exists historial_estados_vehiculo (
  id               uuid primary key default gen_random_uuid(),
  vehiculo_id      uuid not null references vehiculos(id),
  estado           text not null,
  desde            date not null,
  hasta            date,
  creado_en        timestamptz not null default now(),
  creado_por       uuid references usuarios(id),
  actualizado_en   timestamptz,
  actualizado_por  uuid references usuarios(id)
);
create index if not exists historial_estados_vehiculo_veh on historial_estados_vehiculo (vehiculo_id, desde);

-- Rentado a cliente → su gasto va al centro de costo de clientes (MNTOPL3RAS).
-- Cambio de estado → se cierra el tramo anterior y se abre uno nuevo en el historial.
create or replace function tg_vehiculo_v2() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_cc uuid;
begin
  if new.propiedad = 'rentado' then
    select id into v_cc from centros_costo
     where codigo = (select valor from configuracion where clave = 'centro_costo_clientes');
    if v_cc is not null then new.centro_costo_id := v_cc; end if;
  end if;
  if tg_op = 'INSERT' then
    new.estado_desde := coalesce(new.estado_desde, current_date);
  elsif new.estado is distinct from old.estado and new.estado_desde is not distinct from old.estado_desde then
    new.estado_desde := current_date;  -- si no indicaron la fecha del cambio, se toma hoy
  end if;
  return new;
end $$;
drop trigger if exists t3_vehiculo_v2 on vehiculos;
create trigger t3_vehiculo_v2 before insert or update on vehiculos
  for each row execute function tg_vehiculo_v2();

create or replace function tg_vehiculo_historial() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' or new.estado is distinct from old.estado then
    update historial_estados_vehiculo set hasta = greatest(desde, new.estado_desde)
     where vehiculo_id = new.id and hasta is null;
    insert into historial_estados_vehiculo (vehiculo_id, estado, desde) values (new.id, new.estado, new.estado_desde);
  end if;
  return null;
end $$;
drop trigger if exists t8_vehiculo_historial on vehiculos;
create trigger t8_vehiculo_historial after insert or update on vehiculos
  for each row execute function tg_vehiculo_historial();

insert into historial_estados_vehiculo (vehiculo_id, estado, desde)
select v.id, v.estado, v.estado_desde from vehiculos v
 where not exists (select 1 from historial_estados_vehiculo h where h.vehiculo_id = v.id);

-- Plataformas DR (la especificación unificada las trata como plataformas).
update tipos_vehiculo set nombre = 'Plataforma (DR)', diagrama = 'plataforma'
 where prefijo_codigo = 'DR' and nombre = 'Recolector';

-- ============================================================ 4. Técnicos y tarifas
alter table tecnicos add column if not exists codigo text;
alter table tecnicos add column if not exists especialidad text not null default 'mecanica';
alter table tecnicos add column if not exists cargo text;
alter table tecnicos add column if not exists jornada_horas numeric(4,1) not null default 8;
alter table tecnicos add column if not exists fecha_ingreso date;
alter table tecnicos add column if not exists contacto_emergencia text;
alter table tecnicos drop constraint if exists tecnicos_especialidad_check;
alter table tecnicos add constraint tecnicos_especialidad_check check (especialidad in ('mecanica','soldadura','ambas'));
alter table tecnicos drop constraint if exists tecnicos_jornada_check;
alter table tecnicos add constraint tecnicos_jornada_check check (jornada_horas > 0 and jornada_horas <= 24);
update tecnicos t set especialidad = 'soldadura'
  from areas_taller a where a.id = t.area_taller_id and a.nombre ilike 'soldadura%' and t.codigo is null;
with x as (select id, row_number() over (order by creado_en, nombres) n from tecnicos where codigo is null)
update tecnicos t set codigo = 'T' || lpad((x.n + coalesce((select count(*) from tecnicos where codigo is not null), 0))::text, 2, '0')
  from x where x.id = t.id;
alter table tecnicos alter column codigo set not null;
create unique index if not exists tecnicos_codigo_unico on tecnicos (upper(codigo));

-- La tarifa es un costo: va en su propia tabla, que solo ve quien tiene "ver_costos".
create table if not exists tarifas_tecnico (
  id               uuid primary key default gen_random_uuid(),
  tecnico_id       uuid not null references tecnicos(id),
  tarifa_hora      numeric(10,2) not null check (tarifa_hora >= 0),
  vigente_desde    date not null default current_date,
  observacion      text,
  anulado          boolean not null default false,
  anulado_motivo   text,
  anulado_por      uuid references usuarios(id),
  anulado_en       timestamptz,
  creado_en        timestamptz not null default now(),
  creado_por       uuid references usuarios(id),
  actualizado_en   timestamptz,
  actualizado_por  uuid references usuarios(id),
  check (not anulado or coalesce(length(trim(anulado_motivo)),0) > 0)
);
create unique index if not exists tarifas_tecnico_vigencia on tarifas_tecnico (tecnico_id, vigente_desde) where not anulado;

-- Tarifa interna por hora vigente en una fecha (para la mano de obra de la OT).
create or replace function tarifa_vigente(p_tecnico uuid, p_fecha date default current_date) returns numeric
language sql stable security invoker set search_path = public as $$
  select tarifa_hora from tarifas_tecnico
   where tecnico_id = p_tecnico and not anulado and vigente_desde <= p_fecha
   order by vigente_desde desc limit 1
$$;

-- ============================================================ 5. Catálogo de trabajos por taller
-- Sistema/componente (cápsula) → elemento → intervención (horas estándar).
alter table sistemas add column if not exists taller text not null default 'mecanica';
alter table sistemas add column if not exists icono text;
alter table sistemas add column if not exists descripcion text;
alter table sistemas add column if not exists aplica_complejidad boolean not null default true;
alter table sistemas drop constraint if exists sistemas_taller_check;
alter table sistemas add constraint sistemas_taller_check check (taller in ('mecanica','soldadura'));
alter table sistemas drop constraint if exists sistemas_nombre_key;
create unique index if not exists sistemas_taller_nombre on sistemas (taller, lower(nombre));

-- Sistemas del registro de componentes del kardex, con sus mismos parámetros.
create table if not exists sistemas_preventivos (
  id                   uuid primary key default gen_random_uuid(),
  codigo               text not null unique,
  nombre               text not null,
  modo                 text not null default 'km' check (modo in ('km','dias','falla')),
  intervalo_cabezal    numeric(10,1),
  intervalo_plataforma numeric(10,1),
  intervalo_montacarga numeric(10,1),
  dias_sin_km          integer,
  pct_prematuro        integer not null default 0,
  registro_automatico  boolean not null default false,
  incluye              text,
  excluye              text,
  km_incluye           text,
  km_excluye           text,
  motivos_falla        text,
  orden                integer not null default 0,
  activo               boolean not null default true,
  creado_en            timestamptz not null default now(),
  creado_por           uuid references usuarios(id),
  actualizado_en       timestamptz,
  actualizado_por      uuid references usuarios(id)
);

create table if not exists elementos (
  id               uuid primary key default gen_random_uuid(),
  sistema_id       uuid not null references sistemas(id),
  nombre           text not null,
  orden            integer not null default 0,
  activo           boolean not null default true,
  creado_en        timestamptz not null default now(),
  creado_por       uuid references usuarios(id),
  actualizado_en   timestamptz,
  actualizado_por  uuid references usuarios(id)
);
create unique index if not exists elementos_sistema_nombre on elementos (sistema_id, lower(nombre));

-- Las intervenciones son del componente (cápsula) y sirven para todos sus elementos,
-- igual que en la maqueta del coordinador de soldadura.
create table if not exists intervenciones (
  id                     uuid primary key default gen_random_uuid(),
  sistema_id             uuid not null references sistemas(id),
  nombre                 text not null,
  horas_estandar         numeric(6,2) not null check (horas_estandar >= 0),
  sistema_preventivo_id  uuid references sistemas_preventivos(id),
  orden                  integer not null default 0,
  activo                 boolean not null default true,
  creado_en              timestamptz not null default now(),
  creado_por             uuid references usuarios(id),
  actualizado_en         timestamptz,
  actualizado_por        uuid references usuarios(id)
);
create unique index if not exists intervenciones_sistema_nombre on intervenciones (sistema_id, lower(nombre));

create table if not exists complejidades (
  id               uuid primary key default gen_random_uuid(),
  codigo           text not null unique,
  nombre           text not null,
  multiplicador    numeric(4,2) not null check (multiplicador > 0),
  orden            integer not null default 0,
  activo           boolean not null default true,
  creado_en        timestamptz not null default now(),
  creado_por       uuid references usuarios(id),
  actualizado_en   timestamptz,
  actualizado_por  uuid references usuarios(id)
);

-- Vista plana del catálogo (para buscar, exportar y para las cápsulas de la Fase 2).
-- Se crea solo si no existe: la migración 010 la amplía y no debe perder columnas si 007 se vuelve a ejecutar.
do $vista$ begin
  if not exists (select 1 from pg_views where schemaname = 'public' and viewname = 'v_catalogo_trabajos') then
    execute $sql$create view v_catalogo_trabajos with (security_invoker = true) as
select s.taller, s.id as sistema_id, s.nombre as sistema, s.orden as sistema_orden, s.activo as sistema_activo,
       s.aplica_complejidad,
       (select count(*) from elementos e where e.sistema_id = s.id and e.activo) as elementos_activos,
       i.id as intervencion_id, i.nombre as intervencion, i.horas_estandar,
       i.orden as intervencion_orden, i.activo as intervencion_activo,
       p.codigo as sistema_preventivo, p.nombre as sistema_preventivo_nombre
  from sistemas s
  left join intervenciones i on i.sistema_id = s.id
  left join sistemas_preventivos p on p.id = i.sistema_preventivo_id$sql$;
  end if;
end $vista$;

-- ============================================================ 6. Proveedores y talleres externos
create table if not exists proveedores (
  id               uuid primary key default gen_random_uuid(),
  nombre           text not null unique,
  ruc              text unique,
  tipo             text not null default 'repuestos' check (tipo in ('repuestos','taller_externo','ambos')),
  especialidad     text check (especialidad in ('mecanica','soldadura','ambas')),
  contacto         text,
  telefono         text,
  correo           text,
  direccion        text,
  observaciones    text,
  activo           boolean not null default true,
  creado_en        timestamptz not null default now(),
  creado_por       uuid references usuarios(id),
  actualizado_en   timestamptz,
  actualizado_por  uuid references usuarios(id)
);

-- ============================================================ 7. Listas editables
create table if not exists listas_valores (
  id               uuid primary key default gen_random_uuid(),
  lista            text not null check (lista in ('causa_dano','motivo_imprevisto','motivo_no_realizado','motivo_descarte',
                                                  'tipo_novedad_personal','checklist_calidad',
                                                  'motivo_llanta','kit_embrague','frenos','aceite','inyeccion',
                                                  'criterio','estado_compra','estado_herramienta')),
  valor            text not null,
  descripcion      text,
  taller           text check (taller in ('mecanica','soldadura')),
  orden            integer not null default 0,
  activo           boolean not null default true,
  creado_en        timestamptz not null default now(),
  creado_por       uuid references usuarios(id),
  actualizado_en   timestamptz,
  actualizado_por  uuid references usuarios(id)
);
create unique index if not exists listas_valores_unico on listas_valores (lista, lower(valor), coalesce(taller, ''));

-- ============================================================ 7b. Clave de aprobación de ajustes
-- Una sola clave para aprobar ajustes de saldo del kardex (conteos, cierre, reabrir mes).
-- Se guarda cifrada y nadie la puede leer: solo se fija y se verifica con funciones.
create table if not exists clave_aprobacion (
  id               uuid primary key default gen_random_uuid(),
  clave_cifrada    text not null,
  creado_en        timestamptz not null default now(),
  creado_por       uuid references usuarios(id),
  actualizado_en   timestamptz,
  actualizado_por  uuid references usuarios(id)
);

-- ============================================================ 8. Vistas de apoyo
create or replace view v_vehiculos with (security_invoker = true) as
select v.*, t.prefijo_codigo, t.nombre as tipo_vehiculo, t.unidad_medida,
       c.nombre as cliente, cc.codigo as centro_costo, cc.costo_por_km,
       case when v.fecha_ingreso_flota is not null then
         (extract(year from age(current_date, v.fecha_ingreso_flota)) * 12
          + extract(month from age(current_date, v.fecha_ingreso_flota)))::int end as edad_meses
  from vehiculos v
  join tipos_vehiculo t on t.id = v.tipo_vehiculo_id
  left join clientes c on c.id = v.cliente_id
  left join centros_costo cc on cc.id = v.centro_costo_id;

-- ============================================================ 9. Reglas comunes (auditoría, sin borrar, anulación)
-- Se puede volver a ejecutar en migraciones futuras: aplica las reglas a todas las tablas.
create or replace function aplicar_reglas_comunes() returns void
language plpgsql as $$
declare t record;
begin
  for t in select table_name from information_schema.tables
           where table_schema = 'public' and table_type = 'BASE TABLE' loop
    execute format('drop trigger if exists t0_sin_borrar on %I', t.table_name);
    execute format('create trigger t0_sin_borrar before delete on %I for each row execute function tg_prohibir_borrado()', t.table_name);
    continue when t.table_name = 'bitacora_auditoria';
    execute format('drop trigger if exists t1_columnas_comunes on %I', t.table_name);
    execute format('create trigger t1_columnas_comunes before insert or update on %I for each row execute function tg_columnas_comunes()', t.table_name);
    execute format('drop trigger if exists t9_auditoria on %I', t.table_name);
    if t.table_name <> 'contadores_documento' then
      execute format('create trigger t9_auditoria after insert or update on %I for each row execute function tg_auditoria()', t.table_name);
    end if;
    if exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = t.table_name and column_name = 'anulado') then
      execute format('drop trigger if exists t2_anulacion on %I', t.table_name);
      execute format('create trigger t2_anulacion before update on %I for each row execute function tg_anulacion()', t.table_name);
    end if;
  end loop;
end $$;
do $$ begin perform aplicar_reglas_comunes(); end $$;

-- ============================================================ 10. Permisos (Row Level Security)
-- Reemplaza por completo las reglas del archivo 004.
do $$
declare t record;
  -- Solo el maestro modifica
  solo_maestro text[] := array['configuracion','areas_taller','tipos_vehiculo','configuraciones_ejes','categorias_gasto',
                               'items_checklist','tecnicos','centros_costo','complejidades','sistemas_preventivos'];
  -- Maestro o quien tenga el permiso extra "editar_catalogos"
  catalogos text[] := array['vehiculos','conductores','clientes','proveedores','sistemas','elementos','intervenciones',
                            'listas_valores','repuestos'];
  -- Operación del taller (maestro, supervisor o permiso operar_ot)
  operativas text[] := array['actas_recepcion','checklist_recepcion','actas_entrega','checklist_entrega','danos_vehiculo',
                             'archivos','ordenes_trabajo','lineas_trabajo','registros_horas','historial_estados_ot'];
begin
  for t in select table_name from information_schema.tables
           where table_schema = 'public' and table_type = 'BASE TABLE' loop
    execute format('alter table %I enable row level security', t.table_name);
    execute format('drop policy if exists leer on %I', t.table_name);
    execute format('drop policy if exists crear on %I', t.table_name);
    execute format('drop policy if exists modificar on %I', t.table_name);

    if t.table_name in ('bitacora_auditoria','respaldos') then
      execute format($p$create policy leer on %I for select to authenticated using (es_maestro())$p$, t.table_name);
      continue;
    end if;
    continue when t.table_name in ('contadores_documento','clave_aprobacion');  -- solo a través de funciones

    if t.table_name = 'tarifas_tecnico' then
      execute $p$create policy leer on tarifas_tecnico for select to authenticated using (tiene_permiso('ver_costos'))$p$;
      execute $p$create policy crear on tarifas_tecnico for insert to authenticated with check (es_maestro())$p$;
      execute $p$create policy modificar on tarifas_tecnico for update to authenticated using (es_maestro())$p$;
      continue;
    end if;

    execute format($p$create policy leer on %I for select to authenticated using (rol_actual() is not null)$p$, t.table_name);

    if t.table_name = 'usuarios' then
      execute $p$create policy modificar on usuarios for update to authenticated using (es_maestro()) with check (es_maestro())$p$;
    elsif t.table_name = any(solo_maestro) then
      execute format($p$create policy crear on %I for insert to authenticated with check (es_maestro())$p$, t.table_name);
      execute format($p$create policy modificar on %I for update to authenticated using (es_maestro())$p$, t.table_name);
    elsif t.table_name = any(catalogos) then
      execute format($p$create policy crear on %I for insert to authenticated with check (tiene_permiso('editar_catalogos'))$p$, t.table_name);
      execute format($p$create policy modificar on %I for update to authenticated using (tiene_permiso('editar_catalogos'))$p$, t.table_name);
    elsif t.table_name = any(operativas) then
      execute format($p$create policy crear on %I for insert to authenticated with check (tiene_permiso('operar_ot'))$p$, t.table_name);
      execute format($p$create policy modificar on %I for update to authenticated using (tiene_permiso('operar_ot'))$p$, t.table_name);
    elsif t.table_name = 'repuestos_linea' then
      execute $p$create policy crear on repuestos_linea for insert to authenticated with check (tiene_permiso('operar_ot') or tiene_permiso('bodega'))$p$;
      execute $p$create policy modificar on repuestos_linea for update to authenticated using (tiene_permiso('operar_ot') or tiene_permiso('bodega'))$p$;
    elsif t.table_name = 'comentarios_ot' then
      -- Observaciones: el supervisor siempre; el técnico solo en OT donde está asignado. No se editan.
      execute $p$create policy crear on comentarios_ot for insert to authenticated with check (
        tiene_permiso('operar_ot') or exists (
          select 1 from lineas_trabajo l join tecnicos te on te.id = l.tecnico_id
           where l.orden_trabajo_id = comentarios_ot.orden_trabajo_id and not l.anulado and te.usuario_id = usuario_actual()))$p$;
      execute $p$create policy modificar on comentarios_ot for update to authenticated using (tiene_permiso('operar_ot'))$p$;
    end if;
    -- historial_estados_vehiculo: solo lectura; lo llena el disparador.
  end loop;
end $$;

-- ============================================================ 11. Funciones de negocio con los roles nuevos
create or replace function rol_actual() returns text
language sql stable security definer set search_path = public as $$
  select rol from usuarios where id = usuario_actual() and activo
$$;

create or replace function registrar_acta(p_tipo text, p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_veh vehiculos; v_id uuid; v_num text; v_estado text; v_item jsonb; v_dano jsonb;
begin
  if p_tipo not in ('recepcion','entrega') then raise exception 'Tipo de acta no válido.'; end if;
  if not tiene_permiso('operar_ot') then raise exception 'Su usuario no puede registrar actas.'; end if;
  if p_tipo = 'recepcion' then
    select id, numero, estado into v_id, v_num, v_estado from actas_recepcion where id_local = (p->>'id_local')::uuid;
  else
    select id, numero, estado into v_id, v_num, v_estado from actas_entrega where id_local = (p->>'id_local')::uuid;
  end if;
  if v_id is not null then
    return jsonb_build_object('acta_id', v_id, 'numero', v_num, 'estado', v_estado);
  end if;

  select * into v_veh from vehiculos where id = (p->>'vehiculo_id')::uuid;
  if not found then raise exception 'Vehículo no encontrado.'; end if;
  if (p->>'lectura')::numeric < v_veh.lectura_actual then
    raise exception 'La lectura (%) es menor a la última registrada para % (%).',
      p->>'lectura', v_veh.codigo, v_veh.lectura_actual;
  end if;

  if p_tipo = 'recepcion' then
    insert into actas_recepcion (numero, id_local, vehiculo_id, conductor_id, recibido_por, fecha_hora,
           lectura, lectura_hunter, combustible, motivo, observaciones)
    values (siguiente_numero('AR'), (p->>'id_local')::uuid, v_veh.id, (p->>'conductor_id')::uuid,
            usuario_actual(), coalesce((p->>'fecha_hora')::timestamptz, now()),
            (p->>'lectura')::numeric, (p->>'lectura_hunter')::numeric, p->>'combustible',
            p->>'motivo', p->>'observaciones')
    returning id, numero, estado into v_id, v_num, v_estado;
  else
    insert into actas_entrega (numero, id_local, vehiculo_id, conductor_id, entregado_por, fecha_hora,
           lectura, combustible, motivo, observaciones)
    values (siguiente_numero('AE'), (p->>'id_local')::uuid, v_veh.id, (p->>'conductor_id')::uuid,
            usuario_actual(), coalesce((p->>'fecha_hora')::timestamptz, now()),
            (p->>'lectura')::numeric, p->>'combustible', p->>'motivo', p->>'observaciones')
    returning id, numero, estado into v_id, v_num, v_estado;
  end if;

  for v_item in select * from jsonb_array_elements(coalesce(p->'checklist','[]'::jsonb)) loop
    if p_tipo = 'recepcion' then
      insert into checklist_recepcion (acta_recepcion_id, item_checklist_id, resultado, observacion)
      values (v_id, (v_item->>'item_checklist_id')::uuid, v_item->>'resultado', v_item->>'observacion');
    else
      insert into checklist_entrega (acta_entrega_id, item_checklist_id, resultado, observacion)
      values (v_id, (v_item->>'item_checklist_id')::uuid, v_item->>'resultado', v_item->>'observacion');
    end if;
  end loop;
  for v_dano in select * from jsonb_array_elements(coalesce(p->'danos','[]'::jsonb)) loop
    insert into danos_vehiculo (vehiculo_id, acta_recepcion_id, acta_entrega_id, numero_marca, vista,
           posicion_x, posicion_y, tipo_dano, descripcion)
    values (v_veh.id, case when p_tipo = 'recepcion' then v_id end, case when p_tipo = 'entrega' then v_id end,
            (v_dano->>'numero_marca')::int, v_dano->>'vista', (v_dano->>'posicion_x')::numeric,
            (v_dano->>'posicion_y')::numeric, v_dano->>'tipo_dano', v_dano->>'descripcion');
  end loop;
  return jsonb_build_object('acta_id', v_id, 'numero', v_num, 'estado', v_estado);
end $$;

create or replace function firmar_acta(p_tipo text, p_acta uuid, p_ruta_firma_conductor text, p_ruta_firma_responsable text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_num text; v_estado text; v_veh uuid; v_cond uuid; v_lect numeric; v_fecha timestamptz;
        v_tabla text := case when p_tipo = 'recepcion' then 'actas_recepcion' else 'actas_entrega' end;
        v_f1 uuid; v_f2 uuid;
begin
  if not tiene_permiso('operar_ot') then raise exception 'Su usuario no puede firmar actas.'; end if;
  if p_tipo = 'recepcion' then
    select numero, estado, vehiculo_id, conductor_id, lectura, fecha_hora into v_num, v_estado, v_veh, v_cond, v_lect, v_fecha
      from actas_recepcion where id = p_acta for update;
  elsif p_tipo = 'entrega' then
    select numero, estado, vehiculo_id, conductor_id, lectura, fecha_hora into v_num, v_estado, v_veh, v_cond, v_lect, v_fecha
      from actas_entrega where id = p_acta for update;
  else raise exception 'Tipo de acta no válido.';
  end if;
  if v_num is null then raise exception 'Acta no encontrada.'; end if;
  if v_estado = 'firmada' then return jsonb_build_object('acta_numero', v_num); end if;
  if coalesce(p_ruta_firma_conductor,'') = '' or coalesce(p_ruta_firma_responsable,'') = '' then
    raise exception 'Faltan las firmas del conductor y del responsable.';
  end if;

  insert into archivos (tipo, categoria, ruta, tipo_mime, tabla_origen, registro_origen_id, usuario_id)
  values ('firma','firma_conductor', p_ruta_firma_conductor, 'image/png', v_tabla, p_acta, usuario_actual())
  on conflict (ruta) do update set ruta = excluded.ruta returning id into v_f1;
  insert into archivos (tipo, categoria, ruta, tipo_mime, tabla_origen, registro_origen_id, usuario_id)
  values ('firma', case when p_tipo = 'recepcion' then 'firma_recibe' else 'firma_entrega' end,
          p_ruta_firma_responsable, 'image/png', v_tabla, p_acta, usuario_actual())
  on conflict (ruta) do update set ruta = excluded.ruta returning id into v_f2;

  if p_tipo = 'recepcion' then
    update actas_recepcion set estado = 'firmada', firma_conductor_id = v_f1, firma_recibe_id = v_f2 where id = p_acta;
    update vehiculos set conductor_asignado_id = null where id = v_veh and conductor_asignado_id = v_cond;
  else
    update actas_entrega set estado = 'firmada', firma_conductor_id = v_f1, firma_entrega_id = v_f2 where id = p_acta;
    update vehiculos set conductor_asignado_id = v_cond where id = v_veh;
  end if;
  update vehiculos set lectura_actual = v_lect, lectura_actual_fecha = v_fecha
   where id = v_veh and lectura_actual <= v_lect;
  return jsonb_build_object('acta_numero', v_num);
end $$;

create or replace function abrir_ot(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_ot ordenes_trabajo; v_veh vehiculos; v_abierta text;
begin
  if not tiene_permiso('operar_ot') then raise exception 'Su usuario no puede abrir órdenes de trabajo.'; end if;
  select * into v_ot from ordenes_trabajo where id_local = (p->>'id_local')::uuid;
  if found then return jsonb_build_object('ot_id', v_ot.id, 'ot_numero', v_ot.numero); end if;
  select * into v_veh from vehiculos where id = (p->>'vehiculo_id')::uuid;
  if not found then raise exception 'Vehículo no encontrado.'; end if;
  if (p->>'lectura')::numeric < v_veh.lectura_actual then
    raise exception 'La lectura (%) es menor a la última registrada para % (%).',
      p->>'lectura', v_veh.codigo, v_veh.lectura_actual;
  end if;
  select numero into v_abierta from ordenes_trabajo
   where vehiculo_id = v_veh.id and estado <> 'entregado' and not anulado limit 1;
  if v_abierta is not null then
    raise exception 'El vehículo % ya tiene la orden % abierta. Ciérrela o anúlela antes de abrir otra.', v_veh.codigo, v_abierta;
  end if;
  insert into ordenes_trabajo (numero, id_local, vehiculo_id, conductor_id, lectura, motivo_ingreso, falla_reportada,
         prioridad, inmovilizado, estado, jefe_taller_id, fecha_apertura)
  values (siguiente_numero('OT'), (p->>'id_local')::uuid, v_veh.id, (p->>'conductor_id')::uuid, (p->>'lectura')::numeric,
          p->>'motivo_ingreso', p->>'falla_reportada', coalesce(p->>'prioridad','media'),
          coalesce((p->>'inmovilizado')::boolean, false), 'recepcion',
          case when rol_actual() = 'supervisor' then usuario_actual() end,
          coalesce((p->>'fecha_hora')::timestamptz, now()))
  returning * into v_ot;
  insert into historial_estados_ot (orden_trabajo_id, estado_anterior, estado_nuevo, fecha_hora, usuario_id, comentario)
  values (v_ot.id, null, 'recepcion', v_ot.fecha_apertura, usuario_actual(), 'Ingreso al taller');
  update vehiculos set lectura_actual = v_ot.lectura, lectura_actual_fecha = v_ot.fecha_apertura
   where id = v_veh.id and lectura_actual <= v_ot.lectura;
  return jsonb_build_object('ot_id', v_ot.id, 'ot_numero', v_ot.numero);
end $$;

create or replace function cambiar_estado_ot(p_ot uuid, p_estado text, p_comentario text default null)
returns void language plpgsql set search_path = public as $$
declare v_ot ordenes_trabajo;
begin
  if not tiene_permiso('operar_ot') then raise exception 'Solo el supervisor puede cambiar el estado de la OT.'; end if;
  select * into v_ot from ordenes_trabajo where id = p_ot for update;
  if not found then raise exception 'OT no encontrada.'; end if;
  if v_ot.anulado then raise exception 'La OT está anulada.'; end if;
  if v_ot.estado = 'entregado' then raise exception 'La OT ya está cerrada.'; end if;
  if p_estado = v_ot.estado then return; end if;
  if p_estado in ('listo_entrega','entregado') and exists (
       select 1 from lineas_trabajo where orden_trabajo_id = p_ot and not anulado and estado <> 'terminada') then
    raise exception 'Hay trabajos sin terminar. Termínelos o anúlelos antes de pasar a "%".',
      case when p_estado = 'entregado' then 'Entregado / cerrado' else 'Listo para entrega' end;
  end if;
  if p_estado = 'entregado' and not exists (
       select 1 from lineas_trabajo where orden_trabajo_id = p_ot and not anulado) then
    raise exception 'La OT no tiene trabajos registrados. Agregue al menos uno o anule la OT.';
  end if;
  if p_estado = 'entregado' then
    update ordenes_trabajo set
       estado = 'entregado', fecha_cierre = now(),
       horas_parado = round((extract(epoch from (now() - fecha_apertura)) / 3600)::numeric, 1),
       total_horas_internas = (select coalesce(sum(h.horas),0) from registros_horas h
                                 join lineas_trabajo l on l.id = h.linea_trabajo_id
                                where l.orden_trabajo_id = p_ot and not h.anulado and not l.anulado)
     where id = p_ot;
  else
    update ordenes_trabajo set estado = p_estado where id = p_ot;
  end if;
  insert into historial_estados_ot (orden_trabajo_id, estado_anterior, estado_nuevo, usuario_id, comentario)
  values (p_ot, v_ot.estado, p_estado, usuario_actual(), p_comentario);
end $$;

-- ============================================================ 12. Datos iniciales de la Fase 1
insert into configuracion (clave, valor, tipo_dato, descripcion) values
 ('dias_retrabajo','90','numero','Si la misma unidad vuelve por el mismo trabajo antes de estos días, cuenta como retrabajo.'),
 ('umbral_renovado_pct','55','numero','Si renovar cuesta más que este % de una pieza nueva, conviene fabricar o comprar nueva.'),
 ('periodo_produccion_dia_corte','24','numero','Día de corte del período de producción (del 24 al 24).'),
 ('centro_costo_clientes','MNTOPL3RAS','texto','Centro de costo al que se carga el gasto de unidades rentadas a clientes.'),
 ('max_ausentes_por_taller','2','numero','Alerta del calendario si en un día faltan más técnicos que esto en un mismo taller.'),
 ('dias_vacaciones_anuales','15','numero','Días de vacaciones que gana cada técnico por año trabajado.'),
 ('monto_aprobacion_maestro','1000','numero','Cotizaciones de terceros sobre este monto requieren además la aprobación del maestro.'),
 ('preventivo_ventana_dias','60','numero','Preventivos: días de km de Hunter que se usan para el promedio de km por día.'),
 ('preventivo_tope_dias','365','numero','Preventivos: si el pronóstico pasa de estos días, la unidad se marca “Bajo uso”.'),
 ('preventivo_aviso_proximo_dias','30','numero','Preventivos: se avisa “Próximo” cuando faltan estos días o menos.')
on conflict (clave) do nothing;
update configuracion set descripcion = 'Cotizaciones de terceros con subtotal hasta este valor las aprueba el supervisor; más, el maestro.'
 where clave = 'limite_aprobacion_jefe';

insert into centros_costo (codigo, nombre, costo_por_km, es_clientes) values
 ('MNTOPL3RAS','Unidades de clientes / terceros', false, true)
on conflict (codigo) do nothing;

insert into complejidades (codigo, nombre, multiplicador, orden) values
 ('leve','Leve',0.8,1), ('moderado','Moderado',1.0,2), ('grave','Grave',1.4,3)
on conflict (codigo) do nothing;

-- Los 8 sistemas del registro de componentes del kardex, con sus mismos valores.
insert into sistemas_preventivos (codigo, nombre, modo, intervalo_cabezal, intervalo_plataforma, intervalo_montacarga,
       dias_sin_km, pct_prematuro, registro_automatico, incluye, excluye, km_incluye, km_excluye, motivos_falla, orden) values
 ('aceite','Aceite motor','km',10000,6000,0,60,60,false,'FILTRO ACEITE, FLT ACEITE','CAJA',
   'ACEITE MOTOR, FILTRO, FLT, COMBUSTIBLE SECUNDARIO','CAJA, CORONA, HIDRAULICO, TRANSMISION, DIFERENCIAL',null,1),
 ('caja','Caja y corona','km',25000,25000,0,180,60,false,
   'ACEITE CAJA, ACEITE DE CAJA, ACEITE CORONA, ACEITE DE CORONA, ACEITE TRANSMISION, ACEITE DIFERENCIAL','',
   'ACEITE CAJA, ACEITE DE CAJA, ACEITE CORONA, ACEITE DE CORONA, ACEITE TRANSMISION, ACEITE DIFERENCIAL','',null,2),
 ('embrague','Kit de embrague','km',40000,40000,0,365,60,true,
   'KIT EMBRAGUE, KIT DE EMBRAGUE, DISCO DE EMBRAGUE, PLATO DE EMBRAGUE, FORRO EMBRAGUE, FORRO DE EMBRAGUE','VENTILADOR',null,null,null,3),
 ('frenos','Frenos (zapatas)','km',35000,35000,0,180,60,true,
   'ZAPATA, FORRO DE FRENO, BANDA DE FRENO, PASTILLAS DE FRENO','MOTO, TEMPLADOR, PERNO, RESORTE',null,null,null,4),
 ('llantas','Llantas','dias',365,365,365,365,0,false,'LLANTA','VALVULA, PARCHE',null,null,'REVENTADA, CORTADA, PERFORADA, CHICHON',5),
 ('radiador','Radiador','falla',null,null,null,0,0,true,'RADIADOR','TAPA, MANGUERA, REFRIGERANTE, AGUA, ABRAZADERA',null,null,null,6),
 ('inyeccion','Inyección','falla',null,null,null,0,0,true,'INYECTOR, BOMBA INYEC, BOMBA DE INYEC','CAÑERIA, CANERIA, TUBERIA, SELLO, TOBERA',null,null,null,7),
 ('baterias','Baterías','dias',365,365,365,365,50,true,'BATERIA','BORNE, TERMINAL, CABLE, AGUA, CARGADOR',null,null,null,8)
on conflict (codigo) do nothing;

-- Sistemas existentes → cápsulas de mecánica con los nombres de la especificación.
update sistemas set nombre = 'Embrague y caja' where nombre = 'Caja' and taller = 'mecanica'
  and not exists (select 1 from sistemas where lower(nombre) = 'embrague y caja');
update sistemas set nombre = 'Corona / diferencial' where nombre = 'Corona'
  and not exists (select 1 from sistemas where lower(nombre) = 'corona / diferencial');
update sistemas set nombre = 'Sistema eléctrico' where nombre = 'Eléctrico'
  and not exists (select 1 from sistemas where lower(nombre) = 'sistema eléctrico');
update sistemas set activo = false where nombre in ('Embrague','Carrocería','Plataforma','Lavado','Otros') and taller = 'mecanica';

insert into sistemas (taller, nombre, icono, orden, aplica_complejidad)
select x.taller, x.nombre, x.icono, x.orden, x.compl from (values
 ('mecanica','Motor','fa-gears',1,true), ('mecanica','Sistema eléctrico','fa-bolt',2,true), ('mecanica','Frenos','fa-circle-stop',3,true),
 ('mecanica','Suspensión','fa-arrows-up-down',4,true), ('mecanica','Dirección','fa-dharmachakra',5,true), ('mecanica','Embrague y caja','fa-gear',6,true),
 ('mecanica','Corona / diferencial','fa-cog',7,true), ('mecanica','Refrigeración','fa-temperature-low',8,true),
 ('mecanica','Inyección y combustible','fa-gas-pump',9,true), ('mecanica','Sistema neumático (aire)','fa-wind',10,true),
 ('mecanica','Llantas','fa-circle-dot',11,true), ('mecanica','Lubricación / preventivo','fa-oil-can',12,true),
 ('soldadura','Compuertas','fa-bars-staggered',1,true), ('soldadura','Perfiles','fa-table-cells-large',2,true),
 ('soldadura','Travesaños','fa-grip-lines',3,true), ('soldadura','Tanque de lixiviados','fa-box-archive',4,false),
 ('soldadura','Cabina','fa-warehouse',5,true), ('soldadura','UPN','fa-microchip',6,true),
 ('soldadura','Portallantas','fa-circle-dot',7,true), ('soldadura','Escalerillas','fa-stairs',8,true)
) as x(taller, nombre, icono, orden, compl)
where not exists (select 1 from sistemas s where s.taller = x.taller and lower(s.nombre) = lower(x.nombre));
update sistemas s set icono = x.icono, orden = x.orden from (values
 ('Motor','fa-gears',1), ('Sistema eléctrico','fa-bolt',2), ('Frenos','fa-circle-stop',3), ('Suspensión','fa-arrows-up-down',4),
 ('Dirección','fa-dharmachakra',5), ('Embrague y caja','fa-gear',6), ('Corona / diferencial','fa-cog',7), ('Llantas','fa-circle-dot',11)
) as x(nombre, icono, orden) where s.taller = 'mecanica' and s.nombre = x.nombre and (s.icono is null or s.icono not like 'fa-%');

-- Catálogo inicial de soldadura: el de la maqueta del coordinador (editable en Maestros).
insert into elementos (sistema_id, nombre, orden)
select s.id, x.elemento, x.orden from (values
 ('Compuertas','Parantes',1), ('Compuertas','Bisagras',2), ('Compuertas','Orejas de compuertas',3), ('Compuertas','Pin con cadena',4),
 ('Perfiles','Perfil lateral',1), ('Perfiles','Perfil superior',2), ('Perfiles','Perfil inferior',3), ('Perfiles','Base de luz',4),
 ('Travesaños','Chasis falso',1), ('Travesaños','Travesaños',2), ('Travesaños','Guardalodos',3),
 ('Tanque de lixiviados','Válvulas',1), ('Tanque de lixiviados','Mangueras',2), ('Tanque de lixiviados','Defogue',3), ('Tanque de lixiviados','Conexiones',4),
 ('Cabina','Estructura',1), ('Cabina','Parches de cabina',2), ('Cabina','Soportes',3),
 ('UPN','Perfil UPN 100',1), ('UPN','Perfil UPN 120',2), ('UPN','Perfil UPN 150',3)
) as x(sistema, elemento, orden)
join sistemas s on s.taller = 'soldadura' and s.nombre = x.sistema
where not exists (select 1 from elementos e where e.sistema_id = s.id and lower(e.nombre) = lower(x.elemento));

insert into intervenciones (sistema_id, nombre, horas_estandar, orden)
select s.id, x.intervencion, x.horas, x.orden from (values
 ('Compuertas','Resoldar',0.5,1), ('Compuertas','Reparar soporte',1.0,2), ('Compuertas','Fabricar',2.5,3), ('Compuertas','Reponer',1.5,4),
 ('Compuertas','Reparar pin',0.4,5), ('Compuertas','Reparar cadena',0.3,6), ('Compuertas','Reponer cadena',0.4,7), ('Compuertas','Reponer conjunto',2.0,8),
 ('Perfiles','Reparación de perfil',1.2,1), ('Perfiles','Colocación de parche',0.8,2), ('Perfiles','Reposición de sección',2.0,3),
 ('Perfiles','Reparación de base de luz de ruta',0.6,4),
 ('Travesaños','Reparar',1.5,1), ('Travesaños','Enderezar',1.2,2), ('Travesaños','Reforzar',2.0,3), ('Travesaños','Fabricar',3.0,4), ('Travesaños','Reponer',2.5,5),
 ('Tanque de lixiviados','Cambio de manguera',0.8,1), ('Tanque de lixiviados','Reparación de válvula',1.2,2), ('Tanque de lixiviados','Reposición de válvula',1.5,3),
 ('Tanque de lixiviados','Reparación de defogue',1.0,4), ('Tanque de lixiviados','Reparación de conexiones',0.9,5),
 ('Cabina','Reparación de cabina',2.5,1), ('Cabina','Colocación de parches',1.2,2), ('Cabina','Reparación de estructura',3.5,3),
 ('UPN','Enderezar',1.5,1), ('UPN','Reparar',1.8,2), ('UPN','Reforzar',2.2,3), ('UPN','Reponer',3.0,4)
) as x(sistema, intervencion, horas, orden)
join sistemas s on s.taller = 'soldadura' and s.nombre = x.sistema
where not exists (select 1 from intervenciones i where i.sistema_id = s.id and lower(i.nombre) = lower(x.intervencion));

insert into listas_valores (lista, valor, taller, orden)
select x.lista, x.valor, x.taller, x.orden from (values
 ('causa_dano','Corrosión',null,1), ('causa_dano','Golpe',null,2), ('causa_dano','Fatiga',null,3),
 ('causa_dano','Sobrecarga',null,4), ('causa_dano','Desgaste',null,5), ('causa_dano','Fabricación nueva',null,6),
 ('causa_dano','Mejora',null,7),
 ('motivo_imprevisto','Falta de repuesto o material',null,1), ('motivo_imprevisto','Espera de herramienta o equipo',null,2),
 ('motivo_imprevisto','Falta de energía o aire comprimido',null,3), ('motivo_imprevisto','Reasignado a otra urgencia',null,4),
 ('motivo_imprevisto','Espera de autorización',null,5), ('motivo_imprevisto','Pieza agripada o daño oculto',null,6),
 ('motivo_imprevisto','Otro',null,9),
 ('motivo_no_realizado','Sin repuesto en bodega',null,1), ('motivo_no_realizado','Sin autorización',null,2),
 ('motivo_no_realizado','La unidad debía salir',null,3), ('motivo_no_realizado','Requiere taller externo',null,4),
 ('motivo_no_realizado','Otro',null,9),
 ('motivo_descarte','No se encontró la falla',null,1), ('motivo_descarte','Duplicado',null,2),
 ('motivo_descarte','No corresponde',null,3), ('motivo_descarte','Otro',null,9),
 ('tipo_novedad_personal','Permiso',null,1), ('tipo_novedad_personal','Capacitación',null,2),
 ('tipo_novedad_personal','Calamidad doméstica',null,3), ('tipo_novedad_personal','Llamado de atención',null,4),
 ('tipo_novedad_personal','Reconocimiento',null,5),
 ('checklist_calidad','Prueba de ruta realizada','mecanica',1), ('checklist_calidad','Sin fugas (aceite, aire, refrigerante)','mecanica',2),
 ('checklist_calidad','Torque de ruedas verificado','mecanica',3), ('checklist_calidad','Sin testigos encendidos en tablero','mecanica',4),
 ('checklist_calidad','Cordones de soldadura completos y limpios','soldadura',1), ('checklist_calidad','Escoria y salpicaduras retiradas','soldadura',2),
 ('checklist_calidad','Pintura o anticorrosivo aplicado','soldadura',3), ('checklist_calidad','Medidas y escuadra verificadas','soldadura',4),
 ('motivo_llanta','DESGASTE',null,1), ('motivo_llanta','REVENTADA',null,2), ('motivo_llanta','CORTADA/CHICHON',null,3),
 ('motivo_llanta','PERFORADA',null,4), ('motivo_llanta','POR FIN DE VIDA UTIL',null,5),
 ('kit_embrague','COMPLETO',null,1), ('kit_embrague','PLATO',null,2), ('kit_embrague','VOLANTE',null,3),
 ('frenos','ZAPATAS DELANTERAS',null,1), ('frenos','ZAPATAS POSTERIORES',null,2), ('frenos','ZAPATAS COMPLETAS',null,3),
 ('aceite','MOTOR',null,1), ('aceite','CAJA',null,2), ('aceite','CORONA',null,3), ('aceite','CAJA Y CORONA',null,4),
 ('inyeccion','BOMBA',null,1), ('inyeccion','INYECTORES',null,2), ('inyeccion','BOMBA E INYECTORES',null,3),
 ('criterio','OK',null,1), ('criterio','AJUSTAR',null,2), ('criterio','ELIMINAR CODIGO',null,3),
 ('estado_compra','Pendiente',null,1), ('estado_compra','Recibido',null,2), ('estado_compra','Anulada',null,3),
 ('estado_herramienta','PENDIENTE',null,1), ('estado_herramienta','RECIBIDO',null,2)
) as x(lista, valor, taller, orden)
where not exists (select 1 from listas_valores l where l.lista = x.lista and lower(l.valor) = lower(x.valor)
                    and coalesce(l.taller,'') = coalesce(x.taller,''));

-- ============================================================ 12b. Funciones de Maestros
-- El maestro define o cambia la clave de aprobación (mínimo 4 caracteres).
create or replace function fijar_clave_aprobacion(p_nueva text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not es_maestro() then raise exception 'Solo el maestro puede definir la clave de aprobación.'; end if;
  if length(coalesce(p_nueva, '')) < 4 then raise exception 'La clave debe tener al menos 4 caracteres.'; end if;
  if exists (select 1 from clave_aprobacion) then
    update clave_aprobacion set clave_cifrada = crypt(p_nueva, gen_salt('bf'));
  else
    insert into clave_aprobacion (clave_cifrada) values (crypt(p_nueva, gen_salt('bf')));
  end if;
end $$;

-- ¿Está definida? ¿Quién y cuándo? (sin mostrar la clave)
create or replace function estado_clave_aprobacion() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce((select jsonb_build_object('definida', true,
            'por', (select nombre_completo from usuarios where id = coalesce(c.actualizado_por, c.creado_por)),
            'en', coalesce(c.actualizado_en, c.creado_en)) from clave_aprobacion c limit 1),
         jsonb_build_object('definida', false))
$$;

-- Verifica la clave (la usará el kardex en la Fase 3). Exige el permiso aprobar_ajustes.
create or replace function verificar_clave_aprobacion(p_clave text) returns boolean
language plpgsql stable security definer set search_path = public, extensions as $$
declare v text;
begin
  if not tiene_permiso('aprobar_ajustes') then raise exception 'Su usuario no tiene el permiso de aprobar ajustes.'; end if;
  select clave_cifrada into v from clave_aprobacion limit 1;
  if v is null then raise exception 'Aún no hay clave de aprobación. El maestro debe definirla en Maestros → Parámetros.'; end if;
  return crypt(coalesce(p_clave, ''), v) = v;
end $$;

-- El técnico actualiza solo su teléfono y su contacto de emergencia.
create or replace function actualizar_mis_datos(p_telefono text, p_contacto_emergencia text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if tecnico_actual() is null then raise exception 'Su usuario no está vinculado a una ficha de técnico.'; end if;
  update tecnicos set telefono = nullif(trim(p_telefono), ''), contacto_emergencia = nullif(trim(p_contacto_emergencia), '')
   where id = tecnico_actual();
end $$;

-- ============================================================ 13. Accesos de la API
grant execute on function tiene_permiso(text), es_maestro(), tecnico_actual(), tarifa_vigente(uuid,date),
      fijar_clave_aprobacion(text), estado_clave_aprobacion(), verificar_clave_aprobacion(text),
      actualizar_mis_datos(text,text) to authenticated;
revoke execute on function fijar_clave_aprobacion(text), estado_clave_aprobacion(), verificar_clave_aprobacion(text),
      actualizar_mis_datos(text,text) from public, anon;
revoke execute on function aplicar_reglas_comunes() from public;
grant select on v_catalogo_trabajos, v_vehiculos to authenticated;
revoke all on all tables in schema public from anon;
revoke execute on function registrar_acta(text,jsonb), firmar_acta(text,uuid,text,text), abrir_ot(jsonb),
       cambiar_estado_ot(uuid,text,text), siguiente_numero(text) from public, anon;

-- ============================================================ 14. Diccionario de datos (descripciones)
comment on column usuarios.rol is 'maestro | supervisor (asesor de servicios / jefe de patio) | bodega | tecnico.';
comment on column usuarios.permisos_extra is 'Permisos sumados a la persona además de su rol: bodega, aprobar_ajustes, gestion_personal, ver_costos, editar_catalogos.';

comment on table centros_costo is 'Centros de costo a los que se carga el gasto de los vehículos.';
comment on column centros_costo.codigo is 'Código contable, ej. MNTOPL3RAS.';
comment on column centros_costo.nombre is 'Nombre descriptivo.';
comment on column centros_costo.costo_por_km is 'Sí = sus vehículos entran al reporte de costo por km de mecánica.';
comment on column centros_costo.es_clientes is 'Sí = centro de las unidades rentadas a clientes (se concilia y cobra).';
comment on column centros_costo.activo is 'No = ya no se usa. Nunca se borra.';

comment on table clientes is 'Clientes a quienes se renta unidades o se atiende en el taller; se les factura cada cierto tiempo.';
comment on column clientes.nombre is 'Razón social o nombre.';
comment on column clientes.ruc is 'RUC o cédula.';
comment on column clientes.contacto is 'Persona de contacto.';
comment on column clientes.telefono is 'Teléfono de contacto.';
comment on column clientes.correo is 'Correo para enviar la conciliación.';
comment on column clientes.observaciones is 'Notas libres.';
comment on column clientes.activo is 'No = ya no se atiende. Nunca se borra.';

comment on column vehiculos.estado is 'activo | parado | venta | tramite (los mismos estados de la flota del kardex).';
comment on column vehiculos.nombre_hunter is 'Nombre de la columna de esta unidad en el reporte de odómetro de Hunter (ej. DC001--GBP1502). Sirve para cargar los km diarios.';
comment on column vehiculos.estado_desde is 'Fecha desde la que el vehículo está en el estado actual.';
comment on column vehiculos.propiedad is 'propio | rentado (unidad rentada a un cliente).';
comment on column vehiculos.cliente_id is 'Cliente al que está rentada la unidad (obligatorio si es rentada).';
comment on column vehiculos.centro_costo_id is 'Centro de costo del gasto. Las rentadas van siempre al centro de clientes (MNTOPL3RAS).';
comment on column vehiculos.fecha_ingreso_flota is 'Mes y año en que la unidad ingresó a la flota (día 1). Sirve para calcular la edad.';

comment on table historial_estados_vehiculo is 'Tramos de cada estado del vehículo (activo, parado, venta, trámite) con sus fechas. Lo llena el sistema.';
comment on column historial_estados_vehiculo.vehiculo_id is 'Vehículo.';
comment on column historial_estados_vehiculo.estado is 'Estado en ese tramo.';
comment on column historial_estados_vehiculo.desde is 'Inicio del tramo.';
comment on column historial_estados_vehiculo.hasta is 'Fin del tramo (vacío = estado actual).';

comment on column tecnicos.codigo is 'Código corto del técnico (ej. T01). Aparece en sus observaciones y en la producción.';
comment on column tecnicos.especialidad is 'mecanica | soldadura | ambas.';
comment on column tecnicos.cargo is 'Cargo (ej. mecánico A, soldador, ayudante).';
comment on column tecnicos.jornada_horas is 'Horas de trabajo por día. Base de las horas disponibles.';
comment on column tecnicos.contacto_emergencia is 'Contacto autorizado para emergencias. Lo puede editar el propio técnico.';
comment on column tecnicos.fecha_ingreso is 'Fecha de ingreso a la empresa (para el saldo de vacaciones).';
comment on column tecnicos.area_taller_id is 'Área anterior (Fase 1 antigua). Se reemplaza por especialidad.';

comment on table tarifas_tecnico is 'Tarifa interna por hora de cada técnico, con su fecha de vigencia. Solo la ve quien tiene el permiso ver_costos.';
comment on column tarifas_tecnico.tecnico_id is 'Técnico.';
comment on column tarifas_tecnico.tarifa_hora is 'Costo interno por hora (USD).';
comment on column tarifas_tecnico.vigente_desde is 'Desde qué fecha rige esta tarifa.';
comment on column tarifas_tecnico.observacion is 'Motivo del cambio de tarifa.';

comment on table sistemas is 'Sistemas o componentes de cada taller. Cada uno es una cápsula en los ambientes Mecánica y Soldadura.';
comment on column sistemas.taller is 'mecanica | soldadura.';
comment on column sistemas.icono is 'Ícono de la cápsula (nombre de Font Awesome, ej. fa-gears).';
comment on column sistemas.aplica_complejidad is 'Sí = sus trabajos se multiplican por la complejidad (leve, moderado, grave). Ej.: Tanque de lixiviados no.';
comment on column sistemas.descripcion is 'Ayuda breve que se muestra en la cápsula.';

comment on table sistemas_preventivos is 'Sistemas del registro de componentes y pronóstico del kardex, con sus intervalos. Son los “intervalos preventivos” de Parámetros.';
comment on column sistemas_preventivos.codigo is 'Código corto: aceite, caja, embrague, frenos, llantas, radiador, inyeccion, baterias.';
comment on column sistemas_preventivos.nombre is 'Nombre visible.';
comment on column sistemas_preventivos.modo is 'km (por kilometraje) | dias (por tiempo) | falla (frecuencia de daños).';
comment on column sistemas_preventivos.intervalo_cabezal is 'Intervalo para cabezales (DC): km si el modo es km, días si es dias.';
comment on column sistemas_preventivos.intervalo_plataforma is 'Intervalo para plataformas (DP/DR).';
comment on column sistemas_preventivos.intervalo_montacarga is 'Intervalo para montacargas (0 = se calcula por tiempo, no tienen km en Hunter).';
comment on column sistemas_preventivos.dias_sin_km is 'Días que se usan cuando la unidad no tiene km de Hunter.';
comment on column sistemas_preventivos.pct_prematuro is 'Se marca prematuro si el cambio se hizo antes de este % del intervalo (0 = no medir).';
comment on column sistemas_preventivos.registro_automatico is 'Sí = todo despacho con estas palabras cuenta como cambio sin confirmar.';
comment on column sistemas_preventivos.incluye is 'Sugerir como cambio si el artículo incluye estas palabras (separadas por coma).';
comment on column sistemas_preventivos.excluye is '…y no incluye estas palabras.';
comment on column sistemas_preventivos.km_incluye is 'Registro automático por km: el artículo incluye estas palabras y la salida trae km.';
comment on column sistemas_preventivos.km_excluye is '…y no incluye estas palabras.';
comment on column sistemas_preventivos.motivos_falla is 'Motivos que cuentan como falla y no como desgaste (llantas).';
comment on column sistemas_preventivos.orden is 'Orden en las listas.';
comment on column sistemas_preventivos.activo is 'No = ya no se usa.';

comment on table elementos is 'Elementos de cada sistema/cápsula (ej. Compuertas → bisagra).';
comment on column elementos.sistema_id is 'Sistema o cápsula al que pertenece.';
comment on column elementos.nombre is 'Nombre del elemento.';
comment on column elementos.orden is 'Orden en la pantalla.';
comment on column elementos.activo is 'No = ya no aparece para nuevos trabajos. Nunca se borra.';

comment on table intervenciones is 'Intervenciones de cada componente (cápsula), con su tiempo estándar en horas-hombre totales. Sirven para todos los elementos del componente.';
comment on column intervenciones.sistema_id is 'Componente (cápsula) al que pertenece.';
comment on column intervenciones.nombre is 'Nombre de la intervención (ej. Resoldar, Enderezar, Reponer).';
comment on column intervenciones.horas_estandar is 'Horas-hombre totales del trabajo. Si exige dos personas, ya viene multiplicado.';
comment on column intervenciones.sistema_preventivo_id is 'Sistema preventivo que alimenta en el registro de componentes (opcional).';
comment on column intervenciones.orden is 'Orden en la pantalla.';
comment on column intervenciones.activo is 'No = ya no aparece para nuevos trabajos. Nunca se borra.';

comment on table clave_aprobacion is 'Clave de aprobación de ajustes del kardex, cifrada. Nadie la puede leer; se fija y se verifica con funciones.';
comment on column clave_aprobacion.clave_cifrada is 'Clave cifrada con bcrypt (pgcrypto).';

comment on table complejidades is 'Multiplicadores de complejidad del tiempo estándar.';
comment on column complejidades.codigo is 'leve | moderado | grave.';
comment on column complejidades.nombre is 'Nombre visible.';
comment on column complejidades.multiplicador is 'Factor que multiplica las horas estándar (ej. 0,8 / 1,0 / 1,4).';
comment on column complejidades.orden is 'Orden en la pantalla.';
comment on column complejidades.activo is 'No = no se ofrece.';

comment on table proveedores is 'Proveedores de repuestos y talleres externos (terceros).';
comment on column proveedores.nombre is 'Razón social.';
comment on column proveedores.ruc is 'RUC.';
comment on column proveedores.tipo is 'repuestos | taller_externo | ambos.';
comment on column proveedores.especialidad is 'Para talleres externos: mecanica | soldadura | ambas.';
comment on column proveedores.contacto is 'Persona de contacto.';
comment on column proveedores.telefono is 'Teléfono.';
comment on column proveedores.correo is 'Correo.';
comment on column proveedores.direccion is 'Dirección.';
comment on column proveedores.observaciones is 'Notas libres.';
comment on column proveedores.activo is 'No = ya no se usa. Nunca se borra.';

comment on table listas_valores is 'Listas editables: causas de daño, motivos de imprevisto, de no realizado y de descarte, tipos de novedad de personal y checklists de control de calidad.';
comment on column listas_valores.lista is 'causa_dano | motivo_imprevisto | motivo_no_realizado | motivo_descarte | tipo_novedad_personal | checklist_calidad | listas del kardex: motivo_llanta | kit_embrague | frenos | aceite | inyeccion | criterio | estado_compra | estado_herramienta.';
comment on column listas_valores.valor is 'Texto que se elige en la pantalla.';
comment on column listas_valores.descripcion is 'Ayuda opcional.';
comment on column listas_valores.taller is 'Solo para un taller (mecanica | soldadura); vacío = ambos.';
comment on column listas_valores.orden is 'Orden en la lista.';
comment on column listas_valores.activo is 'No = ya no se ofrece. Nunca se borra.';

-- Columnas estándar de las tablas nuevas
do $$
declare c record;
begin
  for c in select cl.relname as table_name, at.attname as column_name
             from pg_class cl join pg_namespace n on n.oid = cl.relnamespace
             join pg_attribute at on at.attrelid = cl.oid and at.attnum > 0 and not at.attisdropped
            where n.nspname = 'public' and cl.relkind = 'r'
              and at.attname in ('id','creado_en','creado_por','actualizado_en','actualizado_por','anulado','anulado_motivo','anulado_por','anulado_en')
              and col_description(cl.oid, at.attnum) is null
  loop
    execute format('comment on column %I.%I is %L', c.table_name, c.column_name, case c.column_name
      when 'id' then 'Identificador único universal (UUID).'
      when 'creado_en' then 'Fecha y hora de creación.'
      when 'creado_por' then 'Usuario que creó el registro.'
      when 'actualizado_en' then 'Fecha y hora de la última modificación.'
      when 'actualizado_por' then 'Usuario que hizo la última modificación.'
      when 'anulado' then 'Sí = registro anulado (no se borra).'
      when 'anulado_motivo' then 'Motivo de la anulación (obligatorio al anular).'
      when 'anulado_por' then 'Usuario que anuló.'
      when 'anulado_en' then 'Fecha y hora de la anulación.' end);
  end loop;
end $$;

notify pgrst, 'reload schema';

-- >>>>>>>>>>>>>>>>>>>> 008_supabase_v2.sql
set client_min_messages = warning;
-- =====================================================================
-- 008 · Ajustes de Supabase para los roles nuevos (Fase 1 unificada)
-- Igual que 005, es lo único que depende de Supabase en esta versión.
-- =====================================================================

-- Los usuarios nuevos nacen como técnico INACTIVO y sin permisos extra.
-- Solo el maestro los activa y les da rol (pantalla Maestros → Usuarios).
create or replace function public.tg_nuevo_usuario_auth() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.usuarios (id, nombre_completo, correo, rol, telefono, activo)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'nombre_completo', split_part(new.email, '@', 1)),
          new.email, 'tecnico', new.raw_user_meta_data->>'telefono', false)
  on conflict (id) do nothing;
  return new;
end $$;

drop policy if exists "archivos_leer" on storage.objects;
create policy "archivos_leer" on storage.objects for select to authenticated
  using (bucket_id = 'archivos' and public.rol_actual() is not null);

drop policy if exists "archivos_subir" on storage.objects;
create policy "archivos_subir" on storage.objects for insert to authenticated
  with check (bucket_id = 'archivos' and public.tiene_permiso('operar_ot'));

notify pgrst, 'reload schema';

-- >>>>>>>>>>>>>>>>>>>> 009_fase2_ot.sql
set client_min_messages = warning;
-- =====================================================================
-- 009 · FASE 2 · OT por segmentos + ambientes Mecánica y Soldadura
--       (cápsulas) + observaciones de técnicos.
-- Se aplica sobre 007/008. Las OT anteriores se conservan tal cual
-- (formato 'anterior'); las nuevas usan los segmentos de la sección 4.
-- =====================================================================

-- ============================================================ 1. Orden de trabajo (segmento 1)
-- Las OT que ya existían quedan como 'anterior'; las nuevas, 'segmentos'.
do $$ begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'ordenes_trabajo' and column_name = 'formato') then
    alter table ordenes_trabajo add column formato text not null default 'anterior';
    alter table ordenes_trabajo alter column formato set default 'segmentos';
  end if;
end $$;
alter table ordenes_trabajo drop constraint if exists ordenes_trabajo_formato_check;
alter table ordenes_trabajo add constraint ordenes_trabajo_formato_check check (formato in ('anterior','segmentos'));

alter table ordenes_trabajo alter column vehiculo_id drop not null;
alter table ordenes_trabajo alter column lectura drop not null;
alter table ordenes_trabajo drop constraint if exists ordenes_trabajo_motivo_ingreso_check;
alter table ordenes_trabajo add constraint ordenes_trabajo_motivo_ingreso_check
  check (motivo_ingreso in ('preventivo','correctivo','siniestro','llantas','fabricacion','renovado','inspeccion'));
alter table ordenes_trabajo add column if not exists combustible text;
alter table ordenes_trabajo drop constraint if exists ordenes_trabajo_combustible_check;
alter table ordenes_trabajo add constraint ordenes_trabajo_combustible_check check (combustible is null or combustible in ('E','1/4','1/2','3/4','F'));
alter table ordenes_trabajo add column if not exists fabricacion_descripcion text;
alter table ordenes_trabajo add column if not exists fabricacion_cantidad integer;
alter table ordenes_trabajo add column if not exists centro_costo_id uuid references centros_costo(id);
alter table ordenes_trabajo add column if not exists cliente_id uuid references clientes(id);
alter table ordenes_trabajo add column if not exists observaciones_recepcion text;
alter table ordenes_trabajo add column if not exists obs_supervisor_mecanica text;
alter table ordenes_trabajo add column if not exists obs_supervisor_soldadura text;
alter table ordenes_trabajo drop constraint if exists ordenes_trabajo_vehiculo_check;
alter table ordenes_trabajo add constraint ordenes_trabajo_vehiculo_check
  check (vehiculo_id is not null or motivo_ingreso = 'fabricacion');

-- Checklist de recepción de la OT
create table if not exists ot_checklist (
  id                 uuid primary key default gen_random_uuid(),
  orden_trabajo_id   uuid not null references ordenes_trabajo(id),
  item_checklist_id  uuid not null references items_checklist(id),
  resultado          text not null check (resultado in ('ok','falta','danado')),
  observacion        text,
  creado_en          timestamptz not null default now(),
  creado_por         uuid references usuarios(id),
  actualizado_en     timestamptz,
  actualizado_por    uuid references usuarios(id),
  unique (orden_trabajo_id, item_checklist_id)
);

-- Diagrama de daños: también desde la OT
alter table danos_vehiculo add column if not exists orden_trabajo_id uuid references ordenes_trabajo(id);
alter table danos_vehiculo drop constraint if exists danos_vehiculo_check;
alter table danos_vehiculo drop constraint if exists danos_vehiculo_origen_check;
alter table danos_vehiculo add constraint danos_vehiculo_origen_check
  check (acta_recepcion_id is not null or acta_entrega_id is not null or orden_trabajo_id is not null);

-- Fotos (Cloudflare R2): el índice vive en "archivos"
alter table archivos drop constraint if exists archivos_tipo_check;
alter table archivos add constraint archivos_tipo_check check (tipo in ('firma','proforma','foto'));

-- ============================================================ 2. Solicitud del chofer (segmento 2)
create table if not exists ot_solicitudes (
  id                uuid primary key default gen_random_uuid(),
  orden_trabajo_id  uuid not null references ordenes_trabajo(id),
  numero_linea      integer not null,
  descripcion       text not null,
  taller_sugerido   text not null check (taller_sugerido in ('mecanica','soldadura')),
  estado            text not null default 'pendiente' check (estado in ('pendiente','atendida','no_realizada','descartada')),
  motivo            text,
  comentario        text,
  resuelto_por      uuid references usuarios(id),
  resuelto_en       timestamptz,
  anulado           boolean not null default false,
  anulado_motivo    text,
  anulado_por       uuid references usuarios(id),
  anulado_en        timestamptz,
  creado_en         timestamptz not null default now(),
  creado_por        uuid references usuarios(id),
  actualizado_en    timestamptz,
  actualizado_por   uuid references usuarios(id),
  unique (orden_trabajo_id, numero_linea),
  check (estado not in ('no_realizada','descartada') or coalesce(length(trim(motivo)),0) > 0),
  check (not anulado or coalesce(length(trim(anulado_motivo)),0) > 0)
);

-- ============================================================ 3. Hallazgos (segmento 3)
create table if not exists ot_hallazgos (
  id                uuid primary key default gen_random_uuid(),
  orden_trabajo_id  uuid not null references ordenes_trabajo(id),
  numero_linea      integer not null,
  descripcion       text not null,
  taller            text not null check (taller in ('mecanica','soldadura')),
  sistema_id        uuid references sistemas(id),
  estado            text not null default 'pendiente' check (estado in ('pendiente','aprobado','descartado')),
  motivo            text,
  comentario        text,
  resuelto_por      uuid references usuarios(id),
  resuelto_en       timestamptz,
  anulado           boolean not null default false,
  anulado_motivo    text,
  anulado_por       uuid references usuarios(id),
  anulado_en        timestamptz,
  creado_en         timestamptz not null default now(),
  creado_por        uuid references usuarios(id),
  actualizado_en    timestamptz,
  actualizado_por   uuid references usuarios(id),
  unique (orden_trabajo_id, numero_linea),
  check (estado <> 'descartado' or coalesce(length(trim(motivo)),0) > 0),
  check (not anulado or coalesce(length(trim(anulado_motivo)),0) > 0)
);

-- ============================================================ 4. Trabajos de mecánica y soldadura (segmentos 4 y 5)
create table if not exists ot_trabajos (
  id                    uuid primary key default gen_random_uuid(),
  orden_trabajo_id      uuid not null references ordenes_trabajo(id),
  numero_linea          integer not null,
  taller                text not null check (taller in ('mecanica','soldadura')),
  sistema_id            uuid not null references sistemas(id),
  elemento_id           uuid references elementos(id),
  intervencion_id       uuid not null references intervenciones(id),
  sistema_nombre        text not null,
  elemento_nombre       text,
  intervencion_nombre   text not null,
  horas_unitarias       numeric(6,2) not null,
  cantidad              numeric(8,2) not null default 1 check (cantidad > 0),
  complejidad_id        uuid references complejidades(id),
  complejidad_nombre    text,
  multiplicador         numeric(4,2) not null default 1,
  horas_estandar        numeric(8,2) not null default 0,
  estado                text not null default 'pendiente' check (estado in ('pendiente','en_proceso','terminado','no_realizado')),
  origen                text not null check (origen in ('chofer','hallazgo','preventivo')),
  solicitud_id          uuid references ot_solicitudes(id),
  hallazgo_id           uuid references ot_hallazgos(id),
  causa                 text,
  material_base         text check (material_base in ('inoxidable','hierro_negro')),
  observacion           text,
  motivo_no_realizado   text,
  detalle_no_realizado  text,
  terminado_en          timestamptz,
  terminado_por         uuid references usuarios(id),
  anulado               boolean not null default false,
  anulado_motivo        text,
  anulado_por           uuid references usuarios(id),
  anulado_en            timestamptz,
  creado_en             timestamptz not null default now(),
  creado_por            uuid references usuarios(id),
  actualizado_en        timestamptz,
  actualizado_por       uuid references usuarios(id),
  unique (orden_trabajo_id, numero_linea),
  check (estado <> 'no_realizado' or coalesce(length(trim(motivo_no_realizado)),0) > 0),
  check (origen <> 'chofer' or solicitud_id is not null),
  check (origen <> 'hallazgo' or hallazgo_id is not null),
  check (not anulado or coalesce(length(trim(anulado_motivo)),0) > 0)
);
create index if not exists ot_trabajos_ot on ot_trabajos (orden_trabajo_id);

-- Técnicos de cada trabajo y reparto de las horas-hombre (por defecto en partes iguales)
create table if not exists ot_trabajo_tecnicos (
  id                uuid primary key default gen_random_uuid(),
  trabajo_id        uuid not null references ot_trabajos(id),
  tecnico_id        uuid not null references tecnicos(id),
  porcentaje        numeric(5,2) not null check (porcentaje > 0 and porcentaje <= 100),
  horas             numeric(8,2) not null default 0,
  anulado           boolean not null default false,
  anulado_motivo    text,
  anulado_por       uuid references usuarios(id),
  anulado_en        timestamptz,
  creado_en         timestamptz not null default now(),
  creado_por        uuid references usuarios(id),
  actualizado_en    timestamptz,
  actualizado_por   uuid references usuarios(id),
  check (not anulado or coalesce(length(trim(anulado_motivo)),0) > 0)
);
create unique index if not exists ot_trabajo_tecnicos_unico on ot_trabajo_tecnicos (trabajo_id, tecnico_id) where not anulado;
create index if not exists ot_trabajo_tecnicos_tecnico on ot_trabajo_tecnicos (tecnico_id);

-- "Inspeccionado OK" por cápsula
create table if not exists ot_inspecciones (
  id                uuid primary key default gen_random_uuid(),
  orden_trabajo_id  uuid not null references ordenes_trabajo(id),
  sistema_id        uuid not null references sistemas(id),
  anulado           boolean not null default false,
  anulado_motivo    text,
  anulado_por       uuid references usuarios(id),
  anulado_en        timestamptz,
  creado_en         timestamptz not null default now(),
  creado_por        uuid references usuarios(id),
  actualizado_en    timestamptz,
  actualizado_por   uuid references usuarios(id),
  check (not anulado or coalesce(length(trim(anulado_motivo)),0) > 0)
);
create unique index if not exists ot_inspecciones_unico on ot_inspecciones (orden_trabajo_id, sistema_id) where not anulado;

-- Imprevistos durante el trabajo (los aprueba o rechaza el supervisor)
create table if not exists ot_imprevistos (
  id                uuid primary key default gen_random_uuid(),
  orden_trabajo_id  uuid not null references ordenes_trabajo(id),
  trabajo_id        uuid not null references ot_trabajos(id),
  tecnico_id        uuid not null references tecnicos(id),
  motivo            text not null,
  detalle           text,
  minutos           integer not null check (minutos > 0 and minutos <= 1440),
  estado            text not null default 'pendiente' check (estado in ('pendiente','aprobado','rechazado')),
  resuelto_por      uuid references usuarios(id),
  resuelto_en       timestamptz,
  anulado           boolean not null default false,
  anulado_motivo    text,
  anulado_por       uuid references usuarios(id),
  anulado_en        timestamptz,
  creado_en         timestamptz not null default now(),
  creado_por        uuid references usuarios(id),
  actualizado_en    timestamptz,
  actualizado_por   uuid references usuarios(id),
  check (not anulado or coalesce(length(trim(anulado_motivo)),0) > 0)
);

-- ============================================================ 5. Observaciones de técnicos (segmento 8)
alter table comentarios_ot add column if not exists tecnico_id uuid references tecnicos(id);

-- ============================================================ 6. Reglas automáticas
-- Numeración de líneas por OT
create or replace function tg_numero_linea_ot() returns trigger
language plpgsql as $$
begin
  if new.numero_linea is null or new.numero_linea = 0 then
    execute format('select coalesce(max(numero_linea), 0) + 1 from %I where orden_trabajo_id = $1', tg_table_name)
      into new.numero_linea using new.orden_trabajo_id;
  end if;
  return new;
end $$;
drop trigger if exists t3_numero on ot_solicitudes;
create trigger t3_numero before insert on ot_solicitudes for each row execute function tg_numero_linea_ot();
drop trigger if exists t3_numero on ot_hallazgos;
create trigger t3_numero before insert on ot_hallazgos for each row execute function tg_numero_linea_ot();
drop trigger if exists t3_numero on ot_trabajos;
create trigger t3_numero before insert on ot_trabajos for each row execute function tg_numero_linea_ot();

-- Solo se escribe en OT abiertas
create or replace function ot_abierta(p_ot uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from ordenes_trabajo where id = p_ot and estado <> 'entregado' and not anulado)
$$;
create or replace function tg_ot_abierta() returns trigger
language plpgsql as $$
begin
  if not ot_abierta(new.orden_trabajo_id) then
    raise exception 'La OT está cerrada o anulada: ya no se puede modificar.';
  end if;
  return new;
end $$;
do $$
declare t text;
begin
  foreach t in array array['ot_checklist','ot_solicitudes','ot_hallazgos','ot_trabajos','ot_inspecciones','ot_imprevistos','comentarios_ot'] loop
    execute format('drop trigger if exists t4_ot_abierta on %I', t);
    execute format('create trigger t4_ot_abierta before insert or update on %I for each row execute function tg_ot_abierta()', t);
  end loop;
end $$;

-- Trabajo: copia los nombres y horas del catálogo, calcula las horas estándar y marca fechas.
create or replace function tg_ot_trabajo() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_sis sistemas; v_int intervenciones; v_el elementos; v_com complejidades;
begin
  if tg_op = 'INSERT' or new.intervencion_id is distinct from old.intervencion_id or new.elemento_id is distinct from old.elemento_id then
    select * into v_int from intervenciones where id = new.intervencion_id;
    select * into v_sis from sistemas where id = v_int.sistema_id;
    if v_int.id is null then raise exception 'Intervención no encontrada.'; end if;
    if tg_op = 'INSERT' and not v_int.activo then raise exception 'La intervención "%" está desactivada en el catálogo.', v_int.nombre; end if;
    new.sistema_id := v_sis.id; new.taller := v_sis.taller; new.sistema_nombre := v_sis.nombre;
    new.intervencion_nombre := v_int.nombre; new.horas_unitarias := v_int.horas_estandar;
    if new.elemento_id is not null then
      select * into v_el from elementos where id = new.elemento_id;
      if v_el.sistema_id is distinct from v_sis.id then raise exception 'El elemento no pertenece a la cápsula %.', v_sis.nombre; end if;
      new.elemento_nombre := v_el.nombre;
    else
      new.elemento_nombre := null;
    end if;
  else
    select * into v_sis from sistemas where id = new.sistema_id;
  end if;
  if v_sis.aplica_complejidad then
    if new.complejidad_id is null then
      select * into v_com from complejidades where codigo = 'moderado';
      new.complejidad_id := v_com.id;
    end if;
    if tg_op = 'INSERT' or new.complejidad_id is distinct from old.complejidad_id then
      select * into v_com from complejidades where id = new.complejidad_id;
      new.complejidad_nombre := v_com.nombre; new.multiplicador := coalesce(v_com.multiplicador, 1);
    end if;
  else
    new.complejidad_id := null; new.complejidad_nombre := null; new.multiplicador := 1;
  end if;
  new.horas_estandar := round(new.horas_unitarias * new.cantidad * new.multiplicador, 2);
  if new.taller <> 'soldadura' then new.material_base := null; end if;
  if new.estado = 'terminado' and (tg_op = 'INSERT' or old.estado <> 'terminado') then
    new.terminado_en := now(); new.terminado_por := usuario_actual();
  elsif new.estado <> 'terminado' then
    new.terminado_en := null; new.terminado_por := null;
  end if;
  return new;
end $$;
drop trigger if exists t3_trabajo on ot_trabajos;
create trigger t3_trabajo before insert or update on ot_trabajos for each row execute function tg_ot_trabajo();

-- Reparto: horas de cada técnico = horas estándar del trabajo × porcentaje.
create or replace function tg_ot_trabajo_tecnico() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.horas := round((select horas_estandar from ot_trabajos where id = new.trabajo_id) * new.porcentaje / 100, 2);
  return new;
end $$;
drop trigger if exists t3_reparto on ot_trabajo_tecnicos;
create trigger t3_reparto before insert or update on ot_trabajo_tecnicos for each row execute function tg_ot_trabajo_tecnico();

create or replace function tg_ot_trabajo_recalcular() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.horas_estandar is distinct from old.horas_estandar then
    update ot_trabajo_tecnicos set horas = round(new.horas_estandar * porcentaje / 100, 2)
     where trabajo_id = new.id and not anulado;
  end if;
  return null;
end $$;
drop trigger if exists t8_recalcular on ot_trabajos;
create trigger t8_recalcular after update on ot_trabajos for each row execute function tg_ot_trabajo_recalcular();

-- Imprevisto: registra quién y cuándo lo resolvió
create or replace function tg_ot_resolucion() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' and new.estado is distinct from old.estado then
    if new.estado in ('pendiente') then new.resuelto_por := null; new.resuelto_en := null;
    else new.resuelto_por := usuario_actual(); new.resuelto_en := now(); end if;
  end if;
  return new;
end $$;
do $$
declare t text;
begin
  foreach t in array array['ot_imprevistos','ot_solicitudes','ot_hallazgos'] loop
    execute format('drop trigger if exists t5_resolucion on %I', t);
    execute format('create trigger t5_resolucion before update on %I for each row execute function tg_ot_resolucion()', t);
  end loop;
end $$;

-- Observación del técnico: el código del técnico se pone solo y no se edita.
create or replace function tg_observacion_tecnico() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.tecnico_id := tecnico_actual();
    new.usuario_id := usuario_actual();
    new.fecha_hora := now();
  elsif new.texto is distinct from old.texto or new.tecnico_id is distinct from old.tecnico_id then
    raise exception 'Las observaciones no se editan: agregue otra observación.';
  end if;
  return new;
end $$;
drop trigger if exists t3_observacion on comentarios_ot;
create trigger t3_observacion before insert or update on comentarios_ot for each row execute function tg_observacion_tecnico();

-- ¿El técnico que opera está asignado a la OT?
create or replace function asignado_a_ot(p_ot uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from ot_trabajo_tecnicos tt join ot_trabajos t on t.id = tt.trabajo_id
                  where t.orden_trabajo_id = p_ot and not t.anulado and not tt.anulado and tt.tecnico_id = tecnico_actual())
      or exists (select 1 from lineas_trabajo l where l.orden_trabajo_id = p_ot and not l.anulado and l.tecnico_id = tecnico_actual())
$$;

-- ============================================================ 7. Funciones de negocio
-- Abre la OT (segmento 1) con checklist, daños y la solicitud del chofer (segmento 2).
-- Idempotente por id_local.
create or replace function abrir_ot(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_ot ordenes_trabajo; v_veh vehiculos; v_abierta text; v_tipo text := coalesce(p->>'motivo_ingreso','correctivo');
        v_item jsonb; v_dano jsonb; v_sol jsonb; n int := 0;
begin
  if not tiene_permiso('operar_ot') then raise exception 'Su usuario no puede abrir órdenes de trabajo.'; end if;
  select * into v_ot from ordenes_trabajo where id_local = (p->>'id_local')::uuid;
  if found then return jsonb_build_object('ot_id', v_ot.id, 'ot_numero', v_ot.numero); end if;
  if nullif(p->>'vehiculo_id','') is not null then
    select * into v_veh from vehiculos where id = (p->>'vehiculo_id')::uuid;
    if not found then raise exception 'Vehículo no encontrado.'; end if;
    if p->>'lectura' is null then raise exception 'Falta el kilometraje (u horómetro) de ingreso.'; end if;
    if (p->>'lectura')::numeric < v_veh.lectura_actual then
      raise exception 'La lectura (%) es menor a la última registrada para % (%).', p->>'lectura', v_veh.codigo, v_veh.lectura_actual;
    end if;
    select numero into v_abierta from ordenes_trabajo where vehiculo_id = v_veh.id and estado <> 'entregado' and not anulado limit 1;
    if v_abierta is not null then
      raise exception 'El vehículo % ya tiene la orden % abierta. Ciérrela o anúlela antes de abrir otra.', v_veh.codigo, v_abierta;
    end if;
  elsif v_tipo <> 'fabricacion' then
    raise exception 'Elija el vehículo. Solo una OT de fabricación para stock puede ir sin vehículo.';
  end if;
  if v_tipo = 'fabricacion' and coalesce(trim(p->>'fabricacion_descripcion'), '') = '' and v_veh.id is null then
    raise exception 'Describa qué se fabrica (ej. 5 portallantas).';
  end if;

  insert into ordenes_trabajo (numero, id_local, formato, vehiculo_id, conductor_id, lectura, motivo_ingreso, falla_reportada,
         prioridad, inmovilizado, estado, jefe_taller_id, fecha_apertura, combustible, fabricacion_descripcion, fabricacion_cantidad,
         centro_costo_id, cliente_id, observaciones_recepcion)
  values (siguiente_numero('OT'), (p->>'id_local')::uuid, 'segmentos', v_veh.id, nullif(p->>'conductor_id','')::uuid,
          (p->>'lectura')::numeric, v_tipo, p->>'falla_reportada', coalesce(p->>'prioridad','media'),
          coalesce((p->>'inmovilizado')::boolean, false), 'recepcion',
          case when rol_actual() = 'supervisor' then usuario_actual() end,
          coalesce((p->>'fecha_hora')::timestamptz, now()), nullif(p->>'combustible',''),
          nullif(p->>'fabricacion_descripcion',''), nullif(p->>'fabricacion_cantidad','')::int,
          v_veh.centro_costo_id, case when v_veh.propiedad = 'rentado' then v_veh.cliente_id end, nullif(p->>'observaciones','') )
  returning * into v_ot;

  for v_item in select * from jsonb_array_elements(coalesce(p->'checklist','[]'::jsonb)) loop
    if v_item->>'resultado' is not null then
      insert into ot_checklist (orden_trabajo_id, item_checklist_id, resultado, observacion)
      values (v_ot.id, (v_item->>'item_checklist_id')::uuid, v_item->>'resultado', v_item->>'observacion');
    end if;
  end loop;
  for v_dano in select * from jsonb_array_elements(coalesce(p->'danos','[]'::jsonb)) loop
    insert into danos_vehiculo (vehiculo_id, orden_trabajo_id, numero_marca, vista, posicion_x, posicion_y, tipo_dano, descripcion)
    values (v_veh.id, v_ot.id, (v_dano->>'numero_marca')::int, v_dano->>'vista', (v_dano->>'posicion_x')::numeric,
            (v_dano->>'posicion_y')::numeric, v_dano->>'tipo_dano', v_dano->>'descripcion');
  end loop;
  for v_sol in select * from jsonb_array_elements(coalesce(p->'solicitudes','[]'::jsonb)) loop
    if coalesce(trim(v_sol->>'descripcion'),'') <> '' then
      n := n + 1;
      insert into ot_solicitudes (orden_trabajo_id, numero_linea, descripcion, taller_sugerido)
      values (v_ot.id, n, trim(v_sol->>'descripcion'), coalesce(v_sol->>'taller_sugerido','mecanica'));
    end if;
  end loop;
  insert into historial_estados_ot (orden_trabajo_id, estado_anterior, estado_nuevo, fecha_hora, usuario_id, comentario)
  values (v_ot.id, null, 'recepcion', v_ot.fecha_apertura, usuario_actual(), 'Ingreso al taller');
  if v_veh.id is not null then
    update vehiculos set lectura_actual = v_ot.lectura, lectura_actual_fecha = v_ot.fecha_apertura,
           conductor_asignado_id = coalesce(conductor_asignado_id, v_ot.conductor_id)
     where id = v_veh.id and lectura_actual <= v_ot.lectura;
  end if;
  return jsonb_build_object('ot_id', v_ot.id, 'ot_numero', v_ot.numero);
end $$;

-- Agrega o edita un trabajo con sus técnicos y el reparto de horas (todo junto).
-- p: { id?, orden_trabajo_id, intervencion_id, elemento_id, cantidad, complejidad_id, origen,
--      solicitud_id?, hallazgo_id?, hallazgo_nuevo?: {descripcion}, causa, material_base, observacion,
--      tecnicos: [{tecnico_id, porcentaje?}] }   (sin porcentaje = partes iguales)
create or replace function guardar_trabajo(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id','')::uuid; v_t ot_trabajos; v_ot uuid; v_hall uuid := nullif(p->>'hallazgo_id','')::uuid;
        v_tec jsonb; v_n int; v_suma numeric := 0; v_pct numeric; v_ids uuid[] := '{}'; v_taller text; v_esp text;
begin
  if not tiene_permiso('operar_ot') then raise exception 'Solo el supervisor registra trabajos.'; end if;
  if v_id is not null then
    select * into v_t from ot_trabajos where id = v_id;
    if not found or v_t.anulado then raise exception 'Trabajo no encontrado.'; end if;
    v_ot := v_t.orden_trabajo_id;
  else
    v_ot := (p->>'orden_trabajo_id')::uuid;
  end if;
  if not ot_abierta(v_ot) then raise exception 'La OT está cerrada o anulada: ya no se puede modificar.'; end if;
  select s.taller into v_taller from intervenciones i join sistemas s on s.id = i.sistema_id
   where i.id = coalesce(nullif(p->>'intervencion_id','')::uuid, v_t.intervencion_id);

  -- Origen
  if p ? 'origen' and p->>'origen' = 'hallazgo' and v_hall is null and coalesce(trim(p#>>'{hallazgo_nuevo,descripcion}'),'') <> '' then
    insert into ot_hallazgos (orden_trabajo_id, descripcion, taller, sistema_id, estado, resuelto_por, resuelto_en)
    values (v_ot, trim(p#>>'{hallazgo_nuevo,descripcion}'), v_taller,
            (select sistema_id from intervenciones where id = (p->>'intervencion_id')::uuid), 'aprobado', usuario_actual(), now())
    returning id into v_hall;
  elsif v_hall is not null then
    update ot_hallazgos set estado = 'aprobado' where id = v_hall and orden_trabajo_id = v_ot and estado = 'pendiente';
    if not exists (select 1 from ot_hallazgos where id = v_hall and orden_trabajo_id = v_ot and estado = 'aprobado') then
      raise exception 'El hallazgo elegido fue descartado o no es de esta OT.';
    end if;
  end if;
  if nullif(p->>'solicitud_id','') is not null and not exists (
       select 1 from ot_solicitudes where id = (p->>'solicitud_id')::uuid and orden_trabajo_id = v_ot and not anulado and estado in ('pendiente','atendida')) then
    raise exception 'La línea de la solicitud del chofer ya se cerró como no realizada o descartada.';
  end if;

  if v_id is null then
    insert into ot_trabajos (orden_trabajo_id, numero_linea, taller, sistema_id, elemento_id, intervencion_id, sistema_nombre, intervencion_nombre,
           horas_unitarias, cantidad, complejidad_id, origen, solicitud_id, hallazgo_id, causa, material_base, observacion)
    values (v_ot, 0, 'mecanica', (select sistema_id from intervenciones where id = (p->>'intervencion_id')::uuid),
            nullif(p->>'elemento_id','')::uuid, (p->>'intervencion_id')::uuid, '', '', 0,
            coalesce((p->>'cantidad')::numeric, 1), nullif(p->>'complejidad_id','')::uuid, p->>'origen',
            case when p->>'origen' = 'chofer' then nullif(p->>'solicitud_id','')::uuid end,
            case when p->>'origen' = 'hallazgo' then v_hall end,
            nullif(p->>'causa',''), nullif(p->>'material_base',''), nullif(p->>'observacion',''))
    returning * into v_t;
  else
    update ot_trabajos set
      cantidad = coalesce((p->>'cantidad')::numeric, cantidad),
      complejidad_id = case when p ? 'complejidad_id' then nullif(p->>'complejidad_id','')::uuid else complejidad_id end,
      elemento_id = case when p ? 'elemento_id' then nullif(p->>'elemento_id','')::uuid else elemento_id end,
      origen = coalesce(p->>'origen', origen),
      solicitud_id = case when coalesce(p->>'origen', origen) = 'chofer' then coalesce(nullif(p->>'solicitud_id','')::uuid, solicitud_id) end,
      hallazgo_id = case when coalesce(p->>'origen', origen) = 'hallazgo' then coalesce(v_hall, hallazgo_id) end,
      causa = case when p ? 'causa' then nullif(p->>'causa','') else causa end,
      material_base = case when p ? 'material_base' then nullif(p->>'material_base','') else material_base end,
      observacion = case when p ? 'observacion' then nullif(p->>'observacion','') else observacion end
    where id = v_id returning * into v_t;
  end if;
  if v_t.solicitud_id is not null then
    update ot_solicitudes set estado = 'atendida' where id = v_t.solicitud_id and estado = 'pendiente';
  end if;

  -- Técnicos y reparto
  if p ? 'tecnicos' then
    v_n := jsonb_array_length(p->'tecnicos');
    if v_n = 0 then raise exception 'Asigne al menos un técnico.'; end if;
    for v_tec in select * from jsonb_array_elements(p->'tecnicos') loop
      v_pct := coalesce(nullif(v_tec->>'porcentaje','')::numeric, round(100.0 / v_n, 2));
      v_suma := v_suma + v_pct;
      select especialidad into v_esp from tecnicos where id = (v_tec->>'tecnico_id')::uuid and activo;
      if v_esp is null then raise exception 'Uno de los técnicos no existe o está inactivo.'; end if;
      v_ids := v_ids || (v_tec->>'tecnico_id')::uuid;
    end loop;
    if (p->'tecnicos'->0 ? 'porcentaje') and abs(v_suma - 100) > 0.05 then
      raise exception 'El reparto de horas debe sumar 100 %% (suma %).', v_suma;
    end if;
    update ot_trabajo_tecnicos set anulado = true, anulado_motivo = 'Cambio de técnicos o de reparto'
     where trabajo_id = v_t.id and not anulado;
    for v_tec in select * from jsonb_array_elements(p->'tecnicos') loop
      insert into ot_trabajo_tecnicos (trabajo_id, tecnico_id, porcentaje)
      values (v_t.id, (v_tec->>'tecnico_id')::uuid, coalesce(nullif(v_tec->>'porcentaje','')::numeric, round(100.0 / v_n, 2)));
    end loop;
    -- el redondeo de partes iguales (33,33 × 3) se ajusta en el primero
    if not (p->'tecnicos'->0 ? 'porcentaje') then
      update ot_trabajo_tecnicos set porcentaje = porcentaje + (100 - (select sum(porcentaje) from ot_trabajo_tecnicos where trabajo_id = v_t.id and not anulado))
       where id = (select id from ot_trabajo_tecnicos where trabajo_id = v_t.id and not anulado order by creado_en, id limit 1);
    end if;
  elsif v_id is null then
    raise exception 'Asigne al menos un técnico.';
  end if;
  return jsonb_build_object('trabajo_id', v_t.id, 'numero_linea', v_t.numero_linea, 'horas_estandar', v_t.horas_estandar);
end $$;

-- Cambio de estado de la OT. Al cerrar ("entregado"): sin trabajos pendientes o en proceso
-- y sin líneas del segmento 2 sin resolver. (Control de calidad y acta de entrega: Fase 4.)
create or replace function cambiar_estado_ot(p_ot uuid, p_estado text, p_comentario text default null)
returns void language plpgsql set search_path = public as $$
declare v_ot ordenes_trabajo;
begin
  if not tiene_permiso('operar_ot') then raise exception 'Solo el supervisor puede cambiar el estado de la OT.'; end if;
  select * into v_ot from ordenes_trabajo where id = p_ot for update;
  if not found then raise exception 'OT no encontrada.'; end if;
  if v_ot.anulado then raise exception 'La OT está anulada.'; end if;
  if v_ot.estado = 'entregado' then raise exception 'La OT ya está cerrada.'; end if;
  if p_estado = v_ot.estado then return; end if;
  if v_ot.formato = 'segmentos' then
    if p_estado in ('listo_entrega','entregado') and exists (
         select 1 from ot_trabajos where orden_trabajo_id = p_ot and not anulado and estado in ('pendiente','en_proceso')) then
      raise exception 'Hay trabajos pendientes o en proceso. Márquelos como terminados o no realizados antes de pasar a "%".',
        case when p_estado = 'entregado' then 'Entregado / cerrado' else 'Listo para entrega' end;
    end if;
    if p_estado in ('listo_entrega','entregado') and exists (
         select 1 from ot_solicitudes where orden_trabajo_id = p_ot and not anulado and estado = 'pendiente') then
      raise exception 'Hay líneas de la solicitud del chofer sin resolver (atendida, no realizada o descartada).';
    end if;
    if p_estado = 'entregado' and not exists (select 1 from ot_trabajos where orden_trabajo_id = p_ot and not anulado)
       and not exists (select 1 from ot_inspecciones where orden_trabajo_id = p_ot and not anulado) then
      raise exception 'La OT no tiene trabajos ni inspecciones. Registre al menos uno o anule la OT.';
    end if;
  else
    if p_estado in ('listo_entrega','entregado') and exists (
         select 1 from lineas_trabajo where orden_trabajo_id = p_ot and not anulado and estado <> 'terminada') then
      raise exception 'Hay trabajos sin terminar. Termínelos o anúlelos antes de pasar a "%".',
        case when p_estado = 'entregado' then 'Entregado / cerrado' else 'Listo para entrega' end;
    end if;
  end if;
  if p_estado = 'entregado' then
    update ordenes_trabajo set
       estado = 'entregado', fecha_cierre = now(),
       horas_parado = round((extract(epoch from (now() - fecha_apertura)) / 3600)::numeric, 1),
       total_horas_internas = case when formato = 'segmentos'
         then (select coalesce(sum(horas_estandar),0) from ot_trabajos where orden_trabajo_id = p_ot and not anulado and estado = 'terminado')
         else (select coalesce(sum(h.horas),0) from registros_horas h join lineas_trabajo l on l.id = h.linea_trabajo_id
                where l.orden_trabajo_id = p_ot and not h.anulado and not l.anulado) end
     where id = p_ot;
  else
    update ordenes_trabajo set estado = p_estado where id = p_ot;
  end if;
  insert into historial_estados_ot (orden_trabajo_id, estado_anterior, estado_nuevo, usuario_id, comentario)
  values (p_ot, v_ot.estado, p_estado, usuario_actual(), p_comentario);
end $$;

-- ============================================================ 8. Vistas
create or replace view v_ot_lista with (security_invoker = true) as
select o.id, o.numero, o.formato, o.estado, o.motivo_ingreso, o.prioridad, o.inmovilizado, o.fecha_apertura, o.fecha_cierre,
       o.lectura, o.anulado, o.fabricacion_descripcion, o.fabricacion_cantidad, o.falla_reportada,
       v.id as vehiculo_id, v.codigo, v.placa, t.nombre as tipo_vehiculo, t.unidad_medida, v.propiedad,
       c.nombre as cliente, cc.codigo as centro_costo,
       round((extract(epoch from (coalesce(o.fecha_cierre, now()) - o.fecha_apertura)) / 3600)::numeric, 1) as horas_parado_actual,
       (select count(*) from ot_trabajos x where x.orden_trabajo_id = o.id and not x.anulado and x.taller = 'mecanica') as trabajos_mecanica,
       (select count(*) from ot_trabajos x where x.orden_trabajo_id = o.id and not x.anulado and x.taller = 'soldadura') as trabajos_soldadura,
       (select count(*) from ot_trabajos x where x.orden_trabajo_id = o.id and not x.anulado and x.estado = 'terminado') as trabajos_terminados,
       (select count(*) from ot_trabajos x where x.orden_trabajo_id = o.id and not x.anulado and x.estado in ('pendiente','en_proceso')) as trabajos_abiertos,
       (select coalesce(sum(x.horas_estandar),0) from ot_trabajos x where x.orden_trabajo_id = o.id and not x.anulado and x.estado <> 'no_realizado') as horas_estandar,
       (select count(*) from ot_solicitudes s where s.orden_trabajo_id = o.id and not s.anulado and s.estado = 'pendiente') as solicitudes_pendientes,
       (select count(*) from ot_hallazgos h where h.orden_trabajo_id = o.id and not h.anulado and h.estado = 'pendiente') as hallazgos_pendientes,
       (select count(*) from ot_imprevistos i where i.orden_trabajo_id = o.id and not i.anulado and i.estado = 'pendiente') as imprevistos_pendientes
  from ordenes_trabajo o
  left join vehiculos v on v.id = o.vehiculo_id
  left join tipos_vehiculo t on t.id = v.tipo_vehiculo_id
  left join clientes c on c.id = o.cliente_id
  left join centros_costo cc on cc.id = o.centro_costo_id;

create or replace view v_ot_trabajos with (security_invoker = true) as
select t.*,
       coalesce((select jsonb_agg(jsonb_build_object('tecnico_id', tt.tecnico_id, 'codigo', te.codigo, 'nombre', te.nombres,
                                                     'porcentaje', tt.porcentaje, 'horas', tt.horas) order by te.codigo)
                   from ot_trabajo_tecnicos tt join tecnicos te on te.id = tt.tecnico_id
                  where tt.trabajo_id = t.id and not tt.anulado), '[]'::jsonb) as tecnicos,
       s.numero_linea as solicitud_linea, s.descripcion as solicitud_descripcion,
       h.numero_linea as hallazgo_linea, h.descripcion as hallazgo_descripcion
  from ot_trabajos t
  left join ot_solicitudes s on s.id = t.solicitud_id
  left join ot_hallazgos h on h.id = t.hallazgo_id;

-- Trabajos asignados al técnico que opera (portal del técnico).
create or replace view v_mis_trabajos with (security_invoker = true) as
select t.id, t.orden_trabajo_id, o.numero, o.estado as estado_ot, v.codigo, v.placa, o.motivo_ingreso, o.prioridad,
       t.taller, t.sistema_nombre, t.elemento_nombre, t.intervencion_nombre, t.cantidad, t.estado, t.observacion,
       tt.porcentaje, tt.horas, t.creado_en
  from ot_trabajo_tecnicos tt
  join ot_trabajos t on t.id = tt.trabajo_id
  join ordenes_trabajo o on o.id = t.orden_trabajo_id
  left join vehiculos v on v.id = o.vehiculo_id
 where not tt.anulado and not t.anulado and not o.anulado and tt.tecnico_id = tecnico_actual();

-- Observaciones de técnicos con su código
create or replace view v_observaciones_ot with (security_invoker = true) as
select c.id, c.orden_trabajo_id, c.fecha_hora, c.texto, c.anulado, te.codigo as tecnico_codigo, te.nombres as tecnico_nombre,
       u.nombre_completo as usuario
  from comentarios_ot c
  left join tecnicos te on te.id = c.tecnico_id
  left join usuarios u on u.id = c.usuario_id;

-- ============================================================ 9. Reglas comunes y permisos
do $$ begin perform aplicar_reglas_comunes(); end $$;

do $$
declare t text;
begin
  foreach t in array array['ot_checklist','ot_solicitudes','ot_hallazgos','ot_trabajos','ot_trabajo_tecnicos','ot_inspecciones','ot_imprevistos'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists leer on %I', t);
    execute format('drop policy if exists crear on %I', t);
    execute format('drop policy if exists modificar on %I', t);
    execute format($p$create policy leer on %I for select to authenticated using (rol_actual() is not null)$p$, t);
    execute format($p$create policy crear on %I for insert to authenticated with check (tiene_permiso('operar_ot'))$p$, t);
    execute format($p$create policy modificar on %I for update to authenticated using (tiene_permiso('operar_ot'))$p$, t);
  end loop;
end $$;

-- Segmento 8: solo los técnicos asignados a la OT escriben; nadie edita (se anula con motivo, solo el supervisor).
drop policy if exists crear on comentarios_ot;
create policy crear on comentarios_ot for insert to authenticated with check (tecnico_actual() is not null and asignado_a_ot(orden_trabajo_id));
drop policy if exists modificar on comentarios_ot;
create policy modificar on comentarios_ot for update to authenticated using (tiene_permiso('operar_ot'));

grant select on v_ot_lista, v_ot_trabajos, v_mis_trabajos, v_observaciones_ot to authenticated;
grant execute on function guardar_trabajo(jsonb), ot_abierta(uuid), asignado_a_ot(uuid) to authenticated;
revoke execute on function guardar_trabajo(jsonb), abrir_ot(jsonb), cambiar_estado_ot(uuid,text,text) from public, anon;
grant execute on function abrir_ot(jsonb), cambiar_estado_ot(uuid,text,text) to authenticated;
revoke all on all tables in schema public from anon;

-- ============================================================ 10. Diccionario de datos
comment on column ordenes_trabajo.formato is 'anterior (OT de la versión anterior, con lineas_trabajo) | segmentos (OT por segmentos de la especificación unificada).';
comment on column ordenes_trabajo.motivo_ingreso is 'Tipo de OT: preventivo | correctivo | siniestro (golpe/siniestro) | llantas | fabricacion | renovado | inspeccion.';
comment on column ordenes_trabajo.vehiculo_id is 'Vehículo. Puede ir vacío solo en fabricación para stock.';
comment on column ordenes_trabajo.lectura is 'Km u horómetro al ingresar (vacío en fabricación para stock).';
comment on column ordenes_trabajo.combustible is 'Combustible al ingresar: E / 1/4 / 1/2 / 3/4 / F.';
comment on column ordenes_trabajo.fabricacion_descripcion is 'Fabricación para stock: qué se fabrica (ej. portallantas).';
comment on column ordenes_trabajo.fabricacion_cantidad is 'Fabricación para stock: cuántas unidades.';
comment on column ordenes_trabajo.centro_costo_id is 'Centro de costo del vehículo al abrir la OT (las rentadas van a MNTOPL3RAS).';
comment on column ordenes_trabajo.cliente_id is 'Cliente, si la unidad es rentada (para el reporte por cliente).';
comment on column ordenes_trabajo.observaciones_recepcion is 'Observaciones generales de la recepción (segmento 1).';
comment on column ordenes_trabajo.obs_supervisor_mecanica is 'Observación del supervisor en el segmento 4 (trabajos de mecánica).';
comment on column ordenes_trabajo.obs_supervisor_soldadura is 'Observación del supervisor en el segmento 5 (trabajos de soldadura).';

comment on table ot_checklist is 'Checklist de recepción de la OT (segmento 1).';
comment on column ot_checklist.orden_trabajo_id is 'OT.';
comment on column ot_checklist.item_checklist_id is 'Ítem del checklist de recepción (Maestros).';
comment on column ot_checklist.resultado is 'ok | falta | danado.';
comment on column ot_checklist.observacion is 'Detalle si falta o está dañado.';
comment on column danos_vehiculo.orden_trabajo_id is 'OT en la que se marcó el daño (recepción).';

comment on table ot_solicitudes is 'Segmento 2: lo que reporta el chofer. Cada línea termina atendida, no realizada o descartada.';
comment on column ot_solicitudes.orden_trabajo_id is 'OT.';
comment on column ot_solicitudes.numero_linea is 'Número de línea dentro de la OT.';
comment on column ot_solicitudes.descripcion is 'Lo que reporta el chofer.';
comment on column ot_solicitudes.taller_sugerido is 'mecanica | soldadura.';
comment on column ot_solicitudes.estado is 'pendiente | atendida (se convirtió en trabajos) | no_realizada | descartada.';
comment on column ot_solicitudes.motivo is 'Motivo obligatorio si no se realizó o se descartó (de las listas de Maestros).';
comment on column ot_solicitudes.comentario is 'Comentario libre.';
comment on column ot_solicitudes.resuelto_por is 'Quién la cerró.';
comment on column ot_solicitudes.resuelto_en is 'Cuándo se cerró.';

comment on table ot_hallazgos is 'Segmento 3: trabajos que se encontraron en la revisión y que el chofer no reportó. Los registra el supervisor.';
comment on column ot_hallazgos.orden_trabajo_id is 'OT.';
comment on column ot_hallazgos.numero_linea is 'Número de línea dentro de la OT.';
comment on column ot_hallazgos.descripcion is 'Qué se encontró.';
comment on column ot_hallazgos.taller is 'mecanica | soldadura.';
comment on column ot_hallazgos.sistema_id is 'Cápsula relacionada (opcional).';
comment on column ot_hallazgos.estado is 'pendiente | aprobado (pasa a trabajo con origen hallazgo) | descartado.';
comment on column ot_hallazgos.motivo is 'Motivo obligatorio si se descarta.';
comment on column ot_hallazgos.comentario is 'Comentario libre.';
comment on column ot_hallazgos.resuelto_por is 'Quién lo aprobó o descartó.';
comment on column ot_hallazgos.resuelto_en is 'Cuándo.';

comment on table ot_trabajos is 'Segmentos 4 (mecánica) y 5 (soldadura): cada trabajo registrado desde las cápsulas del ambiente.';
comment on column ot_trabajos.orden_trabajo_id is 'OT.';
comment on column ot_trabajos.numero_linea is 'Número de línea dentro de la OT.';
comment on column ot_trabajos.taller is 'mecanica (segmento 4) | soldadura (segmento 5). Sale de la cápsula.';
comment on column ot_trabajos.sistema_id is 'Cápsula (sistema o componente).';
comment on column ot_trabajos.elemento_id is 'Elemento atendido.';
comment on column ot_trabajos.intervencion_id is 'Intervención del catálogo.';
comment on column ot_trabajos.sistema_nombre is 'Nombre de la cápsula al momento de registrar (no cambia si el catálogo cambia).';
comment on column ot_trabajos.elemento_nombre is 'Nombre del elemento al momento de registrar.';
comment on column ot_trabajos.intervencion_nombre is 'Nombre de la intervención al momento de registrar.';
comment on column ot_trabajos.horas_unitarias is 'Horas estándar del catálogo al momento de registrar.';
comment on column ot_trabajos.cantidad is 'Cantidad de unidades intervenidas.';
comment on column ot_trabajos.complejidad_id is 'Complejidad (si la cápsula aplica complejidad).';
comment on column ot_trabajos.complejidad_nombre is 'Nombre de la complejidad al registrar.';
comment on column ot_trabajos.multiplicador is 'Multiplicador de complejidad usado (1 si no aplica).';
comment on column ot_trabajos.horas_estandar is 'Horas-hombre totales = horas unitarias × cantidad × multiplicador.';
comment on column ot_trabajos.estado is 'pendiente | en_proceso | terminado | no_realizado. Lo cambia el supervisor.';
comment on column ot_trabajos.origen is 'chofer (solicitud) | hallazgo | preventivo.';
comment on column ot_trabajos.solicitud_id is 'Línea de la solicitud del chofer que atiende.';
comment on column ot_trabajos.hallazgo_id is 'Hallazgo del que sale.';
comment on column ot_trabajos.causa is 'Causa del daño (lista de Maestros).';
comment on column ot_trabajos.material_base is 'Soldadura: inoxidable | hierro_negro.';
comment on column ot_trabajos.observacion is 'Observación del registro del trabajo.';
comment on column ot_trabajos.motivo_no_realizado is 'Motivo obligatorio si el trabajo no se realizó (queda pendiente de la unidad).';
comment on column ot_trabajos.detalle_no_realizado is 'Detalle libre del no realizado.';
comment on column ot_trabajos.terminado_en is 'Cuándo se marcó terminado.';
comment on column ot_trabajos.terminado_por is 'Quién lo marcó terminado (supervisor).';

comment on table ot_trabajo_tecnicos is 'Técnicos de cada trabajo y reparto de las horas-hombre (por defecto en partes iguales).';
comment on column ot_trabajo_tecnicos.trabajo_id is 'Trabajo.';
comment on column ot_trabajo_tecnicos.tecnico_id is 'Técnico.';
comment on column ot_trabajo_tecnicos.porcentaje is 'Parte de las horas que le corresponde (los del trabajo suman 100).';
comment on column ot_trabajo_tecnicos.horas is 'Horas estándar que se le acreditan = horas del trabajo × porcentaje.';

comment on table ot_inspecciones is '“Inspeccionado OK” de cada cápsula en la OT: se revisó sin novedades.';
comment on column ot_inspecciones.orden_trabajo_id is 'OT.';
comment on column ot_inspecciones.sistema_id is 'Cápsula inspeccionada.';

comment on table ot_imprevistos is 'Imprevistos durante el trabajo. Los aprobados no le restan producción al técnico.';
comment on column ot_imprevistos.orden_trabajo_id is 'OT.';
comment on column ot_imprevistos.trabajo_id is 'Trabajo afectado.';
comment on column ot_imprevistos.tecnico_id is 'Técnico afectado.';
comment on column ot_imprevistos.motivo is 'Motivo (lista de Maestros).';
comment on column ot_imprevistos.detalle is 'Texto libre.';
comment on column ot_imprevistos.minutos is 'Minutos de afectación.';
comment on column ot_imprevistos.estado is 'pendiente | aprobado | rechazado (lo decide el supervisor).';
comment on column ot_imprevistos.resuelto_por is 'Quién lo aprobó o rechazó.';
comment on column ot_imprevistos.resuelto_en is 'Cuándo.';

comment on table comentarios_ot is 'Segmento 8: observaciones de los técnicos asignados a la OT. No se editan ni se borran.';
comment on column comentarios_ot.tecnico_id is 'Técnico que escribió (se pone solo con su código).';

do $$
declare c record;
begin
  for c in select cl.relname as table_name, at.attname as column_name
             from pg_class cl join pg_namespace n on n.oid = cl.relnamespace
             join pg_attribute at on at.attrelid = cl.oid and at.attnum > 0 and not at.attisdropped
            where n.nspname = 'public' and cl.relkind = 'r'
              and at.attname in ('id','creado_en','creado_por','actualizado_en','actualizado_por','anulado','anulado_motivo','anulado_por','anulado_en')
              and col_description(cl.oid, at.attnum) is null
  loop
    execute format('comment on column %I.%I is %L', c.table_name, c.column_name, case c.column_name
      when 'id' then 'Identificador único universal (UUID).'
      when 'creado_en' then 'Fecha y hora de creación.'
      when 'creado_por' then 'Usuario que creó el registro.'
      when 'actualizado_en' then 'Fecha y hora de la última modificación.'
      when 'actualizado_por' then 'Usuario que hizo la última modificación.'
      when 'anulado' then 'Sí = registro anulado (no se borra).'
      when 'anulado_motivo' then 'Motivo de la anulación (obligatorio al anular).'
      when 'anulado_por' then 'Usuario que anuló.'
      when 'anulado_en' then 'Fecha y hora de la anulación.' end);
  end loop;
end $$;

notify pgrst, 'reload schema';

-- >>>>>>>>>>>>>>>>>>>> 010_tempario_mecanica.sql
set client_min_messages = warning;
-- =====================================================================
-- 010 · Tempario de mecánica y eléctricos definido con los técnicos
--       (referencias/tempario_mecanica_electricos.xlsx).
-- * Las intervenciones pueden tener código, grupo (sub-categoría dentro
--   de la cápsula) y una nota (ej. duración total estimada).
-- * Las horas estándar pasan a 3 decimales (5 min = 0,083 h).
-- * Carga el tempario en las cápsulas de mecánica. Solo agrega lo que no
--   existe: se puede ejecutar más de una vez y no pisa cambios hechos en Maestros.
-- Conversión usada: tiempos en horas tal cual; "1 persona N días" = N × 8 horas-hombre.
-- =====================================================================

-- Las vistas dependen de las columnas que cambian de tipo: se recrean.
drop view if exists v_catalogo_trabajos;
drop view if exists v_mis_trabajos;
drop view if exists v_ot_trabajos;

alter table intervenciones alter column horas_estandar type numeric(7,3);
alter table ot_trabajos alter column horas_unitarias type numeric(7,3);
alter table intervenciones add column if not exists codigo text;
alter table intervenciones add column if not exists grupo text;
alter table intervenciones add column if not exists nota text;

comment on column intervenciones.horas_estandar is 'Horas-hombre totales del trabajo (3 decimales: 5 min = 0,083 h). Si exige dos personas, ya viene multiplicado.';
comment on column intervenciones.codigo is 'Código del trabajo en el tempario (opcional).';
comment on column intervenciones.grupo is 'Sub-categoría dentro de la cápsula (ej. Checklist, Eléctricos puntuales, Electrónicos). Ordena y agrupa la lista.';
comment on column intervenciones.nota is 'Nota visible al elegir el trabajo (ej. duración total estimada con esperas).';
comment on column ot_trabajos.horas_unitarias is 'Horas estándar del catálogo al momento de registrar (3 decimales).';

create view v_catalogo_trabajos with (security_invoker = true) as
select s.taller, s.id as sistema_id, s.nombre as sistema, s.orden as sistema_orden, s.activo as sistema_activo,
       s.aplica_complejidad,
       (select count(*) from elementos e where e.sistema_id = s.id and e.activo) as elementos_activos,
       i.id as intervencion_id, i.nombre as intervencion, i.horas_estandar,
       i.orden as intervencion_orden, i.activo as intervencion_activo,
       p.codigo as sistema_preventivo, p.nombre as sistema_preventivo_nombre,
       i.grupo, i.codigo, i.nota
  from sistemas s
  left join intervenciones i on i.sistema_id = s.id
  left join sistemas_preventivos p on p.id = i.sistema_preventivo_id;

create view v_ot_trabajos with (security_invoker = true) as
select t.*,
       coalesce((select jsonb_agg(jsonb_build_object('tecnico_id', tt.tecnico_id, 'codigo', te.codigo, 'nombre', te.nombres,
                                                     'porcentaje', tt.porcentaje, 'horas', tt.horas) order by te.codigo)
                   from ot_trabajo_tecnicos tt join tecnicos te on te.id = tt.tecnico_id
                  where tt.trabajo_id = t.id and not tt.anulado), '[]'::jsonb) as tecnicos,
       s.numero_linea as solicitud_linea, s.descripcion as solicitud_descripcion,
       h.numero_linea as hallazgo_linea, h.descripcion as hallazgo_descripcion
  from ot_trabajos t
  left join ot_solicitudes s on s.id = t.solicitud_id
  left join ot_hallazgos h on h.id = t.hallazgo_id;

create view v_mis_trabajos with (security_invoker = true) as
select t.id, t.orden_trabajo_id, o.numero, o.estado as estado_ot, v.codigo, v.placa, o.motivo_ingreso, o.prioridad,
       t.taller, t.sistema_nombre, t.elemento_nombre, t.intervencion_nombre, t.cantidad, t.estado, t.observacion,
       tt.porcentaje, tt.horas, t.creado_en
  from ot_trabajo_tecnicos tt
  join ot_trabajos t on t.id = tt.trabajo_id
  join ordenes_trabajo o on o.id = t.orden_trabajo_id
  left join vehiculos v on v.id = o.vehiculo_id
 where not tt.anulado and not t.anulado and not o.anulado and tt.tecnico_id = tecnico_actual();

grant select on v_catalogo_trabajos, v_ot_trabajos, v_mis_trabajos to authenticated;
revoke all on v_catalogo_trabajos, v_ot_trabajos, v_mis_trabajos from anon;

-- Tempario: cápsula, intervención, horas, grupo, código, nota, sistema preventivo, orden
insert into intervenciones (sistema_id, nombre, horas_estandar, grupo, codigo, nota, sistema_preventivo_id, orden)
select s.id, x.nombre, x.horas, x.grupo, x.codigo, x.nota, (select id from sistemas_preventivos where codigo = x.prev), x.orden
from (values
 ('Sistema eléctrico','SACAR BATERIA',0.5,'Checklist',null,null,null,1),
 ('Sistema eléctrico','REVISION DE LUCES DE UNIDAD (POST|DEL|LAT|INT)',0.0833,'Checklist',null,null,null,2),
 ('Sistema eléctrico','REVISION DE PLUMAS',0.0833,'Checklist',null,null,null,3),
 ('Sistema eléctrico','ESCANEO DE UNIDAD',0.25,'Checklist',null,null,null,4),
 ('Sistema eléctrico','REPARACION DE MOTOR DE ARRANQUE',1.0,'Eléctricos puntuales',null,null,null,5),
 ('Sistema eléctrico','CAMBIO FARO RH|LH',0.5,'Eléctricos puntuales',null,null,null,6),
 ('Sistema eléctrico','CAMBIO DE LUCES DE RUTA',0.1667,'Eléctricos puntuales',null,null,null,7),
 ('Sistema eléctrico','CAMBIO DE HALOGENO DE RETRO',0.3333,'Eléctricos puntuales',null,null,null,8),
 ('Sistema eléctrico','CAMBIO DE PITO DE RETRO',0.25,'Eléctricos puntuales',null,null,null,9),
 ('Sistema eléctrico','CAMBIO DE ALTERNADOR',0.75,'Eléctricos puntuales',null,null,null,10),
 ('Sistema eléctrico','TRABAJO ADICIONAL DE TECNICO',0.5,'Eléctricos puntuales',null,null,null,11),
 ('Sistema eléctrico','REPARACION DE MOTOR ELEVAVIDRIO',1.0,'Eléctricos puntuales',null,'Duración total estimada: 6 horas',null,12),
 ('Sistema eléctrico','REPARACION DE MECANISMO ELEVAVIDRIO',1.0,'Eléctricos puntuales',null,'Duración total estimada: 6 horas',null,13),
 ('Sistema eléctrico','REPARACION DE MECANISMO LIMPIAVIDRIOS',1.0,'Eléctricos puntuales',null,'Duración total estimada: 4 horas',null,14),
 ('Sistema eléctrico','REPARACION DE FRENO DE ESCAPE',1.0,'Eléctricos puntuales',null,'Duración total estimada: 2.5 horas',null,15),
 ('Sistema eléctrico','REVISION DE ENCENDIDO DE UNIDAD',1.0,'Electrónicos',null,'Duración total estimada: 1 hora',null,16),
 ('Sistema eléctrico','REVISION DE FUSILERA',1.0,'Electrónicos',null,'Duración total estimada: 1 hora',null,17),
 ('Sistema eléctrico','REVISION DE LINEA',0.75,'Electrónicos',null,'Duración total estimada: 4 dias peor escenario',null,18),
 ('Sistema eléctrico','DESMONTAJE DE TABLERO DE CABINA',4.0,'Electrónicos',null,null,null,19),
 ('Sistema eléctrico','REPARACION DE ECU',1.0,'Electrónicos',null,'Duración total estimada: 2 a 3 dias',null,20),
 ('Sistema eléctrico','DIAGNOSTICO DE ECU',1.0,'Electrónicos',null,'Duración total estimada: 2 horas',null,21),
 ('Motor','REVISION DE MOTOR POR NO ENCENDIDO',2.0,null,'01141',null,null,1),
 ('Motor','REVISION DE MOTOR POR PERDIDA DE POTENCIA',2.0,null,'00160',null,null,2),
 ('Motor','REVISION DE TESTIGO DE TABLERO ENCENDIDO',1.0,null,'00059',null,null,3),
 ('Motor','DIAGNOSTICO DE DAÑO DE MOTOR',2.0,null,'00635',null,null,4),
 ('Motor','DESARME DE MOTOR COMPLETO',16,null,null,'Referencia de los técnicos: entre 1 persona 2 día entre 2 1 días',null,5),
 ('Motor','DESARME DE MOTOR 3/4',8,null,null,'Referencia de los técnicos: 1 persona 1 día',null,6),
 ('Motor','ARMADO DE MOTOR COMPLETO',32,null,null,'Referencia de los técnicos: entre 1 persona 4 días',null,7),
 ('Motor','ARMADO DE MOTOR 3/4',8,null,null,'Referencia de los técnicos: 1 persona 1 día',null,8),
 ('Motor','LIMPIEZA DE PIEZAS DE MOTOR',8,null,null,'Referencia de los técnicos: 1 persona 1 día',null,9),
 ('Motor','DESARME DE MOTOR 7/8',16,null,null,'Referencia de los técnicos: entre 1 persona 2 día entre 2 1 días',null,10),
 ('Motor','ARMADO DE MOTOR 7/8',32,null,null,'Referencia de los técnicos: entre 1 persona 4 días',null,11),
 ('Motor','TRABAJOS VARIOS DE AVANCE DE MOTOR',1.0,null,null,null,null,12),
 ('Motor','MONTAJE DE BOMBA DE INYECCION',3.0,null,null,null,'inyeccion',13),
 ('Motor','DESMONTAJE DE BOMBA DE INYECCION',3.0,null,null,null,null,14),
 ('Motor','MONTAJE DE TURBO',4.0,null,null,null,null,15),
 ('Motor','DESMONTAJE DE TURBO',4.0,null,null,null,null,16),
 ('Motor','MONTAJE DE BOMBA DE AGUA',2.0,null,null,null,null,17),
 ('Motor','DESMONTAJE DE BOMBA DE AGUA',2.0,null,null,null,null,18),
 ('Motor','MONTAJE DE RADIADOR',1.0,null,null,null,'radiador',19),
 ('Motor','DESMONTAJE DE RADIADOR',1.0,null,null,null,null,20),
 ('Motor','MONTAJE DE INTERCOOLER',1.0,null,null,null,null,21),
 ('Motor','DESMONTAJE DE INTERCOOLER',1.0,null,null,null,null,22),
 ('Motor','MONTAJE DE INYECTORES',3.0,null,null,null,'inyeccion',23),
 ('Motor','DESMONTAJE DE INYECTORES',3.0,null,null,null,null,24),
 ('Motor','MONTAJE DE BOMBA HIDRAULICA',2.0,null,null,null,null,25),
 ('Motor','DESMONTAJE DE BOMBA HIDRAULICA',2.0,null,null,null,null,26),
 ('Motor','MONTAJE DE CAÑERIAS DE INYECTORES',2.0,null,null,null,null,27),
 ('Motor','DESMONTAJE DE CAÑERIA DE INYECTORES',2.0,null,null,null,null,28),
 ('Motor','MONTAJE DE CAÑERIA DE PRESION DE ACEITE',2.0,null,null,null,null,29),
 ('Motor','DESMONTAJE DE CAÑERIA DE PRESION DE ACEITE',2.0,null,null,null,null,30),
 ('Motor','MONTAJE DE CABEZOTE',4.0,null,null,null,null,31),
 ('Motor','DESMONTAJE DE CABEZOTE',4.0,null,null,null,null,32),
 ('Motor','MONTAJE DE CARTER',2.0,null,null,null,null,33),
 ('Motor','DESMONTAJE DE CARTER',2.0,null,null,null,null,34),
 ('Motor','MONTAJE DE RETENEDORES POSTERIORES DE CIGÜEÑAL',4.0,null,null,null,null,35),
 ('Motor','DESMONTAJE DE RETENEDORES POSTERIORES DE CIGÜEÑAL',4.0,null,null,null,null,36),
 ('Motor','MONTAJE DE RETENEDORES DELANTEROS DE CIGÜEÑAL',2.0,null,null,null,null,37),
 ('Motor','DESMONTAJE DE RETENEDORES DELANTEROS DE CIGÜEÑAL',2.0,null,null,null,null,38),
 ('Motor','MONTAJE DE ENFRIADOR DE ACEITE',5.0,null,null,null,null,39),
 ('Motor','DESMONTAJE DE ENFRIADOR DE ACEITE',5.0,null,null,null,null,40),
 ('Motor','MONTAJE DE COMPRESOR DE AIRE',4.0,null,null,null,null,41),
 ('Motor','DESMONTAJE DE COMPRESOR DE AIRE',4.0,null,null,null,null,42),
 ('Motor','CALIBRACION DE VALVULAS DE MOTOR',2.0,null,null,null,null,43),
 ('Motor','CAMBIO DE EMPAQUE DE TAPAVALVULAS MOTOR',1.5,null,null,null,null,44),
 ('Motor','CAMBIO DE EMPAQUE DE CASTILLO MOTOR',3.0,null,null,null,null,45),
 ('Motor','CAMBIO DE RETENEDORES DE INYECTORES',3.0,null,null,null,null,46),
 ('Motor','CAMBIO DE CAÑERIA DE PRESION DE ACEITE DEL ALTERNADOR',1.0,null,null,null,null,47),
 ('Motor','CAMBIO DE CAÑERIA DE PRESION DE ACEITE DEL TURBO',4.0,null,null,null,null,48),
 ('Motor','CAMBIO DE CAÑERIA DE AGUA DE COMPRESOR DE AIRE',2.0,null,null,null,null,49),
 ('Motor','CAMBIO DE CAÑERIAS DE COMBUSTIBLE',2.0,null,null,null,null,50),
 ('Motor','CAMBIO DE BASES DE MOTOR',2.0,null,null,null,null,51),
 ('Motor','CAMBIO DE EMBRAGUE DE VENTILADOR',1.0,null,null,null,null,52),
 ('Motor','MONTAJE DE LA CORAZA DE DISTRIBUCION',4.0,null,null,null,null,53),
 ('Motor','DESMONTAJE DE LA CORAZA DE DISTRIBUCION',4.0,null,null,null,null,54),
 ('Motor','SINCRONIZACION DE PIÑONES DEL TIEMPO DE MOTOR',2.0,null,null,null,null,55),
 ('Motor','INSTALACION DE PISTA DE RETENEDORES',1.0,null,null,null,null,56),
 ('Motor','REPARACION DE ARNES ELECTRONICO DE MOTOR',2.0,null,null,null,null,57),
 ('Motor','MONTAJE DE BASE DE FILTRO DE ACEITE',2.0,null,null,null,null,58),
 ('Motor','DESMONTAJE DE BASE DE FILTRO DE ACEITE',2.0,null,null,null,null,59),
 ('Motor','MONTAJE DE MULTIPLE DE ADMISION',3.0,null,null,null,null,60),
 ('Motor','DESMONTAJE DE MULTIPLE DE ADMISION',3.0,null,null,null,null,61),
 ('Motor','MONTAJE DE MULTIPLE DE ESCAPE',3.0,null,null,null,null,62),
 ('Motor','DESMONTAJE DE MULTIPLE DE ESCAPE',3.0,null,null,null,null,63),
 ('Motor','MONTAJE DE SISTEMA ANTI-RETORNO DE ACEITE',1.0,null,null,null,null,64),
 ('Motor','DESMONTAJE DE SISTEMA ANTI-RETORNO DE ACEITE',1.0,null,null,null,null,65),
 ('Motor','MONTAJE DE SISTEMA DE GASES DE MOTOR (EGR)',2.0,null,null,null,null,66),
 ('Motor','DESMONTAJE DE SISTEMA DE GASES DE MOTOR (EGR)',2.0,null,null,null,null,67),
 ('Motor','MONTAJE DE RIEL DE INYECTORES',2.0,null,null,null,null,68),
 ('Motor','DESMONTAJE DE RIEL DE INYECTORES',2.0,null,null,null,null,69),
 ('Motor','MONTAJE DE MANGUERAS DE ADMISION',1.0,null,null,null,null,70),
 ('Motor','DESMONTAJE DE MANGUERAS DE ADMISION',1.0,null,null,null,null,71),
 ('Motor','MONTAJE DE ARBOL DE LEVAS',3.0,null,null,null,null,72),
 ('Motor','DESMONTAJE DE ARBOL DE LEVAS',3.0,null,null,null,null,73),
 ('Motor','REVISION DE CONSUMO DE COMBUSTIBLE',3.0,null,null,null,null,74),
 ('Motor','MONTAJE DE CHISPEADORES DE ACEITE DE MOTOR',2.0,null,null,null,null,75),
 ('Motor','DESMONTAJE DE CHISPEADORES DE ACEITE DE MOTOR',2.0,null,null,null,null,76),
 ('Motor','INSTALACION DE CAMISAS DE MOTOR',2.0,null,null,null,null,77),
 ('Motor','INSTALACION DE PISTONES DE MOTOR',3.0,null,null,null,null,78),
 ('Motor','INSTALACION DE RINES DE MOTOR',1.0,null,null,null,null,79),
 ('Motor','ENRINADO DE MOTOR',6.0,null,null,null,null,80),
 ('Motor','MONTAJE DE MOTOR',6.0,null,null,null,null,81),
 ('Motor','DESMONTAJE DE MOTOR',6.0,null,null,null,null,82),
 ('Embrague y caja','MONTAJE DE CAJA DE CAMBIO',4.0,null,null,null,null,83),
 ('Embrague y caja','DESMONTAJE DE CAJA DE CAMBIO',4.0,null,null,null,null,84),
 ('Embrague y caja','ARMADO DE CAJA DE CAMBIO',3.0,null,null,null,null,85),
 ('Embrague y caja','DESARMADO DE CAJA DE CAMBIO',6.0,null,null,null,null,86),
 ('Embrague y caja','DESMONTAJE DE PIÑONES (RETRO|1RA|2DA|3RA|4TA|5TA|6TA)',3.0,null,null,null,null,87),
 ('Embrague y caja','CAMBIO DE SINCRONIZADOS (RETRO|1RA|2DA|3RA|4TA|5TA|6TA)',2.0,null,null,null,null,88),
 ('Embrague y caja','CAMBIO DE SEGUROS Y VINCHAS DE SINCRONIZADOS (RETRO|1RA|2DA|3RA|4TA|5TA|6TA)',2.0,null,null,null,null,89),
 ('Embrague y caja','REPARACION DE TAPA SELECTORA DE CAMBIOS',2.0,null,null,null,null,90),
 ('Embrague y caja','MONTAJE DE BRIDA DE CAMBIOS',1.0,null,null,null,null,91),
 ('Embrague y caja','DESMONTAJE DE BRIDA DE CAMBIOS',1.0,null,null,null,null,92),
 ('Embrague y caja','MONTAJE DE RETENEDORES DELANTEROS DE CAJA DE CAMBIOS',4.0,null,null,null,null,93),
 ('Embrague y caja','DESMONTAJE DE RETENEDORES DELANTEROS DE CAJA DE CAMBIOS',4.0,null,null,null,null,94),
 ('Embrague y caja','MONTAJE DE RETENEDORES POSTERIORES DE CAJA DE CAMBIOS',2.0,null,null,null,null,95),
 ('Embrague y caja','DESMONTAJE DE RETENEDORES POSTERIORES DE CAJA DE CAMBIOS',2.0,null,null,null,null,96),
 ('Embrague y caja','CAMBIO DE KIT DE EMBRAGUE (VOLANTE|DISCO|PLATO|RULIMAN)',4.0,null,null,null,'embrague',97),
 ('Embrague y caja','CAMBIO DE CILINDRO PRINCIPAL DE EMBRAGUE',2.5,null,null,null,null,98),
 ('Embrague y caja','CAMBIO DE CILINDRO AUXILIAR DE EMBRAGUE',1.0,null,null,null,null,99),
 ('Embrague y caja','CAMBIO DE RULIMAN DEL CENTRO (CARDAN)',3.0,null,null,null,null,100),
 ('Embrague y caja','CAMBIO DE CRUCETAS DE CARDAN',2.0,null,null,null,null,101),
 ('Corona / diferencial','MONTAJE DE DIFERENCIAL',4.0,null,null,null,null,102),
 ('Corona / diferencial','DESMONTAJE DE DIFERENCIAL',4.0,null,null,null,null,103),
 ('Corona / diferencial','MONTAJE DE EJES POSTERIORES',1.0,null,null,null,null,104),
 ('Corona / diferencial','DESMONTAJE DE EJES POSTERIORES',1.0,null,null,null,null,105),
 ('Corona / diferencial','MONTAJE DE PLANETARIOS Y SATELITES (LAINAS)',4.0,null,null,null,null,106),
 ('Corona / diferencial','DESMONTAJE DE PLANETARIOS Y SATELITES (LAINAS)',4.0,null,null,null,null,107),
 ('Corona / diferencial','CALIBRACION DE CONO',3.0,null,null,null,null,108),
 ('Corona / diferencial','CALIBRACION DE CORONA',2.0,null,null,null,null,109),
 ('Corona / diferencial','CAMBIO DE RODAMIENTOS DE CORONA',2.0,null,null,null,null,110),
 ('Corona / diferencial','CAMBIO DE RETENEDORES DE CORONA',1.0,null,null,null,null,111),
 ('Corona / diferencial','REPARACION DE CORONA',6.0,null,null,null,null,112),
 ('Suspensión','DESMONTAJE DE PAQUETES POSTERIORES',6.0,null,null,null,null,113),
 ('Suspensión','DESMONTAJE DE PAQUETES DELANTEROS',6.0,null,null,null,null,114),
 ('Suspensión','MONTAJE DE PAQUETES POSTERIORES',6.0,null,null,null,null,115),
 ('Suspensión','MONTAJE DE PAQUETES DELANTEROS',6.0,null,null,null,null,116),
 ('Suspensión','CAMBIO DE PINES Y BOCINES DE FRONTAL',6.0,null,null,null,null,117),
 ('Suspensión','CAMBIO DE CAUCHO DE BARRA ESTABILIZADORA',2.0,null,null,null,null,118),
 ('Suspensión','CAMBIO DE BARRA LARGA',2.0,null,null,null,null,119),
 ('Suspensión','CAMBIO DE BARRA CORTA',2.0,null,null,null,null,120),
 ('Suspensión','CAMBIO DE CAJETIN DE DIRECCION',2.0,null,null,null,null,121),
 ('Frenos','DESMONTAJE DEL SISTEMA DE FRENOS',6.0,null,null,null,null,122),
 ('Frenos','MONTAJE DE SISTEMA DE FRENOS',6.0,null,null,null,null,123),
 ('Frenos','LIMPIEZA Y REPARACION DE SISTEMA DE FRENOS (AIRE | HIDRAULICO)',5.0,null,null,null,null,124),
 ('Frenos','CAMBIO DE MANGUERA DE FRENO (AIRE|HIDRAULICO)',1.0,null,null,null,null,125),
 ('Frenos','CAMBIO DE BOOSTER DE FRENO',4.0,null,null,null,null,126),
 ('Motor','CAMBIO DE MANGUERA DE PRESION HIDRAULICA',2.0,null,null,null,null,127),
 ('Frenos','CAMBIO DE PULMONES DE FRENOS',4.0,null,null,null,null,128),
 ('Frenos','CAMBIO DE RACHET DE FRENOS',1.5,null,null,null,null,129),
 ('Frenos','CAMBIO DE TANQUE DE AIRE',1.0,null,null,null,null,130),
 ('Inyección y combustible','CAMBIO DE TANQUE DE COMBUSTIBLE',2.0,null,null,null,null,131),
 ('Frenos','CAMBIO DE FILTRO SECADOR DE AIRE',0.5,null,null,null,null,132),
 ('Sistema neumático (aire)','REVISION DE SISTEMA NEUMATICO',0.5,null,null,null,null,133),
 ('Sistema neumático (aire)','REPARACION DE SISTEMA NEUMATICO',4.0,null,null,null,null,134),
 ('Suspensión','CAMBIO DE AMORTIGUADOR',1.0,null,null,null,null,135),
 ('Suspensión','CAMBIO DE PERNOS DE RUEDAS',4.0,null,null,null,null,136),
 ('Embrague y caja','CAMBIO DE CABLES DE MARCHAS',2.0,null,null,null,null,137),
 ('Embrague y caja','CAMBIO DE MECANISMO DE CAMBIOS',2.0,null,null,null,null,138),
 ('Motor','CAMBIO DE BANDA DE MOTOR',1.0,null,null,null,null,139)
) as x(capsula, nombre, horas, grupo, codigo, nota, prev, orden)
join sistemas s on s.taller = 'mecanica' and s.nombre = x.capsula
-- No duplica: si el trabajo ya existe en cualquier cápsula de mecánica (por ejemplo, porque 011 lo movió), no se vuelve a crear.
where not exists (select 1 from intervenciones i join sistemas si on si.id = i.sistema_id
                   where si.taller = 'mecanica' and lower(i.nombre) = lower(x.nombre));

notify pgrst, 'reload schema';

-- >>>>>>>>>>>>>>>>>>>> 011_tempario_reubicar.sql
set client_min_messages = warning;
-- =====================================================================
-- 011 · Reubica trabajos del tempario en las cápsulas que corresponden
--       (decisión del 23-nov-2026):
--   * cajetín de dirección y barras larga/corta  → Dirección
--   * radiador, bomba de agua e intercooler        → Refrigeración
--   * inyectores, bomba de inyección, cañerías de
--     inyectores y de combustible, consumo         → Inyección y combustible
-- Solo mueve un trabajo si todavía está en su cápsula original (no pisa
-- cambios hechos a mano en Maestros). Las OT ya registradas no cambian.
-- =====================================================================
update intervenciones i set sistema_id = d.id
  from (values
 ('CAMBIO DE BARRA CORTA','Suspensión','Dirección'),
 ('CAMBIO DE BARRA LARGA','Suspensión','Dirección'),
 ('CAMBIO DE CAJETIN DE DIRECCION','Suspensión','Dirección'),
 ('CAMBIO DE CAÑERIAS DE COMBUSTIBLE','Motor','Inyección y combustible'),
 ('CAMBIO DE RETENEDORES DE INYECTORES','Motor','Inyección y combustible'),
 ('DESMONTAJE DE BOMBA DE INYECCION','Motor','Inyección y combustible'),
 ('DESMONTAJE DE CAÑERIA DE INYECTORES','Motor','Inyección y combustible'),
 ('DESMONTAJE DE INYECTORES','Motor','Inyección y combustible'),
 ('DESMONTAJE DE RIEL DE INYECTORES','Motor','Inyección y combustible'),
 ('MONTAJE DE BOMBA DE INYECCION','Motor','Inyección y combustible'),
 ('MONTAJE DE CAÑERIAS DE INYECTORES','Motor','Inyección y combustible'),
 ('MONTAJE DE INYECTORES','Motor','Inyección y combustible'),
 ('MONTAJE DE RIEL DE INYECTORES','Motor','Inyección y combustible'),
 ('REVISION DE CONSUMO DE COMBUSTIBLE','Motor','Inyección y combustible'),
 ('DESMONTAJE DE BOMBA DE AGUA','Motor','Refrigeración'),
 ('DESMONTAJE DE INTERCOOLER','Motor','Refrigeración'),
 ('DESMONTAJE DE RADIADOR','Motor','Refrigeración'),
 ('MONTAJE DE BOMBA DE AGUA','Motor','Refrigeración'),
 ('MONTAJE DE INTERCOOLER','Motor','Refrigeración'),
 ('MONTAJE DE RADIADOR','Motor','Refrigeración')
  ) as x(nombre, desde, hacia)
  join sistemas o on o.taller = 'mecanica' and o.nombre = x.desde
  join sistemas d on d.taller = 'mecanica' and d.nombre = x.hacia
 where i.sistema_id = o.id and i.nombre = x.nombre
   and not exists (select 1 from intervenciones y where y.sistema_id = d.id and lower(y.nombre) = lower(x.nombre));

notify pgrst, 'reload schema';
