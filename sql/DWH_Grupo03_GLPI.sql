/*
Script general para construir nuestro DW para analisis de soporte TI (GLPI)

DimFecha
DimUsuario
DimEntidad
DimUbicacion
DimCategoria
DimGrupo
DimTipo
DimEstado
DimPrioridad
DimCanal
DimSLA
DimTipoSolucion
BridgeTicketTecnico: tabla puente (un ticket puede tener varios tecnicos)
FactTickets: tabla de hechos snapshot acumulativo (una fila por ticket)
*/

--Crear la base de datos DWH_Grupo03_GLPI
IF DB_ID('DWH_Grupo03_GLPI') IS NULL
    CREATE DATABASE DWH_Grupo03_GLPI
GO

--Cambiar a la nueva base de datos
USE DWH_Grupo03_GLPI
GO

--Limpieza por si se re-ejecuta el script
IF OBJECT_ID('dbo.FactTickets', 'U') IS NOT NULL DROP TABLE dbo.FactTickets
IF OBJECT_ID('dbo.BridgeTicketTecnico', 'U') IS NOT NULL DROP TABLE dbo.BridgeTicketTecnico
IF OBJECT_ID('dbo.DimFecha', 'U') IS NOT NULL DROP TABLE dbo.DimFecha
IF OBJECT_ID('dbo.DimUsuario', 'U') IS NOT NULL DROP TABLE dbo.DimUsuario
IF OBJECT_ID('dbo.DimEntidad', 'U') IS NOT NULL DROP TABLE dbo.DimEntidad
IF OBJECT_ID('dbo.DimUbicacion', 'U') IS NOT NULL DROP TABLE dbo.DimUbicacion
IF OBJECT_ID('dbo.DimCategoria', 'U') IS NOT NULL DROP TABLE dbo.DimCategoria
IF OBJECT_ID('dbo.DimGrupo', 'U') IS NOT NULL DROP TABLE dbo.DimGrupo
IF OBJECT_ID('dbo.DimTipo', 'U') IS NOT NULL DROP TABLE dbo.DimTipo
IF OBJECT_ID('dbo.DimEstado', 'U') IS NOT NULL DROP TABLE dbo.DimEstado
IF OBJECT_ID('dbo.DimPrioridad', 'U') IS NOT NULL DROP TABLE dbo.DimPrioridad
IF OBJECT_ID('dbo.DimCanal', 'U') IS NOT NULL DROP TABLE dbo.DimCanal
IF OBJECT_ID('dbo.DimSLA', 'U') IS NOT NULL DROP TABLE dbo.DimSLA
IF OBJECT_ID('dbo.DimTipoSolucion', 'U') IS NOT NULL DROP TABLE dbo.DimTipoSolucion
GO

--Crear las dimensiones

create table DimFecha
(FechaKey int primary key, --Llave surrogada (SK)
--No es autonumerica, guarda las fechas en ISO (AAAAMMDD).
Fecha date not null, --Llave de negocio (BK)
Anio int not null,
Trimestre varchar(2) not null,
Mes int not null,
NombreMes varchar(15) not null,
Dia int not null,
NombreDia varchar(15) not null,
EsFinDeSemana varchar(3) not null,
SemanaAnio int not null)
GO

--Fila bolson: tickets que aun no tienen esa fecha (no resuelto/cerrado)
insert into DimFecha values
(99991231, '9999-12-31', 9999, 'NA', 12, 'Pendiente', 31, 'Pendiente', 'No', 0)
GO

create table DimUsuario
(UsuarioKey int primary key identity(1,1), --Llave surrogada (SK)
UsuarioId_origen int not null, --Llave de negocio (BK)
Login varchar(255) not null,
NombreCompleto varchar(255) not null,
Perfil varchar(255) not null,
Telefono varchar(50) not null,
Ubicacion varchar(255) not null,
Titulo varchar(255) not null,
Categoria varchar(255) not null,
Activo varchar(3) not null,
FechaInicio date not null default getdate(),
FechaFin date not null default '9999-12-31',
EsVigente varchar(3) not null)
GO

--Fila bolson: ticket sin tecnico o sin solicitante asignado
set identity_insert DimUsuario on
insert into DimUsuario (UsuarioKey, UsuarioId_origen, Login, NombreCompleto, Perfil,
Telefono, Ubicacion, Titulo, Categoria, Activo, FechaInicio, FechaFin, EsVigente) values
(-1, -1, 'Sin asignar', 'Sin asignar', 'Sin perfil', 'No disponible', 'Sin ubicacion',
'Sin titulo', 'Sin categoria', 'Si', '1900-01-01', '9999-12-31', 'Si')
set identity_insert DimUsuario off
GO

--entities_id=0 en GLPI es la entidad raiz, es un valor valido, no necesita fila bolson
create table DimEntidad
(EntidadKey int primary key identity(1,1), --Llave surrogada (SK)
EntidadId_origen int not null, --Llave de negocio (BK)
Entidad varchar(255) not null,
EntidadCompleta varchar(255) not null,
Nivel int not null,
Ciudad varchar(255) not null,
Estado varchar(255) not null,
Pais varchar(255) not null)
GO

create table DimUbicacion
(UbicacionKey int primary key identity(1,1), --Llave surrogada (SK)
UbicacionId_origen int not null, --Llave de negocio (BK)
Ubicacion varchar(255) not null,
UbicacionCompleta varchar(255) not null,
Edificio varchar(255) not null,
Sala varchar(255) not null,
Ciudad varchar(255) not null,
Estado varchar(255) not null,
Pais varchar(255) not null)
GO

--Fila bolson: ticket sin ubicacion asignada
set identity_insert DimUbicacion on
insert into DimUbicacion (UbicacionKey, UbicacionId_origen, Ubicacion, UbicacionCompleta,
Edificio, Sala, Ciudad, Estado, Pais) values
(-1, -1, 'Sin ubicacion', 'Sin ubicacion', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A')
set identity_insert DimUbicacion off
GO

create table DimCategoria
(CategoriaKey int primary key identity(1,1), --Llave surrogada (SK)
CategoriaId_origen int not null, --Llave de negocio (BK)
Categoria varchar(255) not null,
CategoriaCompleta varchar(255) not null,
Nivel int not null,
Codigo varchar(255) not null)
GO

--Fila bolson: ticket sin categoria asignada
set identity_insert DimCategoria on
insert into DimCategoria (CategoriaKey, CategoriaId_origen, Categoria, CategoriaCompleta,
Nivel, Codigo) values
(-1, -1, 'Sin categoria', 'Sin categoria', 0, 'N/A')
set identity_insert DimCategoria off
GO

create table DimGrupo
(GrupoKey int primary key identity(1,1), --Llave surrogada (SK)
GrupoId_origen int not null, --Llave de negocio (BK)
Grupo varchar(255) not null,
GrupoCompleto varchar(255) not null,
Nivel int not null,
GrupoPadre varchar(255) not null,
EsAsignable varchar(3) not null)
GO

--Fila bolson: ticket sin grupo de soporte asignado
set identity_insert DimGrupo on
insert into DimGrupo (GrupoKey, GrupoId_origen, Grupo, GrupoCompleto, Nivel, GrupoPadre,
EsAsignable) values
(-1, -1, 'Sin grupo', 'Sin grupo', 0, 'N/A', 'No')
set identity_insert DimGrupo off
GO

create table DimTipo
(TipoKey int primary key identity(1,1),
Tipo varchar(20) not null)
GO

insert into DimTipo (Tipo) values
('Incidencia'),
('Requerimiento')
GO

create table DimEstado
(EstadoKey int primary key identity(1,1),
Estado varchar(30) not null,
EsEstadoFinal varchar(3) not null)
GO

insert into DimEstado (Estado, EsEstadoFinal) values
('Nuevo', 'No'),
('En curso (asignado)', 'No'),
('En curso (planificado)', 'No'),
('En espera', 'No'),
('Resuelto', 'Si'),
('Cerrado', 'Si')
GO

create table DimPrioridad
(PrioridadKey int primary key identity(1,1),
Urgencia varchar(15) not null,
Impacto varchar(15) not null,
Prioridad varchar(15) not null)
GO

create table DimCanal
(CanalKey int primary key identity(1,1), --Llave surrogada (SK)
CanalId_origen int not null, --Llave de negocio (BK)
Canal varchar(255) not null)
GO

create table DimSLA
(SLAKey int primary key identity(1,1), --Llave surrogada (SK)
SLAId_origen int not null, --Llave de negocio (BK)
SLA varchar(255) not null,
TipoSLA varchar(30) not null,
Objetivo varchar(50) not null,
HorasObjetivo decimal(8,2) not null default 0,
UsaCalendario varchar(3) not null)
GO

--Fila bolson: ticket sin SLA asignado
set identity_insert DimSLA on
insert into DimSLA (SLAKey, SLAId_origen, SLA, TipoSLA, Objetivo, HorasObjetivo,
UsaCalendario) values
(-1, -1, 'Sin SLA', 'Sin SLA', 'N/A', 0, 'No')
set identity_insert DimSLA off
GO

create table DimTipoSolucion
(TipoSolucionKey int primary key identity(1,1), --Llave surrogada (SK)
TipoSolucionId_origen int not null, --Llave de negocio (BK)
TipoSolucion varchar(255) not null)
GO

--Dos filas bolson: -1 el ticket aun no se resuelve, -2 se resolvio sin tipo asignado
set identity_insert DimTipoSolucion on
insert into DimTipoSolucion (TipoSolucionKey, TipoSolucionId_origen, TipoSolucion) values
(-1, -1, 'Sin resolver'),
(-2, 0, 'Resuelto sin tipo')
set identity_insert DimTipoSolucion off
GO

--Tabla puente: un ticket puede tener mas de un tecnico asignado a la vez
create table BridgeTicketTecnico
(ConjuntoTecnicosKey int not null,
TecnicoKey int not null foreign key references DimUsuario(UsuarioKey),
FactorPonderacion decimal(5,4) not null,
primary key (ConjuntoTecnicosKey, TecnicoKey))
GO

--Fila bolson: ticket sin tecnico asignado
insert into BridgeTicketTecnico values (-1, -1, 1.0000)
GO

--Crear tabla de hechos (snapshot acumulativo, una fila por ticket)
create table FactTickets
(NumeroTicket int not null primary key, --dimension degenerada (glpi_tickets.id)

FechaCreacionKey int not null foreign key references DimFecha(FechaKey),
FechaTomaCargoKey int not null foreign key references DimFecha(FechaKey),
FechaSolucionKey int not null foreign key references DimFecha(FechaKey),
FechaCierreKey int not null foreign key references DimFecha(FechaKey),

EntidadKey int not null foreign key references DimEntidad(EntidadKey),
CategoriaKey int not null foreign key references DimCategoria(CategoriaKey),
TipoKey int not null foreign key references DimTipo(TipoKey),
EstadoKey int not null foreign key references DimEstado(EstadoKey),
PrioridadKey int not null foreign key references DimPrioridad(PrioridadKey),
CanalKey int not null foreign key references DimCanal(CanalKey),
UbicacionKey int not null foreign key references DimUbicacion(UbicacionKey),
SLAResolucionKey int not null foreign key references DimSLA(SLAKey),
SLARespuestaKey int not null foreign key references DimSLA(SLAKey),
TipoSolucionKey int not null foreign key references DimTipoSolucion(TipoSolucionKey),

SolicitanteKey int not null foreign key references DimUsuario(UsuarioKey),
ConjuntoTecnicosKey int not null, --se valida contra BridgeTicketTecnico
TecnicoResolutorKey int not null foreign key references DimUsuario(UsuarioKey),
GrupoSoporteKey int not null foreign key references DimGrupo(GrupoKey),

--Metricas naturales (segundos)
TiempoPrimeraRespuesta_seg int not null default 0,
TiempoResolucion_seg int not null default 0,
TiempoCierre_seg int not null default 0,
TiempoEspera_seg int not null default 0,
TiempoTrabajadoTareas_seg int not null default 0,

--Metricas derivadas
CantidadTickets int not null default 1,
CantidadTicketsResueltos int not null default 0,
CantidadReaperturas int not null default 0,
CantidadReasignaciones int not null default 0,
CantidadSeguimientos int not null default 0,

--Banderas 1/0
CumpleSLAResolucion int not null default 0,
CumpleSLARespuesta int not null default 0,
EsReabierto int not null default 0,
ResolucionPrimerContacto int not null default 0)
GO
