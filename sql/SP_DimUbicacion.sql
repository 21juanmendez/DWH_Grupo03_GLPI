/*
Procedimiento *_Update para DimUbicacion. Mismo patron que sp_DimCategoria_Update
(ver sql/SP_DimCategoria.sql para la explicacion completa del diseno).

Llamado desde el paquete DimUbicacion_cargaDiferencial.dtsx:
    EXEC dbo.sp_DimUbicacion_Update ?, ?, ?, ?, ?, ?, ?, ?

El filtro UbicacionKey > 0 protege la fila bolson (-1, 'Sin ubicacion').
DimUbicacion no tiene columna Nivel, por eso no aparece aqui (a diferencia
de DimEntidad/DimGrupo/DimCategoria).
*/

USE DWH_Grupo03_GLPI
GO

CREATE OR ALTER PROCEDURE dbo.sp_DimUbicacion_Update
    @UbicacionId_origen int,
    @Ubicacion          varchar(255),
    @UbicacionCompleta  varchar(255),
    @Edificio           varchar(255),
    @Sala               varchar(255),
    @Ciudad             varchar(255),
    @Estado             varchar(255),
    @Pais               varchar(255)
AS
BEGIN
    SET NOCOUNT ON

    UPDATE dbo.DimUbicacion
       SET Ubicacion         = @Ubicacion,
           UbicacionCompleta = @UbicacionCompleta,
           Edificio          = @Edificio,
           Sala              = @Sala,
           Ciudad            = @Ciudad,
           Estado            = @Estado,
           Pais              = @Pais
     WHERE UbicacionId_origen = @UbicacionId_origen
       AND UbicacionKey > 0
       AND (Ubicacion         COLLATE Latin1_General_BIN2 <> @Ubicacion         COLLATE Latin1_General_BIN2
         OR UbicacionCompleta COLLATE Latin1_General_BIN2 <> @UbicacionCompleta COLLATE Latin1_General_BIN2
         OR Edificio          COLLATE Latin1_General_BIN2 <> @Edificio          COLLATE Latin1_General_BIN2
         OR Sala              COLLATE Latin1_General_BIN2 <> @Sala              COLLATE Latin1_General_BIN2
         OR Ciudad            COLLATE Latin1_General_BIN2 <> @Ciudad            COLLATE Latin1_General_BIN2
         OR Estado            COLLATE Latin1_General_BIN2 <> @Estado            COLLATE Latin1_General_BIN2
         OR Pais              COLLATE Latin1_General_BIN2 <> @Pais              COLLATE Latin1_General_BIN2)
END
GO
