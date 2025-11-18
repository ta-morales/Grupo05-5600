  /*
  Nombre: Deudas.sql
  Proposito: Crear funciones y consulta para calcular deudas/intereses por UF y expensa.
  Script a ejecutar antes: 00_CreacionDeTablas.sql
  */


USE Com5600G05
GO

-- Suma pagos de una UF entre dos fechas
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

-- Suma pagos de una UF entre dos fechas
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
		(ex.totalGastoExtraordinario + ex.totalGastoOrdinario) * (uf.dimension/con.metrosTotales)
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
	INNER JOIN Administracion.Consorcio con ON con.id = uf.idConsorcio
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
    LAG([DeudaSegVenc], 1, 0) OVER (PARTITION BY [ID UF] ORDER BY [ID EX]) AS [Deuda],
    LAG([InteresSegundaDeuda], 1, 0) OVER (PARTITION BY [ID UF] ORDER BY [ID EX]) AS [Interes],
	(
        LAG([NuevoMontoSV], 1, 0) OVER (PARTITION BY [ID UF] ORDER BY [ID EX])
	-	LAG([Pagado_S_F], 1, 0) OVER (PARTITION BY [ID UF] ORDER BY [ID EX])
	+	[Monto Base]
	) as [Total a Pagar]
FROM cteFormateoDeuda
WHERE [ID UF] = 1


SELECT * FROM Gastos.Expensa
SELECT * FROM Gastos.DetalleExpensa


SELECT * 
FROM Finanzas.Pagos
WHERE idUF = 1
ORDER BY fecha



CREATE OR ALTER PROCEDURE LogicaBD.sp_GenerarDetalles
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @tasa_venc1 DECIMAL(10,6) = 0.02;  -- 2%
	DECLARE @tasa_venc2 DECIMAL(10,6) = 0.05;  -- 5%

	WITH cteDeudaAPrimerVenc AS
	(
		SELECT 
			uf.id as [ID UF], 
			ex.id as [ID EX], 
			(ex.totalGastoExtraordinario + ex.totalGastoOrdinario) * (uf.dimension/con.metrosTotales) AS [Total Base],
			(
				(ex.totalGastoExtraordinario + ex.totalGastoOrdinario) * (uf.dimension / con.metrosTotales)
				+ CASE WHEN uf.m2Cochera > 0 THEN 50000 ELSE 0 END
				+ CASE WHEN uf.m2Baulera > 0 THEN 50000 ELSE 0 END
			) AS [Total],
			LogicaBD.sumarPagosEntreFechas(
				DATEADD(DAY, 5 - DAY(ex.primerVencimiento), ex.primerVencimiento),
				ex.primerVencimiento,
				uf.id
			) AS [MontoPagadoHastaPrimVenc],
			primerVencimiento,
			segundoVencimiento,
			CASE WHEN uf.m2Cochera > 0 THEN 50000 ELSE 0 END as MontoCochera,
			CASE WHEN uf.m2Baulera > 0 THEN 50000 ELSE 0 END as MontoBaulera
		FROM Gastos.Expensa as ex 
        INNER JOIN Infraestructura.UnidadFuncional AS uf
            ON ex.idConsorcio = uf.idConsorcio
        INNER JOIN Administracion.Consorcio con
            ON con.id = uf.idConsorcio
	),
	cteDeudaASegVenc AS		
	(
		SELECT
			[ID UF],
			[ID EX],
			[Total Base],
			Total,
			[MontoPagadoHastaPrimVenc],
			(Total - [MontoPagadoHastaPrimVenc]) [deudaPrimerVenc],
			CASE 
				WHEN Total - [MontoPagadoHastaPrimVenc] > 0 
					THEN (Total - [MontoPagadoHastaPrimVenc]) * @tasa_venc1
				ELSE 0 
			END AS [interesPrimerVenc],
			CASE 
				WHEN Total - [MontoPagadoHastaPrimVenc] > 0 
					THEN (Total - [MontoPagadoHastaPrimVenc]) * (1 + @tasa_venc1)
				ELSE (Total - [MontoPagadoHastaPrimVenc])  -- si deuda <= 0, queda igual
			END AS [montoPagarEnPrimerVenc],
			LogicaBD.sumarPagosEntreFechas(
				DATEADD(DAY, 1, primerVencimiento),
				segundoVencimiento,
				[ID UF]
			) AS [MontoPagadoEntrePrimVencSegVenc],
			primerVencimiento,
			segundoVencimiento,
			MontoCochera,
			MontoBaulera
		FROM cteDeudaAPrimerVenc
	),
	cteDeudaFinal AS
	(
		SELECT
			[ID UF],
			[ID EX],
			[MontoPagadoHastaPrimVenc],
			[Total Base],
			Total,
			[deudaPrimerVenc],
			[interesPrimerVenc],
			[montoPagarEnPrimerVenc],
			[MontoPagadoEntrePrimVencSegVenc],
			([montoPagarEnPrimerVenc] - [MontoPagadoEntrePrimVencSegVenc]) as [deudaSegVenc],
			CASE 
				WHEN [montoPagarEnPrimerVenc] - [MontoPagadoEntrePrimVencSegVenc] > 0 
					THEN ([montoPagarEnPrimerVenc] - [MontoPagadoEntrePrimVencSegVenc]) * @tasa_venc2
				ELSE 0 
			END AS [InteresSegVenc],
			CASE 
				WHEN [montoPagarEnPrimerVenc] - [MontoPagadoEntrePrimVencSegVenc] > 0 
					THEN ([montoPagarEnPrimerVenc] - [MontoPagadoEntrePrimVencSegVenc]) * (1 + @tasa_venc2)
				ELSE ([montoPagarEnPrimerVenc] - [MontoPagadoEntrePrimVencSegVenc])
			END AS [montoPagarEnSegVenc],
			LogicaBD.sumarPagosEntreFechas(
				DATEADD(DAY, 1, segundoVencimiento),
				DATEADD(
					MONTH,
					1,
					DATEADD(DAY, 4 - DAY(segundoVencimiento), segundoVencimiento) -- 5 del mes siguiente
				),
				[ID UF]
			) AS [MontoPagadoEntreSegVencFinMes],
			MontoCochera,
			MontoBaulera
		FROM cteDeudaASegVenc
	),
	cteFormateoDeuda AS
	(
		SELECT 
			[ID UF],
			[ID EX],
			CAST([Total Base] AS DECIMAL(10,2)) AS [Monto Base],
			CAST(Total AS DECIMAL(10, 2)) AS Total,
			CAST([MontoPagadoHastaPrimVenc] AS DECIMAL(10,2)) as [PagadoI_P_V],
			CAST([deudaPrimerVenc] AS DECIMAL(10,2)) as [DeudaPrimerVenc],
			CAST([interesPrimerVenc] AS DECIMAL(10,2)) as [InteresPrimerDeuda],
			CAST([montoPagarEnPrimerVenc] AS DECIMAL(10,2)) as [NuevoMontoPV],
			CAST([MontoPagadoEntrePrimVencSegVenc] AS DECIMAL(10,2)) as [PagadoP_S_V],
			CAST([deudaSegVenc] AS DECIMAL(10,2)) as [DeudaSegVenc],
			CAST([InteresSegVenc] AS DECIMAL(10,2)) as [InteresSegundaDeuda],
			CAST([montoPagarEnSegVenc] AS DECIMAL(10,2)) [NuevoMontoSV],
			CAST([MontoPagadoEntreSegVencFinMes] AS DECIMAL(10,2)) [Pagado_S_F],
			MontoCochera,
			MontoBaulera
		FROM cteDeudaFinal
	),
	cteArrastre AS
	(
		SELECT
			fd.*,
			LAG([NuevoMontoSV] - [Pagado_S_F], 1, 0) OVER (PARTITION BY [ID UF] ORDER BY [ID EX]) AS SaldoArrastrado,
			LAG([InteresPrimerDeuda] + [InteresSegundaDeuda], 1, 0) OVER (PARTITION BY [ID UF] ORDER BY [ID EX]) AS InteresArrastrado
			FROM cteFormateoDeuda fd
	)

	INSERT INTO Gastos.DetalleExpensa
		(montoBase, deuda, saldoAFavor, intereses, montoCochera, montoBaulera, montoTotal, idExpensa, idUF, estado)
	SELECT
		[Monto Base],
		CASE 
			WHEN SaldoArrastrado > 0 THEN SaldoArrastrado
			ELSE 0
		END AS Deuda,
		CASE 
			WHEN SaldoArrastrado < 0 THEN -SaldoArrastrado
			ELSE 0
		END AS saldoAFavor,
		InteresArrastrado AS intereses,
		MontoCochera,
		MontoBaulera,
		Total AS montoTotal,
		[ID EX],
		[ID UF],
		CASE
			WHEN (SaldoArrastrado + InteresArrastrado + Total) <= 0 THEN 'P'
			ELSE 'D'
		END AS estado
	FROM cteArrastre a

END
GO

IF OBJECT_ID('Gastos.DetalleExpensa', 'U') IS NULL
BEGIN
    CREATE TABLE Gastos.DetalleExpensa (
        id INT IDENTITY(1,1),
        montoBase DECIMAL(10,2),
		saldoAFavor DECIMAL(10, 2),
        deuda DECIMAL(10,2),
        intereses DECIMAL (10,2),
        montoCochera DECIMAL(8,2),
        montoBaulera DECIMAL(8,2),
        montoTotal DECIMAL(20,2),
        estado CHAR(1) NOT NULL CHECK (estado IN ('P', 'E', 'D')),
        idExpensa INT,
        idUF INT,
        CONSTRAINT pk_DetalleExpensa PRIMARY KEY (id),
        CONSTRAINT fk_Detalle_Expensa FOREIGN KEY (idExpensa) REFERENCES Gastos.Expensa(id),
        CONSTRAINT fk_Detalle_UF FOREIGN KEY (idUF) REFERENCES Infraestructura.UnidadFuncional(id)
    )
END



