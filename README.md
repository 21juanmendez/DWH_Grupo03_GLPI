# DWH_Grupo03_GLPI

Data Warehouse para analitica de soporte TI / mesa de ayuda, construido a partir de **GLPI** (Gestionnaire Libre de Parc Informatique). Proyecto academico — Universidad de El Salvador, curso de especializacion en Ingenieria de Datos, Grupo 03.

**Integrantes:** José Oved Chávez Vásquez, Juan Ernesto Méndez Nerio, William Alexander Ventura González.

## Contenido

- [Fases del proyecto](#fases-del-proyecto)
- [Fuentes de datos — IMPORTANTE](#fuentes-de-datos--importante)
- [Requisitos previos](#requisitos-previos)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Estado actual](#estado-actual)
- [Reglas de diseño del modelo dimensional](#reglas-de-diseño-del-modelo-dimensional)
- [Plan de implementación del ETL](#plan-de-implementación-del-etl)
- [Conexiones SSIS: proyecto compartido y parámetros](#conexiones-ssis-proyecto-compartido-y-parámetros)
- [Flujo de trabajo en equipo](#flujo-de-trabajo-en-equipo)

## Fases del proyecto

- **Fase 1 (entregada 2026-06-11):** diseño del modelo dimensional en papel — diccionario de datos, data profiling, modelo estrella. Ver `Etapa1_Grupo03_GLPI.pdf` y `Mapeo_De_Tablas_Grupo03_GLPII.xlsx` (documentos de referencia, no estan en este repo).
- **Fase 2 (en curso):** construcción física del Data Warehouse y del proceso ETL en SSIS, sobre el modelo diseñado en Fase 1.

## Fuente de datos

GLPI 11 desplegado en AWS EC2: `glpi-proyecto03.duckdns.org` / `32.196.220.213:3306`, base de datos `glpidb`, usuario `glpiuser`. Esta es la conexión que se usa en SSIS para el ETL.

## Requisitos previos

- **SQL Server** (instancia local, Windows Auth) + **SSMS** para administrar el DWH.
- **Visual Studio Community** + extensión **SSDT** (SQL Server Data Tools) con el proyecto "Integration Services Project" habilitado, para construir los paquetes ETL (`DWH_Grupo03_GLPI.dtproj`).
- Acceso a la base GLPI en AWS (credenciales las tiene cada integrante por separado, no están en este repo).

## Estructura del repositorio

```
sql/
  DWH_Grupo03_GLPI.sql       -- Script DDL: crea la BD, las 12 dimensiones, el bridge y el fact
  SP_DimCategoria.sql        -- Stored procedure sp_DimCategoria_Update (SCD1), usado por el OLE DB Command del paquete diferencial
  Llenar_DimFecha.sql        -- Script T-SQL para poblar DimFecha con el calendario (2020-2030)
DWH_Grupo03_GLPI.dtproj      -- Proyecto SSIS (paquetes ETL)
Project.params               -- Parámetros de proyecto SSIS (servidor/usuario/contraseña de GLPI y del DWH local)
GLPI_MySQL.conmgr             -- Conexión de proyecto (ADO.NET) hacia MySQL/GLPI
DWH_Local.conmgr              -- Conexión de proyecto (OLE DB) hacia el DWH en SQL Server local
DimUsuario_cargaInicial.dtsx
DimUbicacion_cargaInicial.dtsx
DimSLA_cargaInicial.dtsx
DimCategoria_cargaInicial.dtsx
DimCategoria_cargaDiferencial.dtsx
```

## Estado actual

- ✅ **Script DDL** (`sql/DWH_Grupo03_GLPI.sql`): crea la base `DWH_Grupo03_GLPI` en SQL Server, con las 12 dimensiones, la tabla puente `BridgeTicketTecnico` y la tabla de hechos `FactTickets` (snapshot acumulativo). Incluye las filas bolsón y los catálogos fijos (`DimTipo`, `DimEstado`) ya cargados. Verificado columna por columna contra el Excel de mapeo y contra la base GLPI real, y ejecutado con éxito en SQL Server local.
- ✅ **Paquetes SSIS construidos y probados**: `DimUsuario_cargaInicial`, `DimUbicacion_cargaInicial`, `DimSLA_cargaInicial`, `DimCategoria_cargaInicial`, `DimCategoria_cargaDiferencial` (esta última con el patrón SCD1 completo: Lookup + `sp_DimCategoria_Update`).
- ✅ **Conexiones de proyecto compartidas y parametrizadas** (ver sección dedicada abajo) — ya no hay contraseñas ni servidores hardcodeados por paquete.
- ⏳ Faltan por construir: `DimCanal`, `DimTipoSolucion`, `DimEntidad`, `DimGrupo`, `BridgeTicketTecnico`, `FactTickets`, y el paquete maestro (ver plan abajo).

## Reglas de diseño del modelo dimensional

Estas decisiones ya fueron verificadas contra el Excel de mapeo y contra datos reales de GLPI — **no cambiarlas sin volver a revisar esa evidencia**, para no deshacer correcciones ya validadas:

- **Todas las columnas de las dimensiones son `NOT NULL`**, sin excepción. Cualquier valor vacío del origen se sustituye por un default (ya definidos en el Excel) o por una fila bolsón.
- **`DimUsuario.FechaFin` usa `9999-12-31`** para la versión vigente (SCD2), nunca `NULL` — confirmado en el Excel (`NULL?=N`, `Default Value=9999-12-31`).
- **Solo `DimFecha` tiene llave subrogada no autonumérica** (guarda la fecha en formato ISO `AAAAMMDD`). Todas las demás usan `IDENTITY`.
- **`DimTipo` y `DimEstado` NO tienen columna de llave de negocio (`*_origen`)**. Verificado con `SHOW TABLES LIKE '%type%'/'%status%'` en la base real: esos valores no existen como tabla en GLPI, son enums fijos definidos en el código PHP de la aplicación. La llave subrogada representa directamente el código de GLPI.
- **`DimEstado.EsEstadoFinal = 'Si'` para status 5 (Resuelto) Y 6 (Cerrado)**, no solo Cerrado.
- **`DimPrioridad` se crea vacía a propósito.** No es un catálogo fijo, es una *junk dimension* real (combinación urgencia × impacto × prioridad). Se llena dinámicamente durante la carga de `FactTickets`, según las combinaciones que realmente aparezcan en los tickets (verificado con datos reales que la relación NO es 1 a 1 simple).
- **Filas bolsón (`-1`, y `-2` en `DimTipoSolucion`)** ya precargadas en 7 dimensiones + el bridge, para los casos donde GLPI usa `0` en vez de `NULL` para indicar "sin valor".
- **`BridgeTicketTecnico` no tiene Foreign Key física desde `FactTickets.ConjuntoTecnicosKey`** (no es posible: esa columna no es única por sí sola en el bridge). Por eso el **orden de carga en el ETL es crítico**: `BridgeTicketTecnico` debe estar completamente cargado antes de correr el paquete de `FactTickets`, o pueden quedar referencias huérfanas sin que la base de datos lo detecte.
- **Al insertar la fila bolsón manualmente con `IDENTITY_INSERT ON`, hay que hacer `DBCC CHECKIDENT RESEED` de nuevo después.** SQL Server actualiza el contador del `IDENTITY` al valor que insertaste explícitamente (ej. `-1`), así que la siguiente fila real insertada automáticamente por el Data Flow recibiría `0` en vez de `1` si no se corrige. Esto causó un bug real (duplicados en `DimCategoria` porque el filtro `WHERE CategoriaKey > 0` del Lookup excluía silenciosamente la fila con clave `0`). El patrón correcto en la tarea "Limpieza de tabla" de cualquier dimensión que precargue su bolsón así:
  ```sql
  DELETE FROM DimX;
  DBCC CHECKIDENT('DimX', RESEED, 0);

  SET IDENTITY_INSERT DimX ON;
  INSERT INTO DimX (...) VALUES (-1, ...);  -- fila bolsón
  SET IDENTITY_INSERT DimX OFF;

  DBCC CHECKIDENT('DimX', RESEED, 0);  -- <- este segundo RESEED es el que faltaba
  ```
  Ya corregido en `DimCategoria_cargaInicial` y `DimUbicacion_cargaInicial`. Si algún paquete nuevo sigue este mismo patrón (bolsón insertado a mano dentro del mismo Execute SQL Task de limpieza), no olvidar el segundo `RESEED`.

## Plan de implementación del ETL

El orden de construcción no es arbitrario: cada paso depende de que el anterior esté listo.

### 1. `DimFecha`
No depende de nada — es un script que genera fechas calculadas (día, mes, año, trimestre...), no se conecta a GLPI. Se hace primero porque **4 columnas de `FactTickets`** apuntan a esta dimensión (fecha de creación, toma de cargo, solución y cierre).

### 2. Conexión SSIS → MySQL (AWS)
Paso de infraestructura, no de datos: sin esta conexión, SSIS no puede leer nada de GLPI. Bloquea todo lo que sigue (excepto `DimFecha`, que ya no la necesita).

### 3. Dimensiones de catálogo simple: `DimCanal`, `DimTipoSolucion`
Las más sencillas entre las que sí requieren ETL real: una sola tabla de origen (`glpi_requesttypes`, `glpi_solutiontypes`), sin jerarquía, sin relación con otras dimensiones. Sirven para probar el patrón básico del ETL antes de pasar a algo más complejo.

### 4. Dimensiones jerárquicas: `DimCategoria`, `DimUbicacion`, `DimEntidad`, `DimGrupo`
Tienen jerarquía (categoría padre/hija, ubicación anidada), pero GLPI ya la entrega "aplanada" en el campo `completename`, así que no hay que armarla nosotros. No dependen de ninguna otra dimensión — se pueden hacer en paralelo con el paso 3.

### 5. `DimSLA`
Igual de independiente que el grupo anterior, se puede intercalar en cualquier momento después del paso 2.

### 6. `DimUsuario`
La más compleja: es la única con **SCD2** real (si un usuario cambia de perfil o puesto, se guarda la versión vieja Y la nueva, no se sobrescribe). No depende de que otra dimensión esté cargada — se deja para el final de este grupo solo porque es la que más tiempo toma.

### 7. `BridgeTicketTecnico`
**Primera dependencia dura.** El bridge tiene una Foreign Key real hacia `DimUsuario.UsuarioKey`, así que no se puede construir antes de que el paso 6 esté completo.

### 8. `FactTickets`
El paquete más grande y el último: hace lookup contra las 12 dimensiones a la vez. Depende de que **todas** las dimensiones (1, 3, 4, 5, 6) y el bridge (7) ya estén cargados. Aquí también se llena `DimPrioridad` sobre la marcha.

### 9. Paquete maestro
Orquesta todos los anteriores, en este mismo orden, automáticamente.

---

**Dependencias duras (único orden obligatorio):**
`DimUsuario` → `BridgeTicketTecnico` → `FactTickets`, y **todas** las dimensiones → `FactTickets`.

Todo lo demás (pasos 3, 4, 5, y `DimUsuario` en el 6) se puede repartir y trabajar **en paralelo** entre el equipo, siempre que el paso 2 (la conexión) ya esté lista.

## Conexiones SSIS: proyecto compartido y parámetros

### El problema que resuelve esto

Al principio cada paquete `.dtsx` tenía su propia conexión local (servidor, usuario y contraseña escritos directo en el paquete). Eso generaba dos problemas al compartir por Git:

1. **Servidores hardcodeados distintos por persona** (`Data Source=JOSE`, conexión sin servidor en la de William, etc.) — cada quien tenía que editar el paquete a mano después de cada `git pull`.
2. **Contraseñas cifradas con la llave de Windows de quien las guardó** (`ProtectionLevel = EncryptSensitiveWithUserKey`, el valor por defecto de SSIS): cuando otro integrante bajaba el paquete, Visual Studio no podía descifrarlas ("Error al descifrar un nodo XML cifrado"), porque esa encriptación está atada al usuario de Windows de quien la guardó, no a la persona que la abre.

La solución fue centralizar todo en **2 conexiones de proyecto compartidas** + **parámetros de proyecto**, en vez de que cada paquete tenga su propia configuración.

### Cómo quedó armado

- **`ProtectionLevel` del proyecto = `EncryptSensitiveWithPassword`**, con una contraseña compartida por el equipo (no ligada al usuario de Windows de nadie). Cualquiera que sepa la contraseña puede abrir el proyecto en su propia máquina.
- **`Project.params`** (parámetros de proyecto): 6 valores centralizados, uno de ellos (`GlpiPassword`) marcado como *Sensible*, lo que hace que su valor real se guarde cifrado con AES-256 dentro del propio archivo (solo desencriptable con el `ProtectionLevel` de arriba):

  | Parámetro | Contiene |
  |---|---|
  | `GlpiServer` | IP/host del servidor MySQL de GLPI (AWS) |
  | `GlpiUser` | usuario de MySQL |
  | `GlpiPassword` | contraseña de MySQL (**Sensible**) |
  | `GlpiDatabase` | nombre de la base GLPI |
  | `LocalServer` | servidor SQL Server local (`localhost`) |
  | `LocalDatabase` | nombre de la base del DWH local (`DWH_Grupo03_GLPI`) |

- **2 conexiones de proyecto** (`GLPI_MySQL.conmgr` y `DWH_Local.conmgr`), visibles automáticamente en todos los paquetes del proyecto, cuyas propiedades (`ServerName`, `UserName`, `Password`, `InitialCatalog`) están enlazadas por **expresión** a esos parámetros (ej. `@[$Project::GlpiServer]`) en vez de tener un valor fijo escrito.
- Los 5 paquetes ya no tienen conexiones propias: todos sus componentes (orígenes, destinos, Execute SQL Task, Lookup, OLE DB Command) apuntan a `GLPI_MySQL` / `DWH_Local`.

**Decisión del equipo:** `Project.params` **sí se sube a Git** con los valores reales ya llenos (incluyendo la contraseña, cifrada). Se optó por esto en vez de excluirlo porque los valores son los mismos para todo el equipo (mismo servidor GLPI compartido, misma convención de base local) — no hay nada "personal" que cada quien deba configurar distinto.

### Qué tiene que hacer el equipo al bajar estos cambios (José y William)

1. `git pull origin master`.
2. Abrir el proyecto en Visual Studio. Al abrirlo (o al abrir cualquier paquete), va a pedir la **contraseña del proyecto** para desencriptar los datos sensibles — es la misma contraseña que ya usan para conectarse a GLPI.
3. Nada más que configurar: las conexiones (`GLPI_MySQL`, `DWH_Local`) y los parámetros ya vienen listos en el repositorio. No hace falta crear conexiones nuevas ni escribir contraseñas en ningún paquete.
4. Probar ejecutando cualquiera de los 5 paquetes para confirmar que todo corre bien en su máquina (debería, ya que `LocalServer=localhost` apunta a la instancia local de cada quien).

### Cómo crear un paquete `.dtsx` nuevo de aquí en adelante

1. Agregar el paquete (clic derecho en "Paquetes SSIS" → Agregar → Nuevo elemento SSIS).
2. **No crear conexiones locales nuevas.** En cada Origen/Destino/Execute SQL Task, seleccionar la conexión de proyecto que corresponda: `GLPI_MySQL` para leer de GLPI, `DWH_Local` para escribir en el DWH.
3. **Sincronizar el `ProtectionLevel` del paquete nuevo**: seleccionarlo en el Explorador de soluciones (sin abrirlo) → ventana de Propiedades (F4) → `ProtectionLevel` → `EncryptSensitiveWithPassword` → escribir la contraseña compartida. Un paquete nuevo nace con un `ProtectionLevel` que normalmente no coincide con el del proyecto, y si no se sincroniza, Visual Studio marca "Error al comprobar la coherencia del proyecto" al compilar/ejecutar.
4. Guardar, probar la ejecución, y hacer commit normalmente.

## Flujo de trabajo en equipo

- Cada quien trabaja en su propia rama (`juan`, `jose`, `william`).
- Antes de empezar algo nuevo: `git pull origin master` para traer lo último.
- Cuando una parte está lista y probada: push directo a `master` (sin Pull Request formal) y avisar al grupo para que hagan `pull`.
- Para minimizar choques, repartirse por partes distintas del proyecto cuando se pueda (ej. cada quien un grupo de dimensiones distinto en los pasos 3-6).
