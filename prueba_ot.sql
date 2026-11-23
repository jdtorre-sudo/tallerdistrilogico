-- Prueba de la Fase 2: OT por segmentos, cápsulas, reparto de horas, novedades y observaciones.
-- Ejecutar sobre una base recién creada con datos de ejemplo y usuarios_prueba.sql.
-- Los ESPERADO deben dar error (o el valor indicado).
\set ON_ERROR_STOP 1
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';  -- supervisor

-- ===== Segmento 1 y 2: abrir OT con checklist, daños y solicitud del chofer
\echo '--- ESPERADO: km menor'
\set ON_ERROR_STOP 0
select abrir_ot(jsonb_build_object('id_local',gen_random_uuid(),'vehiculo_id',(select id from vehiculos where codigo='DP176'),'lectura',10,'motivo_ingreso','correctivo'));
\echo '--- ESPERADO: sin vehículo y no es fabricación'
select abrir_ot(jsonb_build_object('id_local',gen_random_uuid(),'motivo_ingreso','correctivo'));
\set ON_ERROR_STOP 1
select abrir_ot(jsonb_build_object('id_local','cccccccc-0000-0000-0000-000000000001',
  'vehiculo_id',(select id from vehiculos where codigo='DP176'),'conductor_id',(select id from conductores where cedula='0956789012'),
  'lectura',98500,'combustible','3/4','motivo_ingreso','siniestro','prioridad','alta','inmovilizado',true,
  'checklist',(select jsonb_agg(jsonb_build_object('item_checklist_id',id,'resultado','ok')) from items_checklist),
  'danos','[{"numero_marca":1,"vista":"izquierda","posicion_x":0.4,"posicion_y":0.5,"tipo_dano":"golpe","descripcion":"Compuerta lateral hundida"}]'::jsonb,
  'solicitudes','[{"descripcion":"Compuerta trasera no cierra","taller_sugerido":"soldadura"},{"descripcion":"Frenos largos","taller_sugerido":"mecanica"},{"descripcion":"Ruido en cabina","taller_sugerido":"soldadura"}]'::jsonb)) as ot;
select abrir_ot('{"id_local":"cccccccc-0000-0000-0000-000000000001"}'::jsonb) as idempotente;
select id as ot from ordenes_trabajo where id_local='cccccccc-0000-0000-0000-000000000001' \gset
select numero, formato, motivo_ingreso, combustible, (select codigo from centros_costo where id=centro_costo_id) as cc,
       (select count(*) from ot_checklist where orden_trabajo_id=:'ot') as checklist,
       (select count(*) from danos_vehiculo where orden_trabajo_id=:'ot') as danos,
       (select count(*) from ot_solicitudes where orden_trabajo_id=:'ot') as solicitudes
  from ordenes_trabajo where id=:'ot';
-- Fabricación para stock: sin vehículo
select abrir_ot(jsonb_build_object('id_local',gen_random_uuid(),'motivo_ingreso','fabricacion','fabricacion_descripcion','Portallantas para stock','fabricacion_cantidad',5))->>'ot_numero' as fabricacion;
-- Unidad rentada: el centro de costo es MNTOPL3RAS y queda el cliente
select abrir_ot(jsonb_build_object('id_local',gen_random_uuid(),'vehiculo_id',(select id from vehiculos where codigo='DP1034'),'lectura',45300,'motivo_ingreso','correctivo')) is not null as rentada;
select o.numero, cc.codigo, c.nombre from ordenes_trabajo o join centros_costo cc on cc.id=o.centro_costo_id join clientes c on c.id=o.cliente_id;

-- ===== Segmentos 4/5: trabajos desde las cápsulas
-- Soldadura: Compuertas > Bisagras > Resoldar 0,5 h × 2 × grave 1,4 = 1,4 h; 2 técnicos en partes iguales; atiende la línea 1 del chofer
select guardar_trabajo(jsonb_build_object('orden_trabajo_id',:'ot',
  'intervencion_id',(select i.id from intervenciones i join sistemas s on s.id=i.sistema_id where s.nombre='Compuertas' and i.nombre='Resoldar'),
  'elemento_id',(select e.id from elementos e join sistemas s on s.id=e.sistema_id where s.nombre='Compuertas' and e.nombre='Bisagras'),
  'cantidad',2,'complejidad_id',(select id from complejidades where codigo='grave'),
  'origen','chofer','solicitud_id',(select id from ot_solicitudes where orden_trabajo_id=:'ot' and numero_linea=1),
  'causa','Golpe','material_base','hierro_negro','observacion','Soldadura en cordón',
  'tecnicos',jsonb_build_array(jsonb_build_object('tecnico_id',(select id from tecnicos where codigo='S01')),jsonb_build_object('tecnico_id',(select id from tecnicos where codigo='S02')))))->>'horas_estandar' as horas_1_4;
-- Tanque de lixiviados (sin complejidad): aunque manden "grave", multiplica por 1. Reparto 70/30. Origen: hallazgo nuevo
select guardar_trabajo(jsonb_build_object('orden_trabajo_id',:'ot',
  'intervencion_id',(select i.id from intervenciones i join sistemas s on s.id=i.sistema_id where s.nombre='Tanque de lixiviados' and i.nombre='Reparación de válvula'),
  'elemento_id',(select e.id from elementos e join sistemas s on s.id=e.sistema_id where s.nombre='Tanque de lixiviados' and e.nombre='Válvulas'),
  'cantidad',1,'complejidad_id',(select id from complejidades where codigo='grave'),
  'origen','hallazgo','hallazgo_nuevo',jsonb_build_object('descripcion','Válvula del tanque con fuga'),
  'tecnicos',jsonb_build_array(jsonb_build_object('tecnico_id',(select id from tecnicos where codigo='S01'),'porcentaje',70),jsonb_build_object('tecnico_id',(select id from tecnicos where codigo='M03'),'porcentaje',30))))->>'horas_estandar' as horas_1_2;
\echo '--- ESPERADO: reparto que no suma 100'
\set ON_ERROR_STOP 0
select guardar_trabajo(jsonb_build_object('orden_trabajo_id',:'ot',
  'intervencion_id',(select i.id from intervenciones i join sistemas s on s.id=i.sistema_id where s.nombre='UPN' and i.nombre='Enderezar'),
  'origen','preventivo','tecnicos',jsonb_build_array(jsonb_build_object('tecnico_id',(select id from tecnicos where codigo='S01'),'porcentaje',60),jsonb_build_object('tecnico_id',(select id from tecnicos where codigo='S02'),'porcentaje',30))));
\echo '--- ESPERADO: sin técnicos'
select guardar_trabajo(jsonb_build_object('orden_trabajo_id',:'ot',
  'intervencion_id',(select i.id from intervenciones i join sistemas s on s.id=i.sistema_id where s.nombre='UPN' and i.nombre='Enderezar'),'origen','preventivo','tecnicos','[]'::jsonb));
\echo '--- ESPERADO: elemento de otra cápsula'
select guardar_trabajo(jsonb_build_object('orden_trabajo_id',:'ot',
  'intervencion_id',(select i.id from intervenciones i join sistemas s on s.id=i.sistema_id where s.nombre='UPN' and i.nombre='Enderezar'),
  'elemento_id',(select e.id from elementos e where e.nombre='Bisagras'),'origen','preventivo','tecnicos',jsonb_build_array(jsonb_build_object('tecnico_id',(select id from tecnicos where codigo='S01')))));
\set ON_ERROR_STOP 1
-- Mecánica: una intervención agregada en Maestros, 3 técnicos en partes iguales (33,34 / 33,33 / 33,33)
reset role;
insert into intervenciones (sistema_id, nombre, horas_estandar) select id, 'Regular frenos', 1.0 from sistemas where nombre='Frenos' and taller='mecanica';
set role authenticated;
select guardar_trabajo(jsonb_build_object('orden_trabajo_id',:'ot','intervencion_id',(select id from intervenciones where nombre='Regular frenos'),
  'origen','chofer','solicitud_id',(select id from ot_solicitudes where orden_trabajo_id=:'ot' and numero_linea=2),
  'tecnicos',jsonb_build_array(jsonb_build_object('tecnico_id',(select id from tecnicos where codigo='M01')),jsonb_build_object('tecnico_id',(select id from tecnicos where codigo='M02')),jsonb_build_object('tecnico_id',(select id from tecnicos where codigo='M03')))));
select numero_linea, taller, sistema_nombre, elemento_nombre, intervencion_nombre, cantidad, complejidad_nombre, multiplicador, horas_estandar, origen,
       (select string_agg(x->>'codigo' || ' ' || (x->>'porcentaje') || '% ' || (x->>'horas') || 'h', ' | ') from jsonb_array_elements(tecnicos) x) as reparto
  from v_ot_trabajos where orden_trabajo_id=:'ot' order by numero_linea;
select numero_linea, estado from ot_solicitudes where orden_trabajo_id=:'ot' order by 1;
select numero_linea, descripcion, estado from ot_hallazgos where orden_trabajo_id=:'ot';

-- Edición: cambiar cantidad y reparto (los anteriores quedan anulados, no se borran)
select guardar_trabajo(jsonb_build_object('id',(select id from ot_trabajos where orden_trabajo_id=:'ot' and numero_linea=1),'cantidad',3,
  'tecnicos',jsonb_build_array(jsonb_build_object('tecnico_id',(select id from tecnicos where codigo='S01'),'porcentaje',70),jsonb_build_object('tecnico_id',(select id from tecnicos where codigo='S02'),'porcentaje',30))))->>'horas_estandar' as horas_2_1;
select (select count(*) from ot_trabajo_tecnicos tt join ot_trabajos t on t.id=tt.trabajo_id where t.numero_linea=1 and t.orden_trabajo_id=:'ot' and tt.anulado) as repartos_anulados,
       (select string_agg(x->>'codigo' || ' ' || (x->>'horas'), ' | ') from v_ot_trabajos, jsonb_array_elements(tecnicos) x where orden_trabajo_id=:'ot' and numero_linea=1) as horas_1_47_y_0_63;

-- Inspeccionado OK y novedades
insert into ot_inspecciones (orden_trabajo_id, sistema_id) select :'ot', id from sistemas where nombre='Cabina';
insert into ot_imprevistos (orden_trabajo_id, trabajo_id, tecnico_id, motivo, detalle, minutos)
 select :'ot', id, (select id from tecnicos where codigo='S01'), 'Falta de repuesto o material', 'Faltan pernos', 30 from ot_trabajos where orden_trabajo_id=:'ot' and numero_linea=1;
update ot_imprevistos set estado='aprobado' where orden_trabajo_id=:'ot';
select estado, resuelto_por is not null as con_quien from ot_imprevistos where orden_trabajo_id=:'ot';
\echo '--- ESPERADO: no realizado sin motivo'
\set ON_ERROR_STOP 0
update ot_trabajos set estado='no_realizado' where orden_trabajo_id=:'ot' and numero_linea=3;
\set ON_ERROR_STOP 1

-- ===== Técnico: ve la OT, escribe solo donde está asignado, no cambia estados
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';  -- técnico M01 (Carlos Mora)
select count(*) as ve_trabajos from v_ot_trabajos where orden_trabajo_id=:'ot';
select numero, intervencion_nombre, horas from v_mis_trabajos;
insert into comentarios_ot (orden_trabajo_id, texto) values (:'ot', 'Terminé de regular frenos; zapatas al 30 %.');
select tecnico_codigo, texto from v_observaciones_ot where orden_trabajo_id=:'ot';
\echo '--- ESPERADO: técnico no edita su observación'
\set ON_ERROR_STOP 0
update comentarios_ot set texto='otro' where orden_trabajo_id=:'ot';
\set ON_ERROR_STOP 1
\echo '--- ESPERADO: técnico no marca terminado ni registra trabajos'
update ot_trabajos set estado='terminado' where orden_trabajo_id=:'ot';
select count(*) as terminados_debe_ser_0 from ot_trabajos where orden_trabajo_id=:'ot' and estado='terminado';
\set ON_ERROR_STOP 0
select guardar_trabajo(jsonb_build_object('orden_trabajo_id',:'ot','intervencion_id',(select id from intervenciones where nombre='Regular frenos'),'origen','preventivo','tecnicos',jsonb_build_array(jsonb_build_object('tecnico_id',(select id from tecnicos where codigo='M01')))));
\echo '--- ESPERADO: técnico no asignado no escribe en otra OT'
insert into comentarios_ot (orden_trabajo_id, texto) select id, 'hola' from ordenes_trabajo where id <> :'ot' limit 1;
\set ON_ERROR_STOP 1
-- El supervisor no escribe en el segmento 8 (tiene su propio espacio)
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
\echo '--- ESPERADO: supervisor no escribe en observaciones de técnicos'
\set ON_ERROR_STOP 0
insert into comentarios_ot (orden_trabajo_id, texto) values (:'ot', 'supervisor');
\set ON_ERROR_STOP 1
update ordenes_trabajo set obs_supervisor_soldadura='Revisar escuadra de compuerta' where id=:'ot';

-- ===== Cierre: no con trabajos abiertos ni solicitudes pendientes
\echo '--- ESPERADO: cerrar con trabajos pendientes'
\set ON_ERROR_STOP 0
select cambiar_estado_ot(:'ot','entregado');
\set ON_ERROR_STOP 1
update ot_trabajos set estado='terminado' where orden_trabajo_id=:'ot' and numero_linea in (1,2);
update ot_trabajos set estado='no_realizado', motivo_no_realizado='Sin repuesto en bodega' where orden_trabajo_id=:'ot' and numero_linea=3;
\echo '--- ESPERADO: línea 3 del chofer sin resolver'
\set ON_ERROR_STOP 0
select cambiar_estado_ot(:'ot','entregado');
\set ON_ERROR_STOP 1
update ot_solicitudes set estado='descartada', motivo='No se encontró la falla' where orden_trabajo_id=:'ot' and numero_linea=3;
select cambiar_estado_ot(:'ot','entregado','Unidad entregada');
select numero, estado, total_horas_internas as horas_terminadas, horas_parado is not null as parado from ordenes_trabajo where id=:'ot';
\echo '--- ESPERADO: OT cerrada no se modifica'
\set ON_ERROR_STOP 0
update ot_trabajos set observacion='x' where orden_trabajo_id=:'ot';
\set ON_ERROR_STOP 1
reset role;
select count(*) as campos_sin_descripcion from v_diccionario_datos where coalesce(significado,'')='';
