/*
Procedimiento de actualizacion SCD HIBRIDO (tipo 1 + tipo 2) para DimUsuario,
segun el diseno oficial documentado en Mapeo_De_Tablas_Grupo03_GLPII.xlsx
(hoja DimUsuario, columna "SCD Type"):

  SCD tipo 1 (sobrescribe, NO genera historial): Login, NombreCompleto,
    Telefono, Categoria, Activo.
    Un cambio en estos atributos actualiza TODAS las filas (vigente e
    historicas) del mismo UsuarioId_origen, porque un atributo tipo 1 no
    tiene version: se considera "siempre el valor actual", incluso visto
    desde una fila historica.

  SCD tipo 2 (versiona, genera fila nueva): Perfil, Ubicacion, Titulo.
    Un cambio en cualquiera de estos tres cierra la version vigente
    (FechaFin = hoy, EsVigente = 'No') e inserta una fila nueva con todos
    los valores actuales (FechaInicio = hoy, FechaFin = '9999-12-31',
    EsVigente = 'Si', nueva UsuarioKey autogenerada).

Los dos tipos de cambio son independientes y pueden ocurrir en la misma
corrida (ej. cambia el Perfil Y el Telefono a la vez): el bloque SCD1 corre
primero y actualiza todas las filas, luego el bloque SCD2 inserta la fila
nueva ya con los valores SCD1 correctos.

Si no hay ningun cambio real en ningun atributo, no hace nada.

Llamado desde el paquete DimUsuario_cargaDiferencial.dtsx:
    EXEC dbo.sp_DimUsuario_SCD2 ?, ?, ?, ?, ?, ?, ?, ?, ?

El Lookup del paquete busca solo contra EsVigente='Si' (la version vigente),
nunca contra el historial. El filtro UsuarioKey > 0 protege la fila bolson
(-1, 'Sin asignar').
*/

USE DWH_Grupo03_GLPI
GO

CREATE OR ALTER PROCEDURE dbo.sp_DimUsuario_SCD2
    @UsuarioId_origen int,
    @Login            varchar(255),
    @NombreCompleto   varchar(255),
    @Perfil           varchar(255),
    @Telefono         varchar(50),
    @Ubicacion        varchar(255),
    @Titulo           varchar(255),
    @Categoria        varchar(255),
    @Activo           varchar(3)
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @CambioSCD1 bit = 0
    DECLARE @CambioSCD2 bit = 0

    SELECT
        @CambioSCD1 = CASE WHEN
               Login          COLLATE Latin1_General_BIN2 <> @Login          COLLATE Latin1_General_BIN2
            OR NombreCompleto COLLATE Latin1_General_BIN2 <> @NombreCompleto COLLATE Latin1_General_BIN2
            OR Telefono       COLLATE Latin1_General_BIN2 <> @Telefono       COLLATE Latin1_General_BIN2
            OR Categoria      COLLATE Latin1_General_BIN2 <> @Categoria      COLLATE Latin1_General_BIN2
            OR Activo         COLLATE Latin1_General_BIN2 <> @Activo         COLLATE Latin1_General_BIN2
            THEN 1 ELSE 0 END,
        @CambioSCD2 = CASE WHEN
               Perfil    COLLATE Latin1_General_BIN2 <> @Perfil    COLLATE Latin1_General_BIN2
            OR Ubicacion COLLATE Latin1_General_BIN2 <> @Ubicacion COLLATE Latin1_General_BIN2
            OR Titulo    COLLATE Latin1_General_BIN2 <> @Titulo    COLLATE Latin1_General_BIN2
            THEN 1 ELSE 0 END
    FROM dbo.DimUsuario
    WHERE UsuarioId_origen = @UsuarioId_origen
      AND EsVigente = 'Si'
      AND UsuarioKey > 0

    -- SCD1: se aplica a TODAS las versiones (vigente e historicas) del usuario
    IF @CambioSCD1 = 1
    BEGIN
        UPDATE dbo.DimUsuario
           SET Login          = @Login,
               NombreCompleto = @NombreCompleto,
               Telefono       = @Telefono,
               Categoria      = @Categoria,
               Activo         = @Activo
         WHERE UsuarioId_origen = @UsuarioId_origen
           AND UsuarioKey > 0
    END

    -- SCD2: cierra la version vigente y abre una nueva con todos los valores actuales
    IF @CambioSCD2 = 1
    BEGIN
        UPDATE dbo.DimUsuario
           SET FechaFin  = CAST(GETDATE() AS date),
               EsVigente = 'No'
         WHERE UsuarioId_origen = @UsuarioId_origen
           AND EsVigente = 'Si'
           AND UsuarioKey > 0

        INSERT INTO dbo.DimUsuario
            (UsuarioId_origen, Login, NombreCompleto, Perfil, Telefono, Ubicacion, Titulo, Categoria, Activo, FechaInicio, FechaFin, EsVigente)
        VALUES
            (@UsuarioId_origen, @Login, @NombreCompleto, @Perfil, @Telefono, @Ubicacion, @Titulo, @Categoria, @Activo,
             CAST(GETDATE() AS date), '9999-12-31', 'Si')
    END
END
GO
