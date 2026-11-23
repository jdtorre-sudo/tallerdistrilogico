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
