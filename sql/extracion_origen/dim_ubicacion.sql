SELECT
    l.id                                                                AS UbicacionId_origen,
    COALESCE(NULLIF(TRIM(l.name),''),'Sin nombre')                      AS Ubicacion,
    CAST(COALESCE(NULLIF(TRIM(l.completename),''),
                  NULLIF(TRIM(l.name),''),'Sin nombre') AS CHAR(255))   AS UbicacionCompleta,
    COALESCE(NULLIF(TRIM(l.building),''),'N/A')                         AS Edificio,
    COALESCE(NULLIF(TRIM(l.room),''),'N/A')                             AS Sala,
    COALESCE(NULLIF(TRIM(l.town),''),'No especificado')                 AS Ciudad,
    COALESCE(NULLIF(TRIM(l.state),''),'No especificado')                AS Estado,
    COALESCE(NULLIF(TRIM(l.country),''),'No especificado')              AS Pais
FROM glpi_locations l
ORDER BY l.id;