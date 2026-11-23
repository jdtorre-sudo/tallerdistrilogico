set client_min_messages = warning;
-- =====================================================================
-- 011 · Reubica trabajos del tempario en las cápsulas que corresponden
--       (decisión del 23-nov-2026):
--   * cajetín de dirección y barras larga/corta  → Dirección
--   * radiador, bomba de agua e intercooler        → Refrigeración
--   * inyectores, bomba de inyección, cañerías de
--     inyectores y de combustible, consumo         → Inyección y combustible
-- Solo mueve un trabajo si todavía está en su cápsula original (no pisa
-- cambios hechos a mano en Maestros). Las OT ya registradas no cambian.
-- =====================================================================
update intervenciones i set sistema_id = d.id
  from (values
 ('CAMBIO DE BARRA CORTA','Suspensión','Dirección'),
 ('CAMBIO DE BARRA LARGA','Suspensión','Dirección'),
 ('CAMBIO DE CAJETIN DE DIRECCION','Suspensión','Dirección'),
 ('CAMBIO DE CAÑERIAS DE COMBUSTIBLE','Motor','Inyección y combustible'),
 ('CAMBIO DE RETENEDORES DE INYECTORES','Motor','Inyección y combustible'),
 ('DESMONTAJE DE BOMBA DE INYECCION','Motor','Inyección y combustible'),
 ('DESMONTAJE DE CAÑERIA DE INYECTORES','Motor','Inyección y combustible'),
 ('DESMONTAJE DE INYECTORES','Motor','Inyección y combustible'),
 ('DESMONTAJE DE RIEL DE INYECTORES','Motor','Inyección y combustible'),
 ('MONTAJE DE BOMBA DE INYECCION','Motor','Inyección y combustible'),
 ('MONTAJE DE CAÑERIAS DE INYECTORES','Motor','Inyección y combustible'),
 ('MONTAJE DE INYECTORES','Motor','Inyección y combustible'),
 ('MONTAJE DE RIEL DE INYECTORES','Motor','Inyección y combustible'),
 ('REVISION DE CONSUMO DE COMBUSTIBLE','Motor','Inyección y combustible'),
 ('DESMONTAJE DE BOMBA DE AGUA','Motor','Refrigeración'),
 ('DESMONTAJE DE INTERCOOLER','Motor','Refrigeración'),
 ('DESMONTAJE DE RADIADOR','Motor','Refrigeración'),
 ('MONTAJE DE BOMBA DE AGUA','Motor','Refrigeración'),
 ('MONTAJE DE INTERCOOLER','Motor','Refrigeración'),
 ('MONTAJE DE RADIADOR','Motor','Refrigeración')
  ) as x(nombre, desde, hacia)
  join sistemas o on o.taller = 'mecanica' and o.nombre = x.desde
  join sistemas d on d.taller = 'mecanica' and d.nombre = x.hacia
 where i.sistema_id = o.id and i.nombre = x.nombre
   and not exists (select 1 from intervenciones y where y.sistema_id = d.id and lower(y.nombre) = lower(x.nombre));

notify pgrst, 'reload schema';
