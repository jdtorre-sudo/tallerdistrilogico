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
