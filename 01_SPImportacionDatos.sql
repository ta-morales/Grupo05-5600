USE Grupo05_5600
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

    SET @ruta = REPLACE(@ruta, '/', '\\');

    WHILE LEN(@ruta) > 0 AND RIGHT(@ruta,1) = '\\'
        SET @ruta = LEFT(@ruta, LEN(@ruta)-1);

    SET @ruta = @ruta + '\\';
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

    RETURN TRY_CONVERT(DECIMAL(18,2), @tmp);
END
GO

/* =============================== Trigger =============================== */
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
        ed.metrosTotales, 
        uf.porcentajeParticipacion, 
        uf.m2Cochera, 
        uf.m2Baulera
    FROM inserted i 
    INNER JOIN Administracion.Consorcio c	ON i.idConsorcio = c.id
    INNER JOIN Infraestructura.UnidadFuncional uf	ON uf.idEdificio = c.idEdificio
    INNER JOIN Infraestructura.Edificio ed	ON uf.idEdificio = ed.id;

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
CREATE OR ALTER PROCEDURE Infraestructura.sp_InsertarEnConsorcio 
@direccion VARCHAR(100),
@nombre VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @idEdificio INT
    SET @idEdificio = ( SELECT TOP 1 id FROM Infraestructura.Edificio WHERE direccion = @direccion ORDER BY id)
    IF @idEdificio IS NOT NULL AND NOT EXISTS (
        SELECT 1 
        FROM Administracion.Consorcio 
        WHERE idEdificio = @idEdificio
    )
    BEGIN
        INSERT INTO Administracion.Consorcio (nombre, idEdificio) VALUES (@nombre, @idEdificio)
        PRINT 'Consorcio ' + @nombre + ' insertado.'
    END
END
GO

CREATE OR ALTER PROCEDURE sp_ImportarConsorciosYEdificios
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Infraestructura.Edificio (direccion, metrosTotales) VALUES
        ('Belgrano 3344', 1281),
        ('Callao 1122', 914),
        ('Santa Fe 910', 784),
        ('Corrientes 5678', 1316),
        ('Rivadavia 1234', 1691)

    PRINT 'Edificios Insertados'
    
    EXEC Infraestructura.sp_InsertarEnConsorcio @direccion='Belgrano 3344', @nombre='Azcuenaga'
    EXEC Infraestructura.sp_InsertarEnConsorcio @direccion='Callao 1122', @nombre='Alzaga'
    EXEC Infraestructura.sp_InsertarEnConsorcio @direccion='Santa Fe 910', @nombre='Alberdi'
    EXEC Infraestructura.sp_InsertarEnConsorcio @direccion='Corrientes 5678', @nombre='Unzue'
    EXEC Infraestructura.sp_InsertarEnConsorcio @direccion='Rivadavia 1234', @nombre='Pereyra Iraola'
END
GO

CREATE OR ALTER PROCEDURE sp_ImportarInquilinosPropietarios
@rutaArchivoInquilinosPropietarios VARCHAR(100),
@nombreArchivoInquilinosPropietarios VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
            @ruta VARCHAR(100) = LogicaNormalizacion.fn_NormalizarRutaArchivo(@rutaArchivoInquilinosPropietarios),
            @archivo VARCHAR(100) = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivoInquilinosPropietarios, 'csv');
    
    IF (@ruta IS NULL OR @ruta = '' OR @archivo = '')
    BEGIN
        PRINT 'Ruta o archivo inválidos (se esperaba .csv)'; 
        RETURN;
    END;

    DECLARE @rutaArchivoCompleto VARCHAR(200) = REPLACE(@ruta + @archivo, '''', '''''');
    PRINT @rutaArchivoCompleto;

    IF OBJECT_ID('tempdb..#temporalInquilinosPropietariosCSV') IS NOT NULL
    BEGIN
        DROP TABLE #temporalInquilinosPropietariosCSV
    END

    CREATE TABLE #temporalInquilinosPropietariosCSV (
        cvu VARCHAR(100),
        consorcio VARCHAR(100),
        nroUF VARCHAR(5),
        piso VARCHAR(5),
        dpto VARCHAR(5)
    )

    DECLARE @sql NVARCHAR(MAX) = N'
        BULK INSERT #temporalInquilinosPropietariosCSV
        FROM ''' + @rutaArchivoCompleto + '''
        WITH (
            FIELDTERMINATOR = '','',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''65001'',
            FIRSTROW = 2
        )';
    
    EXEC sp_executesql @sql;

    SELECT COUNT(*) AS FilasCargadas
    FROM #temporalInquilinosPropietariosCSV;
END
GO

CREATE OR ALTER PROCEDURE sp_InsertarUnidadesFuncionales
  @nombreRuta VARCHAR(100),
  @nombreArchivo VARCHAR(100),
  @rutaArchivoIPUF VARCHAR(100) = NULL,
  @nombreArchivoIPUF VARCHAR(100) = NULL
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @ruta VARCHAR(100) = LogicaNormalizacion.fn_NormalizarRutaArchivo(@nombreRuta),
          @archivo VARCHAR(100) = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivo, 'txt');

  IF (@ruta = '' OR @archivo = '')
  BEGIN
    PRINT 'Ruta o archivo inválidos (se esperaba .txt)';
    RETURN;
  END;

  DECLARE @rutaArchivoCompleto VARCHAR(200) = REPLACE(@ruta + @archivo, '''', '''''');
  PRINT @rutaArchivoCompleto;

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

  DECLARE @creadaIPUF BIT = 0;
  IF OBJECT_ID('tempdb..#temporalInquilinosPropietariosCSV') IS NULL
  BEGIN
    DECLARE @rutaIP VARCHAR(100)  = LogicaNormalizacion.fn_NormalizarRutaArchivo(@rutaArchivoIPUF);
    DECLARE @archIP VARCHAR(100)  = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivoIPUF, 'csv');

    IF (@rutaIP IS NOT NULL AND @rutaIP <> '' AND @archIP <> '')
    BEGIN
      CREATE TABLE #temporalInquilinosPropietariosCSV (
        cvu VARCHAR(100),
        consorcio VARCHAR(100),
        nroUF VARCHAR(5),
        piso VARCHAR(5),
        dpto VARCHAR(5)
      );

      DECLARE @rutaIPCompleta VARCHAR(200) = REPLACE(@rutaIP + @archIP, '''', '''''');
      DECLARE @sqlIP NVARCHAR(MAX) = N'
        BULK INSERT #temporalInquilinosPropietariosCSV
        FROM ''' + @rutaIPCompleta + N'''
        WITH (
          FIELDTERMINATOR = '','',
          ROWTERMINATOR = ''\n'',
          CODEPAGE = ''65001'',
          FIRSTROW = 2
        )';
      EXEC sp_executesql @sqlIP;
      SET @creadaIPUF = 1;
    END
  END

  DELETE FROM #temporalUF 
  WHERE nombreConsorcio IS NULL OR LTRIM(RTRIM(nombreConsorcio)) = '';

  DELETE uf
  FROM Infraestructura.UnidadFuncional uf
  INNER JOIN Administracion.Consorcio c ON c.idEdificio = uf.idEdificio
  INNER JOIN #temporalUF t ON t.nombreConsorcio = c.nombre
                           AND t.piso = uf.piso
                           AND t.dpto = uf.departamento;

  INSERT INTO Infraestructura.UnidadFuncional
    (piso, departamento, dimension, m2Cochera, m2Baulera, porcentajeParticipacion, cbu_cvu, idEdificio)
  SELECT
    CAST(t.piso AS CHAR(2)) AS piso,
    CAST(t.dpto AS CHAR(1)) AS departamento,
    CAST(t.m2UF AS DECIMAL(5,2)) AS dimension,
    t.m2Cochera,
    t.m2Baulera,
    CAST(REPLACE(t.coeficiente, ',', '.') AS DECIMAL(4,2)) AS porcentajeParticipacion,
    tpi.cvu AS cbu_cvu,
    c.idEdificio
  FROM #temporalUF t
  INNER JOIN Administracion.Consorcio c ON c.nombre = t.nombreConsorcio
  LEFT JOIN #temporalInquilinosPropietariosCSV tpi
         ON tpi.consorcio = t.nombreConsorcio
        AND tpi.piso      = t.piso
        AND tpi.dpto      = t.dpto
  WHERE tpi.cvu IS NOT NULL;

  IF (@creadaIPUF = 1 AND OBJECT_ID('tempdb..#temporalInquilinosPropietariosCSV') IS NOT NULL)
  BEGIN
    DROP TABLE #temporalInquilinosPropietariosCSV;
  END
END
GO

CREATE OR ALTER PROCEDURE sp_ImportarDatosInquilinos
@nombreArchivo VARCHAR(100),
@rutaArchivo VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ruta VARCHAR(100) = LogicaNormalizacion.fn_NormalizarRutaArchivo(@rutaArchivo), 
            @archivo VARCHAR(100) = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivo, 'csv')

    IF (@ruta = '' OR @archivo = '')
    BEGIN
        PRINT 'Ruta o archivo inválidos (se esperaba .csv)';
        RETURN;
    END;

    DECLARE @rutaArchivoCompleto VARCHAR(200) = REPLACE(@ruta + @archivo, '''', '''''');
    PRINT @rutaArchivoCompleto;

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
            FIELDTERMINATOR = '','',
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
        INSERT INTO Personas.Persona (DNI, Nombre, Apellido, Email, Telefono, cbu_cvu)
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
            SET P.Nombre = S.nombre,
                P.Apellido = S.apellido,
                P.Email = CASE 
                                WHEN NOT EXISTS (SELECT 1 FROM Personas.Persona X
                                                 WHERE X.email_trim = S.email
                                                   AND X.dni <> P.dni)
                                THEN COALESCE(S.email, P.Email)
                                ELSE P.Email
                              END,
                P.Telefono = COALESCE(S.telefono, P.Telefono),
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

/* Modificado: sp_ImportarGastosOrdinarios parametrizado y sin duplicados de expensas */
CREATE OR ALTER PROCEDURE sp_ImportarGastosOrdinarios 
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

    CREATE TABLE #datosProveedores (
        tipoGasto varchar(100),
        empresa varchar(100),
        cuentaBancaria varchar(100),
        consorcio varchar(100)
    );

    INSERT INTO #datosProveedores(tipoGasto,empresa,cuentaBancaria,consorcio)
    VALUES
    ('GASTOS BANCARIOS', 'BANCO CREDICOOP - Gastos bancario', NULL, 'Azcuenaga'),
    ('GASTOS DE ADMINISTRACION', 'FLAVIO HERNAN DIAZ - Honorarios', NULL, 'Azcuenaga'),
    ('SEGUROS', 'FEDERACION PATRONAL SEGUROS - Integral de consorcio', NULL, 'Azcuenaga'),
    ('SERVICIOS PUBLICOS', 'AYSA', 'Cuenta 195329', 'Azcuenaga'),
    ('SERVICIOS PUBLICOS', 'EDENOR', 'Cuenta 4363152506', 'Azcuenaga'),
    ('GASTOS DE LIMPIEZA', 'Serv. Limpieza', 'Limptech', 'Azcuenaga');

    DECLARE @ruta VARCHAR(100) = LogicaNormalizacion.fn_NormalizarRutaArchivo(@rutaArchivo),
            @archivo VARCHAR(100) = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivo, 'json');

    IF (@ruta = '' OR @archivo = '')
    BEGIN
        PRINT 'Ruta o archivo inválidos (se esperaba .json)';
        RETURN;
    END;

    DECLARE @rutaCompleta VARCHAR(200) = REPLACE(@ruta + @archivo, '''', '''''');
    DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO #datosGastosOrdinarios(id,consorcio,mes,bancarios,limpieza,administracion,seguros,generales, agua, luz, internet)
        SELECT JSON_VALUE(_id, ''$[''$oid'']'') AS id, consorcio, mes, bancarios, limpieza, administracion, seguros, generales, agua, luz, internet
        FROM OPENROWSET (BULK ''' + @rutaCompleta + N''', SINGLE_CLOB) AS ordinariosJSON
        CROSS APPLY OPENJSON(ordinariosJSON.BulkColumn, ''$'') 
        WITH ( 
            _id NVARCHAR(MAX) as JSON,
            consorcio varchar(100) ''$[''Nombre del consorcio'']'',
            mes varchar(15) ''$.Mes'',
            bancarios varchar(100) ''$.BANCARIOS'',
            limpieza varchar(100) ''$.LIMPIEZA'',
            administracion varchar(100) ''$.ADMINISTRACION'',
            seguros varchar(100) ''$.SEGUROS'',
            generales varchar(100) ''$[''GASTOS GENERALES'']'',
            agua varchar(100) ''$[''SERVICIOS PUBLICOS-Agua'']'',
            luz varchar(100) ''$[''SERVICIOS PUBLICOS-Luz'']'',
            internet varchar(100) ''$[''SERVICIOS PUBLICOS-Internet'']''
        )';
    EXEC sp_executesql @sql;

    DELETE FROM #datosGastosOrdinarios WHERE consorcio IS NULL;

    UPDATE #datosGastosOrdinarios
    SET 
        consorcio = ( SELECT idEdificio FROM Administracion.Consorcio c WHERE c.nombre = #datosGastosOrdinarios.consorcio),
        mes = LogicaNormalizacion.fn_NumeroMes(mes),
        bancarios = REPLACE(bancarios,'.','');

    INSERT INTO Gastos.Expensa 
        (periodo, totalGastoOrdinario, totalGastoExtraordinario, primerVencimiento, segundoVencimiento, idConsorcio)
    SELECT s.Periodo, s.TotalOrd, s.TotalExtra, s.PrimerV, s.SegundoV, s.IdConsorcio
    FROM (
        SELECT 
            CONCAT(RIGHT('0' + CAST(gOrd.mes AS VARCHAR(2)),2), CAST(YEAR(GETDATE()) AS VARCHAR(4))) AS Periodo, 
            ISNULL(sum(gOrd.importeFactura),0) AS TotalOrd, 
            ISNULL(sum(gEOrd.importe),0) AS TotalExtra, 
            CAST(GETDATE() AS DATE) AS PrimerV,
            CAST(DATEADD(DAY, 7, GETDATE()) AS DATE) AS SegundoV,
            gOrd.idConsorcio AS IdConsorcio
        FROM Gastos.GastoOrdinario as gOrd 
        LEFT JOIN Gastos.GastoExtraordinario as gEOrd
            ON gEord.mes = gOrd.mes AND gEOrd.idConsorcio = gOrd.idConsorcio
        GROUP BY gOrd.mes, gOrd.idConsorcio
    ) s
    WHERE NOT EXISTS (
        SELECT 1 FROM Gastos.Expensa e 
        WHERE e.periodo = s.Periodo AND e.idConsorcio = s.IdConsorcio
    );
END
GO

/* Modificado: sp_ImportarPagos parametrizado, sin insertar IDENTITY y con join corregido a expensa por periodo */
CREATE OR ALTER PROCEDURE sp_ImportarPagos
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
        PRINT 'Ruta o archivo inválidos (se esperaba .csv)';
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

    DELETE FROM #temporalPagos WHERE monto IS NULL OR fecha IS NULL OR claveBancaria IS NULL;
    
    UPDATE #temporalPagos
    SET 
        id = LTRIM(RTRIM(id)),
        claveBancaria =  LTRIM(RTRIM(claveBancaria)),
        monto = REPLACE(LTRIM(RTRIM(monto)),'$','');

    UPDATE #temporalPagos
    SET monto = REPLACE(monto, '.','');

    INSERT INTO Finanzas.Pagos
        (fecha,
        monto,
        cuentaBancaria,
        valido,
        idExpensa,
        idUF) 
    SELECT 
        CONVERT(DATE, LTRIM(RTRIM(fecha)), 103), 
        CAST(tP.monto AS DECIMAL(10,2)), 
        tP.claveBancaria, 
        CASE WHEN uf.id IS NULL OR e.id IS NULL THEN 0 ELSE 1 END, 
        e.id, 
        uf.id
    FROM #temporalPagos as tP
    LEFT JOIN Infraestructura.UnidadFuncional as uf
        ON uf.cbu_cvu = tP.claveBancaria
    LEFT JOIN Administracion.Consorcio as c
        ON uf.idEdificio = c.idEdificio
    LEFT JOIN Gastos.Expensa as e
        ON e.idConsorcio = c.id
       AND e.periodo = (
            RIGHT('0' + CAST(MONTH(CONVERT(DATE, LTRIM(RTRIM(fecha)),103)) AS VARCHAR(2)),2)
            + CAST(YEAR(CONVERT(DATE, LTRIM(RTRIM(fecha)),103)) AS VARCHAR(4))
        );
END
GO

-- Ejemplos de ejecución (ajustar rutas y descomentar para probar)
-- EXEC sp_ImportarConsorciosYEdificios;
-- EXEC sp_ImportarInquilinosPropietarios @rutaArchivoInquilinosPropietarios='C:\\ruta\\consorcios', @nombreArchivoInquilinosPropietarios='Inquilino-propietarios-UF.csv';
-- EXEC sp_InsertarUnidadesFuncionales @nombreRuta='C:\\ruta\\consorcios', @nombreArchivo='UF por consorcio.txt', @rutaArchivoIPUF='C:\\ruta\\consorcios', @nombreArchivoIPUF='Inquilino-propietarios-UF.csv';
-- EXEC sp_ImportarDatosInquilinos @nombreArchivo='Inquilino-propietarios-datos.csv', @rutaArchivo='C:\\ruta\\consorcios';
-- EXEC sp_ImportarGastosOrdinarios @rutaArchivo='C:\\ruta\\consorcios', @nombreArchivo='Servicios.Servicios.json';
-- EXEC sp_ImportarPagos @rutaArchivo='C:\\ruta\\consorcios', @nombreArchivo='pagos_consorcios.csv';

/* ============================ Ejecución con rutas locales ============================ */
USE Grupo05_5600;

EXEC sp_ImportarConsorciosYEdificios;

EXEC sp_ImportarInquilinosPropietarios
  @rutaArchivoInquilinosPropietarios = 'C:\Users\franc\OneDrive\Escritorio\UNlaM\BD\Grupo05-5600-main',
  @nombreArchivoInquilinosPropietarios = 'Inquilino-propietarios-UF.csv';

EXEC sp_InsertarUnidadesFuncionales
  @nombreRuta = 'C:\Users\franc\OneDrive\Escritorio\UNlaM\BD\Grupo05-5600-main',
  @nombreArchivo = 'UF por consorcio.txt',
  @rutaArchivoIPUF = 'C:\Users\franc\OneDrive\Escritorio\UNlaM\BD\Grupo05-5600-main',
  @nombreArchivoIPUF = 'Inquilino-propietarios-UF.csv';

EXEC sp_ImportarDatosInquilinos
  @nombreArchivo = 'Inquilino-propietarios-datos.csv',
  @rutaArchivo = 'C:\Users\franc\OneDrive\Escritorio\UNlaM\BD\Grupo05-5600-main';

EXEC sp_ImportarGastosOrdinarios
  @rutaArchivo = 'C:\Users\franc\OneDrive\Escritorio\UNlaM\BD\Grupo05-5600-main',
  @nombreArchivo = 'Servicios.Servicios.json';

EXEC sp_ImportarPagos
  @rutaArchivo = 'C:\Users\franc\OneDrive\Escritorio\UNlaM\BD\Grupo05-5600-main',
  @nombreArchivo = 'pagos_consorcios.csv';
