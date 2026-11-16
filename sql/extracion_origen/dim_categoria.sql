SELECT
    c.id                                                                AS CategoriaId_origen,
    COALESCE(NULLIF(TRIM(c.name),''),'Sin nombre')                      AS Categoria,
    CAST(COALESCE(NULLIF(TRIM(c.completename),''),
                  NULLIF(TRIM(c.name),''),'Sin nombre') AS CHAR(255))   AS CategoriaCompleta,
    COALESCE(c.level,1)                                                 AS Nivel,
    COALESCE(NULLIF(TRIM(c.code),''),'N/A')                      AS Codigo
FROM glpi_itilcategories c
ORDER BY c.id;