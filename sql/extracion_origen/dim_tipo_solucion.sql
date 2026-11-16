SELECT
    id                                                     AS TipoSolucionId_origen,
    COALESCE(NULLIF(TRIM(name),''),'Sin nombre')            AS TipoSolucion
FROM glpi_solutiontypes
ORDER BY id;