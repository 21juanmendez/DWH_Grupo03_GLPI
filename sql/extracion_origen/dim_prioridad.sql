SELECT
    CASE u.n WHEN 1 THEN 'Muy baja' WHEN 2 THEN 'Baja' WHEN 3 THEN 'Mediana'
             WHEN 4 THEN 'Alta'     WHEN 5 THEN 'Muy alta' END      AS Urgencia,
    CASE i.n WHEN 1 THEN 'Muy bajo' WHEN 2 THEN 'Bajo' WHEN 3 THEN 'Mediano'
             WHEN 4 THEN 'Alto'     WHEN 5 THEN 'Muy alto' END      AS Impacto,
    CASE p.n WHEN 1 THEN 'Muy baja' WHEN 2 THEN 'Baja' WHEN 3 THEN 'Mediana'
             WHEN 4 THEN 'Alta'     WHEN 5 THEN 'Muy alta'
             WHEN 6 THEN 'Mayor' END                                AS Prioridad
FROM      (SELECT 1 n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) u
              CROSS JOIN(SELECT 1 n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) i
              CROSS JOIN(SELECT 1 n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5
                         UNION SELECT 6) p
ORDER BY u.n, i.n, p.n;