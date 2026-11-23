-- =====================================================================
-- 900 · DATOS DE EJEMPLO (solo para probar). No ejecutar en producción
-- si ya se cargaron los datos reales.
-- =====================================================================

insert into conductores (cedula, nombres, apellidos, telefono, tipo_licencia, licencia_vence) values
 ('0912345678','Luis Alberto','Pérez Mora','0991234567','E','2027-05-10'),
 ('0923456789','Carlos Andrés','Mendoza Ruiz','0982345678','E','2026-12-01'),
 ('0934567890','José Miguel','Vera Castro','0973456789','E','2028-02-15'),
 ('1712345678','Fernando','Chávez León','0964567890','D','2027-08-20'),
 ('0945678901','Ángel David','Quiñónez Bravo','0955678901','E','2027-01-30'),
 ('0956789012','Marco Antonio','Salazar Ortiz','0946789012','C','2026-11-15');

insert into vehiculos (codigo, placa, tipo_vehiculo_id, configuracion_ejes_id, marca, modelo, anio,
                       numero_chasis, numero_motor, color, conductor_asignado_id, lectura_actual, lectura_actual_fecha)
select v.codigo, v.placa,
       (select id from tipos_vehiculo where prefijo_codigo = left(v.codigo, 2)),
       (select id from configuraciones_ejes where nombre = v.config),
       v.marca, v.modelo, v.anio, v.chasis, v.motor, v.color,
       (select id from conductores where cedula = v.cedula), v.lectura, now() - interval '8 days'
from (values
 ('DC001','GSA-4512','Cabezal 6x4','Hino','700 SH',2019,'JHHUCS4H5KK01233','E13C-TL41522','Blanco','0912345678',411950.0),
 ('DC003','GSA-4410','Cabezal 6x4','Volvo','FH 460',2020,'YV2RT40A5LB123456','D13K-889012','Blanco','0923456789',298400.0),
 ('DC007','GSA-4590','Cabezal 6x4','Kenworth','T800',2018,'1XKDD49X8JJ456789','ISX15-7781','Rojo','0934567890',503120.0),
 ('DC014','PCQ-3381','Cabezal 4x2','Hino','500 FM',2021,'JHHAFJ4H2MK11223','J08E-55120','Blanco','1712345678',187650.0),
 ('DP151','GSC-1148','Plataforma 6x4','Hino','500 GH',2017,'JHHAFJ4H7HK00112','J08E-33401','Blanco','0945678901',356200.0),
 ('DP162','GSC-1302','Plataforma 4x2','Isuzu','FVR',2019,'JALFVR34K7000123','6HK1-77845','Blanco',null,241880.0),
 ('DP176','GSD-2209','Plataforma 4x2','Hino','500 FC',2022,'JHHAFJ4H9NK22345','J05E-11893','Blanco','0956789012',98420.0),
 ('DP180','GSD-2290','Plataforma 4x2','Isuzu','FTR',2022,'JALFTR34N7000456','4HK1-22987','Blanco',null,91200.0),
 ('DR010','GBC-7720','Recolector 6x4','International','7400',2018,'1HTWGAZT8JJ612345','MAXXF-4410','Verde',null,276300.0),
 ('DR012','GBC-7745','Recolector 4x2','Hino','300 Dutro',2020,'JHHYJL1H0LK33456','N04C-99102','Verde',null,154900.0),
 ('MC002',null,'Montacargas','Toyota','8FGU25',2016,'8FGU25-31234','4Y-554321','Naranja',null,8420.0)
) as v(codigo, placa, config, marca, modelo, anio, chasis, motor, color, cedula, lectura);

insert into tecnicos (codigo, nombres, cedula, telefono, especialidad, cargo, jornada_horas, fecha_ingreso, contacto_emergencia)
values
 ('M01','Carlos Mora','0911111111','0991111111','mecanica','Mecánico A',8,'2019-03-01','María Mora (esposa) - 0987654321'),
 ('M02','Pedro Zambrano','0922222222','0992222222','mecanica','Mecánico B',8,'2021-06-15',null),
 ('M03','Wilson Cedeño','0933333333','0993333333','ambas','Mecánico electricista',8,'2022-01-10',null),
 ('S01','Diego Vera','0944444444','0994444444','soldadura','Soldador A',8,'2018-09-01',null),
 ('S02','Iván Loor','0955555555','0995555555','soldadura','Soldador B',8,'2023-02-20',null);

insert into tarifas_tecnico (tecnico_id, tarifa_hora, vigente_desde)
select id, case when cargo like '%A' then 6.50 else 5.25 end, '2026-01-01' from tecnicos;

-- Centros de costo y clientes
insert into centros_costo (codigo, nombre, costo_por_km) values
 ('OPLOG01','Operación logística (flota propia)', true),
 ('ADM01','Administración', false);
update vehiculos set centro_costo_id = (select id from centros_costo where codigo = 'OPLOG01');
insert into clientes (nombre, ruc, contacto, telefono) values
 ('Reciclajes del Pacífico S.A.','0992222333001','Ana Torres','0987654321'),
 ('Agroexport Litoral Cía. Ltda.','0993333444001','Mario Ruiz','0976543210');
insert into vehiculos (codigo, placa, tipo_vehiculo_id, configuracion_ejes_id, marca, modelo, anio, propiedad, cliente_id, lectura_actual, fecha_ingreso_flota, nombre_hunter)
values ('DP1034','GSE-1034',(select id from tipos_vehiculo where prefijo_codigo='DP'),(select id from configuraciones_ejes where nombre='Plataforma 4x2'),
        'Hino','500 FC',2023,'rentado',(select id from clientes where ruc='0992222333001'),45200,'2023-05-01','DP1034--GSE1034');
update vehiculos set fecha_ingreso_flota = make_date(anio, 3, 1) where fecha_ingreso_flota is null and anio is not null;

-- Proveedores y talleres externos
insert into proveedores (nombre, ruc, tipo, especialidad, contacto, telefono) values
 ('Rectificadora El Pistón','0991111222001','taller_externo','mecanica','Hugo Pazmiño','0991112223'),
 ('Metalmecánica Guayas','0994444555001','taller_externo','soldadura','Rosa Mendoza','0994445556'),
 ('Importadora de Repuestos Andina','0995555666001','repuestos',null,'Ventas','042555666');

insert into repuestos (codigo, descripcion, unidad, categoria_gasto_id)
select r.codigo, r.descripcion, r.unidad, (select id from categorias_gasto where nombre = r.cat)
from (values
 ('FR-VR-110','Válvula relé de freno','UND','Mantenimiento Correctivo'),
 ('MN-038','Manguera neumática 3/8"','M','Mantenimiento Correctivo'),
 ('AC-15W40','Aceite de motor 15W40','GL','Insumos'),
 ('FL-AC-H700','Filtro de aceite Hino 700','UND','Insumos'),
 ('FL-CB-H700','Filtro de combustible Hino 700','UND','Insumos'),
 ('FL-AI-H700','Filtro de aire Hino 700','UND','Insumos'),
 ('KE-H500','Kit de embrague Hino 500','UND','Mantenimiento Correctivo'),
 ('ZP-FR-01','Zapatas de freno eje trasero (juego)','JGO','Mantenimiento Correctivo'),
 ('GR-EP2','Grasa EP2','KG','Insumos'),
 ('EL-SOLD-7018','Electrodo 7018','KG','Insumos')
) as r(codigo, descripcion, unidad, cat);

update vehiculos set nombre_hunter = codigo || '--' || replace(placa, '-', '') where placa is not null and nombre_hunter is null;
