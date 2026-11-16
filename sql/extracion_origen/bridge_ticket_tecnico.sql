SELECT
    tu.tickets_id      AS ConjuntoTecnicosKey,   
    tu.users_id        AS TecnicoId_origen,      
    ROUND(1.0 / COUNT(*) OVER (PARTITION BY tu.tickets_id), 4) AS FactorPonderacion
FROM glpi_tickets_users tu
JOIN glpi_tickets t ON t.id = tu.tickets_id
WHERE tu.type = 2          
  AND t.is_deleted = 0;