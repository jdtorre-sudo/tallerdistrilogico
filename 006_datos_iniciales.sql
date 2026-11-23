-- =====================================================================
-- 006 · Catálogos iniciales (se pueden editar después desde la app)
-- =====================================================================

insert into configuracion (clave, valor, tipo_dato, descripcion) values
 ('nombre_empresa','DISTRILÓGICO','texto','Nombre que aparece en el encabezado de los PDF.'),
 ('ruc_empresa','0990000000001','texto','RUC que aparece en los PDF.'),
 ('direccion_empresa','Guayaquil, Ecuador','texto','Dirección para los PDF.'),
 ('telefono_empresa','','texto','Teléfono para los PDF.'),
 ('diferencia_max_hunter_km','500','numero','Aviso si el km del acta difiere más que esto del km estimado por Hunter.'),
 ('limite_aprobacion_jefe','300','numero','Cotizaciones con subtotal hasta este valor las aprueba el jefe de taller; más, gerencia.'),
 ('tolerancia_factura_pct','10','numero','Alerta si la factura supera lo cotizado en más de este porcentaje.'),
 ('iva_pct','15','numero','Porcentaje de IVA para cotizaciones de terceros.');

insert into areas_taller (nombre, es_externo, requiere_cotizacion, orden) values
 ('Mecánico', false, false, 1),
 ('Soldadura', false, false, 2),
 ('Lavadora', true, false, 3),
 ('Talleres externos', true, true, 4);

insert into tipos_vehiculo (prefijo_codigo, nombre, unidad_medida, diagrama) values
 ('DC','Cabezal','km','cabezal'),
 ('DP','Plataforma','km','plataforma'),
 ('DR','Recolector','km','recolector'),
 ('MC','Montacargas','horas','montacargas');

insert into configuraciones_ejes (nombre, numero_ejes, numero_llantas, descripcion) values
 ('Cabezal 6x4', 3, 10, '1 eje direccional + 2 ejes de tracción con llanta doble'),
 ('Cabezal 4x2', 2, 6, '1 eje direccional + 1 eje de tracción con llanta doble'),
 ('Plataforma 4x2', 2, 6, '1 eje direccional + 1 eje trasero con llanta doble'),
 ('Plataforma 6x4', 3, 10, '1 eje direccional + 2 ejes traseros con llanta doble'),
 ('Recolector 4x2', 2, 6, '1 eje direccional + 1 eje trasero con llanta doble'),
 ('Recolector 6x4', 3, 10, '1 eje direccional + 2 ejes traseros con llanta doble'),
 ('Montacargas', 2, 4, '2 ejes con llanta simple');

insert into categorias_gasto (nombre, grupo, orden) values
 ('Mantenimiento Preventivo','Mantenimiento',1),
 ('Mantenimiento Correctivo','Mantenimiento',2),
 ('Insumos','Insumos',3),
 ('Llantas','Llantas',4),
 ('Otros','Otros',5);

insert into sistemas (nombre, orden, categoria_preventivo_id, categoria_correctivo_id)
select s.nombre, s.orden,
       (select id from categorias_gasto where nombre = s.prev),
       (select id from categorias_gasto where nombre = s.corr)
from (values
 ('Motor',1,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Caja',2,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Corona',3,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Embrague',4,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Frenos',5,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Suspensión',6,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Dirección',7,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Eléctrico',8,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Llantas',9,'Llantas','Llantas'),
 ('Carrocería',10,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Plataforma',11,'Mantenimiento Preventivo','Mantenimiento Correctivo'),
 ('Lavado',12,'Otros','Otros'),
 ('Otros',13,'Otros','Otros')
) as s(nombre, orden, prev, corr);

insert into items_checklist (nombre, grupo, orden) values
 ('Extintor vigente','Seguridad',1),
 ('Triángulos de seguridad','Seguridad',2),
 ('Botiquín','Seguridad',3),
 ('Gata','Seguridad',4),
 ('Llave de ruedas','Seguridad',5),
 ('Llanta(s) de emergencia','Seguridad',6),
 ('Conos','Seguridad',7),
 ('Cintas reflectivas','Seguridad',8),
 ('Matrícula','Documentos',10),
 ('SOAT','Documentos',11),
 ('Permiso de operación','Documentos',12),
 ('Tacógrafo / GPS','Documentos',13),
 ('Tapa de combustible','Exterior',20),
 ('Espejos','Exterior',21),
 ('Plumas (limpiaparabrisas)','Exterior',22),
 ('Luces','Exterior',23),
 ('Cadenas / fajas / chicotes de amarre','Carga',30);

-- Pide a la API de Supabase que relea las tablas y funciones nuevas.
notify pgrst, 'reload schema';
