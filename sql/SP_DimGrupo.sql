/*
Procedimiento *_Update para DimGrupo. Mismo patron que sp_DimCategoria_Update
(ver sql/SP_DimCategoria.sql para la explicacion completa del diseno).

Llamado desde el paquete DimGrupo_cargaDiferencial.dtsx:
    EXEC dbo.sp_DimGrupo_Update ?, ?, ?, ?, ?, ?

El filtro GrupoKey > 0 protege la fila bolson (-1, 'Sin grupo').
*/

USE DWH_Grupo03_GLPI
GO

CREATE OR ALTER PROCEDURE dbo.sp_DimGrupo_Update
    @GrupoId_origen int,
    @Grupo          varchar(255),
    @GrupoCompleto  varchar(255),
    @Nivel          int,
    @GrupoPadre     varchar(255),
    @EsAsignable    varchar(3)
AS
BEGIN
    SET NOCOUNT ON

    UPDATE dbo.DimGrupo
       SET Grupo         = @Grupo,
           GrupoCompleto = @GrupoCompleto,
           Nivel         = @Nivel,
           GrupoPadre    = @GrupoPadre,
           EsAsignable   = @EsAsignable
     WHERE GrupoId_origen = @GrupoId_origen
       AND GrupoKey > 0
       AND (Grupo         COLLATE Latin1_General_BIN2 <> @Grupo         COLLATE Latin1_General_BIN2
         OR GrupoCompleto COLLATE Latin1_General_BIN2 <> @GrupoCompleto COLLATE Latin1_General_BIN2
         OR GrupoPadre    COLLATE Latin1_General_BIN2 <> @GrupoPadre    COLLATE Latin1_General_BIN2
         OR EsAsignable   COLLATE Latin1_General_BIN2 <> @EsAsignable   COLLATE Latin1_General_BIN2
         OR Nivel <> @Nivel)
END
GO
