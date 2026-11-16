SELECT
    r.id                                                            AS CanalId_origen,
    COALESCE(NULLIF(TRIM(r.name),''),'Sin nombre')                  AS Canal
FROM glpi_requesttypes r
ORDER BY r.id;