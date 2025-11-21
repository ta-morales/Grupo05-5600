  /*
  Enunciado: resolucion Entrega06, generacion de los informes pedidos con
  integracion de API para obtener precio del dolar.
  Fecha entrega:
  Comision: 5600
  Grupo: 05
  Materia: Base de datos aplicadas
  Integrantes:
    - ERMASI, Franco: 44613354
    - GATTI, Gonzalo: 46208638
    - MORALES, Tomas: 40.755.243

  Nombre: 04_ReportesApi.sql
  Proposito: Creacion de reportes/informes de pagos y gastos.
  Script a ejecutar antes: 00_CreacionDeTablas.sql
  */

USE Com5600G05
GO

CREATE OR ALTER PROCEDURE LogicaBD.sp_PrecioDolarHoy
    @precioDolar DECIMAL(10,2) OUTPUT
AS
BEGIN
	DECLARE @obj INT
	DECLARE @url VARCHAR(100)
	DECLARE @retorno VARCHAR(200)

	SET @url = 'https://dolarapi.com/v1/dolares/oficial'

	EXEC sp_OACreate 'MSXML2.XMLHTTP', @obj OUTPUT

	EXEC sp_OAMethod @obj, 'open', NULL, 'GET', @url, 'false'

	EXEC sp_OAMethod @obj, 'send'

	EXEC sp_OAMethod @obj, 'responseText', @retorno OUTPUT

	EXEC sp_OADestroy @obj

    
    SELECT @precioDolar = venta
    FROM OPENJSON(@retorno)
    WITH (
        moneda VARCHAR(3) '$.moneda',
        casa VARCHAR(10) '$.casa',
        nombre VARCHAR(10) '$.nombre',
        compra DECIMAL(18,2) '$.compra',
        venta DECIMAL(18,2) '$.venta',
        fecha DATETIME '$.fechaActualizacion'
    )
END
GO

CREATE OR ALTER FUNCTION LogicaBD.sumarGastoOrdinario
(
    @mes INT,
    @cons INT
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @monto DECIMAL(10,2);

    SELECT 
        @monto = SUM(gor.importeFactura)
    FROM Gastos.GastoOrdinario AS gor
    WHERE gor.mes = @mes
      AND gor.idConsorcio = @cons;

    RETURN ISNULL(@monto, 0);
END
GO

CREATE OR ALTER FUNCTION LogicaBD.sumarGastoExtraordinario
(
    @mes INT,
    @cons INT
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @monto DECIMAL(10,2);

    SELECT 
        @monto = SUM(geor.importe)
    FROM Gastos.GastoExtraordinario AS geor
    WHERE geor.mes = @mes
      AND geor.idConsorcio = @cons;

    RETURN ISNULL(@monto, 0);
END
GO

CREATE OR ALTER FUNCTION LogicaBD.sumarPagosHastaMes
(
    @mes INT,
    @idUF INT
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @monto DECIMAL(10,2);

    SELECT
        @monto = SUM(pg.monto)
    FROM Finanzas.Pagos AS pg LEFT JOIN Infraestructura.UnidadFuncional as uf 
    ON pg.idUF = uf.id
    WHERE idUF = @idUF AND month(pg.fecha) < @mes

    RETURN ISNULL(@monto, 0);
END;
GO

CREATE OR ALTER PROCEDURE LogicaBD.CreacionIndicesAuxiliares
AS
BEGIN
    IF EXISTS (SELECT 1 
           FROM sys.indexes 
           WHERE name = 'ix_UF_idConsorcio_Piso_Depto' 
             AND object_id = OBJECT_ID('Infraestructura.UnidadFuncional'))
    BEGIN
        DROP INDEX ix_UF_idConsorcio_Piso_Depto
        ON Infraestructura.UnidadFuncional;
    END
    CREATE NONCLUSTERED INDEX ix_UF_idConsorcio_Piso_Depto 
    ON Infraestructura.UnidadFuncional(idConsorcio, piso, departamento); 

    IF EXISTS (SELECT 1 
           FROM sys.indexes 
           WHERE name = 'ix_PAGOS_fecha_uf_expensa' 
             AND object_id = OBJECT_ID('Finanzas.Pagos'))
    BEGIN
        DROP INDEX ix_PAGOS_fecha_uf_expensa
        ON Finanzas.Pagos;
    END
    CREATE NONCLUSTERED INDEX ix_PAGOS_fecha_uf_expensa 
    ON Finanzas.Pagos(idUF, idExpensa, fecha); 

    IF EXISTS (SELECT 1 
           FROM sys.indexes 
           WHERE name = 'ix_CONSORCIO_nombre' 
             AND object_id = OBJECT_ID('Administracion.Consorcio'))
    BEGIN
        DROP INDEX ix_CONSORCIO_nombre
        ON Administracion.Consorcio;
    END
    CREATE NONCLUSTERED INDEX ix_CONSORCIO_nombre 
    ON Administracion.Consorcio(nombre); 

    IF EXISTS (SELECT 1 
           FROM sys.indexes 
           WHERE name = 'ix_EXPENSA_periodo_idConsorcio' 
             AND object_id = OBJECT_ID('Gastos.Expensa'))
    BEGIN
        DROP INDEX ix_EXPENSA_periodo_idConsorcio
        ON Gastos.Expensa;
    END

    CREATE NONCLUSTERED INDEX ix_EXPENSA_periodo_idConsorcio 
    ON Gastos.Expensa(periodo, idConsorcio) 
    INCLUDE (totalGastoOrdinario, totalGastoExtraordinario);
END
GO

-- INFORME 01: PAGOS ORDINARIOS Y EXTRAORDINARIOS POR SEMANA + promedio semanal por mes + total por mes
CREATE OR ALTER PROCEDURE LogicaBD.sp_Informe01
@mesInicio INT = NULL , 
@mesFinal INT = NULL,
@nombreConsorcio VARCHAR(100) = NULL,
@piso CHAR(2) = NULL,
@departamento CHAR(1) = NULL
AS
BEGIN
    
    DECLARE @mesIni INT
    DECLARE @mesFin INT

    SELECT @mesIni = ISNULL(@mesInicio, MIN(MONTH(fecha))),
           @mesFin  = ISNULL(@mesFinal, MAX(MONTH(fecha)))
    FROM Finanzas.Pagos
    
    ;WITH cteTiposPagos AS 
    (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY fecha, idUF, idExpensa ORDER BY fecha) AS NroPago
        FROM Finanzas.Pagos
    ),
    cteSumaSemanas AS (
    SELECT DISTINCT
        CAST(
            RIGHT('0' + CAST(MONTH(TRY_CONVERT(DATE, fecha, 103)) AS VARCHAR(2)),2)
            + CAST(YEAR(TRY_CONVERT(DATE, fecha, 103)) AS VARCHAR(4)) as CHAR(6)) AS [periodo],
        DATEPART(WEEK, fecha) AS [numero_semana],
        SUM(CASE WHEN NroPago = 1 THEN monto ELSE 0 END) AS [pagos_ordinarios],
        SUM(CASE WHEN NroPago > 1 THEN monto ELSE 0 END) AS [pagos_extraordinarios],
        SUM(monto) as [total_semana]
    FROM cteTiposPagos AS cte
    LEFT JOIN Infraestructura.UnidadFuncional AS uf ON cte.idUF = uf.id
    LEFT JOIN Administracion.Consorcio AS c ON uf.idConsorcio = c.id
    WHERE MONTH(fecha) BETWEEN @mesIni AND @mesFin
        AND (@nombreConsorcio IS NULL OR c.nombre = @nombreConsorcio)
        AND (@piso IS NULL OR RTRIM(CAST(uf.piso  AS CHAR(2))) = @piso)
        AND (@departamento IS NULL OR RTRIM(UPPER(uf.departamento)) = @departamento)
    GROUP BY CAST(
            RIGHT('0' + CAST(MONTH(TRY_CONVERT(DATE, fecha, 103)) AS VARCHAR(2)),2)
            + CAST(YEAR(TRY_CONVERT(DATE, fecha, 103)) AS VARCHAR(4)) as CHAR(6)
		),
        DATEPART(WEEK, fecha)
    )

    SELECT periodo, numero_semana, pagos_ordinarios, pagos_extraordinarios, 
    CAST(AVG(total_semana) OVER(PARTITION BY periodo ORDER BY numero_semana) AS DECIMAL(10,2)) AS [avg_pagos],
    SUM(total_semana) OVER(PARTITION BY periodo ORDER BY numero_semana) AS [acumulado_pagos]
    FROM cteSumaSemanas as Periodo
    FOR XML AUTO, ELEMENTS,ROOT('RecaudacionesSemanales')
     
END
GO

-- INFORME 02: PIVOT DE MES Y PAGOS
CREATE OR ALTER PROCEDURE LogicaBD.sp_Informe02
@consorcio VARCHAR(100) = NULL,
@piso CHAR(2) = NULL,
@depto CHAR(1) = NULL
AS
BEGIN
    WITH ctePagosMes AS
    (
        SELECT 
            MONTH(pg.fecha) AS mes, 
            c.nombre AS [consorcio],
            CONCAT(TRIM(uf.piso), '-', uf.departamento) AS [piso_depto], 
            pg.monto as [monto]
        FROM Finanzas.Pagos AS pg 
        INNER JOIN Infraestructura.UnidadFuncional AS uf
            ON pg.idUF = uf.id
        INNER JOIN Administracion.Consorcio AS c
            ON uf.idConsorcio = c.id
        WHERE 
            (@consorcio IS NULL OR @consorcio = c.nombre) AND
            (@piso IS NULL OR @piso = uf.piso) AND
            (@depto IS NULL OR @depto = uf.departamento)
    )
    SELECT 
        [consorcio],
        [piso_depto],
        ISNULL([1],0) AS [Ene],
        ISNULL([2],0) AS [Feb],
        ISNULL([3],0) AS [Mar],
        ISNULL([4],0) AS [Abr],
        ISNULL([5],0) AS [May],
        ISNULL([6],0) AS [Jun],
        ISNULL([7],0) AS [Jul],
        ISNULL([8],0) AS [Ago],
        ISNULL([9],0) AS [Sep],
        ISNULL([10],0) AS [Oct],
        ISNULL([11],0) AS [Nov],
        ISNULL([12],0) AS [Dic]
    FROM ctePagosMes
    PIVOT (
        SUM(Monto)
        FOR mes IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12])
    ) AS p
    ORDER BY [consorcio], [piso_depto]
END
GO

-- INFORME 03: PIVOT DE MES Y TIPO DE GASTO
CREATE OR ALTER PROCEDURE LogicaBD.sp_Informe03
AS
BEGIN       
    SET NOCOUNT ON
    DECLARE @precio DECIMAL(10,2)
    EXEC LogicaBD.sp_PrecioDolarHoy @precioDolar = @precio OUTPUT

    ;WITH cteTiposPagos AS
    (
        SELECT 
            CONCAT(
                RIGHT('0' + CAST(MONTH(fecha) AS VARCHAR(2)), 2), 
                CAST(YEAR(fecha) AS VARCHAR(4))
            ) AS Periodo,
            CASE
                WHEN ROW_NUMBER() OVER (PARTITION BY fecha, idUF, idExpensa ORDER BY fecha) = 1 THEN 'Ordinario' 
                ELSE 'Extraordinario' 
            END AS [Tipo Pago],
            monto
        FROM Finanzas.Pagos
    )

    SELECT 
        Periodo,
        ISNULL([Ordinario], 0) AS [Pagos ordinarios $],
        ISNULL([Extraordinario], 0) AS [Pagos extraordinarios $],
        (ISNULL([Ordinario],0) + ISNULL([Extraordinario],0)) AS [Pagos totales $],
        CAST((ISNULL([Ordinario], 0) / @precio) AS DECIMAL(10,2)) AS [Pagos ordinarios U$D],
        CAST((ISNULL([Extraordinario], 0) / @precio) AS DECIMAL(10,2)) AS [Pagos extraordinarios U$D],
        CAST(((ISNULL([Ordinario],0) + ISNULL([Extraordinario],0)) / @precio) AS DECIMAL(10,2)) AS [Pagos totales U$D]
    FROM cteTiposPagos AS cte
    PIVOT (
        sum(monto)
        FOR [Tipo Pago] IN ([Ordinario], [Extraordinario])
    ) as p
END
GO

-- INFORME 04: INGRESOS Y EGRESOS POR MES
CREATE OR ALTER PROCEDURE LogicaBD.sp_Informe04
( 
    @fechaInicio DATE = NULL,
    @fechaFin DATE = NULL,
    @nombreConsorcio VARCHAR(100) = NULL
)
AS
BEGIN
    DECLARE @idConsorcio INT = NULL;
    DECLARE @precio DECIMAL(10,2)
    EXEC LogicaBD.sp_PrecioDolarHoy @precioDolar = @precio OUTPUT

    IF @nombreConsorcio IS NOT NULL
    BEGIN
        SELECT TOP 1 @idConsorcio = id 
        FROM Administracion.Consorcio 
        WHERE LOWER(nombre) = LOWER(@nombreConsorcio);
    END

    ;WITH bases AS (
        SELECT 
            ex.periodo,
            (totalGastoExtraordinario + totalGastoOrdinario) as [Gastos$],
            ing.[Ingresos] AS [Ingresos$]
        FROM Gastos.Expensa as ex
        INNER JOIN (
            SELECT
                CONCAT(
                    RIGHT('0' + TRIM(CAST(MONTH(fecha) AS CHAR(2))), 2), 
                    TRIM(CAST(YEAR(fecha) AS CHAR(4)))
                ) AS Periodo,
                sum(monto) AS 'Ingresos'
            FROM Finanzas.Pagos
            WHERE 
                (@fechaFin IS NULL OR @fechaFin >= fecha) AND
                (@fechaInicio IS NULL OR @fechaInicio <= fecha)
            GROUP BY CONCAT(
                    RIGHT('0' + TRIM(CAST(MONTH(fecha) AS CHAR(2))), 2), 
                    TRIM(CAST(YEAR(fecha) AS CHAR(4)))
                ) 
        ) as ing ON ing.Periodo = ex.periodo
        WHERE (@idConsorcio IS NULL OR ex.idConsorcio = @idConsorcio)
    )

    -- Top 5 meses de mayores gastos
    SELECT TOP 5 
        periodo,
        [Gastos$] AS [Gastos $],
        CAST([Gastos$] / @precio AS DECIMAL(10,2)) as [Gastos U$D]
    FROM bases
    ORDER BY [Gastos$] DESC;

    -- Top 5 meses de mayores ingresos
    ;WITH bases AS (
        SELECT 
            ex.periodo,
            (totalGastoExtraordinario + totalGastoOrdinario) as [Gastos$],
            ing.[Ingresos] AS [Ingresos$]
        FROM Gastos.Expensa as ex
        INNER JOIN (
            SELECT
                CONCAT(
                    RIGHT('0' + TRIM(CAST(MONTH(fecha) AS CHAR(2))), 2), 
                    TRIM(CAST(YEAR(fecha) AS CHAR(4)))
                ) AS Periodo,
                sum(monto) AS 'Ingresos'
            FROM Finanzas.Pagos
            WHERE 
                (@fechaFin IS NULL OR @fechaFin >= fecha) AND
                (@fechaInicio IS NULL OR @fechaInicio <= fecha)
            GROUP BY CONCAT(
                    RIGHT('0' + TRIM(CAST(MONTH(fecha) AS CHAR(2))), 2), 
                    TRIM(CAST(YEAR(fecha) AS CHAR(4)))
                ) 
        ) as ing ON ing.Periodo = ex.periodo
        WHERE (@idConsorcio IS NULL OR ex.idConsorcio = @idConsorcio)
    )
    SELECT TOP 5 
        periodo,
        [Ingresos$] AS [Ingresos $],
        CAST([Ingresos$] / @precio AS DECIMAL(10,2)) AS [Ingresos U$D]
    FROM bases
    ORDER BY [Ingresos$] DESC;

END
GO

-- INFORME 05: TOP 3 PROPIETARIOS CON MAYOR MOROSIDAD
CREATE OR ALTER PROCEDURE LogicaBD.sp_Informe05
(
    @nombreConsorcio VARCHAR(100) = NULL,
    @periodoDesde CHAR(6) = NULL,
    @periodoHasta CHAR(6) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH propietarios AS (
        SELECT 
            p.idPersona,
            p.nombre as [nombre],
            p.apellido as [apellido],
            p.dni as [dni],
            p.email as [email],
            p.telefono as [telefono],
            --Personas.fn_DesencriptarNombre(p.idPersona) as [nombre],
            --Personas.fn_DesencriptarApellido(p.idPersona) as [apellido],
            --Personas.fn_DesencriptarDNI(p.idPersona) as [dni],
            --Personas.fn_DesencriptarEmail(p.idPersona) as [email],
            --Personas.fn_DesencriptarTelefono(p.idPersona) as [telefono],
            uf.id          AS idUF,
            c.id           AS idConsorcio,
            c.nombre       AS consorcio
        FROM Personas.PersonaEnUF peu
        INNER JOIN Personas.Persona p ON p.idPersona = peu.idPersona
        INNER JOIN Infraestructura.UnidadFuncional uf ON uf.id = peu.idUF
        INNER JOIN Administracion.Consorcio c ON c.id = uf.idConsorcio
        WHERE peu.inquilino = 0  -- solo propietarios
          AND peu.fechaHasta IS NULL -- relación activa
          AND (@nombreConsorcio IS NULL OR c.nombre = @nombreConsorcio)
    )
    SELECT TOP 3 
        pr.apellido,
        pr.nombre,
        pr.dni,
        pr.email,
        pr.telefono,
        SUM(CASE WHEN (d.deuda + d.intereses) > 0 THEN (d.deuda + d.intereses) ELSE 0 END) AS morosidad_total
    FROM propietarios pr
    INNER JOIN Gastos.DetalleExpensa d ON d.idUF = pr.idUF
    INNER JOIN Gastos.Expensa ex ON ex.id = d.idExpensa AND ex.idConsorcio = pr.idConsorcio
    WHERE (@periodoDesde IS NULL OR ex.periodo >= @periodoDesde)
      AND (@periodoHasta IS NULL OR ex.periodo <= @periodoHasta)
    GROUP BY pr.apellido, pr.nombre, pr.dni, pr.email, pr.telefono
    ORDER BY morosidad_total DESC
    FOR XML PATH('Propietario'), ELEMENTS, ROOT('Morosos')
END
GO

-- INFORME 06: DIFERENCIA DE DIAS ENTRE PAGOS
CREATE OR ALTER PROCEDURE LogicaBD.sp_Informe06 
( @nombreConsorcio VARCHAR(100) = NULL, 
@piso CHAR(2) = NULL, 
@departamento CHAR(1) = NULL ) 
AS BEGIN
SELECT 
    c.nombre as [consorcio], 
    CONCAT(TRIM(uf.piso), '-', uf.departamento) AS [piso_depto], 
    sub1.fecha, 
    ISNULL( 
        DATEDIFF( 
            DAY, 
            LAG(sub1.fecha,1,null) OVER (PARTITION BY idUF ORDER BY idUF, fecha), 
            sub1.fecha )
        ,0) as [dias_entre_pagos] 
    FROM ( 
        SELECT 
            pg.idUF, 
            ex.idConsorcio, 
            ex.totalGastoOrdinario, 
            pg.fecha, 
            ex.periodo 
        FROM Gastos.Expensa as ex INNER JOIN ( 
            SELECT 
                *, 
                ROW_NUMBER() 
                    OVER (PARTITION BY fecha, idUF, idExpensa ORDER BY fecha) AS NroPago FROM Finanzas.Pagos ) AS pg 
        ON ex.id = pg.idExpensa 
        WHERE pg.NroPago = 1 ) AS sub1 
        INNER JOIN Infraestructura.UnidadFuncional as uf 
            ON sub1.idUF = uf.id
        INNER JOIN Administracion.Consorcio as c 
            ON sub1.idConsorcio = c.id 
        WHERE 
            (@departamento IS NULL OR LOWER(@departamento) = uf.departamento) AND 
            (@piso IS NULL OR LOWER(@piso) = uf.piso) AND 
            (@nombreConsorcio IS NULL OR @nombreConsorcio = c.nombre) 
        ORDER BY sub1. idUF, sub1.periodo, sub1.fecha 

END 
GO 

EXEC LogicaBD.CreacionIndicesAuxiliares




