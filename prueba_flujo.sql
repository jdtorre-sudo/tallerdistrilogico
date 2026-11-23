-- Prueba de las actas de entrega y recepción por rol. Ejecutar sobre una base recién creada
-- con datos de ejemplo y usuarios_prueba.sql. Los errores marcados ESPERADO deben aparecer.
\set ON_ERROR_STOP 1
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';  -- jefe de taller
select rol_actual();

-- ===== Actas de asignación (independientes)
\echo '--- ESPERADO: km menor'
\set ON_ERROR_STOP 0
select registrar_acta('entrega', jsonb_build_object('id_local',gen_random_uuid(),
  'vehiculo_id',(select id from vehiculos where codigo='DP162'),'conductor_id',(select id from conductores where cedula='0923456789'),
  'lectura',100,'combustible','F','motivo','asignacion'));
\set ON_ERROR_STOP 1
select registrar_acta('entrega', jsonb_build_object('id_local','aaaaaaaa-0000-0000-0000-000000000001',
  'vehiculo_id',(select id from vehiculos where codigo='DP162'),'conductor_id',(select id from conductores where cedula='0923456789'),
  'lectura',241900,'combustible','F','motivo','asignacion',
  'checklist',(select jsonb_agg(jsonb_build_object('item_checklist_id',id,'resultado','ok')) from items_checklist),
  'danos','[{"numero_marca":1,"vista":"frontal","posicion_x":0.5,"posicion_y":0.5,"tipo_dano":"rayon","descripcion":"Parachoques"}]'::jsonb)) as r;
select registrar_acta('entrega','{"id_local":"aaaaaaaa-0000-0000-0000-000000000001"}'::jsonb) as idempotente;
select firmar_acta('entrega',(select id from actas_entrega where id_local='aaaaaaaa-0000-0000-0000-000000000001'),'2026/10/GSC-1302/AE-1/firma_conductor.png','2026/10/GSC-1302/AE-1/firma_entrega.png');
select v.codigo, c.nombres as asignado, v.lectura_actual from vehiculos v left join conductores c on c.id=v.conductor_asignado_id where v.codigo='DP162';

-- El técnico ya no registra actas (solo el supervisor o el maestro)
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
\echo '--- ESPERADO: técnico no registra actas'
\set ON_ERROR_STOP 0
select registrar_acta('recepcion', jsonb_build_object('id_local',gen_random_uuid(),'vehiculo_id',(select id from vehiculos where codigo='DP162'),
  'conductor_id',(select id from conductores where cedula='0923456789'),'lectura',242500,'combustible','1/2','motivo','otro'));
\set ON_ERROR_STOP 1
-- El supervisor registra la recepción del mismo vehículo (devolución) aunque no exista OT
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select registrar_acta('recepcion', jsonb_build_object('id_local','aaaaaaaa-0000-0000-0000-000000000002',
  'vehiculo_id',(select id from vehiculos where codigo='DP162'),'conductor_id',(select id from conductores where cedula='0923456789'),
  'lectura',242500,'combustible','1/2','motivo','vacaciones_permiso','observaciones','Entrega por vacaciones',
  'checklist',(select jsonb_agg(jsonb_build_object('item_checklist_id',id,'resultado','ok')) from items_checklist)));
select firmar_acta('recepcion',(select id from actas_recepcion where id_local='aaaaaaaa-0000-0000-0000-000000000002'),'2026/10/GSC-1302/AR-1/firma_conductor.png','2026/10/GSC-1302/AR-1/firma_recibe.png');
select v.codigo, v.conductor_asignado_id is null as sin_conductor, v.lectura_actual from vehiculos v where v.codigo='DP162';
select tipo, numero, codigo, conductor, motivo, estado from v_actas order by numero;

-- (La OT por segmentos se prueba en prueba_ot.sql)

set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';  -- bodega
\echo '--- ESPERADO: bodega no escribe observaciones ni actas'
\set ON_ERROR_STOP 0
select registrar_acta('entrega','{}'::jsonb);
\set ON_ERROR_STOP 1

reset role; reset request.jwt.claim.sub;
\echo '--- ESPERADO: sin sesión (anon) no puede llamar funciones'
set role anon;
\set ON_ERROR_STOP 0
select abrir_ot('{}'::jsonb);
\set ON_ERROR_STOP 1
reset role;

select tabla, accion, count(*) from bitacora_auditoria where tabla in ('actas_entrega','actas_recepcion','ordenes_trabajo','vehiculos') group by 1,2 order by 1,2;
select count(*) as campos_sin_descripcion from v_diccionario_datos where coalesce(significado,'')='';
