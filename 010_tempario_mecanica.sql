set client_min_messages = warning;
-- =====================================================================
-- 010 · Tempario de mecánica y eléctricos definido con los técnicos
--       (referencias/tempario_mecanica_electricos.xlsx).
-- * Las intervenciones pueden tener código, grupo (sub-categoría dentro
--   de la cápsula) y una nota (ej. duración total estimada).
-- * Las horas estándar pasan a 3 decimales (5 min = 0,083 h).
-- * Carga el tempario en las cápsulas de mecánica. Solo agrega lo que no
--   existe: se puede ejecutar más de una vez y no pisa cambios hechos en Maestros.
-- Conversión usada: tiempos en horas tal cual; "1 persona N días" = N × 8 horas-hombre.
-- =====================================================================

-- Las vistas dependen de las columnas que cambian de tipo: se recrean.
drop view if exists v_catalogo_trabajos;
drop view if exists v_mis_trabajos;
drop view if exists v_ot_trabajos;

alter table intervenciones alter column horas_estandar type numeric(7,3);
alter table ot_trabajos alter column horas_unitarias type numeric(7,3);
alter table intervenciones add column if not exists codigo text;
alter table intervenciones add column if not exists grupo text;
alter table intervenciones add column if not exists nota text;

comment on column intervenciones.horas_estandar is 'Horas-hombre totales del trabajo (3 decimales: 5 min = 0,083 h). Si exige dos personas, ya viene multiplicado.';
comment on column intervenciones.codigo is 'Código del trabajo en el tempario (opcional).';
comment on column intervenciones.grupo is 'Sub-categoría dentro de la cápsula (ej. Checklist, Eléctricos puntuales, Electrónicos). Ordena y agrupa la lista.';
comment on column intervenciones.nota is 'Nota visible al elegir el trabajo (ej. duración total estimada con esperas).';
comment on column ot_trabajos.horas_unitarias is 'Horas estándar del catálogo al momento de registrar (3 decimales).';

create view v_catalogo_trabajos with (security_invoker = true) as
select s.taller, s.id as sistema_id, s.nombre as sistema, s.orden as sistema_orden, s.activo as sistema_activo,
       s.aplica_complejidad,
       (select count(*) from elementos e where e.sistema_id = s.id and e.activo) as elementos_activos,
       i.id as intervencion_id, i.nombre as intervencion, i.horas_estandar,
       i.orden as intervencion_orden, i.activo as intervencion_activo,
       p.codigo as sistema_preventivo, p.nombre as sistema_preventivo_nombre,
       i.grupo, i.codigo, i.nota
  from sistemas s
  left join intervenciones i on i.sistema_id = s.id
  left join sistemas_preventivos p on p.id = i.sistema_preventivo_id;

create view v_ot_trabajos with (security_invoker = true) as
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

create view v_mis_trabajos with (security_invoker = true) as
select t.id, t.orden_trabajo_id, o.numero, o.estado as estado_ot, v.codigo, v.placa, o.motivo_ingreso, o.prioridad,
       t.taller, t.sistema_nombre, t.elemento_nombre, t.intervencion_nombre, t.cantidad, t.estado, t.observacion,
       tt.porcentaje, tt.horas, t.creado_en
  from ot_trabajo_tecnicos tt
  join ot_trabajos t on t.id = tt.trabajo_id
  join ordenes_trabajo o on o.id = t.orden_trabajo_id
  left join vehiculos v on v.id = o.vehiculo_id
 where not tt.anulado and not t.anulado and not o.anulado and tt.tecnico_id = tecnico_actual();

grant select on v_catalogo_trabajos, v_ot_trabajos, v_mis_trabajos to authenticated;
revoke all on v_catalogo_trabajos, v_ot_trabajos, v_mis_trabajos from anon;

-- Tempario: cápsula, intervención, horas, grupo, código, nota, sistema preventivo, orden
insert into intervenciones (sistema_id, nombre, horas_estandar, grupo, codigo, nota, sistema_preventivo_id, orden)
select s.id, x.nombre, x.horas, x.grupo, x.codigo, x.nota, (select id from sistemas_preventivos where codigo = x.prev), x.orden
from (values
 ('Sistema eléctrico','SACAR BATERIA',0.5,'Checklist',null,null,null,1),
 ('Sistema eléctrico','REVISION DE LUCES DE UNIDAD (POST|DEL|LAT|INT)',0.0833,'Checklist',null,null,null,2),
 ('Sistema eléctrico','REVISION DE PLUMAS',0.0833,'Checklist',null,null,null,3),
 ('Sistema eléctrico','ESCANEO DE UNIDAD',0.25,'Checklist',null,null,null,4),
 ('Sistema eléctrico','REPARACION DE MOTOR DE ARRANQUE',1.0,'Eléctricos puntuales',null,null,null,5),
 ('Sistema eléctrico','CAMBIO FARO RH|LH',0.5,'Eléctricos puntuales',null,null,null,6),
 ('Sistema eléctrico','CAMBIO DE LUCES DE RUTA',0.1667,'Eléctricos puntuales',null,null,null,7),
 ('Sistema eléctrico','CAMBIO DE HALOGENO DE RETRO',0.3333,'Eléctricos puntuales',null,null,null,8),
 ('Sistema eléctrico','CAMBIO DE PITO DE RETRO',0.25,'Eléctricos puntuales',null,null,null,9),
 ('Sistema eléctrico','CAMBIO DE ALTERNADOR',0.75,'Eléctricos puntuales',null,null,null,10),
 ('Sistema eléctrico','TRABAJO ADICIONAL DE TECNICO',0.5,'Eléctricos puntuales',null,null,null,11),
 ('Sistema eléctrico','REPARACION DE MOTOR ELEVAVIDRIO',1.0,'Eléctricos puntuales',null,'Duración total estimada: 6 horas',null,12),
 ('Sistema eléctrico','REPARACION DE MECANISMO ELEVAVIDRIO',1.0,'Eléctricos puntuales',null,'Duración total estimada: 6 horas',null,13),
 ('Sistema eléctrico','REPARACION DE MECANISMO LIMPIAVIDRIOS',1.0,'Eléctricos puntuales',null,'Duración total estimada: 4 horas',null,14),
 ('Sistema eléctrico','REPARACION DE FRENO DE ESCAPE',1.0,'Eléctricos puntuales',null,'Duración total estimada: 2.5 horas',null,15),
 ('Sistema eléctrico','REVISION DE ENCENDIDO DE UNIDAD',1.0,'Electrónicos',null,'Duración total estimada: 1 hora',null,16),
 ('Sistema eléctrico','REVISION DE FUSILERA',1.0,'Electrónicos',null,'Duración total estimada: 1 hora',null,17),
 ('Sistema eléctrico','REVISION DE LINEA',0.75,'Electrónicos',null,'Duración total estimada: 4 dias peor escenario',null,18),
 ('Sistema eléctrico','DESMONTAJE DE TABLERO DE CABINA',4.0,'Electrónicos',null,null,null,19),
 ('Sistema eléctrico','REPARACION DE ECU',1.0,'Electrónicos',null,'Duración total estimada: 2 a 3 dias',null,20),
 ('Sistema eléctrico','DIAGNOSTICO DE ECU',1.0,'Electrónicos',null,'Duración total estimada: 2 horas',null,21),
 ('Motor','REVISION DE MOTOR POR NO ENCENDIDO',2.0,null,'01141',null,null,1),
 ('Motor','REVISION DE MOTOR POR PERDIDA DE POTENCIA',2.0,null,'00160',null,null,2),
 ('Motor','REVISION DE TESTIGO DE TABLERO ENCENDIDO',1.0,null,'00059',null,null,3),
 ('Motor','DIAGNOSTICO DE DAÑO DE MOTOR',2.0,null,'00635',null,null,4),
 ('Motor','DESARME DE MOTOR COMPLETO',16,null,null,'Referencia de los técnicos: entre 1 persona 2 día entre 2 1 días',null,5),
 ('Motor','DESARME DE MOTOR 3/4',8,null,null,'Referencia de los técnicos: 1 persona 1 día',null,6),
 ('Motor','ARMADO DE MOTOR COMPLETO',32,null,null,'Referencia de los técnicos: entre 1 persona 4 días',null,7),
 ('Motor','ARMADO DE MOTOR 3/4',8,null,null,'Referencia de los técnicos: 1 persona 1 día',null,8),
 ('Motor','LIMPIEZA DE PIEZAS DE MOTOR',8,null,null,'Referencia de los técnicos: 1 persona 1 día',null,9),
 ('Motor','DESARME DE MOTOR 7/8',16,null,null,'Referencia de los técnicos: entre 1 persona 2 día entre 2 1 días',null,10),
 ('Motor','ARMADO DE MOTOR 7/8',32,null,null,'Referencia de los técnicos: entre 1 persona 4 días',null,11),
 ('Motor','TRABAJOS VARIOS DE AVANCE DE MOTOR',1.0,null,null,null,null,12),
 ('Motor','MONTAJE DE BOMBA DE INYECCION',3.0,null,null,null,'inyeccion',13),
 ('Motor','DESMONTAJE DE BOMBA DE INYECCION',3.0,null,null,null,null,14),
 ('Motor','MONTAJE DE TURBO',4.0,null,null,null,null,15),
 ('Motor','DESMONTAJE DE TURBO',4.0,null,null,null,null,16),
 ('Motor','MONTAJE DE BOMBA DE AGUA',2.0,null,null,null,null,17),
 ('Motor','DESMONTAJE DE BOMBA DE AGUA',2.0,null,null,null,null,18),
 ('Motor','MONTAJE DE RADIADOR',1.0,null,null,null,'radiador',19),
 ('Motor','DESMONTAJE DE RADIADOR',1.0,null,null,null,null,20),
 ('Motor','MONTAJE DE INTERCOOLER',1.0,null,null,null,null,21),
 ('Motor','DESMONTAJE DE INTERCOOLER',1.0,null,null,null,null,22),
 ('Motor','MONTAJE DE INYECTORES',3.0,null,null,null,'inyeccion',23),
 ('Motor','DESMONTAJE DE INYECTORES',3.0,null,null,null,null,24),
 ('Motor','MONTAJE DE BOMBA HIDRAULICA',2.0,null,null,null,null,25),
 ('Motor','DESMONTAJE DE BOMBA HIDRAULICA',2.0,null,null,null,null,26),
 ('Motor','MONTAJE DE CAÑERIAS DE INYECTORES',2.0,null,null,null,null,27),
 ('Motor','DESMONTAJE DE CAÑERIA DE INYECTORES',2.0,null,null,null,null,28),
 ('Motor','MONTAJE DE CAÑERIA DE PRESION DE ACEITE',2.0,null,null,null,null,29),
 ('Motor','DESMONTAJE DE CAÑERIA DE PRESION DE ACEITE',2.0,null,null,null,null,30),
 ('Motor','MONTAJE DE CABEZOTE',4.0,null,null,null,null,31),
 ('Motor','DESMONTAJE DE CABEZOTE',4.0,null,null,null,null,32),
 ('Motor','MONTAJE DE CARTER',2.0,null,null,null,null,33),
 ('Motor','DESMONTAJE DE CARTER',2.0,null,null,null,null,34),
 ('Motor','MONTAJE DE RETENEDORES POSTERIORES DE CIGÜEÑAL',4.0,null,null,null,null,35),
 ('Motor','DESMONTAJE DE RETENEDORES POSTERIORES DE CIGÜEÑAL',4.0,null,null,null,null,36),
 ('Motor','MONTAJE DE RETENEDORES DELANTEROS DE CIGÜEÑAL',2.0,null,null,null,null,37),
 ('Motor','DESMONTAJE DE RETENEDORES DELANTEROS DE CIGÜEÑAL',2.0,null,null,null,null,38),
 ('Motor','MONTAJE DE ENFRIADOR DE ACEITE',5.0,null,null,null,null,39),
 ('Motor','DESMONTAJE DE ENFRIADOR DE ACEITE',5.0,null,null,null,null,40),
 ('Motor','MONTAJE DE COMPRESOR DE AIRE',4.0,null,null,null,null,41),
 ('Motor','DESMONTAJE DE COMPRESOR DE AIRE',4.0,null,null,null,null,42),
 ('Motor','CALIBRACION DE VALVULAS DE MOTOR',2.0,null,null,null,null,43),
 ('Motor','CAMBIO DE EMPAQUE DE TAPAVALVULAS MOTOR',1.5,null,null,null,null,44),
 ('Motor','CAMBIO DE EMPAQUE DE CASTILLO MOTOR',3.0,null,null,null,null,45),
 ('Motor','CAMBIO DE RETENEDORES DE INYECTORES',3.0,null,null,null,null,46),
 ('Motor','CAMBIO DE CAÑERIA DE PRESION DE ACEITE DEL ALTERNADOR',1.0,null,null,null,null,47),
 ('Motor','CAMBIO DE CAÑERIA DE PRESION DE ACEITE DEL TURBO',4.0,null,null,null,null,48),
 ('Motor','CAMBIO DE CAÑERIA DE AGUA DE COMPRESOR DE AIRE',2.0,null,null,null,null,49),
 ('Motor','CAMBIO DE CAÑERIAS DE COMBUSTIBLE',2.0,null,null,null,null,50),
 ('Motor','CAMBIO DE BASES DE MOTOR',2.0,null,null,null,null,51),
 ('Motor','CAMBIO DE EMBRAGUE DE VENTILADOR',1.0,null,null,null,null,52),
 ('Motor','MONTAJE DE LA CORAZA DE DISTRIBUCION',4.0,null,null,null,null,53),
 ('Motor','DESMONTAJE DE LA CORAZA DE DISTRIBUCION',4.0,null,null,null,null,54),
 ('Motor','SINCRONIZACION DE PIÑONES DEL TIEMPO DE MOTOR',2.0,null,null,null,null,55),
 ('Motor','INSTALACION DE PISTA DE RETENEDORES',1.0,null,null,null,null,56),
 ('Motor','REPARACION DE ARNES ELECTRONICO DE MOTOR',2.0,null,null,null,null,57),
 ('Motor','MONTAJE DE BASE DE FILTRO DE ACEITE',2.0,null,null,null,null,58),
 ('Motor','DESMONTAJE DE BASE DE FILTRO DE ACEITE',2.0,null,null,null,null,59),
 ('Motor','MONTAJE DE MULTIPLE DE ADMISION',3.0,null,null,null,null,60),
 ('Motor','DESMONTAJE DE MULTIPLE DE ADMISION',3.0,null,null,null,null,61),
 ('Motor','MONTAJE DE MULTIPLE DE ESCAPE',3.0,null,null,null,null,62),
 ('Motor','DESMONTAJE DE MULTIPLE DE ESCAPE',3.0,null,null,null,null,63),
 ('Motor','MONTAJE DE SISTEMA ANTI-RETORNO DE ACEITE',1.0,null,null,null,null,64),
 ('Motor','DESMONTAJE DE SISTEMA ANTI-RETORNO DE ACEITE',1.0,null,null,null,null,65),
 ('Motor','MONTAJE DE SISTEMA DE GASES DE MOTOR (EGR)',2.0,null,null,null,null,66),
 ('Motor','DESMONTAJE DE SISTEMA DE GASES DE MOTOR (EGR)',2.0,null,null,null,null,67),
 ('Motor','MONTAJE DE RIEL DE INYECTORES',2.0,null,null,null,null,68),
 ('Motor','DESMONTAJE DE RIEL DE INYECTORES',2.0,null,null,null,null,69),
 ('Motor','MONTAJE DE MANGUERAS DE ADMISION',1.0,null,null,null,null,70),
 ('Motor','DESMONTAJE DE MANGUERAS DE ADMISION',1.0,null,null,null,null,71),
 ('Motor','MONTAJE DE ARBOL DE LEVAS',3.0,null,null,null,null,72),
 ('Motor','DESMONTAJE DE ARBOL DE LEVAS',3.0,null,null,null,null,73),
 ('Motor','REVISION DE CONSUMO DE COMBUSTIBLE',3.0,null,null,null,null,74),
 ('Motor','MONTAJE DE CHISPEADORES DE ACEITE DE MOTOR',2.0,null,null,null,null,75),
 ('Motor','DESMONTAJE DE CHISPEADORES DE ACEITE DE MOTOR',2.0,null,null,null,null,76),
 ('Motor','INSTALACION DE CAMISAS DE MOTOR',2.0,null,null,null,null,77),
 ('Motor','INSTALACION DE PISTONES DE MOTOR',3.0,null,null,null,null,78),
 ('Motor','INSTALACION DE RINES DE MOTOR',1.0,null,null,null,null,79),
 ('Motor','ENRINADO DE MOTOR',6.0,null,null,null,null,80),
 ('Motor','MONTAJE DE MOTOR',6.0,null,null,null,null,81),
 ('Motor','DESMONTAJE DE MOTOR',6.0,null,null,null,null,82),
 ('Embrague y caja','MONTAJE DE CAJA DE CAMBIO',4.0,null,null,null,null,83),
 ('Embrague y caja','DESMONTAJE DE CAJA DE CAMBIO',4.0,null,null,null,null,84),
 ('Embrague y caja','ARMADO DE CAJA DE CAMBIO',3.0,null,null,null,null,85),
 ('Embrague y caja','DESARMADO DE CAJA DE CAMBIO',6.0,null,null,null,null,86),
 ('Embrague y caja','DESMONTAJE DE PIÑONES (RETRO|1RA|2DA|3RA|4TA|5TA|6TA)',3.0,null,null,null,null,87),
 ('Embrague y caja','CAMBIO DE SINCRONIZADOS (RETRO|1RA|2DA|3RA|4TA|5TA|6TA)',2.0,null,null,null,null,88),
 ('Embrague y caja','CAMBIO DE SEGUROS Y VINCHAS DE SINCRONIZADOS (RETRO|1RA|2DA|3RA|4TA|5TA|6TA)',2.0,null,null,null,null,89),
 ('Embrague y caja','REPARACION DE TAPA SELECTORA DE CAMBIOS',2.0,null,null,null,null,90),
 ('Embrague y caja','MONTAJE DE BRIDA DE CAMBIOS',1.0,null,null,null,null,91),
 ('Embrague y caja','DESMONTAJE DE BRIDA DE CAMBIOS',1.0,null,null,null,null,92),
 ('Embrague y caja','MONTAJE DE RETENEDORES DELANTEROS DE CAJA DE CAMBIOS',4.0,null,null,null,null,93),
 ('Embrague y caja','DESMONTAJE DE RETENEDORES DELANTEROS DE CAJA DE CAMBIOS',4.0,null,null,null,null,94),
 ('Embrague y caja','MONTAJE DE RETENEDORES POSTERIORES DE CAJA DE CAMBIOS',2.0,null,null,null,null,95),
 ('Embrague y caja','DESMONTAJE DE RETENEDORES POSTERIORES DE CAJA DE CAMBIOS',2.0,null,null,null,null,96),
 ('Embrague y caja','CAMBIO DE KIT DE EMBRAGUE (VOLANTE|DISCO|PLATO|RULIMAN)',4.0,null,null,null,'embrague',97),
 ('Embrague y caja','CAMBIO DE CILINDRO PRINCIPAL DE EMBRAGUE',2.5,null,null,null,null,98),
 ('Embrague y caja','CAMBIO DE CILINDRO AUXILIAR DE EMBRAGUE',1.0,null,null,null,null,99),
 ('Embrague y caja','CAMBIO DE RULIMAN DEL CENTRO (CARDAN)',3.0,null,null,null,null,100),
 ('Embrague y caja','CAMBIO DE CRUCETAS DE CARDAN',2.0,null,null,null,null,101),
 ('Corona / diferencial','MONTAJE DE DIFERENCIAL',4.0,null,null,null,null,102),
 ('Corona / diferencial','DESMONTAJE DE DIFERENCIAL',4.0,null,null,null,null,103),
 ('Corona / diferencial','MONTAJE DE EJES POSTERIORES',1.0,null,null,null,null,104),
 ('Corona / diferencial','DESMONTAJE DE EJES POSTERIORES',1.0,null,null,null,null,105),
 ('Corona / diferencial','MONTAJE DE PLANETARIOS Y SATELITES (LAINAS)',4.0,null,null,null,null,106),
 ('Corona / diferencial','DESMONTAJE DE PLANETARIOS Y SATELITES (LAINAS)',4.0,null,null,null,null,107),
 ('Corona / diferencial','CALIBRACION DE CONO',3.0,null,null,null,null,108),
 ('Corona / diferencial','CALIBRACION DE CORONA',2.0,null,null,null,null,109),
 ('Corona / diferencial','CAMBIO DE RODAMIENTOS DE CORONA',2.0,null,null,null,null,110),
 ('Corona / diferencial','CAMBIO DE RETENEDORES DE CORONA',1.0,null,null,null,null,111),
 ('Corona / diferencial','REPARACION DE CORONA',6.0,null,null,null,null,112),
 ('Suspensión','DESMONTAJE DE PAQUETES POSTERIORES',6.0,null,null,null,null,113),
 ('Suspensión','DESMONTAJE DE PAQUETES DELANTEROS',6.0,null,null,null,null,114),
 ('Suspensión','MONTAJE DE PAQUETES POSTERIORES',6.0,null,null,null,null,115),
 ('Suspensión','MONTAJE DE PAQUETES DELANTEROS',6.0,null,null,null,null,116),
 ('Suspensión','CAMBIO DE PINES Y BOCINES DE FRONTAL',6.0,null,null,null,null,117),
 ('Suspensión','CAMBIO DE CAUCHO DE BARRA ESTABILIZADORA',2.0,null,null,null,null,118),
 ('Suspensión','CAMBIO DE BARRA LARGA',2.0,null,null,null,null,119),
 ('Suspensión','CAMBIO DE BARRA CORTA',2.0,null,null,null,null,120),
 ('Suspensión','CAMBIO DE CAJETIN DE DIRECCION',2.0,null,null,null,null,121),
 ('Frenos','DESMONTAJE DEL SISTEMA DE FRENOS',6.0,null,null,null,null,122),
 ('Frenos','MONTAJE DE SISTEMA DE FRENOS',6.0,null,null,null,null,123),
 ('Frenos','LIMPIEZA Y REPARACION DE SISTEMA DE FRENOS (AIRE | HIDRAULICO)',5.0,null,null,null,null,124),
 ('Frenos','CAMBIO DE MANGUERA DE FRENO (AIRE|HIDRAULICO)',1.0,null,null,null,null,125),
 ('Frenos','CAMBIO DE BOOSTER DE FRENO',4.0,null,null,null,null,126),
 ('Motor','CAMBIO DE MANGUERA DE PRESION HIDRAULICA',2.0,null,null,null,null,127),
 ('Frenos','CAMBIO DE PULMONES DE FRENOS',4.0,null,null,null,null,128),
 ('Frenos','CAMBIO DE RACHET DE FRENOS',1.5,null,null,null,null,129),
 ('Frenos','CAMBIO DE TANQUE DE AIRE',1.0,null,null,null,null,130),
 ('Inyección y combustible','CAMBIO DE TANQUE DE COMBUSTIBLE',2.0,null,null,null,null,131),
 ('Frenos','CAMBIO DE FILTRO SECADOR DE AIRE',0.5,null,null,null,null,132),
 ('Sistema neumático (aire)','REVISION DE SISTEMA NEUMATICO',0.5,null,null,null,null,133),
 ('Sistema neumático (aire)','REPARACION DE SISTEMA NEUMATICO',4.0,null,null,null,null,134),
 ('Suspensión','CAMBIO DE AMORTIGUADOR',1.0,null,null,null,null,135),
 ('Suspensión','CAMBIO DE PERNOS DE RUEDAS',4.0,null,null,null,null,136),
 ('Embrague y caja','CAMBIO DE CABLES DE MARCHAS',2.0,null,null,null,null,137),
 ('Embrague y caja','CAMBIO DE MECANISMO DE CAMBIOS',2.0,null,null,null,null,138),
 ('Motor','CAMBIO DE BANDA DE MOTOR',1.0,null,null,null,null,139)
) as x(capsula, nombre, horas, grupo, codigo, nota, prev, orden)
join sistemas s on s.taller = 'mecanica' and s.nombre = x.capsula
-- No duplica: si el trabajo ya existe en cualquier cápsula de mecánica (por ejemplo, porque 011 lo movió), no se vuelve a crear.
where not exists (select 1 from intervenciones i join sistemas si on si.id = i.sistema_id
                   where si.taller = 'mecanica' and lower(i.nombre) = lower(x.nombre));

notify pgrst, 'reload schema';
