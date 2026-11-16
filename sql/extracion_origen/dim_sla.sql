SELECT
    s.id                                                            AS SLAId_origen,
    COALESCE(NULLIF(TRIM(s.name),''),'Sin nombre')                  AS SLA,
    CASE s.type
        WHEN 0 THEN 'Resolucion (TTR)'
        WHEN 1 THEN 'Respuesta (TTO)'
        ELSE 'No definido' END                                      AS TipoSLA,
    CONCAT(COALESCE(s.number_time,0),' ',
           CASE s.definition_time
               WHEN 'minute' THEN 'minutos'
               WHEN 'hour'   THEN 'horas'
               WHEN 'day'    THEN 'dias'
               ELSE 'N/A' END)                                      AS Objetivo,
    ROUND(CASE s.definition_time
              WHEN 'minute' THEN COALESCE(s.number_time,0)/60
              WHEN 'hour'   THEN COALESCE(s.number_time,0)
              WHEN 'day'    THEN COALESCE(s.number_time,0)*24
              ELSE 0 END, 2)                                        AS HorasObjetivo,
    CASE WHEN s.use_ticket_calendar = 1 THEN 'Si' ELSE 'No' END     AS UsaCalendario
FROM glpi_slas s
ORDER BY s.id;