/*
Procedimiento *_Update para DimEntidad. Mismo patron que sp_DimCategoria_Update
(ver sql/SP_DimCategoria.sql para la explicacion completa del diseno: quien
detecta el cambio, por que BIN2, por que no hace falta NULL-safe compare).

Llamado desde el paquete DimEntidad_cargaDiferencial.dtsx:
    EXEC dbo.sp_DimEntidad_Update ?, ?, ?, ?, ?, ?, ?

El filtro EntidadKey > 0 protege la fila bolson. Nota: a diferencia de
DimCategoria/DimGrupo/DimUbicacion, DimEntidad no tiene fila bolson -1 en el
DDL (entities_id=0 en GLPI es la entidad raiz, un valor valido, no "sin
asignar"); el filtro > 0 se deja de todos modos como buena practica y por
si en el futuro se agrega una.
*/

USE DWH_Grupo03_GLPI
GO

CREATE OR ALTER PROCEDURE dbo.sp_DimEntidad_Update
    @EntidadId_origen int,
    @Entidad          varchar(255),
    @EntidadCompleta  varchar(255),
    @Nivel            int,
    @Ciudad           varchar(255),
    @Estado           varchar(255),
    @Pais             varchar(255)
AS
BEGIN
    SET NOCOUNT ON

    UPDATE dbo.DimEntidad
       SET Entidad         = @Entidad,
           EntidadCompleta = @EntidadCompleta,
           Nivel           = @Nivel,
           Ciudad          = @Ciudad,
           Estado          = @Estado,
           Pais            = @Pais
     WHERE EntidadId_origen = @EntidadId_origen
       AND EntidadKey > 0
       AND (Entidad         COLLATE Latin1_General_BIN2 <> @Entidad         COLLATE Latin1_General_BIN2
         OR EntidadCompleta COLLATE Latin1_General_BIN2 <> @EntidadCompleta COLLATE Latin1_General_BIN2
         OR Ciudad          COLLATE Latin1_General_BIN2 <> @Ciudad          COLLATE Latin1_General_BIN2
         OR Estado          COLLATE Latin1_General_BIN2 <> @Estado          COLLATE Latin1_General_BIN2
         OR Pais            COLLATE Latin1_General_BIN2 <> @Pais            COLLATE Latin1_General_BIN2
         OR Nivel <> @Nivel)
END
GO
