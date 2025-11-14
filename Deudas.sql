  /*
  Nombre: Deudas.sql
  Proposito: Crear funciones y consulta para calcular deudas/intereses por UF y expensa.
  Script a ejecutar antes: 00_CreacionDeTablas.sql
  */


USE Com5600G05
GO

CREATE OR ALTER FUNCTION LogicaBD.sumarPagosEntreFechas
(
    @fechaIni DATE,
    @fechaFin DATE,
    @uf INT
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @total DECIMAL(18,2);

    SELECT @total = ISNULL(SUM(pg.monto), 0)
    FROM Finanzas.Pagos AS pg
    WHERE pg.fecha BETWEEN @fechaIni AND @fechaFin AND pg.idUF = @uf

    RETURN @total;
END;
GO

CREATE OR ALTER FUNCTION LogicaBD.sumarPagosHastaFecha
(
    @fechaLimite DATE,
    @uf INT
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @total DECIMAL(18,2);

    SELECT @total = ISNULL(SUM(pg.monto), 0)
    FROM Finanzas.Pagos AS pg
    WHERE pg.fecha < @fechaLimite AND pg.idUF = @uf

    RETURN @total;
END;
GO

DECLARE @tasa_venc1 DECIMAL(9,6) = 0.02;  -- 2%
DECLARE @tasa_venc2 DECIMAL(9,6) = 0.05;  -- 5%


WITH cteDeudaAPrimerVenc AS
(
	SELECT 
		uf.id as [ID UF], 
		ex.id as [ID EX], 
		(
		(ex.totalGastoExtraordinario + ex.totalGastoOrdinario) * (uf.porcentajeParticipacion/100)
		+ CASE WHEN uf.m2Cochera > 0 THEN 50000 ELSE 0 END
		+ CASE WHEN uf.m2Baulera > 0 THEN 50000 ELSE 0 END
		) AS [Total Base],
		LogicaBD.sumarPagosEntreFechas(
			DATEADD(DAY, 1 - DAY(ex.primerVencimiento), ex.primerVencimiento),
			ex.primerVencimiento,
			uf.id
		) AS [Monto],
		primerVencimiento,
		segundoVencimiento
	FROM Gastos.Expensa as ex INNER JOIN Infraestructura.UnidadFuncional AS uf
		ON ex.idConsorcio = uf.idConsorcio
),
cteDeudaASegVenc AS 
(
	SELECT
		[ID UF],
		[ID EX],
		[Total Base],
		[Monto],
		([Total Base] - [Monto]) [deudaPrimerVenc],
		(([Total Base] - [Monto]) * @tasa_venc1) as [interesPrimerVenc],
		(([Total Base] - [Monto]) * (1+@tasa_venc1))as [montoPagarPostPrimerVenc],
		LogicaBD.sumarPagosEntreFechas(
			primerVencimiento,
			segundoVencimiento,
			[ID UF]
		) AS [MontoPagadoHastaSegVenc],
		primerVencimiento,
		segundoVencimiento
	FROM cteDeudaAPrimerVenc
),
cteDeudaFinal AS
(
	SELECT
		[ID UF],
		[ID EX],
		[Monto],
		[Total Base],
		[deudaPrimerVenc],
		[interesPrimerVenc],
		[montoPagarPostPrimerVenc],
		[MontoPagadoHastaSegVenc],
		([montoPagarPostPrimerVenc] - [MontoPagadoHastaSegVenc]) as [deudaSegVenc],
		(([montoPagarPostPrimerVenc] - [MontoPagadoHastaSegVenc]) * @tasa_venc2) as [InteresSegVenc],
		(([montoPagarPostPrimerVenc] - [MontoPagadoHastaSegVenc]) * (1+@tasa_venc2)) as [montoPagarPostSegVenc],
		LogicaBD.sumarPagosEntreFechas(
			segundoVencimiento,
			EOMONTH(segundoVencimiento),
			[ID UF]
		) AS [MontoPagadoHastaFinMes]
	FROM cteDeudaASegVenc
),
cteFormateoDeuda AS
(
	SELECT 
		[ID UF],
		[ID EX],
		CAST([Total Base] AS DECIMAL(10,2)) AS [Monto Base],
		CAST([Monto] AS DECIMAL(10,2)) as [PagadoI_P_V],
		CAST([deudaPrimerVenc] AS DECIMAL(10,2)) as [DeudaPrimerVenc],
		CAST([interesPrimerVenc] AS DECIMAL(10,2)) as [InteresPrimerDeuda],
		CAST([montoPagarPostPrimerVenc] AS DECIMAL(10,2)) as [NuevoMontoPV],
		CAST([MontoPagadoHastaSegVenc] AS DECIMAL(10,2)) as [PagadoP_S_V],
		CAST([deudaSegVenc] AS DECIMAL(10,2)) as [DeudaSegVenc],
		CAST([InteresSegVenc] AS DECIMAL(10,2)) as [InteresSegundaDeuda],
		CAST([montoPagarPostSegVenc] AS DECIMAL(10,2)) [NuevoMontoSV],
		CAST([MontoPagadoHastaFinMes] AS DECIMAL(10,2)) [Pagado_S_F]
	FROM cteDeudaFinal
)

SELECT 
	[ID UF],
	[ID EX],
	[Monto Base],
	LAG([DeudaSegVenc], 1, 0) OVER (PARTITION BY [ID UF] ORDER BY [ID UF]) AS [Deuda],
	LAG([InteresSegundaDeuda], 1, 0) OVER (PARTITION BY [ID UF] ORDER BY [ID UF]) AS [Interes],
	(
		LAG([NuevoMontoSV], 1, 0) OVER (PARTITION BY [ID UF] ORDER BY [ID UF])
	-	LAG([Pagado_S_F], 1, 0) OVER (PARTITION BY [ID UF] ORDER BY [ID UF])
	+	[Monto Base]
	) as [Total a Pagar]
FROM cteFormateoDeuda
