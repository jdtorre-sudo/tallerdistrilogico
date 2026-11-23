-- Prueba de permisos del módulo Maestros (Fase 1 unificada). Ejecutar sobre una base
-- recién creada con datos de ejemplo y usuarios_prueba.sql. Los ESPERADO deben dar error o 0.
\set ON_ERROR_STOP 1
set role authenticated;

-- ===== Técnico: no ve costos ni edita maestros
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select rol_actual(), tiene_permiso('ver_costos') as ve_costos, tecnico_actual() is not null as tiene_ficha;
select count(*) as tarifas_visibles_para_tecnico_debe_ser_0 from tarifas_tecnico;
\echo '--- ESPERADO: técnico no crea vehículos ni catálogo'
\set ON_ERROR_STOP 0
insert into vehiculos (codigo, tipo_vehiculo_id) values ('DC999', (select id from tipos_vehiculo where prefijo_codigo='DC'));
insert into intervenciones (sistema_id, nombre, horas_estandar) values ((select id from sistemas where nombre='Compuertas'), 'X', 1);
\set ON_ERROR_STOP 1

-- ===== Supervisor sin permiso extra: tampoco edita maestros
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
\echo '--- ESPERADO: supervisor sin editar_catalogos no crea choferes'
\set ON_ERROR_STOP 0
insert into conductores (cedula, nombres, apellidos) values ('0999999999','Prueba','Chofer');
\set ON_ERROR_STOP 1

-- El maestro le suma el permiso "editar_catalogos" y "bodega" (domingo de turno)
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
update usuarios set permisos_extra = '{editar_catalogos,bodega}' where id = '11111111-1111-1111-1111-111111111111';
\echo '--- ESPERADO: permiso extra inexistente'
\set ON_ERROR_STOP 0
update usuarios set permisos_extra = '{volar}' where id = '11111111-1111-1111-1111-111111111111';
\set ON_ERROR_STOP 1

set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select tiene_permiso('editar_catalogos') as cat, tiene_permiso('bodega') as bod, tiene_permiso('ver_costos') as costos;
insert into conductores (cedula, nombres, apellidos) values ('0999999999','Prueba','Chofer');
insert into intervenciones (sistema_id, nombre, horas_estandar)
  values ((select id from sistemas where nombre='Compuertas'), 'Ajustar bisagra', 0.25);
\echo '--- ESPERADO: supervisor no toca técnicos, tarifas, complejidad ni parámetros (solo maestro)'
\set ON_ERROR_STOP 0
insert into tecnicos (codigo, nombres) values ('X1','Nuevo');
insert into tarifas_tecnico (tecnico_id, tarifa_hora) values ((select id from tecnicos where codigo='M01'), 99);
\set ON_ERROR_STOP 1
update complejidades set multiplicador = 9 where codigo = 'grave';
update configuracion set valor = '1' where clave = 'dias_retrabajo';
select (select multiplicador from complejidades where codigo='grave') as grave_sigue_1_4,
       (select valor from configuracion where clave='dias_retrabajo') as retrabajo_sigue_90;

-- ===== Maestro: todo
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
update complejidades set multiplicador = 1.5 where codigo = 'grave';
insert into tarifas_tecnico (tecnico_id, tarifa_hora, vigente_desde) values ((select id from tecnicos where codigo='M01'), 7.00, '2026-11-01');
select codigo, tarifa_vigente(id, '2026-10-15') as octubre, tarifa_vigente(id, '2026-11-23') as noviembre from tecnicos where codigo='M01';
\echo '--- ESPERADO: código de técnico repetido (sin importar mayúsculas)'
\set ON_ERROR_STOP 0
insert into tecnicos (codigo, nombres) values ('m01','Repetido');
\set ON_ERROR_STOP 1

-- Unidad rentada: va sola al centro de costo de clientes
select codigo, propiedad, cliente, centro_costo, costo_por_km, edad_meses is not null as tiene_edad from v_vehiculos where codigo in ('DP1034','DC001');
\echo '--- ESPERADO: rentada sin cliente'
\set ON_ERROR_STOP 0
insert into vehiculos (codigo, tipo_vehiculo_id, propiedad) values ('DP999', (select id from tipos_vehiculo where prefijo_codigo='DP'), 'rentado');
\set ON_ERROR_STOP 1
-- Estado y fechas de parada
update vehiculos set estado = 'parado', estado_desde = '2026-11-01' where codigo = 'DP176';
update vehiculos set estado = 'activo', estado_desde = '2026-11-20' where codigo = 'DP176';
select h.estado, h.desde, h.hasta from historial_estados_vehiculo h join vehiculos v on v.id = h.vehiculo_id
 where v.codigo = 'DP176' order by h.desde, h.creado_en;

-- Catálogo: la misma intervención no se repite en un elemento
\echo '--- ESPERADO: intervención repetida'
\set ON_ERROR_STOP 0
insert into intervenciones (sistema_id, nombre, horas_estandar) values ((select id from sistemas where nombre='Compuertas'), 'resoldar', 1);
\set ON_ERROR_STOP 1
select taller, count(distinct sistema_id) as capsulas, count(intervencion_id) as intervenciones
  from v_catalogo_trabajos where sistema_activo group by taller order by 1;
select sistema, aplica_complejidad, elementos_activos, count(intervencion_id) as intervenciones
  from v_catalogo_trabajos where taller = 'soldadura' group by 1,2,3, sistema_orden order by sistema_orden;
select codigo, modo, intervalo_cabezal, intervalo_plataforma, pct_prematuro, registro_automatico from sistemas_preventivos order by orden;

-- ===== Clave de aprobación
\echo '--- ESPERADO: supervisor no define la clave; clave corta'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
\set ON_ERROR_STOP 0
select fijar_clave_aprobacion('12345');
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
select fijar_clave_aprobacion('12');
\set ON_ERROR_STOP 1
select fijar_clave_aprobacion('Taller2026');
select estado_clave_aprobacion()->>'definida' as definida;
select verificar_clave_aprobacion('Taller2026') as correcta, verificar_clave_aprobacion('otra') as incorrecta;
\echo '--- ESPERADO: nadie lee la clave cifrada'
\set ON_ERROR_STOP 0
select * from clave_aprobacion;
\set ON_ERROR_STOP 1
\echo '--- ESPERADO: bodega sin aprobar_ajustes no verifica'
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
\set ON_ERROR_STOP 0
select verificar_clave_aprobacion('Taller2026');
\set ON_ERROR_STOP 1

-- ===== El técnico edita solo su teléfono y contacto de emergencia
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select actualizar_mis_datos('0990000001', 'Ana Mora (hija) - 0991112222');
update tecnicos set cargo = 'Jefe' where codigo = 'M01';
select codigo, telefono, contacto_emergencia, cargo as cargo_sin_cambio from tecnicos where codigo = 'M01';
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';

\echo '--- ESPERADO: nadie borra (se desactiva)'
\set ON_ERROR_STOP 0
delete from intervenciones where nombre = 'Ajustar bisagra';
\set ON_ERROR_STOP 1
select count(*) as sigue_existiendo_debe_ser_1 from intervenciones where nombre = 'Ajustar bisagra';
reset role;
select count(*) as campos_sin_descripcion from v_diccionario_datos where coalesce(significado,'')='';
