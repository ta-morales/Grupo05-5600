USE Grupo05_5600
GO

EXECUTE sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

EXECUTE sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
GO

/* ======================== Funciones de Normalización ======================== */
IF SCHEMA_ID('LogicaNormalizacion') IS NULL EXEC('CREATE SCHEMA LogicaNormalizacion');
IF SCHEMA_ID('LogicaBD') IS NULL EXEC('CREATE SCHEMA LogicaBD');
GO

CREATE OR ALTER FUNCTION LogicaNormalizacion.fn_NormalizarNombreArchivoCSV
(
    @nombreArchivo VARCHAR(100),
    @extension VARCHAR(5) 
)
RETURNS VARCHAR(100)
AS
BEGIN
    DECLARE 
        @nom VARCHAR(100) = LTRIM(RTRIM(@nombreArchivo)),
        @ext VARCHAR(5) = LOWER(LTRIM(RTRIM(@extension)));

    IF @nom IS NULL OR @ext IS NULL OR @ext = ''
        RETURN '';

    IF LEFT(@ext,1) = '.'
        SET @ext = STUFF(@ext,1,1,'');

    IF LOWER(RIGHT(@nom, LEN(@ext) + 1)) = '.' + @ext
        RETURN @nom;

    IF CHARINDEX('.', @nom) > 0
        RETURN '';

    RETURN @nom + '.' + @ext;
END
GO

CREATE OR ALTER FUNCTION LogicaNormalizacion.fn_NormalizarRutaArchivo
( @rutaArchivo VARCHAR(100) )
RETURNS VARCHAR(100)
AS
BEGIN
    DECLARE @ruta VARCHAR(100)

    SET @ruta = LTRIM(RTRIM(@rutaArchivo));
    IF @ruta IS NULL OR @ruta = '' RETURN '';

    IF LEFT(@ruta,1) = '"' AND RIGHT(@ruta,1) = '"'
        SET @ruta = SUBSTRING(@ruta, 2, LEN(@ruta)-2);

    SET @ruta = REPLACE(@ruta, '/', '\');

    WHILE LEN(@ruta) > 0 AND RIGHT(@ruta,1) = '\'
        SET @ruta = LEFT(@ruta, LEN(@ruta)-1);

    SET @ruta = @ruta + '\';
    RETURN @ruta;
END
GO

CREATE OR ALTER FUNCTION LogicaNormalizacion.fn_NumeroMes
( @mes VARCHAR(15) )
RETURNS INT
AS
BEGIN
    DECLARE @numeroMes INT
    SET @mes = LOWER(LTRIM(RTRIM(@mes)));
    SET @numeroMes = CASE @mes
        WHEN 'enero' THEN 1
        WHEN 'febrero' THEN 2
        WHEN 'marzo' THEN 3
        WHEN 'abril' THEN 4
        WHEN 'mayo' THEN 5
        WHEN 'junio' THEN 6
        WHEN 'julio' THEN 7
        WHEN 'agosto' THEN 8
        WHEN 'septiembre' THEN 9
        WHEN 'octubre' THEN 10
        WHEN 'noviembre' THEN 11
        WHEN 'diciembre' THEN 12
        ELSE NULL
    END
    RETURN @numeroMes
END
GO

CREATE OR ALTER FUNCTION LogicaNormalizacion.fn_ToDecimal
(
    @s VARCHAR(200)
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE 
        @n    VARCHAR(200) = NULLIF(LTRIM(RTRIM(@s)), ''),
        @rev  VARCHAR(200),
        @iDot INT,
        @iCom INT,
        @tmp  VARCHAR(200);

    IF @n IS NULL RETURN NULL;

    SET @n = REPLACE(@n, ' ', '');
    SET @n = REPLACE(@n, CHAR(9), '');
    SET @n = REPLACE(@n, '$',  '');
    SET @n = REPLACE(@n, '''', '');

    SET @rev = REVERSE(@n);
    SET @iDot = CHARINDEX('.', @rev);
    SET @iCom = CHARINDEX(',', @rev);

    IF (@iDot = 0 AND @iCom = 0)
    BEGIN
        SET @tmp = REPLACE(REPLACE(@n, '.', ''), ',', '');
    END
    ELSE IF (@iDot = 0)
    BEGIN
        SET @tmp = REPLACE(@n, '.', '');
        SET @tmp = REPLACE(@tmp, ',', '.');
    END
    ELSE IF (@iCom = 0)
    BEGIN
        SET @tmp = REPLACE(@n, ',', '');
    END
    ELSE
    BEGIN
        IF (@iDot < @iCom)
        BEGIN
            SET @tmp = REPLACE(@n, ',', '');
        END
        ELSE
        BEGIN
            SET @tmp = REPLACE(@n, '.', '');
            SET @tmp = REPLACE(@tmp, ',', '.');
        END
    END

    RETURN TRY_CONVERT(DECIMAL(10,2), @tmp);
END
GO

/* =============================== Triggers =============================== */
CREATE OR ALTER TRIGGER Gastos.tg_CrearDetalleExpensa 
ON Gastos.Expensa
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #auxiliarGastos (
        idConsorcio int,
        idExpensa INT,
        idUF INT,
        periodo CHAR(6),
        monto DECIMAL(12,2),
        mtsTotEd DECIMAL(8,2),
        coeficienteUF DECIMAL(5,2),
        mtsCochera DECIMAL(5,2),
        mtsBaulera DECIMAL(5,2)
    );

    INSERT INTO #auxiliarGastos (idConsorcio, idExpensa, idUF, periodo, monto, mtsTotEd, coeficienteUF, mtsCochera, mtsBaulera)
    SELECT
        i.idConsorcio,  
        i.id, 
        uf.id, 
        i.periodo, 
        (i.totalGastoExtraordinario + i.totalGastoOrdinario) as monto, 
        c.metrosTotales, 
        uf.porcentajeParticipacion, 
        uf.m2Cochera, 
        uf.m2Baulera
    FROM inserted i 
    INNER JOIN Administracion.Consorcio c	ON i.idConsorcio = c.id
    INNER JOIN Infraestructura.UnidadFuncional uf	ON uf.idConsorcio = c.id;

    ;WITH ctePagos AS
    (
        SELECT 
            pg.idExpensa AS idExp, 
            pg.idUF AS idUF, 
            CONCAT(
                RIGHT('0' + CAST(MONTH(pg.fecha) AS VARCHAR(2)),2), 
                CAST(YEAR(pg.fecha) AS VARCHAR(4))
            ) AS Periodo,
            SUM(pg.monto) as MontoPagado
        FROM Finanzas.Pagos pg
        WHERE EXISTS (SELECT 1 FROM inserted i WHERE i.id = pg.idExpensa)
        GROUP BY 
            pg.idExpensa, 
            pg.idUF, 
            CONCAT(
                RIGHT('0' + CAST(MONTH(pg.fecha) AS VARCHAR(2)),2), 
                CAST(YEAR(pg.fecha) AS VARCHAR(4))
            ) 
    ), cteCalc AS (
        SELECT
            g.idExpensa,
            g.idUF,
            g.periodo,
            CAST(g.monto * (g.coeficienteUF/100.0) AS DECIMAL (12,2)) AS MontoBase,
            CASE WHEN g.mtsCochera > 0 THEN 50000 ELSE 0 END AS MontoCochera,
            CASE WHEN g.mtsBaulera > 0 THEN 50000 ELSE 0 END AS MontoBaulera,
            COALESCE(p.MontoPagado, 0)  AS MontoPagado
        FROM #auxiliarGastos g
        LEFT JOIN ctePagos p	ON p.idExp = g.idExpensa AND p.idUF = g.idUF
    )

    INSERT INTO Gastos.DetalleExpensa
    (montoBase, deuda, intereses, montoCochera, montoBaulera, montoTotal, estado, idExpensa, idUF)
    SELECT
        MontoBase,
        CASE WHEN (MontoBase + MontoCochera + MontoBaulera) > MontoPagado
                THEN (MontoBase + MontoCochera + MontoBaulera) - MontoPagado ELSE 0 END AS Deuda,
        CASE WHEN (MontoBase + MontoCochera + MontoBaulera) > MontoPagado
                THEN CAST(((MontoBase + MontoCochera + MontoBaulera) - MontoPagado) * 0.05 AS DECIMAL(12,2)) ELSE 0 END AS Intereses,
        MontoCochera,
        MontoBaulera,
        CAST(MontoBase + MontoCochera + MontoBaulera AS DECIMAL(12,2)) AS MontoTotal,
        'P',
        idExpensa,
        idUF
    FROM cteCalc;

    DROP TABLE #auxiliarGastos
END
GO

/* =============================== Procedimientos =============================== */
CREATE OR ALTER PROCEDURE LogicaBD.sp_InsertarEnConsorcio 
@rutaArchivo VARCHAR(100),
@nombreArchivo VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
        @ruta     VARCHAR(100) = LogicaNormalizacion.fn_NormalizarRutaArchivo(@rutaArchivo),
        @archivo  VARCHAR(100) = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivo, 'xlsx'),
        @fullpath VARCHAR(200),
        @sql      NVARCHAR(MAX);

    IF (@ruta = '' OR @archivo = '')
        RETURN;

    SET @fullpath = REPLACE(@ruta + @archivo, '''', '''''');

    IF OBJECT_ID('tempdb..#ConsorciosStage') IS NOT NULL DROP TABLE #ConsorciosStage;
    CREATE TABLE #ConsorciosStage(
		consorcio VARCHAR(200),
        nombre        VARCHAR(200),
        domicilio     VARCHAR(200),
		cantidadUF VARCHAR(50),
        metrosTotales VARCHAR(100)
    );


    SET @sql = N'
    INSERT INTO #ConsorciosStage 
    SELECT *
    FROM OPENROWSET(''Microsoft.ACE.OLEDB.16.0'',
            ''Excel 12.0;HDR=NO;Database=' + @fullpath + N''',
            ''SELECT * FROM [Consorcios$]'');';
    EXEC sp_executesql @sql;

   
    -- Limpieza básica
    UPDATE #ConsorciosStage
    SET nombre        = LTRIM(RTRIM(nombre)),
        domicilio     = LTRIM(RTRIM(domicilio)),
        metrosTotales = LTRIM(RTRIM(metrosTotales));

    DELETE FROM #ConsorciosStage
    WHERE nombre IS NULL OR domicilio IS NULL OR metrosTotales IS NULL OR TRY_CONVERT(INT, cantidadUF) < 10;

    -- Conversión y carga
    INSERT INTO Administracion.Consorcio (nombre, direccion, metrosTotales)
    SELECT 
        LEFT(s.nombre, 100),
        LEFT(s.domicilio, 100),
        CAST(LogicaNormalizacion.fn_ToDecimal(s.metrosTotales) AS DECIMAL(8,2))
    FROM #ConsorciosStage s; 

    	SET @fullpath = REPLACE(@ruta + @archivo, '''', '''''');

	IF OBJECT_ID('tempdb..##datosProveedores') IS NOT NULL DROP TABLE ##datosProveedores;
	CREATE TABLE ##datosProveedores (
        tipoGasto varchar(100),
        empresa varchar(100),
        cuentaBancaria varchar(100),
        consorcio varchar(100)
    );

	SET @sql = N'
    INSERT INTO ##datosProveedores 
    SELECT *
    FROM OPENROWSET(''Microsoft.ACE.OLEDB.16.0'',
            ''Excel 12.0;HDR=NO;Database=' + @fullpath + N''',
            ''SELECT * FROM [Proveedores$]'');';
    EXEC sp_executesql @sql;

    DELETE FROM ##datosProveedores
    WHERE tipoGasto IS NULL
END
GO

CREATE OR ALTER PROCEDURE LogicaBD.sp_ImportarInquilinosPropietarios
@rutaArchivo VARCHAR(100),
@nombreArchivo VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
            @ruta VARCHAR(100) = LogicaNormalizacion.fn_NormalizarRutaArchivo(@rutaArchivo),
            @archivo VARCHAR(100) = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivo, 'csv');
    
    IF (@ruta IS NULL OR @ruta = '' OR @archivo = '')
    BEGIN
        RETURN;
    END;

    DECLARE @rutaArchivoCompleto VARCHAR(200) = REPLACE(@ruta + @archivo, '''', '''''');

    IF OBJECT_ID('tempdb..##temporalInquilinosPropietariosCSV') IS NOT NULL
    BEGIN
        DROP TABLE ##temporalInquilinosPropietariosCSV
    END

    CREATE TABLE ##temporalInquilinosPropietariosCSV (
        cvu VARCHAR(100),
        consorcio VARCHAR(100),
        nroUF VARCHAR(5),
        piso VARCHAR(5),
        dpto VARCHAR(5)
    )

    DECLARE @sql NVARCHAR(MAX) = N'
        BULK INSERT ##temporalInquilinosPropietariosCSV
        FROM ''' + @rutaArchivoCompleto + '''
        WITH (
            FIELDTERMINATOR = ''|'',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''65001'',
            FIRSTROW = 2
        )';
    
    EXEC sp_executesql @sql;
END
GO

CREATE OR ALTER PROCEDURE LogicaBD.sp_InsertarUnidadesFuncionales
  @rutaArchivo VARCHAR(100),
  @nombreArchivo VARCHAR(100)
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @ruta VARCHAR(100) = LogicaNormalizacion.fn_NormalizarRutaArchivo(@rutaArchivo),
          @archivo VARCHAR(100) = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivo, 'txt');

  IF (@ruta = '' OR @archivo = '')
  BEGIN
    RETURN;
  END;

  DECLARE @rutaArchivoCompleto VARCHAR(200) = REPLACE(@ruta + @archivo, '''', '''''');

  IF OBJECT_ID('tempdb..#temporalUF') IS NOT NULL 
  BEGIN
    DROP TABLE #temporalUF;
  END

  CREATE TABLE #temporalUF (
    nombreConsorcio VARCHAR(100),
    uF VARCHAR(10),
    piso VARCHAR(10),
    dpto VARCHAR(10),
    coeficiente VARCHAR(10),
    m2UF INT,
    baulera CHAR(2),
    cochera CHAR(2),
    m2Baulera INT,
    m2Cochera INT
  );

  DECLARE @sql NVARCHAR(MAX) = N'
    BULK INSERT #temporalUF
    FROM ''' + @rutaArchivoCompleto + N'''
    WITH (
      FIELDTERMINATOR = ''\t'',
      ROWTERMINATOR = ''\n'',
      CODEPAGE = ''65001'',
      FIRSTROW = 2
    )';
  EXEC sp_executesql @sql;

  DELETE FROM #temporalUF 
  WHERE nombreConsorcio IS NULL OR LTRIM(RTRIM(nombreConsorcio)) = '';

  UPDATE uf
  SET
    uf.dimension = CAST(t.m2UF AS DECIMAL(5,2)),
    uf.m2Cochera = t.m2Cochera,
    uf.m2Baulera = t.m2Baulera,
    uf.porcentajeParticipacion = CAST(REPLACE(t.coeficiente, ',', '.') AS DECIMAL(4,2)),
    uf.cbu_cvu  = COALESCE(tpi.cvu, uf.cbu_cvu)
  FROM Infraestructura.UnidadFuncional uf
  INNER JOIN Administracion.Consorcio c ON c.id = uf.idConsorcio
  INNER JOIN #temporalUF t ON t.nombreConsorcio = c.nombre
                           AND CAST(t.piso AS CHAR(2)) = uf.piso
                           AND CAST(t.dpto AS CHAR(1)) = uf.departamento
  LEFT JOIN ##temporalInquilinosPropietariosCSV AS tpi
         ON tpi.consorcio = t.nombreConsorcio
        AND tpi.piso      = t.piso
        AND tpi.dpto      = t.dpto
  WHERE
    (
      tpi.cvu IS NULL
      OR NOT EXISTS (
            SELECT 1
            FROM Infraestructura.UnidadFuncional x
            WHERE x.cbu_cvu = tpi.cvu AND x.id <> uf.id
      )
    );

  INSERT INTO Infraestructura.UnidadFuncional
    (piso, departamento, dimension, m2Cochera, m2Baulera, porcentajeParticipacion, cbu_cvu, idConsorcio)
  SELECT
    CAST(t.piso AS CHAR(2)) AS piso,
    CAST(t.dpto AS CHAR(1)) AS departamento,
    CAST(t.m2UF AS DECIMAL(5,2)) AS dimension,
    t.m2Cochera,
    t.m2Baulera,
    CAST(REPLACE(t.coeficiente, ',', '.') AS DECIMAL(4,2)) AS porcentajeParticipacion,
    tpi.cvu AS cbu_cvu,
    c.id
  FROM #temporalUF t
  INNER JOIN Administracion.Consorcio c ON c.nombre = t.nombreConsorcio
  LEFT JOIN ##temporalInquilinosPropietariosCSV AS tpi
         ON tpi.consorcio = t.nombreConsorcio
        AND tpi.piso      = t.piso
        AND tpi.dpto      = t.dpto
  WHERE tpi.cvu IS NOT NULL
    AND NOT EXISTS (
          SELECT 1
          FROM Infraestructura.UnidadFuncional uf
          WHERE uf.idConsorcio = c.id
            AND uf.piso = CAST(t.piso AS CHAR(2))
            AND uf.departamento = CAST(t.dpto AS CHAR(1))
    )
    AND NOT EXISTS (
          SELECT 1
          FROM Infraestructura.UnidadFuncional x
          WHERE x.cbu_cvu = tpi.cvu
    );

  IF (OBJECT_ID('tempdb..##temporalInquilinosPropietariosCSV') IS NOT NULL)
  BEGIN
    DROP TABLE ##temporalInquilinosPropietariosCSV;
  END
END
GO

CREATE OR ALTER PROCEDURE LogicaBD.sp_ImportarDatosInquilinos
@rutaArchivo VARCHAR(100),
@nombreArchivo VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ruta VARCHAR(100) = LogicaNormalizacion.fn_NormalizarRutaArchivo(@rutaArchivo), 
            @archivo VARCHAR(100) = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivo, 'csv')

    IF (@ruta = '' OR @archivo = '')
    BEGIN
        RETURN;
    END;

    DECLARE @rutaArchivoCompleto VARCHAR(200) = REPLACE(@ruta + @archivo, '''', '''''');

    IF OBJECT_ID('tempdb..#temporalInquilinosCSV') IS NOT NULL
    BEGIN
        DROP TABLE #temporalInquilinosCSV;
    END

    CREATE TABLE #temporalInquilinosCSV (
        nombre VARCHAR(100),
        apellido VARCHAR(100),
        dni VARCHAR(100),
        email VARCHAR(100),
        telefono VARCHAR(100),
        cvu VARCHAR(100),
        inquilino VARCHAR(100)
    );

    DECLARE @sql NVARCHAR(MAX) = N'
        BULK INSERT #temporalInquilinosCSV
        FROM ''' + @rutaArchivoCompleto + N'''
        WITH (
            FIELDTERMINATOR = '';'',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''65001'',
            FIRSTROW = 2
        )';

    EXEC sp_executesql @sql;

    UPDATE #temporalInquilinosCSV
    SET nombre = CONCAT(UPPER(LEFT(LTRIM(RTRIM(nombre)),1)), LOWER(SUBSTRING(LTRIM(RTRIM(nombre)),2,100))),
        apellido = CONCAT(UPPER(LEFT(LTRIM(RTRIM(apellido)),1)), LOWER(SUBSTRING(LTRIM(RTRIM(apellido)),2,100))),
        dni = REPLACE(REPLACE(LTRIM(RTRIM(dni)),' ',''),'.',''),
        email = NULLIF(LTRIM(RTRIM(email)), ''),
        telefono = NULLIF(LTRIM(RTRIM(telefono)), ''),
        cvu = NULLIF(LTRIM(RTRIM(cvu)), ''),
        inquilino = LTRIM(RTRIM(inquilino));

    DELETE FROM #temporalInquilinosCSV 
    WHERE nombre IS NULL OR apellido IS NULL OR dni IS NULL OR cvu IS NULL OR inquilino IS NULL 
        OR email IS NULL OR telefono IS NULL OR LEN(telefono) <> 10 OR telefono LIKE '%[^0-9]%' OR LEN(cvu) <> 22 
        OR cvu LIKE '%[^0-9]%';
    
    ;WITH dni_repetidos AS
    (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY dni ORDER BY dni, email) AS filasDni
        FROM #temporalInquilinosCSV
    )
    DELETE FROM dni_repetidos WHERE filasDni > 1;

    ;WITH cvu_repetidos AS (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY cvu ORDER BY cvu, dni) as filasCvu
      FROM #temporalInquilinosCSV
    )
    DELETE FROM cvu_repetidos WHERE filasCvu > 1;

    ;WITH email_repetidos AS (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY LOWER(LTRIM(RTRIM(email))) ORDER BY dni) filasEmail
      FROM #temporalInquilinosCSV
    )
    DELETE FROM email_repetidos WHERE filasEmail > 1;

    UPDATE #temporalInquilinosCSV
    SET email = LOWER(LTRIM(RTRIM(email)));
    
    BEGIN TRY
        INSERT INTO Personas.Persona (dni, nombre, apellido, email, telefono, cbu_cvu)
        SELECT S.dni, S.nombre, S.apellido, S.email, S.telefono, S.cvu
        FROM #temporalInquilinosCSV S
        WHERE NOT EXISTS (SELECT 1 FROM Personas.Persona T WHERE T.DNI = S.dni)
            AND NOT EXISTS (SELECT 1 FROM Personas.Persona T WHERE T.cbu_cvu = S.cvu)
            AND NOT EXISTS (SELECT 1 FROM Personas.Persona T WHERE T.email_trim = S.email);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601,2627)
        BEGIN
            UPDATE P
            SET P.nombre = S.nombre,
                P.apellido = S.apellido,
                P.email = CASE 
                                WHEN NOT EXISTS (SELECT 1 FROM Personas.Persona X
                                                 WHERE X.email_trim = S.email
                                                   AND X.dni <> P.dni)
                                THEN COALESCE(S.email, P.email)
                                ELSE P.email
                              END,
                P.telefono = COALESCE(S.telefono, P.telefono),
                P.cbu_cvu = COALESCE(S.cvu, P.cbu_cvu)
            FROM Personas.Persona P
            JOIN #temporalInquilinosCSV S ON P.DNI = S.dni;
        END
        ELSE
            THROW;
    END CATCH;

    INSERT INTO Personas.PersonaEnUF 
    (dniPersona, idUF, inquilino, fechaDesde, fechaHasta)
    SELECT  P.DNI AS dniPersona,
            UF.id AS idUF,                      
            CAST(T.inquilino AS bit) AS inquilino,              
            GETDATE() AS fechaDesde,
            NULL AS fechaHasta
    FROM #temporalInquilinosCSV T
    JOIN Personas.Persona P	ON P.DNI = T.dni
    JOIN Infraestructura.UnidadFuncional UF	ON UF.cbu_cvu = P.cbu_cvu
    WHERE NOT EXISTS (
        SELECT 1
        FROM Personas.PersonaEnUF X
        WHERE X.dniPersona = P.DNI AND X.idUF = UF.id AND X.fechaHasta IS NULL
    );
END
GO

--CREATE OR ALTER PROCEDURE LogicaBD.sp_ImportarProveedores 
--@rutaArchivo VARCHAR(100),
--@nombreArchivo VARCHAR(100)
--AS
--BEGIN
--	SET NOCOUNT ON;

--	DECLARE @ruta VARCHAR(100) = LogicaNormalizacion.fn_NormalizarRutaArchivo(@rutaArchivo),
--            @archivo VARCHAR(100) = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivo, 'xlxs'),
--			@fullpath VARCHAR(200),
--			@sql      NVARCHAR(MAX);

--    IF (@ruta = '' OR @archivo = '')
--    BEGIN
--        RETURN;
--    END;



--END
--GO

CREATE OR ALTER PROCEDURE LogicaBD.sp_InsertarGastosExtraordinarios
@idCons INT,
@mesGasto INT
AS
BEGIN
    DECLARE @idConsGastoExt INT = ( SELECT MIN(idConsorcio) FROM Gastos.GastoExtraordinario )
    PRINT CONCAT('idCons: ', ISNULL(CAST(@idConsGastoExt AS CHAR(2)), 'NULL'))
    IF @idConsGastoExt IS NULL
    BEGIN
        DECLARE @idMin INT = (SELECT MIN(id) FROM Administracion.Consorcio)
        DECLARE @idMax INT = (SELECT MAX(id) FROM Administracion.Consorcio)

        SET @idConsGastoExt = ( SELECT FLOOR(RAND() * (@idMax - @idMin + 1)) + @idMin )
        INSERT INTO Gastos.GastoExtraordinario(mes, detalle, importe, formaPago, nroCuotaAPagar, nroTotalCuotas, idConsorcio)
            VALUES (1, '', 1, 'Total', NULL, NULL, @idConsGastoExt)
    END

    PRINT CONCAT('idCons: ', CAST(@idConsGastoExt AS CHAR(2)))
    PRINT CONCAT('idParam: ',CAST(@idCons  AS CHAR(2)))
    PRINT CONCAT('mes: ',CAST(@mesGasto AS CHAR(2)))

    IF @idConsGastoExt != @idCons
    BEGIN
        PRINT CONCAT('SALGO CON ID: ', CAST(@idCons  AS CHAR(2)))
        RETURN
    END

    BEGIN
        DECLARE @cantMax INT = ( SELECT FLOOR(RAND() * (2 - 1 + 1)) + 2 )
        DECLARE @cant INT = 0
        WHILE @cant < @cantMax
        BEGIN
            DECLARE @estructura VARCHAR(25) =   CASE ( 
                                                    SELECT FLOOR(RAND() * (5 - 1 + 1)) + 1 )
                                                        WHEN 1 THEN 'pileta'
                                                        WHEN 2 THEN 'salon de eventos'
                                                        WHEN 3 THEN 'entrada'
                                                        WHEN 4 THEN 'recepcion'
                                                        WHEN 5 THEN 'jardines'
                                                        ELSE 'sistema de seguridad'
                                                    END
            DECLARE @detalle VARCHAR(200) = CASE ( 
                                                SELECT FLOOR(RAND() * (2 - 1 + 1)) + 1 )
                                                WHEN 1 THEN CONCAT('Reparacion de ', @estructura, '.') 
                                                ELSE CONCAT('Construccion de ', @estructura, ' agregada al complejo.')
                                            END

            -- Importe
            DECLARE @impMin DECIMAL(10,2) = 9999999.99
            DECLARE @impMax DECIMAL(10,2) = 100000.00
            DECLARE @importe DECIMAL(10,2) = (SELECT CAST(((@impMax - @impMin) * RAND() + @impMin) AS DECIMAL(10,2)))
            DECLARE @formaPago VARCHAR(6) = 'Total'

            INSERT INTO Gastos.GastoExtraordinario(mes, detalle, importe, formaPago, nroCuotaAPagar, nroTotalCuotas, idConsorcio)
            VALUES (@mesGasto, @detalle, @importe, 'Total', NULL, NULL, @idConsGastoExt)
            SET @cant = @cant + 1
        END
    END
END
GO

/* Modificado: sp_ImportarGastosOrdinarios parametrizado y sin duplicados de expensas */
CREATE OR ALTER PROCEDURE LogicaBD.sp_ImportarGastosOrdinarios 
@rutaArchivo VARCHAR(100),
@nombreArchivo VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #datosGastosOrdinarios (
        id varchar(100),
        consorcio varchar(100),
        mes varchar(15),
        bancarios varchar(100),
        limpieza varchar(100),
        administracion varchar(100),
        seguros varchar(100),
        generales varchar(100),
        agua varchar(100),
        luz varchar(100),
        internet varchar(100)
    );

    
    DECLARE @ruta VARCHAR(100) = LogicaNormalizacion.fn_NormalizarRutaArchivo(@rutaArchivo),
            @archivo VARCHAR(100) = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivo, 'json');

    IF (@ruta = '' OR @archivo = '')
    BEGIN
        RETURN;
    END;

    UPDATE p
    SET p.consorcio = c.id
    FROM ##datosProveedores AS p
    INNER JOIN Administracion.Consorcio AS c ON c.nombre = p.consorcio;

    DECLARE @rutaCompleta VARCHAR(200) = REPLACE(@ruta + @archivo, '''', '''''');
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO #datosGastosOrdinarios(id,consorcio,mes,bancarios,limpieza,administracion,seguros,generales, agua, luz, internet)
        SELECT 
            JSON_VALUE(_id, ''$."$oid"'') AS id, 
            consorcio, 
            mes, 
            bancarios, 
            limpieza, 
            administracion, 
            seguros, 
            generales, 
            agua, 
            luz, 
            internet
        FROM OPENROWSET (BULK ''' + @rutaCompleta + N''', SINGLE_CLOB) AS ordinariosJSON
        CROSS APPLY OPENJSON(ordinariosJSON.BulkColumn, ''$'') 
        WITH ( 
            _id NVARCHAR(MAX) as JSON,
            consorcio varchar(100) ''$."Nombre del consorcio"'',
            mes varchar(15) ''$.Mes'',
            bancarios varchar(100) ''$.BANCARIOS'',
            limpieza varchar(100) ''$.LIMPIEZA'',
            administracion varchar(100) ''$.ADMINISTRACION'',
            seguros varchar(100) ''$.SEGUROS'',
            generales varchar(100) ''$."GASTOS GENERALES"'',
            agua varchar(100) ''$."SERVICIOS PUBLICOS-Agua"'',
            luz varchar(100) ''$."SERVICIOS PUBLICOS-Luz"'',
            internet varchar(100) ''$."SERVICIOS PUBLICOS-Internet"''
        );'

    EXEC sp_executesql @sql;

    DELETE FROM #datosGastosOrdinarios WHERE consorcio IS NULL

    UPDATE #datosGastosOrdinarios
    SET
        mes = LogicaNormalizacion.fn_NumeroMes(mes),
        bancarios = REPLACE(bancarios,'.',''),
        limpieza = REPLACE(limpieza,'.',''),
        administracion = REPLACE(administracion,'.',''),
        seguros = REPLACE(seguros,'.',''),
        generales = REPLACE(generales,'.',''),
        agua = REPLACE(agua,'.',''),
        luz = REPLACE(luz,'.',''),
        internet = REPLACE(internet,'.','')

    UPDATE g
        SET g.consorcio = c.id
        FROM #datosGastosOrdinarios AS g
        INNER JOIN Administracion.Consorcio AS c ON c.nombre = g.consorcio

    UPDATE #datosGastosOrdinarios
    SET 
        bancarios = REPLACE(LTRIM(RTRIM(bancarios)),',',''),
        limpieza = REPLACE(LTRIM(RTRIM(limpieza)),',',''),
        administracion = REPLACE(LTRIM(RTRIM(administracion)),',',''),
        seguros = REPLACE(LTRIM(RTRIM(seguros)),',',''),
        generales = REPLACE(LTRIM(RTRIM(generales)),',',''),
        agua = REPLACE(LTRIM(RTRIM(agua)),',',''),
        luz = REPLACE(LTRIM(RTRIM(luz)),',',''),
        internet = REPLACE(LTRIM(RTRIM(internet)),',','')
        
    DECLARE @contador INT = 0
    DECLARE @cantidadRegistros INT  = (SELECT COUNT(*) FROM #datosGastosOrdinarios)
    DECLARE @numeroFactura INT = ISNULL((SELECT MAX(nroFactura) FROM Gastos.GastoOrdinario), 999) + 1
        
    WHILE @contador < @cantidadRegistros
    BEGIN
        DECLARE @gastoBan DECIMAL(10,2) = CAST((SELECT bancarios  FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY) AS DECIMAL(10,2))
        DECLARE @gastoLim DECIMAL (10,2) = CAST((SELECT limpieza FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)  AS DECIMAL(10,2))
        DECLARE @gastoAdm DECIMAL (10,2) = CAST((SELECT administracion FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)  AS DECIMAL(10,2))
        DECLARE @gastoSeg DECIMAL (10,2) = CAST((SELECT seguros FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)  AS DECIMAL(10,2))
        DECLARE @gastoGen DECIMAL (10,2) = CAST((SELECT generales FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)  AS DECIMAL(10,2))
        DECLARE @gastoAgu DECIMAL (10,2) = CAST((SELECT agua FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)  AS DECIMAL(10,2))
        DECLARE @gastoLuz DECIMAL (10,2) = CAST((SELECT luz FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)  AS DECIMAL(10,2))
        DECLARE @gastoNet DECIMAL (10,2) = CAST((SELECT internet FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)  AS DECIMAL(10,2))
        DECLARE @mes INT  = (SELECT mes FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)
        DECLARE @idConsorcio INT = (SELECT consorcio FROM #datosGastosOrdinarios ORDER BY mes, consorcio OFFSET @contador ROWS FETCH NEXT 1 ROWS ONLY)
        DECLARE @empresa VARCHAR(100)
        
        IF NOT EXISTS (
            SELECT 1
            FROM Gastos.GastoOrdinario
            WHERE mes = @mes
              AND tipoGasto = 'Mantenimiento de cuenta bancaria'
              AND detalle = ''
              AND idConsorcio = @idConsorcio
        ) 
        BEGIN
            SET @empresa = (SELECT empresa FROM ##datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%BANCARIOS%')
            INSERT INTO Gastos.GastoOrdinario (mes, tipoGasto, empresaPersona, nroFactura, importeFactura, detalle, idConsorcio)
            VALUES (@mes, 'Mantenimiento de cuenta bancaria', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoBan/100, '', @idConsorcio)
            SET @numeroFactura = @numeroFactura + 1
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Gastos.GastoOrdinario
            WHERE mes = @mes
              AND tipoGasto = 'Limpieza'
              AND detalle = ''
              AND idConsorcio = @idConsorcio
        ) 
        BEGIN
            SET @empresa = (SELECT empresa FROM ##datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%LIMPIEZA%')
            INSERT INTO Gastos.GastoOrdinario (mes, tipoGasto, empresaPersona, nroFactura, importeFactura, detalle, idConsorcio)
            VALUES (@mes, 'Limpieza', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoLim/100, '', @idConsorcio)
            SET @numeroFactura = @numeroFactura + 1
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Gastos.GastoOrdinario
            WHERE mes = @mes
              AND tipoGasto = 'Administracion/Honorarios'
              AND detalle = ''
              AND idConsorcio = @idConsorcio
        ) 
        BEGIN
            SET @empresa = (SELECT empresa FROM ##datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%ADMINISTRACION%')
            INSERT INTO Gastos.GastoOrdinario (mes, tipoGasto, empresaPersona, nroFactura, importeFactura, detalle, idConsorcio)
            VALUES (@mes, 'Administracion/Honorarios', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoAdm/100, '', @idConsorcio)
            SET @numeroFactura = @numeroFactura + 1
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Gastos.GastoOrdinario
            WHERE mes = @mes
              AND tipoGasto = 'Seguro'
              AND detalle = ''
              AND idConsorcio = @idConsorcio
        ) 
        BEGIN
            SET @empresa = (SELECT empresa FROM ##datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%SEGUROS%')
            INSERT INTO Gastos.GastoOrdinario (mes, tipoGasto, empresaPersona, nroFactura, importeFactura, detalle, idConsorcio)
            VALUES (@mes, 'Seguro', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoSeg/100, '', @idConsorcio)
            SET @numeroFactura = @numeroFactura + 1
        END

         IF NOT EXISTS (
            SELECT 1
            FROM Gastos.GastoOrdinario
            WHERE mes = @mes
              AND tipoGasto = 'Generales'
              AND detalle = ''
              AND idConsorcio = @idConsorcio
        ) 
        BEGIN
            SET @empresa = NULL
            INSERT INTO Gastos.GastoOrdinario (mes, tipoGasto, empresaPersona, nroFactura, importeFactura, detalle, idConsorcio)
            VALUES (@mes, 'Generales', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoGen/100, '', @idConsorcio)
            SET @numeroFactura = @numeroFactura + 1
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Gastos.GastoOrdinario
            WHERE mes = @mes
              AND tipoGasto = 'Servicios Publico'
              AND detalle = 'Agua'
              AND idConsorcio = @idConsorcio
        ) 
        BEGIN
            SET @empresa = (SELECT empresa FROM ##datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%PUBLICOS%' AND empresa LIKE '%AYSA%')
            INSERT INTO Gastos.GastoOrdinario (mes, tipoGasto, empresaPersona, nroFactura, importeFactura, detalle, idConsorcio)
            VALUES (@mes, 'Servicios Publico', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoAgu/100, 'Agua', @idConsorcio)
            SET @numeroFactura = @numeroFactura + 1
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Gastos.GastoOrdinario
            WHERE mes = @mes
              AND tipoGasto = 'Servicios Publico'
              AND detalle = 'Luz'
              AND idConsorcio = @idConsorcio
        ) 
        BEGIN
            SET @empresa = (SELECT empresa FROM ##datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%PUBLICOS%' AND ( empresa LIKE '%EDENOR%' OR empresa LIKE '%EDESUR%'))
            INSERT INTO Gastos.GastoOrdinario (mes, tipoGasto, empresaPersona, nroFactura, importeFactura, detalle, idConsorcio)
            VALUES (@mes, 'Servicios Publico', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoLuz/100, 'Luz', @idConsorcio)
            SET @numeroFactura = @numeroFactura + 1
        END
        
        IF @gastoNet IS NOT NULL AND NOT EXISTS (
            SELECT 1
            FROM Gastos.GastoOrdinario
            WHERE mes = @mes
              AND tipoGasto = 'Servicios Publico'
              AND detalle = 'Internet'
              AND idConsorcio = @idConsorcio
        ) 
        BEGIN
            SET @empresa = (SELECT empresa FROM ##datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%PUBLICOS%' AND ( empresa NOT LIKE '%EDENOR%' AND empresa NOT LIKE '%EDESUR%' AND empresa NOT LIKE '%AYSA%'))
            INSERT INTO Gastos.GastoOrdinario (mes, tipoGasto, empresaPersona, nroFactura, importeFactura, detalle, idConsorcio)
            VALUES (@mes, 'Servicios Publico', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoLuz/100, 'Internet', @idConsorcio)
            SET @numeroFactura = @numeroFactura + 1
        END
        
        EXEC LogicaBD.sp_InsertarGastosExtraordinarios @idCons = @idConsorcio, @mesGasto = @mes

        SET @contador = @contador + 1
    END    

    DELETE FROM Gastos.GastoExtraordinario
    WHERE id = 1
END
GO

CREATE OR ALTER PROCEDURE LogicaBD.sp_GenerarExpensa
AS
BEGIN
    SET NOCOUNT ON

	;WITH O AS (
        SELECT mes, idConsorcio, SUM(importeFactura) AS SumaOrd
        FROM Gastos.GastoOrdinario
        GROUP BY mes, idConsorcio
    ),
    E AS (
        SELECT mes, idConsorcio, SUM(importe) AS SumaExtra
        FROM Gastos.GastoExtraordinario
        GROUP BY mes, idConsorcio
    ),
    U AS (  -- Unión por mes/consorcio
        SELECT 
            COALESCE(O.mes, E.mes)                AS mes,
            COALESCE(O.idConsorcio, E.idConsorcio) AS idConsorcio,
            ISNULL(O.SumaOrd, 0)                  AS SumaOrd,
            ISNULL(E.SumaExtra, 0)                AS SumaExtra
        FROM O
        FULL JOIN E
          ON O.mes = E.mes AND O.idConsorcio = E.idConsorcio
    )

	INSERT INTO Gastos.Expensa 
        (periodo, totalGastoOrdinario, totalGastoExtraordinario, primerVencimiento, segundoVencimiento, idConsorcio)
    SELECT 
        CONCAT(RIGHT('0' + CAST(U.mes AS VARCHAR(2)), 2), CAST(YEAR(GETDATE()) AS VARCHAR(4))) AS Periodo,
        U.SumaOrd,
        U.SumaExtra,
        CAST(GETDATE() AS DATE)                         AS PrimerV,
        CAST(DATEADD(DAY, 7, GETDATE()) AS DATE)        AS SegundoV,
        U.idConsorcio
    FROM U
    WHERE NOT EXISTS (
        SELECT 1
        FROM Gastos.Expensa ex
        WHERE ex.periodo = CONCAT(RIGHT('0' + CAST(U.mes AS VARCHAR(2)), 2), CAST(YEAR(GETDATE()) AS VARCHAR(4)))
          AND ex.idConsorcio = U.idConsorcio
    );

END
GO

/* Modificado: sp_ImportarPagos parametrizado, sin insertar IDENTITY y con join corregido a expensa por periodo */
CREATE OR ALTER PROCEDURE LogicaBD.sp_ImportarPagos
@rutaArchivo VARCHAR(100),
@nombreArchivo VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #temporalPagos (
        id CHAR(5),
        fecha VARCHAR(10),
        claveBancaria VARCHAR(22),
        monto VARCHAR(20)
    );

    DECLARE @ruta VARCHAR(100) = LogicaNormalizacion.fn_NormalizarRutaArchivo(@rutaArchivo),
            @archivo VARCHAR(100) = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivo, 'csv');

    IF (@ruta = '' OR @archivo = '')
    BEGIN
        RETURN;
    END;

    DECLARE @rutaCompleta VARCHAR(200) = REPLACE(@ruta + @archivo, '''', '''''');
    DECLARE @sql NVARCHAR(MAX) = N'
        BULK INSERT #temporalPagos
        FROM ''' + @rutaCompleta + N'''
        WITH (
            FIELDTERMINATOR = '','',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''65001'',
            FIRSTROW = 2
        )';
    EXEC sp_executesql @sql;
    
    UPDATE #temporalPagos
		SET 
			id = LTRIM(RTRIM(id)),
			fecha = LTRIM(RTRIM(fecha)),
			claveBancaria = LTRIM(RTRIM(claveBancaria)),
			monto = LogicaNormalizacion.fn_ToDecimal(monto);

	DELETE FROM #temporalPagos
		WHERE NULLIF(fecha,'') IS NULL
			OR NULLIF(claveBancaria,'') IS NULL
			OR NULLIF(monto,'') IS NULL;

	UPDATE #temporalPagos
        SET claveBancaria = NULL
        WHERE claveBancaria NOT LIKE '%[0-9]%' OR LEN(claveBancaria) <> 22;


    INSERT INTO Finanzas.Pagos
        (fecha,
        monto,
        cuentaBancaria,
        valido,
        idExpensa,
        idUF) 
    SELECT 
        TRY_CONVERT(DATE, fecha, 103), 
        tP.monto, 
        tP.claveBancaria, 
        CASE 
			WHEN uf.id IS NULL OR e.id IS NULL OR tP.claveBancaria IS NULL THEN 0 
			ELSE 1 
		END AS valido, 
        e.id, 
        uf.id
    FROM #temporalPagos as tP
    LEFT JOIN Infraestructura.UnidadFuncional as uf
        ON uf.cbu_cvu = tP.claveBancaria
    LEFT JOIN Administracion.Consorcio as c
        ON uf.idConsorcio = c.id
    LEFT JOIN Gastos.Expensa as e
        ON e.idConsorcio = c.id
       AND e.periodo = (
            RIGHT('0' + CAST(MONTH(TRY_CONVERT(DATE, fecha, 103)) AS VARCHAR(2)),2)
            + CAST(YEAR(TRY_CONVERT(DATE, fecha, 103)) AS VARCHAR(4))
        );
END
GO