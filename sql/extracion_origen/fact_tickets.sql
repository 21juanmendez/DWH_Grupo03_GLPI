WITH reap AS (
  SELECT items_id AS tid, COUNT(*) AS n FROM glpi_logs
  WHERE itemtype='Ticket' AND id_search_option=12
    AND old_value IN ('5','6') AND new_value='2' GROUP BY items_id),
reasig AS (
  SELECT items_id AS tid, GREATEST(COUNT(*)-1,0) AS n FROM glpi_logs
  WHERE itemtype='Ticket' AND linked_action=15 AND itemtype_link='User'
    AND id_search_option=5 GROUP BY items_id),
segui AS (
  SELECT items_id AS tid, COUNT(*) AS n FROM glpi_itilfollowups
  WHERE itemtype='Ticket' GROUP BY items_id),
sol AS (
  SELECT s.items_id AS tid, s.users_id, s.solutiontypes_id FROM glpi_itilsolutions s
  JOIN (SELECT items_id, MAX(id) AS mx FROM glpi_itilsolutions
        WHERE itemtype='Ticket' GROUP BY items_id) u
    ON u.items_id=s.items_id AND u.mx=s.id WHERE s.itemtype='Ticket')
SELECT
  -- Dimension degenerada
  CAST(t.id AS SIGNED) AS NumeroTicket,

  -- Llaves de fecha (AAAAMMDD; 99991231 = pendiente)
  CAST(DATE_FORMAT(t.date,'%Y%m%d') AS SIGNED) AS FechaCreacionKey,
  CAST(COALESCE(DATE_FORMAT(t.takeintoaccountdate,'%Y%m%d'),'99991231') AS SIGNED) AS FechaTomaCargoKey,
  CAST(COALESCE(DATE_FORMAT(t.solvedate,'%Y%m%d'),'99991231') AS SIGNED) AS FechaSolucionKey,
  CAST(COALESCE(DATE_FORMAT(t.closedate,'%Y%m%d'),'99991231') AS SIGNED) AS FechaCierreKey,

  -- Llaves directas (coinciden con los enums de GLPI)
  CAST(t.type AS SIGNED)   AS TipoKey,
  CAST(t.status AS SIGNED) AS EstadoKey,

  -- Llaves de negocio para los Lookups (0 -> -1 = fila bolson)
  CAST(t.entities_id AS SIGNED) AS EntidadId_origen,
  CAST(CASE WHEN t.itilcategories_id=0 THEN -1 ELSE t.itilcategories_id END AS SIGNED) AS CategoriaId_origen,
  CAST(CASE WHEN t.locations_id=0     THEN -1 ELSE t.locations_id     END AS SIGNED) AS UbicacionId_origen,
  CAST(CASE WHEN t.requesttypes_id=0  THEN -1 ELSE t.requesttypes_id  END AS SIGNED) AS CanalId_origen,
  CAST(CASE WHEN t.slas_id_ttr=0      THEN -1 ELSE t.slas_id_ttr      END AS SIGNED) AS SLAResolucionId_origen,
  CAST(CASE WHEN t.slas_id_tto=0      THEN -1 ELSE t.slas_id_tto      END AS SIGNED) AS SLARespuestaId_origen,

  -- Prioridad (junk): el Lookup busca por los tres textos
  CAST(CASE t.urgency WHEN 1 THEN 'Muy baja' WHEN 2 THEN 'Baja' WHEN 3 THEN 'Mediana'
                      WHEN 4 THEN 'Alta' WHEN 5 THEN 'Muy alta'
                      ELSE 'Mediana' END AS CHAR(15)) AS Urgencia,
  CAST(CASE t.impact  WHEN 1 THEN 'Muy bajo' WHEN 2 THEN 'Bajo' WHEN 3 THEN 'Mediano'
                      WHEN 4 THEN 'Alto' WHEN 5 THEN 'Muy alto'
                      ELSE 'Mediano' END AS CHAR(15)) AS Impacto,
  CAST(CASE t.priority WHEN 1 THEN 'Muy baja' WHEN 2 THEN 'Baja' WHEN 3 THEN 'Mediana'
                       WHEN 4 THEN 'Alta' WHEN 5 THEN 'Muy alta' WHEN 6 THEN 'Mayor'
                       ELSE 'Mediana' END AS CHAR(15)) AS Prioridad,

  -- Actores
  CAST(COALESCE((SELECT tu.users_id FROM glpi_tickets_users tu
                 WHERE tu.tickets_id=t.id AND tu.type=1
                 ORDER BY (tu.users_id=t.users_id_recipient) DESC, tu.id ASC
                 LIMIT 1),-1) AS SIGNED) AS SolicitanteId_origen,
  CAST(CASE WHEN EXISTS (SELECT 1 FROM glpi_tickets_users tu
                         WHERE tu.tickets_id=t.id AND tu.type=2)
            THEN t.id ELSE -1 END AS SIGNED) AS ConjuntoTecnicosKey,
  CAST(COALESCE(sol.users_id,-1) AS SIGNED) AS TecnicoResolutorId_origen,
  CAST(COALESCE((SELECT gt.groups_id FROM glpi_groups_tickets gt
                 WHERE gt.tickets_id=t.id AND gt.type=2
                 ORDER BY gt.id LIMIT 1),-1) AS SIGNED) AS GrupoSoporteId_origen,
  CAST(COALESCE(sol.solutiontypes_id,-1) AS SIGNED) AS TipoSolucionId_origen,

  -- Metricas naturales (ya vienen netas de espera)
  CAST(t.takeintoaccount_delay_stat AS SIGNED) AS TiempoPrimeraRespuesta_seg,
  CAST(t.solve_delay_stat           AS SIGNED) AS TiempoResolucion_seg,
  CAST(t.close_delay_stat           AS SIGNED) AS TiempoCierre_seg,
  CAST(t.waiting_duration           AS SIGNED) AS TiempoEspera_seg,
  CAST(t.actiontime                 AS SIGNED) AS TiempoTrabajadoTareas_seg,

  -- Metricas derivadas
  CAST(1 AS SIGNED) AS CantidadTickets,
  CAST(CASE WHEN t.status IN (5,6) THEN 1 ELSE 0 END AS SIGNED) AS CantidadTicketsResueltos,
  CAST(COALESCE(reap.n,0)   AS SIGNED) AS CantidadReaperturas,
  CAST(COALESCE(reasig.n,0) AS SIGNED) AS CantidadReasignaciones,
  CAST(COALESCE(segui.n,0)  AS SIGNED) AS CantidadSeguimientos,

  -- Banderas 1/0
  CAST(CASE WHEN t.slas_id_ttr>0 AND t.solvedate IS NOT NULL AND t.time_to_resolve IS NOT NULL
                 AND t.solvedate<=t.time_to_resolve
            THEN 1 ELSE 0 END AS SIGNED) AS CumpleSLAResolucion,
  CAST(CASE WHEN t.slas_id_tto>0 AND t.takeintoaccountdate IS NOT NULL AND t.time_to_own IS NOT NULL
                 AND t.takeintoaccountdate<=t.time_to_own
            THEN 1 ELSE 0 END AS SIGNED) AS CumpleSLARespuesta,
  CAST(CASE WHEN COALESCE(reap.n,0)>0 THEN 1 ELSE 0 END AS SIGNED) AS EsReabierto,
  CAST(CASE WHEN t.status IN (5,6) AND COALESCE(reap.n,0)=0 AND COALESCE(segui.n,0)<=1
            THEN 1 ELSE 0 END AS SIGNED) AS ResolucionPrimerContacto
FROM glpi_tickets t
LEFT JOIN reap   ON reap.tid=t.id
LEFT JOIN reasig ON reasig.tid=t.id
LEFT JOIN segui  ON segui.tid=t.id
LEFT JOIN sol    ON sol.tid=t.id
WHERE t.is_deleted=0
ORDER BY t.id;