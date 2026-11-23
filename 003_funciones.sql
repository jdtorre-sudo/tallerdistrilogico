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
