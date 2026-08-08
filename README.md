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
  DWH_Grupo03_GLPI.sql   -- Script DDL: crea la BD, las 12 dimensiones, el bridge y el fact
DWH_Grupo03_GLPI.dtproj  -- Proyecto SSIS (paquetes ETL)
Package.dtsx             -- Paquete SSIS (pendiente de renombrar / dividir por dimension)
```

## Estado actual

- ✅ **Script DDL** (`sql/DWH_Grupo03_GLPI.sql`): crea la base `DWH_Grupo03_GLPI` en SQL Server, con las 12 dimensiones, la tabla puente `BridgeTicketTecnico` y la tabla de hechos `FactTickets` (snapshot acumulativo). Incluye las filas bolsón y los catálogos fijos (`DimTipo`, `DimEstado`) ya cargados. Verificado columna por columna contra el Excel de mapeo y contra la base GLPI real, y ejecutado con éxito en SQL Server local.
- ⏳ Paquetes SSIS: aún no construidos (ver plan abajo).

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

## Flujo de trabajo en equipo

- Cada quien trabaja en su propia rama (`juan`, `jose`, `william`).
- Antes de empezar algo nuevo: `git pull origin master` para traer lo último.
- Cuando una parte está lista y probada: push directo a `master` (sin Pull Request formal) y avisar al grupo para que hagan `pull`.
- Para minimizar choques, repartirse por partes distintas del proyecto cuando se pueda (ej. cada quien un grupo de dimensiones distinto en los pasos 3-6).
