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
