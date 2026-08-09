INSERT INTO DimFecha VALUES
(99991231, '9999-12-31', 9999, 'NA', 12, 'Pendiente', 31, 'Pendiente', 'No', 0)
GO

DECLARE @Fecha date = '2020-01-01'
DECLARE @Fin   date = '2030-12-31'
DECLARE @dow   int

WHILE @Fecha <= @Fin
BEGIN
    -- 0=Lunes ... 6=Domingo (independiente de DATEFIRST; el 1900-01-01 fue lunes)
    SET @dow = DATEDIFF(day, '1900-01-01', @Fecha) % 7

    INSERT INTO DimFecha (FechaKey, Fecha, Anio, Trimestre, Mes, NombreMes, Dia, NombreDia, EsFinDeSemana, SemanaAnio)
    VALUES (
        CONVERT(int, CONVERT(varchar(8), @Fecha, 112)),        -- FechaKey en AAAAMMDD
        @Fecha,                                                -- Fecha (llave de negocio)
        YEAR(@Fecha),                                          -- Anio
        'Q' + CAST(DATEPART(quarter, @Fecha) AS varchar(1)),   -- Trimestre: Q1..Q4
        MONTH(@Fecha),                                         -- Mes
        CASE MONTH(@Fecha)
            WHEN 1 THEN 'Enero'   WHEN 2 THEN 'Febrero'  WHEN 3 THEN 'Marzo'
            WHEN 4 THEN 'Abril'   WHEN 5 THEN 'Mayo'     WHEN 6 THEN 'Junio'
            WHEN 7 THEN 'Julio'   WHEN 8 THEN 'Agosto'   WHEN 9 THEN 'Septiembre'
            WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' ELSE 'Diciembre' END,
        DAY(@Fecha),                                           -- Dia
        CASE @dow
            WHEN 0 THEN 'Lunes'  WHEN 1 THEN 'Martes'   WHEN 2 THEN 'Miercoles'
            WHEN 3 THEN 'Jueves' WHEN 4 THEN 'Viernes'  WHEN 5 THEN 'Sabado'
            ELSE 'Domingo' END,                                -- NombreDia
        CASE WHEN @dow IN (5,6) THEN 'Si' ELSE 'No' END,       -- EsFinDeSemana
        DATEPART(iso_week, @Fecha)                             -- SemanaAnio (semana ISO)
    )

    SET @Fecha = DATEADD(day, 1, @Fecha)
END
GO


