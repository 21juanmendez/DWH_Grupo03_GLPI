/*
Procedimientos almacenados usados por los paquetes SSIS del ETL.

Cada dimension tiene un procedimiento *_Update que se invoca desde el
componente "Comando de OLE DB" (OLE DB Command), en la rama "Cambio" de la
division condicional: es decir, solo para las filas que YA existen en la
dimension y cuyos atributos cambiaron en el origen (SCD Tipo 1).

Las filas nuevas NO pasan por aqui: van por la rama "sin coincidencia" del
Lookup directo al destino OLE DB con carga rapida.
*/

USE DWH_Grupo03_GLPI
GO

--------------------------------------------------------------------------
-- DimCategoria
--
-- Llamada desde el paquete Dim_Categoria.dtsx:
--     EXEC dbo.sp_DimCategoria_Update ?, ?, ?, ?, ?
--
-- El filtro CategoriaKey > 0 es una red de seguridad: impide que una
-- ejecucion mal configurada pise la fila bolson (-1, 'Sin categoria'),
-- que no proviene del origen y no debe modificarse nunca.
--
-- DECISION DE DISEÑO: quien detecta el cambio es ESTE procedimiento, no
-- el paquete. El paquete no lleva division condicional: la salida "Match"
-- del Lookup va directo al Comando OLE DB, que llama aqui una vez por cada
-- fila que YA existe en la dimension. El WHERE decide si escribe o no.
--
-- Por que el COLLATE Latin1_General_BIN2:
-- la collation por defecto de la base es CI_AS (no distingue mayusculas),
-- asi que para SQL Server 'Hardware' = 'HARDWARE' y un cambio de
-- capitalizacion en GLPI nunca llegaria al DWH. BIN2 compara byte a byte,
-- que es lo que necesita un ETL: cualquier diferencia real se propaga.
-- Nivel es int y no lleva COLLATE.
--
-- No hacen falta comparaciones a prueba de NULL (ISNULL / IS DISTINCT
-- FROM): todas las columnas de las dimensiones son NOT NULL por regla de
-- diseño del modelo.
--------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_DimCategoria_Update
    @CategoriaId_origen int,
    @Categoria          varchar(255),
    @CategoriaCompleta  varchar(255),
    @Nivel              int,
    @Codigo             varchar(255)
AS
BEGIN
    SET NOCOUNT ON

    UPDATE dbo.DimCategoria
       SET Categoria         = @Categoria,
           CategoriaCompleta = @CategoriaCompleta,
           Nivel             = @Nivel,
           Codigo            = @Codigo
     WHERE CategoriaId_origen = @CategoriaId_origen
       AND CategoriaKey > 0
       AND (Categoria         COLLATE Latin1_General_BIN2 <> @Categoria         COLLATE Latin1_General_BIN2
         OR CategoriaCompleta COLLATE Latin1_General_BIN2 <> @CategoriaCompleta COLLATE Latin1_General_BIN2
         OR Codigo            COLLATE Latin1_General_BIN2 <> @Codigo            COLLATE Latin1_General_BIN2
         OR Nivel <> @Nivel)
END
GO
