SELECT
    u.id                                                            AS UsuarioId_origen,
    COALESCE(NULLIF(TRIM(u.name),''),'Desconocido')                 AS Login,
    COALESCE(NULLIF(TRIM(CONCAT_WS(' ', u.firstname, u.realname)),''),
             NULLIF(TRIM(u.name),''),'Desconocido')                 AS NombreCompleto,
    COALESCE((SELECT p.name
              FROM glpi_profiles_users pu
                       JOIN glpi_profiles p ON p.id = pu.profiles_id
              WHERE pu.users_id = u.id
              ORDER BY pu.is_default_profile DESC, p.id ASC
              LIMIT 1),'Sin perfil')                               AS Perfil,
    COALESCE(NULLIF(TRIM(u.phone),''),
             NULLIF(TRIM(u.mobile),''),'No disponible')             AS Telefono,
    CAST(COALESCE(NULLIF(TRIM(l.completename),''),'Sin ubicacion') AS CHAR(255)) AS Ubicacion,
    COALESCE(NULLIF(TRIM(ut.name),''),'Sin titulo')                 AS Titulo,
    COALESCE(NULLIF(TRIM(uc.name),''),'Sin categoria')              AS Categoria,
    CASE WHEN u.is_active = 1 THEN 'Si' ELSE 'No' END               AS Activo,
    CURRENT_DATE                                                    AS FechaInicio,
    DATE('9999-12-31')                                              AS FechaFin,
    'Si'                                                            AS EsVigente
FROM glpi_users u
         LEFT JOIN glpi_locations      l  ON l.id  = u.locations_id
         LEFT JOIN glpi_usertitles     ut ON ut.id = u.usertitles_id
         LEFT JOIN glpi_usercategories uc ON uc.id = u.usercategories_id
ORDER BY u.id;