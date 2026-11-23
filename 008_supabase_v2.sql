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
