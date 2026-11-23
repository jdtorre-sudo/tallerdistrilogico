# Taller Distrilógico · Sistema de Gestión del Taller

Sistema web del taller de la flota Distrilógico (mecánica y soldadura). Funciona en Chrome en PC, tablet y celular, y se instala como app. La especificación completa está en [`referencias/especificacion_v1.md`](referencias/especificacion_v1.md) y el diseño copia las maquetas de [`referencias/`](referencias/).

**Fase 1: login, roles y permisos + Maestros**
- **Cuatro roles** con permisos aplicados en la base de datos: Maestro, Supervisor (asesor de servicios / jefe de patio), Bodega y Técnico.
- **Permisos extra** que se suman a una persona: bodega, aprobar ajustes, gestión de personal, ver costos y editar catálogos.
- **Maestros:** usuarios, técnicos (con tarifas aparte, solo para quien ve costos), choferes, vehículos (propios o rentados a clientes, centro de costo, edad, estados con fechas de parada, nombre en Hunter), clientes, centros de costo, catálogo de trabajos de soldadura y de mecánica en cápsulas, complejidad, intervalos preventivos del kardex, proveedores, listas (las del taller y las del kardex), checklist de recepción, parámetros y la clave de aprobación de ajustes.
- **Perfil del técnico:** ve sus datos y edita solo su teléfono y su contacto de emergencia.

**Fase 2 (esta versión): OT por segmentos + ambientes Mecánica y Soldadura + observaciones de técnicos**
- **Órdenes de trabajo:** lista con búsqueda y la OT completa por segmentos plegables, cada uno con su estado:
  1. vehículo y recepción (chofer, km u horómetro, combustible, checklist, daños y fotos);
  2. solicitud del chofer (cada línea: atendida, no realizada o descartada);
  3. hallazgos (se aprueban o descartan; indicador de % de hallazgos);
  4. trabajos de mecánica y 5. trabajos de soldadura (estado, origen, causa, material, fotos antes/después, observación del supervisor);
  8. observaciones de técnicos (solo los asignados; no se editan ni se borran).
  Los segmentos 6 (repuestos) y 7 (terceros) llegan en las fases 3 y 4.
- **Ambientes Soldadura y Mecánica:** el flujo de la maqueta del coordinador. Cápsulas → elemento → intervención con horas → cantidad, complejidad, técnicos con **reparto de horas** (partes iguales o el que diga el supervisor), origen y causa; "Inspeccionado OK", novedades (imprevistos con aprobación y trabajos no realizados) y tabla resumen.
- **Trabajos asignados** para el técnico (sin botón "Completar": lo escribe en su observación y el supervisor marca el trabajo terminado).
- **Fotos** en Cloudflare R2 (plan gratis de 10 GB).
- Los demás módulos aparecen en el menú con la marca "Fase N" y una explicación de lo que traerán.
- Exportación completa, respaldo semanal a Google Drive y bitácora de auditoría.

Todo usa planes **gratuitos permanentes**: Supabase, Cloudflare Pages, GitHub y Google Drive. No se pide tarjeta en ninguno.

> **¿Ya tenía instalada la versión anterior (actas y OT)?** Vea la sección [Actualizar una base que ya está en uso](#actualizar-una-base-que-ya-está-en-uso). No hay que reinstalar nada ni se pierden datos.

---

## Índice

1. [Qué hay en esta carpeta](#1-qué-hay-en-esta-carpeta)
2. [Instalación paso a paso (una sola vez)](#2-instalación-paso-a-paso-una-sola-vez)
3. [Probar la Fase 1](#3-probar-la-fase-1) · [Fase 2](#3b-probar-la-fase-2)
4. [Uso diario](#4-uso-diario)
5. [Respaldos y cómo restaurar](#5-respaldos-y-cómo-restaurar)
6. [Migrar a otro servidor o sistema](#6-migrar-a-otro-servidor-o-sistema)
7. [Pasar todo a otra persona o cuenta](#7-pasar-todo-a-otra-persona-o-cuenta)
8. [Límites del plan gratis](#8-límites-del-plan-gratis)
9. [Solución de problemas](#9-solución-de-problemas)
10. [Notas técnicas](#10-notas-técnicas-para-quien-mantenga-el-sistema)

---

## 1. Qué hay en esta carpeta

| Carpeta / archivo | Para qué sirve |
|---|---|
| `base_de_datos/INSTALAR_TODO.sql` | Crea toda la base de datos. Se pega una sola vez en Supabase. |
| `base_de_datos/900_datos_ejemplo.sql` | Vehículos, conductores, técnicos y repuestos **de ejemplo** (DC001, DP176…). Opcional. |
| `base_de_datos/001…006_*.sql` | Las mismas instrucciones de `INSTALAR_TODO.sql`, separadas por tema. |
| `src/` | El código de la aplicación (pantallas). |
| `functions/api/` | Funciones pequeñas que corren en Cloudflare: crear usuarios, pedir un respaldo y guardar/mostrar fotos (R2). |
| `.github/workflows/` | Tareas automáticas: mantener activa la base cada día y respaldar cada domingo. |
| `herramientas/google_drive_respaldo.gs` | Script que recibe los respaldos en su Google Drive. |
| `docs/DICCIONARIO_DATOS.md` | Qué significa cada tabla y cada campo. |
| `docs/diseno.html` | Diseño de la versión anterior (solo como historia). |
| `referencias/` | Especificación vigente y las 3 maquetas que definen cómo se ve y se usa el sistema. |
| `pruebas/` | Pruebas automáticas que se usaron para verificar el sistema. |
| `public/logo.png` | Logo que sale en los PDF. **Reemplácelo por el logo real** con el mismo nombre. |

---

## 2. Instalación paso a paso (una sola vez)

Tiempo aproximado: **1 a 2 horas**. Use una computadora con Chrome. Todas las cuentas se crean con su Gmail (**juandiegotorresotomayor@gmail.com**).

> **Consejo:** abra un documento de notas (Bloc de notas o Google Keep) y vaya copiando ahí cada clave o dirección que se indica con 📋. Las va a necesitar en los pasos siguientes. **No comparta esas notas con nadie.**

### Paso 1 · GitHub (donde se guarda el código)

1. Entre a **https://github.com/signup**.
2. Cree la cuenta con su Gmail. Le enviarán un código al correo para confirmar.
3. Ya dentro, arriba a la derecha toque **+** y luego **New repository**.
4. Complete:
   - **Repository name:** `taller-distrilogico`
   - Marque **Private** (privado).
   - No marque ninguna otra casilla (ni README ni .gitignore).
5. Toque **Create repository**.
6. 📋 Anote su usuario de GitHub y el nombre del repositorio, por ejemplo `juandiegotorres/taller-distrilogico`.
7. **Avíseme ese nombre en el chat** y yo subo el código. Si prefiere subirlo usted:
   - Descomprima el ZIP del proyecto.
   - En la página del repositorio toque **uploading an existing file**.
   - Arrastre **todo el contenido** de la carpeta (no la carpeta misma).
   - Toque **Commit changes**.

### Paso 2 · Supabase (la base de datos y los usuarios)

**2.1 Crear el proyecto**
1. Entre a **https://supabase.com** → **Start your project** → **Continue with GitHub**. Así usa la cuenta del paso 1.
2. Toque **New project** y complete:
   - **Name:** `taller-distrilogico`
   - **Database Password:** toque **Generate a password**. 📋 **Cópiela y guárdela**: es la clave maestra de la base.
   - **Region:** *East US (North Virginia)*. Es la más rápida desde Ecuador.
   - **Plan:** Free.
3. Toque **Create new project** y espere 1 a 2 minutos.

**2.2 Crear las tablas**
1. En el menú de la izquierda abra **SQL Editor** y luego **New query**.
2. Abra el archivo `base_de_datos/INSTALAR_TODO.sql`. En GitHub se abre el archivo y se toca el botón **Raw**.
3. Seleccione todo (Ctrl+A), cópielo (Ctrl+C) y péguelo en el editor de Supabase (Ctrl+V).
4. Toque **Run**. Debe decir **Success. No rows returned**.
5. **Solo si quiere datos de ejemplo:** abra otra **New query**, pegue `base_de_datos/900_datos_ejemplo.sql` y toque **Run**.

**2.3 Cerrar el registro libre**
Así nadie de afuera puede crearse una cuenta.
1. Vaya a **Authentication** → **Sign In / Providers**. En algunas versiones está en **Authentication → Settings**.
2. **Desactive** la opción **Allow new users to sign up**.
3. En **Email**, desactive **Confirm email**.
4. Guarde.

> Aunque alguien lograra registrarse, su usuario nace **inactivo** y sin permisos. Solo el maestro puede activarlo.

**2.4 Crear su usuario de maestro (administrador)**
1. Vaya a **Authentication** → **Users** → **Add user** → **Create new user**.
2. Complete:
   - **Email:** `admin@taller.local`. Para ingresar a la app solo escribirá `admin`.
   - **Password:** una contraseña segura. 📋 Anótela.
   - Marque **Auto Confirm User**.
3. Toque **Create user**.
4. Vuelva a **SQL Editor** → **New query**, pegue lo siguiente y toque **Run**:
   ```sql
   update usuarios set rol = 'maestro', activo = true, nombre_completo = 'Juan Diego Torres'
   where correo = 'admin@taller.local';
   ```

**2.5 Copiar las claves de conexión**
1. Vaya a **Project Settings** (el engranaje) → **API Keys** (o **Data API**).
2. 📋 Anote estos tres datos:
   - **Project URL**, por ejemplo `https://abcdxyz.supabase.co`.
   - **Publishable key**. En la pestaña *Legacy* se llama **anon public**.
   - **Secret key**. En la pestaña *Legacy* se llama **service_role**. ⚠️ Esta es secreta: nunca la ponga en el código ni la envíe por WhatsApp.
3. Arriba toque el botón **Connect** → busque **Session pooler** → copie la dirección que empieza con `postgresql://postgres.`.
4. Reemplace `[YOUR-PASSWORD]` por la clave del paso 2.1. 📋 Anótela como **DB_URL**.

### Paso 3 · Cloudflare Pages (publicar la app en internet)

1. Entre a **https://dash.cloudflare.com/sign-up** y cree la cuenta con su Gmail. No pide tarjeta.
2. En el menú vaya a **Workers & Pages** → **Create** → pestaña **Pages** → **Connect to Git** (o **Import an existing Git repository**).
3. Autorice a GitHub y elija el repositorio `taller-distrilogico`.
4. En **Build settings** ponga:
   - **Framework preset:** `React (Vite)`. Si no aparece, elija `None`.
   - **Build command:** `npm run build`
   - **Build output directory:** `dist`
5. Abra **Environment variables (advanced)** y agregue:

   | Nombre | Valor |
   |---|---|
   | `VITE_SUPABASE_URL` | la Project URL del paso 2.5 |
   | `VITE_SUPABASE_ANON_KEY` | la Publishable/anon key del paso 2.5 |
   | `SUPABASE_URL` | la misma Project URL |
   | `SUPABASE_SERVICE_ROLE_KEY` | la Secret/service_role key. Toque **Encrypt** para ocultarla. |
   | `NODE_VERSION` | `22` |

6. Toque **Save and Deploy** y espere unos 2 minutos.
7. 📋 La app queda publicada en una dirección como **https://taller-distrilogico.pages.dev**. Ese es el enlace que usará todo el personal.

> Si después cambia alguna variable, vaya a **Deployments** y toque **Retry deployment** para que se aplique.

**3b. Fotos (Cloudflare R2, gratis hasta 10 GB)**
1. En Cloudflare, menú **R2 Object Storage** → **Create bucket**. Nombre: `taller-fotos`. Ubicación automática. **Create bucket**. (Si le pide activar R2, el plan gratis no cobra mientras no pase de 10 GB.)
2. Vaya a **Workers & Pages** → su proyecto → **Settings** → **Bindings** → **Add** → **R2 bucket**.
   - **Variable name:** `FOTOS`
   - **R2 bucket:** `taller-fotos`
3. Guarde y vuelva a publicar (**Deployments → Retry deployment**).

Las fotos no son públicas: solo las ven usuarios con sesión activa, y solo suben fotos el supervisor y el maestro.

### Paso 4 · Google Drive (recibir los respaldos)

1. Entre a **https://script.google.com** con su Gmail → **Nuevo proyecto**.
2. Borre lo que aparece y pegue el contenido de `herramientas/google_drive_respaldo.gs`.
3. En la línea `const CLAVE = '…'` cambie el texto por una clave larga inventada, por ejemplo `Taller-2026-respaldo-x8Kq3PzL`. 📋 Anótela como **DRIVE_TOKEN**.
4. Guarde con el disquete. Arriba elija la función **probar** y toque **Ejecutar**.
5. Google le pedirá permisos: **Revisar permisos** → su cuenta → **Configuración avanzada** → **Ir a proyecto (no seguro)** → **Permitir**. Es su propio script; es seguro.
6. Toque **Implementar** → **Nueva implementación** → el engranaje → **Aplicación web**:
   - **Ejecutar como:** Yo
   - **Quién tiene acceso:** Cualquier usuario
7. Toque **Implementar**. 📋 Copie la **URL de la aplicación web** (termina en `/exec`) y anótela como **DRIVE_URL**.

En su Drive aparecerá la carpeta **Respaldos Taller Distrilogico**.

### Paso 5 · Tareas automáticas en GitHub

1. En GitHub, abra su repositorio → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.
2. Cree estos 5 secretos, uno por uno:

   | Name | Secret |
   |---|---|
   | `SUPABASE_URL` | Project URL |
   | `SUPABASE_ANON_KEY` | Publishable/anon key |
   | `SUPABASE_DB_URL` | la DB_URL del paso 2.5 |
   | `DRIVE_SCRIPT_URL` | la DRIVE_URL del paso 4 |
   | `DRIVE_SCRIPT_TOKEN` | la DRIVE_TOKEN del paso 4 |

3. Vaya a la pestaña **Actions**. Si aparece un aviso, toque **I understand my workflows, go ahead and enable them**.
4. Pruebe el respaldo: a la izquierda elija **Respaldo semanal** → **Run workflow** → **Run workflow**.
5. En 2 o 3 minutos debe salir un ✅ verde y un archivo `.zip` nuevo en su carpeta de Drive.

### Paso 6 · Botón “Hacer respaldo SQL ahora” (opcional)

Este paso es opcional: el respaldo automático de cada domingo funciona aunque no lo haga.

1. En GitHub: su foto (arriba a la derecha) → **Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens** → **Generate new token**.
2. Complete:
   - **Repository access:** *Only select repositories* → `taller-distrilogico`.
   - **Permissions → Actions:** *Read and write*.
3. Genere el token y 📋 cópielo.
4. En Cloudflare Pages → su proyecto → **Settings** → **Variables and Secrets**, agregue:
   - `GITHUB_TOKEN` = el token (cifrado).
   - `GITHUB_REPO` = `su-usuario/taller-distrilogico`.
5. Vuelva a publicar con **Retry deployment**.

### Paso 7 · Primer ingreso y dar acceso al personal

1. Abra la dirección de la app (paso 3.7) e ingrese con usuario `admin` y su contraseña.
2. Abra **Maestros → Usuarios y roles → + Nuevo usuario**. Para cada persona:
   - **Usuario:** corto, sin espacios. Por ejemplo `cmora` o `jsalazar`.
   - **Nombre completo**.
   - **Rol:** Maestro, Supervisor, Bodega o Técnico.
   - **Contraseña inicial:** mínimo 8 caracteres. Entréguela en persona.
3. En la misma tabla, toque los **permisos extra** que quiera sumarle a cada persona (por ejemplo, "Bodega" al supervisor que cubre el domingo).
4. Abra **Maestros → Técnicos** y en cada técnico elija su **Usuario vinculado**. Así ve su perfil al ingresar.
5. Revise **Vehículos**, **Choferes**, **Clientes** y **Centros de costo**.
6. Abra **Maestros → Parámetros y clave**:
   - defina la **clave de aprobación de ajustes**;
   - escriba nombre, RUC, dirección y teléfono de la empresa para los PDF.
7. **Instalar en tablet o celular:** abra el enlace en Chrome → menú ⋮ → **Instalar aplicación** o **Agregar a la pantalla principal**.

**Roles y permisos:**

| Rol | Puede |
|---|---|
| Maestro | Todo: usuarios y roles, Maestros, parámetros, clave de aprobación, exportación. |
| Supervisor | Asesor de servicios / jefe de patio: OT, hallazgos, trabajos, técnicos, imprevistos, cierre y asistencia (desde la Fase 2). En la Fase 1 ve Maestros solo si tiene el permiso extra "Editar catálogos". |
| Bodega | OT abiertas, repuestos a la OT e Inventarios (desde la Fase 3). |
| Técnico | Su perfil (teléfono y contacto de emergencia). Desde la Fase 2: OT abiertas y su observación en las OT donde está asignado. Nunca ve costos. |

| Permiso extra | Para qué sirve |
|---|---|
| Bodega | Despachar repuestos y usar Inventarios. |
| Aprobar ajustes | Aprobar ajustes del kardex con la clave de aprobación. |
| Gestión de personal | Asistencia, novedades, días libres y vacaciones. |
| Ver costos | Ver tarifas, costos de repuestos, mano de obra y terceros. |
| Editar catálogos | Editar vehículos, choferes, clientes, proveedores, listas y el catálogo de trabajos (sección 7: "editables por Supervisor si se le da permiso"). |

Los conductores (choferes) **no tienen usuario**.

### Actualizar una base que ya está en uso

Si ya tenía instalada la versión anterior (actas y OT), **no ejecute `INSTALAR_TODO.sql`**. Haga esto una sola vez:

1. Antes, descargue un respaldo: en la app anterior, **Exportación → Descargar exportación completa**.
2. En Supabase → **SQL Editor** → **New query**, pegue `base_de_datos/007_unificada_fase1.sql` y toque **Run**.
3. Otra **New query** con `base_de_datos/008_supabase_v2.sql` → **Run**.
4. Otra **New query** con `base_de_datos/009_fase2_ot.sql` → **Run** (OT por segmentos).
   Luego otra con `base_de_datos/010_tempario_mecanica.sql` → **Run** (tempario de mecánica y eléctricos definido con los técnicos).
   Y otra con `base_de_datos/011_tempario_reubicar.sql` → **Run** (pasa dirección, refrigeración e inyección a sus cápsulas).
5. Configure las fotos (paso 3b) y vuelva a publicar la app en Cloudflare (**Deployments → Retry deployment**) si no se publicó sola.

Qué cambia en sus datos (no se borra nada):
- Roles: **administrador → Maestro**, **jefe de taller → Supervisor**, **técnico → Técnico**. Los usuarios **gerencia** y **consulta** pasan a Supervisor pero **quedan inactivos**: actívelos en Maestros → Usuarios si corresponde.
- Vehículos "inactivo" o "baja" pasan a **parado**.
- Los técnicos reciben un código (T01, T02…). Cámbielo en Maestros → Técnicos si usan otro.
- Los sistemas anteriores se convierten en cápsulas de mecánica. Carrocería, Plataforma, Lavado, Otros y Embrague quedan inactivos (los datos que los usan se conservan).
- Las OT del sistema anterior quedan guardadas tal cual (formato "anterior"). Las nuevas usan los segmentos. Las actas de entrega y recepción vuelven en la Fase 4 (acta de entrega de la OT).

## 3. Probar la Fase 1

Requiere los datos de ejemplo (`900_datos_ejemplo.sql`) o sus datos reales. Siga este guion en PC y en celular:

1. **Ingreso y roles**
   - Ingrese con una contraseña equivocada: dice "Usuario o contraseña incorrectos".
   - Ingrese como **maestro**. El menú lateral muestra todos los módulos; los de fases futuras dicen "FASE N".
2. **Catálogo de soldadura** (Maestros → Catálogo soldadura)
   - Debe ver 8 cápsulas: las 6 de la maqueta con sus elementos e intervenciones, y Portallantas y Escalerillas vacías. Tanque de lixiviados dice "Sin complejidad".
   - Toque **Editar** en Compuertas. Toque **+ Intervención**, escriba "Cambiar bisagra completa", 1,8 horas, y guarde.
   - Toque **Catálogo** (botón gris del recuadro azul). En la ventana "Gestión de catálogo extensible", agregue a PORTALLANTAS el elemento "Portallantas trasero" con la intervención "Fabricar portallantas", 4 horas.
   - Toque **Exportar**: se descarga el Excel. Puede editarlo y volver a cargarlo con **Importar Excel** (agrega y actualiza, nunca borra).
3. **Catálogo de mecánica:** 12 cápsulas con el aviso "Sin intervenciones — agregar en Maestros".
4. **Técnicos y tarifas**
   - En Técnicos, cree uno nuevo (código S03).
   - En **Tarifas**, registre su tarifa por hora con la fecha desde la que rige.
5. **Vehículos:** abra DP1034 (rentada a cliente). Al elegir "Rentado a cliente" pide el cliente y el centro de costo queda solo en MNTOPL3RAS.
6. **Intervalos preventivos:** los 8 sistemas del kardex con sus valores (aceite 10.000 km cabezal / 6.000 km plataforma, etc.).
7. **Listas:** revise las del taller y las del kardex (motivo de cambio de llanta, kit de embrague, etc.).
8. **Parámetros y clave:** defina la clave de aprobación. Queda "DEFINIDA" y no se puede ver.
9. **Permisos extra:** en Usuarios, dé "Editar catálogos" al supervisor. Ingrese como supervisor:
   - ve Maestros, pero no Usuarios, Tarifas ni Parámetros;
   - Técnicos es de solo lectura;
   - Choferes sí lo puede editar.
10. **Bodega:** ve Inventarios (Fase 3) y no Maestros, ni escribiendo la dirección.
11. **Técnico (en celular):** entra directo a su **Perfil**. Puede cambiar su teléfono y su contacto de emergencia; los demás campos tienen 🔒. No ve Maestros ni los ambientes.

En el entorno de pruebas los usuarios son `admin` (maestro), `jefe` (supervisor), `bodega` y `tecnico`, todos con la contraseña `prueba123`.

---

## 3b. Probar la Fase 2

Ingrese como **supervisor** (`jefe`) y siga este guion:

1. **Abrir la OT:** Órdenes de trabajo → **Nueva OT**.
   - Tipo **Golpe / siniestro**. Escriba `dp176` y elija el vehículo: aparece su ficha (tipo, marca, centro de costo, propio/rentado, edad).
   - Escriba km 100: no deja seguir porque es menor al último. Corrija a **98500**, combustible **F**, **Marcar todo OK**.
   - Solicitud del chofer: “La compuerta trasera no cierra” (Soldadura) y “Frenos largos” (Mecánica).
   - **Abrir orden de trabajo**: sale la OT con sus segmentos. En el segmento 1 toque **Agregar foto**.
2. **Ambiente Soldadura** (botón rojo de la OT):
   - Cápsula **Compuertas** → **Inspeccionar** → **Bisagras** → **Resoldar** → complejidad **Grave**, cantidad 2, técnicos **S01** y **S02**, causa Golpe → **+ AGREGAR TRABAJO**. Producción: 0,5 × 2 × 1,4 = **1,40 h**, 0,70 h a cada uno.
   - Cápsula **Tanque de lixiviados** (sin complejidad) → Válvulas → Reparación de válvula → marque **Ver todos**, técnicos **S01** y **M01**, **Cambiar reparto** 70/30, origen **Hallazgo** “Válvula con fuga”.
   - En **Cabina** toque ✓ (**Inspeccionado OK**).
   - **NOVEDADES** → Imprevisto → guarde, y apruébelo con ✓.
3. **Ambiente Mecánica:** las cápsulas sin catálogo dicen “Sin intervenciones — agregar en Maestros”.
4. **Ver OT:**
   - Segmento 2: la línea 1 quedó **Atendida**; marque la 2 como **No realizada** con su motivo.
   - Segmento 3: el hallazgo y el % de hallazgos.
   - Segmento 5: cambie el trabajo 1 a **Terminado**, agregue fotos de antes/después y la observación del supervisor.
   - Pruebe pasar la OT a **Entregado / cerrado** con trabajos pendientes: no lo permite.
5. **Técnico (en celular):** ingrese como `tecnico` (M01) → **Trabajos asignados** → **Ver OT y observar** → escriba su observación. Queda con su código, fecha y hora, y no la puede editar. No ve cómo cambiar estados.

---

## 4. Uso diario

- **Todo se configura en Maestros**, sin tocar el programa. Nada se borra: se desactiva (desmarque "Activo" o cambie el estado).
- **Tempario de mecánica:** ya viene cargado desde `referencias/tempario_mecanica_electricos.xlsx` (160 trabajos). Dirección (cajetín y barras), Refrigeración (radiador, bomba de agua, intercooler) e Inyección y combustible (inyectores, bomba de inyección, cañerías) quedaron en sus cápsulas. Los tiempos en días se pasaron a horas-hombre con jornada de 8 h (1 persona 2 días = 16 h). Cada trabajo se puede corregir en Maestros → Catálogo mecánica (nombre, horas, grupo, código, nota, mover de cápsula).
- **Catálogo de trabajos:** cada componente es una cápsula. Las intervenciones son del componente y sirven para todos sus elementos. El tiempo estándar son **horas-hombre totales**: si el trabajo exige dos personas, póngalo ya multiplicado.
- **Vehículos:** al cambiar el estado (activo, parado, venta, trámite) ponga la fecha del cambio. El historial de paradas queda guardado.
- **Bitácora:** Maestros → Exportación y bitácora muestra quién cambió qué y cuándo.
- **Cada unidad que entra:** el asesor abre la OT con la solicitud del chofer. En los ambientes, el supervisor registra lo que se hace en cada cápsula (o marca “Inspeccionado OK”). Lo que se encuentra en la revisión entra como **hallazgo**.
- **Varios técnicos en un trabajo:** el tiempo estándar son horas-hombre totales y se reparte en partes iguales; si no fue así, toque **Cambiar reparto** (ej. 70/30).
- **El técnico no marca terminado:** lo escribe en su observación y el supervisor cambia el estado del trabajo.
- **Cerrar la OT:** sin trabajos pendientes o en proceso y sin líneas del chofer sin resolver. (El control de calidad y el acta de entrega se agregan en la Fase 4.)

---

## 5. Respaldos y cómo restaurar

**Qué respaldos existen:**
1. **Automático, cada domingo:** un ZIP en Google Drive, en la carpeta *Respaldos Taller Distrilogico*. Se guardan los últimos 12. Además queda una copia 30 días en GitHub (Actions → la ejecución → *Artifacts*). Contiene:
   - `base_completa.sql`: el respaldo SQL completo.
   - `usuarios_inicio_sesion.sql`.
   - `csv/` con una tabla por archivo.
   - `diccionario_datos.csv`.
2. **Manual, cuando quiera:** en la app, **Exportación** → **Descargar exportación completa** (CSV, Excel, diccionario e índice de archivos). Con el paso 6 hecho, también el botón **Hacer respaldo SQL ahora**.

### Restaurar en un proyecto nuevo de Supabase

1. Cree un proyecto nuevo (paso 2.1).
2. **No** ejecute `INSTALAR_TODO.sql`.
3. Descomprima el último respaldo.
4. En el **SQL Editor**, pegue y ejecute en este orden:
   1. `usuarios_inicio_sesion.sql` (usuarios y contraseñas). Si da error, cree los usuarios a mano; vea la nota de abajo.
   2. `base_completa.sql` (todas las tablas, reglas y datos).
   3. `base_de_datos/005_supabase.sql` (conexión con el inicio de sesión y la carpeta de firmas).
5. Las **firmas** (imágenes PNG) están en Supabase → **Storage** → `archivos`. Para llevarlas a otro proyecto, descargue la carpeta y súbala igual en el nuevo. El archivo `indice_archivos.csv` dice qué firma corresponde a cada acta.
6. Cambie `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` en Cloudflare y vuelva a publicar.

> **Nota:** si los usuarios se crean a mano, la tabla `usuarios` debe tener el mismo `id` que el usuario de inicio de sesión. Cree cada usuario y luego corrija el id con SQL: `update usuarios set id = '<id nuevo>' where correo = '<correo>';`

### Restaurar en cualquier PostgreSQL (sin Supabase)

```bash
createdb taller
psql -d taller -f pruebas/simular_supabase.sql   # crea los roles authenticated/anon que usan los permisos
psql -d taller -f base_completa.sql
```

---

## 6. Migrar a otro servidor o sistema

El sistema se diseñó para no quedar atado a ningún proveedor:

- **PostgreSQL estándar:**
  - La lógica de negocio está en SQL estándar (archivo `003_funciones.sql`): numeración, estados, cierre de OT, validaciones y bitácora.
  - Todo lo propio de Supabase está aislado en **un solo archivo**: `005_supabase.sql` (inicio de sesión y carpeta de firmas).
- **Identificadores:** todas las tablas usan UUID, más los números legibles AR-, OT- y AE-.
- **Usuario que opera:** la función `usuario_actual()` lee el usuario de la variable `request.jwt.claim.sub`. En otro servidor basta con ejecutar `set request.jwt.claim.sub = '<uuid>'` al abrir cada conexión.
- **Archivos:** las rutas son estándar y predecibles: `año/mes/placa/AE-2026-00001/firma_conductor.png`.
- **Datos para un ERP o software de flotas:** use los CSV de la exportación junto con `DICCIONARIO_DATOS.md`.
- **App:** usa la librería de Supabase solo para leer y escribir tablas, llamar funciones y subir archivos. En otro servidor se reemplaza por PostgREST, que es la misma tecnología de código abierto que usa Supabase, o por una API propia.

---

## 7. Pasar todo a otra persona o cuenta

Las cuentas están a su nombre. Si en el futuro otra persona debe administrar el sistema:

- **GitHub:** repositorio → Settings → *Transfer ownership*. También puede agregarla como colaboradora.
- **Supabase:** Organization → *Team* → invitar como **Owner**. Después usted puede salir.
- **Cloudflare:** *Manage account* → *Members* → invitar como Administrator.
- **Google Drive:** compartir la carpeta *Respaldos Taller Distrilogico*. Para cambiar quién recibe los respaldos, la nueva persona repite el paso 4 y se actualizan los secretos del paso 5.

---

## 8. Límites del plan gratis

| Servicio | Límite gratis | Uso esperado (500 OT/mes) |
|---|---|---|
| Supabase · base de datos | 500 MB | ≈ 5 MB/mes → más de 5 años |
| Supabase · archivos (firmas) | 1 GB | ≈ 20 MB/mes → varios años |
| Cloudflare R2 (fotos) | 10 GB | ≈ 150 MB/mes (fotos de 200 KB) → más de 5 años |
| Supabase · usuarios | 50.000 usuarios activos/mes | 15 |
| Cloudflare Pages | Sin límite de visitas; 500 publicaciones/mes | Pocas |
| GitHub Actions (repositorio privado) | 2.000 min/mes | ≈ 60 min/mes |
| Google Drive | 15 GB (compartidos con Gmail) | ≈ 10–30 MB por respaldo, se guardan 12 |

- **Supabase pausa los proyectos gratis tras 7 días sin uso.** La tarea *Mantener activa la base* lo evita consultando la base cada día. Si alguna vez se pausara, entre a supabase.com y toque **Restore project**.
- Si algún día se superara un límite, se activa el plan de pago de ese servicio y **no hay que cambiar nada** del sistema.

---

## 9. Solución de problemas

| Mensaje o situación | Qué hacer |
|---|---|
| “Falta configurar la conexión con Supabase” | Faltan `VITE_SUPABASE_URL` o `VITE_SUPABASE_ANON_KEY` en Cloudflare. Agréguelas y toque **Retry deployment**. |
| “Su usuario existe pero no tiene ficha activa” | El maestro debe activarlo en **Maestros → Usuarios y roles**. Si es el primer maestro, ejecute el SQL del paso 2.4. |
| Crear usuario dice “El servidor no respondió” | Revise `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` en Cloudflare y vuelva a publicar. |
| “La base de datos no está actualizada” | Ejecute en Supabase el último archivo SQL de la versión que se publicó. |
| Arriba dice “N por enviar” | Hay actas guardadas en ese equipo. Con señal se envían solas. Si una muestra un error en rojo en **Por enviar**, léalo; por ejemplo, el vehículo ya tenía una OT abierta. |
| “El vehículo ya tiene la orden … abierta” | Cierre esa OT (trabajos terminados o no realizados y solicitud del chofer resuelta) o anúlela con motivo. |
| “No se pudo subir la foto” / “Falta conectar el almacenamiento de fotos” | Haga el paso 3b (bucket R2 con el nombre de variable `FOTOS`) y vuelva a publicar. |
| No llega el respaldo a Drive | GitHub → Actions → *Respaldo semanal*: abra la ejecución en rojo y revise que los 5 secretos estén bien escritos. |

---

## 10. Notas técnicas (para quien mantenga el sistema)

- **App:**
  - React 18 + Vite + TypeScript, PWA con `vite-plugin-pwa`.
  - Estilo: Tailwind CSS con la paleta "industrial" de las maquetas (`tailwind.config.js`), letra Inter e íconos Font Awesome instalados en la app (funcionan sin internet).
  - Sin conexión: los catálogos y los borradores se guardan en IndexedDB (`idb-keyval`).
  - Las actas se envían por una cola idempotente (`src/lib/cola.ts`): cada acta tiene `id_local`, así que reenviar no duplica.
  - PDF: `jspdf` + `jspdf-autotable`. Firmas: `signature_pad`. Excel: `xlsx`. ZIP: `jszip`.
- **Base de datos:**
  - Para cambios futuros, agregue archivos nuevos numerados (`007_…sql`) y vuelva a generar `INSTALAR_TODO.sql`.
  - El diccionario se genera solo desde la vista `v_diccionario_datos` (comentarios de cada tabla y columna).
- **Probar en una computadora:**
  ```bash
  npm install
  cp .env.ejemplo .env.local   # complete con los datos de Supabase
  npm run dev                  # abre http://localhost:5173
  ```
- **Pruebas automáticas** (`pruebas/`):
  - `prueba_flujo.sql`: reglas de la base por rol.
  - `prueba_maestros.sql`: permisos de Maestros por rol, tarifas ocultas al técnico, clave de aprobación, unidades rentadas, catálogo y preventivos.
  - `prueba_ot.sql`: OT por segmentos, cálculo de horas y reparto, hallazgos, novedades, observaciones y cierre, por rol.
  - `prueba_fase2.cjs`: abrir OT, foto, cápsulas, reparto 70/30, inspeccionado OK, imprevisto, segmentos y técnico en celular.
  - `prueba_fase1.cjs`: ingreso, menú por rol, catálogo en cápsulas, técnicos, vehículos, clave, permisos extra y perfil del técnico, en Chrome de PC y de celular (deja capturas).
  - Corren contra PostgreSQL local + PostgREST + `servidor_simulado.mjs`, que imita a Supabase.
- **Fases siguientes** (sección 10 de la especificación):
  - Fase 2: OT por segmentos, ambientes Mecánica y Soldadura (cápsulas) y observaciones de técnicos.
  - Fase 3: Inventarios (kardex importado), pantalla de bodega y costos en la OT.
  - Fase 4: terceros con cotizaciones, control de calidad, acta de entrega y cierre de OT.
  - Fase 5: gestión de personal.
  - Fase 6: tableros, reportes, portal del técnico y directorio de contactos.
