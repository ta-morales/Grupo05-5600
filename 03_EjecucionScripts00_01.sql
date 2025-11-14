  /*
  Nombre: 03_EjecucionScripts00_01.sql
  Proposito: Ejecutables de los SP de importacion.
  Script a ejecutar antes: 01_SPImportacionDatos.sql
  */


/* ============================ Ejecución con rutas locales ============================ */
USE Com5600G05
GO

DECLARE @ruta VARCHAR(200) = 'C:\SQL_SERVER_IMPORTS'

EXEC LogicaBD.sp_InsertaConsorcioProveedor
	@rutaArchivo = @ruta,
	@nombreArchivo = 'datos varios.xlsx';

EXEC LogicaBD.sp_InsertarUnidadesFuncionales
  @rutaArchivo = @ruta,
  @nombreArchivo = 'UF por consorcio.txt'

EXEC LogicaBD.sp_ImportarInquilinosPropietarios
  @rutaArchivo = @ruta,
  @nombreArchivo = 'Inquilino-propietarios-UF.csv';

EXEC LogicaBD.sp_ImportarDatosInquilinos
  @rutaArchivo = @ruta,
  @nombreArchivo = 'Inquilino-propietarios-datos.csv';

EXEC LogicaBD.sp_ImportarGastosOrdinarios
  @rutaArchivo = @ruta,
  @nombreArchivo = 'Servicios.Servicios.json';

EXEC LogicaBD.sp_GenerarExpensa

EXEC LogicaBD.sp_ImportarPagos
  @rutaArchivo = @ruta,
  @nombreArchivo = 'pagos_consorcios.csv';

-- Esto es para generar mejor el detalle
/*
WITH cteGastos AS
(
    SELECT  
        ex.id AS ex,
        uf.id AS uf,
        ex.periodo,
        ex.totalGastoOrdinario,
        ex.totalGastoExtraordinario,
        (ex.totalGastoOrdinario + ex.totalGastoExtraordinario) AS sumaGastos,
        (uf.porcentajeParticipacion / 100.0) AS Mult,
        ((ex.totalGastoOrdinario + ex.totalGastoExtraordinario) * (uf.porcentajeParticipacion / 100.0)) AS MontoBase,
        CASE WHEN uf.m2Cochera > 0 THEN 50000 ELSE 0 END AS MontoCochera,
        CASE WHEN uf.m2Baulera > 0 THEN 50000 ELSE 0 END AS MontoBaulera
    FROM Gastos.Expensa AS ex
    INNER JOIN Infraestructura.UnidadFuncional AS uf
        ON ex.idConsorcio = uf.idConsorcio
)

SELECT 
    sub1.*, 
    (   sub1.MontoBase +
        LAG(sub1.Deuda,1,0) OVER (PARTITION BY sub1.idExp, sub1.idUf, sub1.periodo ORDER BY sub1.idExp, sub1.idUf, sub1.periodo) +
        LAG(sub1.Intereses,1,0) OVER (PARTITION BY sub1.idExp, sub1.idUf, sub1.periodo ORDER BY sub1.idExp, sub1.idUf, sub1.periodo) 
    ) AS 'MontoTotal'
FROM (
    SELECT 
        cte.ex 'idExp',
        cte.uf 'idUf',
        cte.periodo 'periodo',
        CAST( cte.MontoBase AS DECIMAL(12,2) ) as 'MontoBase',
        CAST( cte.MontoCochera AS DECIMAL(12,2) ) as 'Cochera',
        CAST( cte.MontoBaulera AS DECIMAL(12,2) ) as 'Baulera' ,
        SUM(pg.monto) AS TotalPagado,
        CAST( ((cte.MontoBase + cte.MontoCochera + cte.MontoBaulera) -  SUM(pg.monto)) AS DECIMAL(12,2) ) AS 'Deuda',
        CASE
            WHEN CAST( (((cte.MontoBase + cte.MontoCochera + cte.MontoBaulera) -  SUM(pg.monto)) * mult) AS DECIMAL(12,2) ) < 0
                THEN 0
            ELSE CAST( (((cte.MontoBase + cte.MontoCochera + cte.MontoBaulera) -  SUM(pg.monto)) * mult) AS DECIMAL(12,2) ) 
        END AS 'Intereses'
    FROM cteGastos AS cte
    INNER JOIN Finanzas.Pagos AS pg
        ON pg.idExpensa = cte.ex AND pg.idUF = cte.uf
    GROUP BY
        cte.ex,
        cte.uf,
        cte.periodo,
        cte.totalGastoOrdinario,
        cte.totalGastoExtraordinario,
        cte.sumaGastos,
        cte.Mult,
        cte.MontoBase,
        cte.MontoCochera,
        cte.MontoBaulera
    ) AS sub1
GO
*/

