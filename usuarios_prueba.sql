insert into auth.users (id,email,raw_user_meta_data) values
 ('00000000-0000-0000-0000-0000000000a1','admin@taller.local','{"nombre_completo":"Juan Diego Torres"}'),
 ('11111111-1111-1111-1111-111111111111','jefe@taller.local','{"nombre_completo":"Jorge Salazar"}'),
 ('22222222-2222-2222-2222-222222222222','tecnico@taller.local','{"nombre_completo":"Carlos Mora"}'),
 ('33333333-3333-3333-3333-333333333333','bodega@taller.local','{"nombre_completo":"Luis Bodega"}');
update usuarios set activo = true, rol = case correo when 'admin@taller.local' then 'maestro' when 'jefe@taller.local' then 'supervisor'
  when 'tecnico@taller.local' then 'tecnico' else 'bodega' end;
update tecnicos set usuario_id = '22222222-2222-2222-2222-222222222222' where nombres = 'Carlos Mora';
