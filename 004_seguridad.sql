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
