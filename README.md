# DWH_Grupo03_GLPI

Data Warehouse para analitica de soporte TI / mesa de ayuda, construido a partir de **GLPI** (Gestionnaire Libre de Parc Informatique). Proyecto academico — Universidad de El Salvador, curso de especializacion en Ingenieria de Datos, Grupo 03.

**Integrantes:** José Oved Chávez Vásquez, Juan Ernesto Méndez Nerio, William Alexander Ventura González.

## Contenido

- [Fases del proyecto](#fases-del-proyecto)
- [Fuentes de datos — IMPORTANTE](#fuentes-de-datos--importante)
- [Requisitos previos](#requisitos-previos)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Estado actual](#estado-actual)
- [Modelo de datos implementado](#modelo-de-datos-implementado)
- [Tipos de dimensiones implementadas](#tipos-de-dimensiones-implementadas)
- [Reglas de negocio](#reglas-de-negocio)
- [Componentes de nube utilizados](#componentes-de-nube-utilizados)
- [Reglas de diseño del modelo dimensional](#reglas-de-diseño-del-modelo-dimensional)
- [Plan de implementación del ETL](#plan-de-implementación-del-etl)
- [Conexiones SSIS: proyecto compartido y parámetros](#conexiones-ssis-proyecto-compartido-y-parámetros)
- [Flujo de trabajo en equipo](#flujo-de-trabajo-en-equipo)

## Fases del proyecto

- **Fase 1 (entregada 2026-06-12):** diseño del modelo dimensional en papel — diccionario de datos, data profiling, modelo estrella. Ver [`docs/Etapa 1/Etapa1_ Grupo03_GLPI.pdf`](docs/Etapa%201/Etapa1_%20Grupo03_GLPI.pdf) y [`docs/Etapa 1/Mapeo_De_Tablas_Grupo03_GLPII.xlsx`](docs/Etapa%201/Mapeo_De_Tablas_Grupo03_GLPII.xlsx).
- **Fase 2 (entregada):** construcción física del Data Warehouse y del proceso ETL en SSIS, sobre el modelo diseñado en Fase 1. Ver [`docs/Etapa 2/Etapa2_ Grupo03_GLPI.pdf`](docs/Etapa%202/Etapa2_%20Grupo03_GLPI.pdf) (Informe Final), [`docs/Etapa 2/Paper_IEEE_Grupo03_GLPI.pdf`](docs/Etapa%202/Paper_IEEE_Grupo03_GLPI.pdf) (publicación en formato IEEE) y [`docs/Etapa 2/Archivo_Powerbi.rar`](docs/Etapa%202/Archivo_Powerbi.rar) (contiene el `.pbix` del tablero).

## Fuente de datos

GLPI 11 desplegado en AWS EC2: `glpi-proyecto03.duckdns.org` / `32.196.220.213:3306`, base de datos `glpidb`, usuario `glpiuser`. Esta es la conexión que se usa en SSIS para el ETL.

## Requisitos previos

- **SQL Server** (instancia local, Windows Auth) + **SSMS** para administrar el DWH.
- **Visual Studio Community** + extensión **SSDT** (SQL Server Data Tools) con el proyecto "Integration Services Project" habilitado, para construir los paquetes ETL (`DWH_Grupo03_GLPI.dtproj`).
- Acceso a la base GLPI en AWS (credenciales las tiene cada integrante por separado, no están en este repo).

## Estructura del repositorio

```
docs/
  Etapa 1/
    Etapa1_ Grupo03_GLPI.pdf          -- Informe de Etapa 1 (diseño del modelo dimensional)
    Mapeo_De_Tablas_Grupo03_GLPII.xlsx -- Excel de mapeo origen-destino, columna por columna
  Etapa 2/
    Etapa2_ Grupo03_GLPI.pdf          -- Informe Final de Etapa 2 (ETL, DW y resultados)
    Paper_IEEE_Grupo03_GLPI.pdf       -- Publicación del trabajo de aplicación (formato IEEE)
    Archivo_Powerbi.rar                -- Tablero de Power BI (.pbix comprimido)

sql/
  DWH_Grupo03_GLPI.sql        -- Script DDL: crea la BD, las 12 dimensiones, el bridge y el fact
  Llenar_DimFecha.sql         -- Script T-SQL para poblar DimFecha con el calendario (2020-2030)
  SP_DimCategoria.sql         -- sp_DimCategoria_Update (SCD1)
  SP_DimEntidad.sql           -- sp_DimEntidad_Update (SCD1)
  SP_DimGrupo.sql             -- sp_DimGrupo_Update (SCD1)
  SP_DimUbicacion.sql         -- sp_DimUbicacion_Update (SCD1)
  SP_DimUsuario.sql           -- sp_DimUsuario_SCD2 (SCD1/SCD2 híbrido)

DWH_Grupo03_GLPI.dtproj       -- Proyecto SSIS (paquetes ETL)
Project.params                -- Parámetros de proyecto SSIS (servidor/usuario/contraseña de GLPI y del DWH local)
GLPI_MySQL.conmgr              -- Conexión de proyecto (ADO.NET) hacia MySQL/GLPI
DWH_Local.conmgr               -- Conexión de proyecto (OLE DB) hacia el DWH en SQL Server local

-- Cargas iniciales (trunca y recarga completo)
DimUsuario_cargaInicial.dtsx
DimUbicacion_cargaInicial.dtsx
DimEntidad_cargaInicial.dtsx
DimGrupo_cargaInicial.dtsx
DimCategoria_cargaInicial.dtsx
DimCanal_cargaInicial.dtsx
DimSLA_cargaInicial.dtsx
DimTipoSolucion_cargaInicial.dtsx
DimPrioridad_cargaInicial.dtsx
BridgeTicketTecnico_cargaInicial.dtsx
FactTickets_cargaInicial.dtsx
Orquestador_cargaInicial.dtsx        -- orquesta todas las cargas iniciales en el orden correcto

-- Cargas diferenciales (solo inserta/actualiza lo que cambió, vía Lookup + SP)
DimUsuario_cargaDiferencial.dtsx     -- SCD1/SCD2 híbrido
DimUbicacion_cargaDiferencial.dtsx   -- SCD1
DimEntidad_cargaDiferencial.dtsx     -- SCD1
DimGrupo_cargaDiferencial.dtsx       -- SCD1
DimCategoria_cargaDiferencial.dtsx   -- SCD1
Orquestador_cargaDiferencial.dtsx    -- orquesta todas las cargas diferenciales
```

## Estado actual

- **Script DDL** (`sql/DWH_Grupo03_GLPI.sql`): crea la base `DWH_Grupo03_GLPI` en SQL Server, con las 12 dimensiones, la tabla puente `BridgeTicketTecnico` y la tabla de hechos `FactTickets` (snapshot acumulativo). Incluye las filas bolsón y los catálogos fijos (`DimTipo`, `DimEstado`) ya cargados.
- **Las 12 dimensiones, el bridge y el fact tienen su carga inicial construida y probada**, orquestadas por `Orquestador_cargaInicial.dtsx` en el orden de dependencias correcto (ver [Plan de implementación del ETL](#plan-de-implementación-del-etl)).
- **Carga diferencial construida y probada para 5 dimensiones** (`DimCategoria`, `DimEntidad`, `DimGrupo`, `DimUbicacion`, `DimUsuario`), orquestadas por `Orquestador_cargaDiferencial.dtsx`. Cada una usa el patrón Lookup + stored procedure (`sp_Dim*_Update`) para detectar inserciones/actualizaciones sin duplicar registros.
- **Pendiente como trabajo futuro (documentado como limitación conocida):** `FactTickets` y `BridgeTicketTecnico` solo tienen carga inicial (truncan y recargan todo), no una versión diferencial — requiere un diseño propio (detectar tickets nuevos vs. modificados, y en el bridge manejar que la relación M:N técnico-ticket puede cambiar por completo). `DimCanal`, `DimSLA`, `DimTipoSolucion` y `DimPrioridad` tampoco tienen carga diferencial (catálogos de baja variabilidad, o en el caso de `DimPrioridad` precargada una sola vez con todas sus combinaciones posibles; no se priorizó frente a lo anterior).
- **Conexiones de proyecto compartidas y parametrizadas** (ver sección dedicada abajo) — ya no hay contraseñas ni servidores hardcodeados por paquete.

## Modelo de datos implementado

Esquema en estrella (metodología Kimball), un solo proceso de negocio: **la gestión de tickets de soporte TI**. Grano de `FactTickets`: **una fila por ticket** (`glpi_tickets.id`).

**12 dimensiones + 1 tabla puente + 1 tabla de hechos:**

| Tabla | Rol en el modelo | Origen en GLPI |
|---|---|---|
| `DimFecha` | Role-playing (4 roles) | Calculada (calendario 2020–2030), no viene de GLPI |
| `DimUsuario` | Role-playing (2 roles) + SCD1/SCD2 híbrido | `glpi_users` + `glpi_profiles_users` |
| `DimEntidad` | Jerárquica, SCD1 | `glpi_entities` |
| `DimUbicacion` | Jerárquica, SCD1 | `glpi_locations` |
| `DimCategoria` | Jerárquica, SCD1 | `glpi_itilcategories` |
| `DimGrupo` | Jerárquica, SCD1 | `glpi_groups` |
| `DimTipo` | Catálogo fijo | Enum interno de GLPI (sin tabla de origen) |
| `DimEstado` | Catálogo fijo | Enum interno de GLPI (sin tabla de origen) |
| `DimPrioridad` | Junk dimension | Generada (producto cartesiano completo de los enums de `glpi_tickets.urgency/impact/priority`, no viene de una tabla) |
| `DimCanal` | Catálogo simple | `glpi_requesttypes` |
| `DimSLA` | Role-playing (2 roles) | `glpi_slas` |
| `DimTipoSolucion` | Catálogo simple | `glpi_solutiontypes` |
| `BridgeTicketTecnico` | Tabla puente (M:N con factor de ponderación) | `glpi_tickets_users` (type=2, técnico) |
| `FactTickets` | Hecho — snapshot acumulativo | `glpi_tickets` + `glpi_logs` (reaperturas, reasignaciones) |

**Métricas de `FactTickets`:** naturales en segundos (tiempo de primera respuesta, resolución, cierre, espera, trabajo en tareas), derivadas (cantidad de tickets, cantidad de tickets resueltos, reaperturas, reasignaciones, seguimientos) y banderas 0/1 (cumplimiento de SLA de resolución/respuesta, reabierto, resolución en primer contacto). El detalle de cómo se calcula cada una está en [Reglas de negocio](#reglas-de-negocio).

## Tipos de dimensiones implementadas

- **Role-playing dimensions:** `DimFecha` cumple 4 roles en el fact (`FechaCreacionKey`, `FechaTomaCargoKey`, `FechaSolucionKey`, `FechaCierreKey`); `DimSLA` cumple 2 roles (`SLAResolucionKey` = SLA de resolución/TTR, `SLARespuestaKey` = SLA de respuesta/TTO); `DimUsuario` cumple 2 roles directos en el fact (`SolicitanteKey`, `TecnicoResolutorKey`), además de ser referenciada desde la tabla puente como técnico asignado.
- **Junk dimension:** `DimPrioridad` agrupa Urgencia, Impacto y Prioridad (atributos de baja cardinalidad y correlacionados, enums de GLPI con 5, 5 y 6 valores respectivamente) en una sola tabla. Se carga una sola vez con el **producto cartesiano completo** de las 150 combinaciones posibles (5 × 5 × 6), no solo las que aparecen en los tickets. `FactTickets` solo hace un Lookup de solo lectura contra esta tabla ya poblada, no inserta filas nuevas en tiempo de carga.
- **Dimensión degenerada:** `NumeroTicket` en `FactTickets` (el propio `glpi_tickets.id`, sin tabla de dimensión asociada ni llave subrogada) — identifica el ticket individual sin necesitar una "DimTicket" vacía de atributos propios.
- **Tabla puente con factor de ponderación:** `BridgeTicketTecnico` resuelve la relación muchos-a-muchos entre un ticket y sus técnicos asignados; `FactorPonderacion` (1/N técnicos) permite distribuir correctamente las métricas aditivas del fact sin duplicarlas al hacer join.
- **SCD tipo 1 (sobrescritura):** `DimCategoria`, `DimEntidad`, `DimUbicacion`, `DimGrupo` — un cambio en el origen actualiza la fila existente, sin conservar el valor anterior.
- **SCD híbrido (1 y 2 en la misma tabla):** `DimUsuario` — `Login`, `NombreCompleto`, `Telefono`, `Categoria` y `Activo` se tratan como SCD1 (se sobrescriben); `Perfil`, `Ubicacion` y `Titulo` se tratan como SCD2 (se versiona: fila vieja se cierra con `FechaFin`/`EsVigente='No'`, se inserta fila nueva vigente).
- **Catálogos fijos (sin ETL):** `DimTipo` y `DimEstado` — GLPI no los representa como tabla real en MySQL, son enums definidos en el código PHP de la aplicación; se cargan una sola vez junto con el DDL.
- **Fact table — snapshot acumulativo:** `FactTickets` tiene una sola fila por ticket que se actualiza a medida que el ticket avanza en su ciclo de vida (creación → toma de cargo → solución → cierre), a diferencia de un snapshot periódico o un fact transaccional de un solo evento.
- **Filas bolsón (`-1`, y `-2` en `DimTipoSolucion`):** precargadas en 7 dimensiones + el bridge, para los casos donde el ticket no tiene un valor real asociado (sin técnico, sin SLA, sin categoría, etc.) — ver también la sección de reglas de diseño más abajo.

## Reglas de negocio

Reglas del dominio (gestión de tickets de soporte TI en GLPI) que el ETL traduce en columnas y métricas de `FactTickets`.

**SLA de Resolución y SLA de Respuesta (`CumpleSLAResolucion` / `CumpleSLARespuesta`)**
GLPI maneja dos acuerdos de nivel de servicio por ticket: TTR (*Time To Resolve*, tiempo de resolución) y TTO (*Time To Own*, tiempo de toma de cargo/primera respuesta). Un ticket cumple cada SLA si la fecha real del evento quedó dentro del plazo límite que GLPI calculó para ese acuerdo:
- `CumpleSLAResolucion = 1` si el ticket tiene un SLA de resolución asignado (`slas_id_ttr > 0`) y `solvedate <= time_to_resolve`; si no tiene SLA asignado, queda en `0` y se excluye del indicador filtrando `SLAResolucionKey <> -1` (la fila bolsón "Sin SLA").
- `CumpleSLARespuesta = 1` bajo la misma lógica, comparando `takeintoaccountdate <= time_to_own`.

**Reaperturas (`CantidadReaperturas` / `EsReabierto`)**
GLPI registra en `glpi_logs` cada cambio de estado de un ticket. Una reapertura es un evento donde el ticket pasa de un estado final (Resuelto=5 o Cerrado=6) de vuelta a En curso (2) — típicamente porque el solicitante rechazó la solución propuesta:
- `CantidadReaperturas` = `COUNT(*)` en `glpi_logs` donde `itemtype='Ticket'`, `id_search_option=12`, `old_value IN (5,6)` y `new_value=2`.
- `EsReabierto = 1` si `CantidadReaperturas > 0`.
- KPI Tasa de reapertura = `SUM(EsReabierto) / SUM(CantidadTicketsResueltos)`.

**Reasignaciones (`CantidadReasignaciones`)**
Cuenta los cambios de técnico asignado registrados en la bitácora, descontando la asignación inicial: `GREATEST(COUNT(*) - 1, 0)` sobre `glpi_logs` donde `linked_action=15`, `itemtype_link='User'` e `id_search_option=5`. Es una métrica informativa, independiente de la fórmula de Resolución en Primer Contacto.

**Resolución en Primer Contacto / FCR (`ResolucionPrimerContacto`)**
`ResolucionPrimerContacto = 1` si el ticket está resuelto o cerrado (`status IN (5,6)`), no tuvo ninguna reapertura (`CantidadReaperturas = 0`) y tiene **como máximo un seguimiento** registrado en `glpi_itilfollowups` (`CantidadSeguimientos <= 1`). KPI FCR % = `SUM(ResolucionPrimerContacto) / SUM(CantidadTicketsResueltos)`.

**Factor de ponderación del bridge (`BridgeTicketTecnico.FactorPonderacion`)**
Cuando un ticket tiene N técnicos asignados simultáneamente (`glpi_tickets_users.type=2`), cada fila del bridge para ese ticket recibe `FactorPonderacion = ROUND(1.0 / N, 4)`, calculado con `1.0 / COUNT(*) OVER (PARTITION BY tu.tickets_id)`. Esto permite que KPIs aditivos por técnico (ej. "tickets por técnico" = `SUM(CantidadTickets × FactorPonderacion)` agrupado por técnico) no dupliquen el conteo de un ticket con varios técnicos. `ConjuntoTecnicosKey` es directamente el `id` del ticket, no un identificador compartido entre tickets con el mismo conjunto exacto de técnicos.

**Solicitante, técnico resolutor y grupo de soporte**
- `SolicitanteKey`: se busca en `glpi_tickets_users` (`type=1`) el usuario que coincide con `users_id_recipient`; si no hay coincidencia exacta, se usa el primer `type=1` del ticket.
- `TecnicoResolutorKey`: el autor (`users_id`) de la **última** entrada en `glpi_itilsolutions` para ese ticket; `-1` si el ticket no tiene ninguna solución registrada.
- `GrupoSoporteKey`: el primer grupo (`type=2`) en `glpi_groups_tickets` asociado al ticket; `-1` si no tiene grupo asignado.

**Estado final del ticket**
`DimEstado.EsEstadoFinal = 'Sí'` para los estados 5 (Resuelto) **y** 6 (Cerrado) — ambos cuentan como ticket resuelto para efectos de `CantidadTicketsResueltos` (el denominador de SLA Compliance, Tasa de reapertura y FCR), no solo Cerrado.

**KPIs derivados (no se almacenan, se calculan en la herramienta de BI):**

| KPI | Fórmula |
|---|---|
| SLA Compliance % | `SUM(CumpleSLAResolucion) / SUM(CantidadTicketsResueltos)`, con `SLAResolucionKey <> -1` |
| MTTR (Mean Time to Resolve) | `SUM(TiempoResolucion_seg) / SUM(CantidadTicketsResueltos)` |
| Tasa de reapertura | `SUM(EsReabierto) / SUM(CantidadTicketsResueltos)` |
| First Contact Resolution (FCR) | `SUM(ResolucionPrimerContacto) / SUM(CantidadTicketsResueltos)` |
| Tickets por técnico | `SUM(CantidadTickets × FactorPonderacion)` agrupado por técnico (vía bridge) |
| Categorías más frecuentes | `SUM(CantidadTickets)` por `DimCategoria`, con drill-down jerárquico |

## Componentes de nube utilizados

- **Amazon EC2 (AWS):** aloja el sistema origen completo — GLPI 11 + MySQL 8.0 — en una instancia Linux accesible en `glpi-proyecto03.duckdns.org` / `32.196.220.213:3306`. Es la única pieza de infraestructura en la nube que el ETL necesita en tiempo real (SSIS se conecta a esta instancia vía el Connection Manager `GLPI_MySQL`).
- **Microsoft Power BI Service:** el tablero de visualización se publica en línea (no se usa Power BI Desktop para la demo/entrega), para que el jurado y los usuarios finales puedan consultarlo sin depender de que alguien lo abra localmente. Tablero publicado: https://app.powerbi.com/links/U2_Nl2IqMw?ctid=de44d3c8-30dc-416f-b26c-4e533c37353f&pbi_source=linkShare
- El Data Warehouse en sí (SQL Server + SSISDB) se documenta en el Informe Final como desplegable en una instancia EC2 con SQL Server Standard (*License Included*) para un escenario de producción — en este repositorio, para desarrollo y pruebas, corre en una instancia local de SQL Server.

## Reglas de diseño del modelo dimensional

Decisiones de diseño que no deben cambiarse sin coordinar con el equipo, para no deshacer correcciones ya aplicadas:

- **Todas las columnas de las dimensiones son `NOT NULL`**, sin excepción. Cualquier valor vacío del origen se sustituye por un default o por una fila bolsón.
- **`DimUsuario.FechaFin` usa `9999-12-31`** para la versión vigente (SCD2), nunca `NULL`.
- **Solo `DimFecha` tiene llave subrogada no autonumérica** (guarda la fecha en formato ISO `AAAAMMDD`). Todas las demás usan `IDENTITY`.
- **`DimTipo` y `DimEstado` NO tienen columna de llave de negocio (`*_origen`)**. Esos valores no existen como tabla en GLPI, son enums fijos definidos en el código PHP de la aplicación. La llave subrogada representa directamente el código de GLPI.
- **`DimEstado.EsEstadoFinal = 'Si'` para status 5 (Resuelto) Y 6 (Cerrado)**, no solo Cerrado.
- **`DimPrioridad` es una *junk dimension* real (combinación urgencia × impacto × prioridad), no un catálogo fijo de enums simples.** Se carga una sola vez, en su propio paquete (`DimPrioridad_cargaInicial.dtsx`), con el producto cartesiano completo de las 150 combinaciones posibles (5 urgencias × 5 impactos × 6 prioridades). `FactTickets` únicamente hace un Lookup de lectura contra esta tabla ya poblada (ver [Reglas de negocio](#reglas-de-negocio)).
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

**Ya completado en su totalidad** — se deja esta sección como referencia del orden de dependencias real que se siguió para construir los paquetes, útil para entender por qué el ETL está dividido así y en qué orden debe ejecutarse (es el mismo orden que automatiza `Orquestador_cargaInicial.dtsx`).

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
El paquete más grande y el último: hace lookup contra las 12 dimensiones a la vez (incluyendo `DimPrioridad`, ya precargada con sus 150 combinaciones en su propio paquete). Depende de que **todas** las dimensiones (1, 3, 4, 5, 6) y el bridge (7) ya estén cargados.

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
