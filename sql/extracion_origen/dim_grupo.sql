SELECT
    g.id                                                                AS GrupoId_origen,
    COALESCE(NULLIF(TRIM(g.name),''),'Sin nombre')                      AS Grupo,
    CAST(COALESCE(NULLIF(TRIM(g.completename),''),
                  NULLIF(TRIM(g.name),''),'Sin nombre') AS CHAR(255))   AS GrupoCompleto,
    COALESCE(g.level,1)                                                 AS Nivel,
    COALESCE(NULLIF(TRIM(pg.name),''),'Ninguno')                        AS GrupoPadre,
    CASE WHEN g.is_assign = 1 THEN 'Si' ELSE 'No' END                   AS EsAsignable
FROM glpi_groups g
LEFT JOIN glpi_groups pg ON pg.id = g.groups_id
ORDER BY g.id