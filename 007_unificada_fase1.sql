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
