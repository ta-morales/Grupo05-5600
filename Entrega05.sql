  /*
  Nombre: Entrega05.sql
  Proposito: Creacion de reportes/informes de pagos y gastos.
  Script a ejecutar antes: 00_CreacionDeTablas.sql
  */



USE Com5600G05
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
END;
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
END;
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

-- CODIGO PARA INFORME 01: PAGOS ORDINARIOS Y EXTRAORDINARIOS POR SEMANA
CREATE OR ALTER PROCEDURE sp_Informe01
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
    FROM Finanzas.Pagos;
    
    WITH cteTiposPagos AS
    (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY fecha, idUF, idExpensa ORDER BY fecha) AS NroPago
        FROM Finanzas.Pagos
    )
    SELECT
        DATEPART(WEEK, fecha) AS NSem,
        c.nombre as 'Consorcio',
        CONCAT(TRIM(uf.piso), '-', uf.departamento) as 'Piso - Depto.',
        SUM(CASE WHEN NroPago = 1 THEN monto ELSE 0 END) AS PagosOrdinarios,
        SUM(CASE WHEN NroPago > 1 THEN monto ELSE 0 END) AS PagosExtraordinarios
    FROM cteTiposPagos AS cte
    LEFT JOIN Infraestructura.UnidadFuncional AS uf ON cte.idUF = uf.id
    LEFT JOIN Administracion.Consorcio AS c ON uf.idConsorcio = c.id
    WHERE MONTH(fecha) BETWEEN @mesIni AND @mesFin
      AND (@nombreConsorcio IS NULL OR c.nombre = @nombreConsorcio)
      AND (@piso IS NULL OR RTRIM(CAST(uf.piso  AS CHAR(2))) = @piso)
      AND (@departamento IS NULL OR RTRIM(UPPER(uf.departamento)) = @departamento)
    GROUP BY DATEPART(WEEK, fecha), c.nombre, CONCAT(TRIM(uf.piso), '-', uf.departamento)
END

GO

-- CODIGO PARA INFORME 02: PIVOT DE MES Y PAGOS
CREATE OR ALTER PROCEDURE sp_Informe02
@consorcio VARCHAR(100) = NULL,
@piso CHAR(2) = NULL,
@depto CHAR(1) = NULL
AS
BEGIN
    WITH ctePagosMes AS
    (
        SELECT 
            MONTH(pg.fecha) AS mes, 
            c.nombre AS 'Consorcio',
            CONCAT(TRIM(uf.piso), '-', uf.departamento) AS 'Depto', 
            pg.monto as 'Monto'
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
        Consorcio,
        Depto,
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
    ORDER BY Consorcio, Depto;
END
GO

IF OBJECT_ID('sp_Informe03', 'P') IS NOT NULL
    DROP PROCEDURE sp_Informe03;
GO

-- CODIGO PARA INFORME 03: PIVOT DE MES Y TIPO DE GASTO
CREATE PROCEDURE sp_Informe03
AS
BEGIN       
    SET NOCOUNT ON
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
        ISNULL([Ordinario], 0) AS [Pagos ordinarios],
        ISNULL([Extraordinario], 0) AS [Pagos extraordinarios],
        (ISNULL([Ordinario],0) + ISNULL([Extraordinario],0)) AS [Pagos totales]
    FROM cteTiposPagos AS cte
    PIVOT (
        sum(monto)
        FOR [Tipo Pago] IN ([Ordinario], [Extraordinario])
    ) as p
END
GO

CREATE OR ALTER PROCEDURE sp_Informe04
( 
    @fechaInicio DATE = NULL,
    @fechaFin DATE = NULL,
    @nombreConsorcio VARCHAR(100) = NULL
)
AS
BEGIN
    DECLARE @idConsorcio INT = NULL;

    IF @nombreConsorcio IS NOT NULL
    BEGIN
        SELECT TOP 1 @idConsorcio = id 
        FROM Administracion.Consorcio 
        WHERE LOWER(nombre) = LOWER(@nombreConsorcio);
    END

    SELECT 
        ex.periodo,
        (totalGastoExtraordinario + totalGastoOrdinario) as [Gastos],
        ing.[Ingresos]
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
     ORDER BY periodo
END
GO

EXEC sp_Informe01

EXEC sp_Informe01 @mesInicio = 4, @mesFinal = 5, @nombreConsorcio = 'Azcuenaga', @piso = 'PB', @departamento = 'E'

EXEC sp_Informe02

EXEC sp_Informe03

EXEC sp_Informe04 @nombreConsorcio = 'azcuenaga'
