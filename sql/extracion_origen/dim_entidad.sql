SELECT
    e.id                                                                AS EntidadId_origen,
    COALESCE(NULLIF(TRIM(e.name),''),'Sin nombre')                      AS Entidad,
    CAST(COALESCE(NULLIF(TRIM(e.completename),''),
                  NULLIF(TRIM(e.name),''),'Sin nombre') AS CHAR(255))   AS EntidadCompleta,
    COALESCE(e.level,1)                                                 AS Nivel,
    COALESCE(NULLIF(TRIM(e.town),''),'No especificado')                 AS Ciudad,
    COALESCE(NULLIF(TRIM(e.state),''),'No especificado')                AS Estado,
    COALESCE(NULLIF(TRIM(e.country),''),'No especificado')              AS Pais
FROM glpi_entities e
ORDER BY e.id;