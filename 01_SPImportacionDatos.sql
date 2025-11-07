USE Grupo05_5600
GO
-- djsfhnsadjkgnbsajkga
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
CREATE OR ALTER PROCEDURE LogicaBD.sp_InsertarEnConsorcio 
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
    END
END
GO

CREATE OR ALTER PROCEDURE LogicaBD.sp_ImportarConsorciosYEdificios
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Infraestructura.Edificio (direccion, metrosTotales) VALUES
        ('Belgrano 3344', 1281),
        ('Callao 1122', 914),
        ('Santa Fe 910', 784),
        ('Corrientes 5678', 1316),
        ('Rivadavia 1234', 1691)
    
    EXEC LogicaBD.sp_InsertarEnConsorcio @direccion='Belgrano 3344', @nombre='Azcuenaga'
    EXEC LogicaBD.sp_InsertarEnConsorcio @direccion='Callao 1122', @nombre='Alzaga'
    EXEC LogicaBD.sp_InsertarEnConsorcio @direccion='Santa Fe 910', @nombre='Alberdi'
    EXEC LogicaBD.sp_InsertarEnConsorcio @direccion='Corrientes 5678', @nombre='Unzue'
    EXEC LogicaBD.sp_InsertarEnConsorcio @direccion='Rivadavia 1234', @nombre='Pereyra Iraola'
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

  DELETE tUF
    FROM #temporalUF AS tUF
    LEFT JOIN Administracion.Consorcio AS c
        ON tUF.nombreConsorcio = c.nombre
    LEFT JOIN Infraestructura.UnidadFuncional AS uf
        ON tUF.piso = uf.piso
        AND tUF.dpto = uf.departamento
        AND c.idEdificio = uf.idEdificio
    WHERE c.id IS NOT NULL AND uf.id IS NOT NULL

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
  LEFT JOIN ##temporalInquilinosPropietariosCSV AS tpi
         ON tpi.consorcio = t.nombreConsorcio
        AND tpi.piso      = t.piso
        AND tpi.dpto      = t.dpto
  WHERE tpi.cvu IS NOT NULL;

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
            FIELDTERMINATOR = '','',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''65001'',
            FIRSTROW = 2
        )';

    EXEC sp_executesql @sql;

    SELECT * FROM #temporalInquilinosCSV

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
    ('SEGUROS', 'FEDERACIÓN PATRONAL SEGUROS - Integral de consorcio', NULL, 'Azcuenaga'),
    ('SERVICIOS PUBLICOS', 'AYSA', 'Cuenta 195329', 'Azcuenaga'),
    ('SERVICIOS PUBLICOS', 'EDENOR', 'Cuenta 4363152506', 'Azcuenaga'),
    ('GASTOS DE LIMPIEZA', 'Serv. Limpieza', 'Limptech', 'Azcuenaga'),
    ('GASTOS BANCARIOS', 'BANCO CREDICOOP - Gastos bancario', NULL, 'Alzaga'),
    ('GASTOS DE ADMINISTRACION', 'FLAVIO HERNAN DIAZ - Honorarios', NULL, 'Alzaga'),
    ('SEGUROS', 'FEDERACIÓN PATRONAL SEGUROS - Integral de consorcio', NULL, 'Alzaga'),
    ('SERVICIOS PUBLICOS', 'AYSA', 'Cuenta 174329', 'Alzaga'),
    ('SERVICIOS PUBLICOS', 'EDENOR', 'Cuenta 4363125506', 'Alzaga'),
    ('GASTOS DE LIMPIEZA', 'Serv. Limpieza', 'Limpi AR', 'Alzaga'),
    ('SEGUROS', 'FEDERACIÓN PATRONAL SEGUROS - Integral de consorcio', NULL, 'Alberdi'),
    ('SERVICIOS PUBLICOS', 'AYSA', 'Cuenta 215329', 'Alberdi'),
    ('SERVICIOS PUBLICOS', 'EDENOR', 'Cuenta 4463152506', 'Alberdi'),
    ('GASTOS DE LIMPIEZA', 'Serv. Limpieza', 'Clean SA', 'Alberdi'),
    ('GASTOS BANCARIOS', 'BANCO CREDICOOP - Gastos bancario', NULL, 'Unzue'),
    ('GASTOS DE ADMINISTRACION', 'FLAVIO HERNAN DIAZ - Honorarios', NULL, 'Unzue'),
    ('SEGUROS', 'FEDERACIÓN PATRONAL SEGUROS - Integral de consorcio', NULL, 'Unzue'),
    ('SERVICIOS PUBLICOS', 'AYSA', 'Cuenta 544329', 'Unzue'),
    ('SERVICIOS PUBLICOS', 'EDENOR', 'Cuenta 4447852506', 'Unzue'),
    ('GASTOS DE LIMPIEZA', 'Serv. Limpieza', 'Limpieza General SA', 'Unzue'),
    ('GASTOS BANCARIOS', 'BANCO CREDICOOP - Gastos bancario', NULL, 'Pereyra Iraola'),
    ('GASTOS DE ADMINISTRACION', 'FLAVIO HERNAN DIAZ - Honorarios', NULL, 'Pereyra Iraola'),
    ('SEGUROS', 'FEDERACIÓN PATRONAL SEGUROS - Integral de consorcio', NULL, 'Pereyra Iraola'),
    ('SERVICIOS PUBLICOS', 'AYSA', 'Cuenta 5147329', 'Pereyra Iraola'),
    ('SERVICIOS PUBLICOS', 'EDENOR', 'Cuenta 445742506', 'Pereyra Iraola'),
    ('GASTOS DE LIMPIEZA', 'Serv. Limpieza', 'Limptech', 'Pereyra Iraola');
    
    DECLARE @ruta VARCHAR(100) = LogicaNormalizacion.fn_NormalizarRutaArchivo(@rutaArchivo),
            @archivo VARCHAR(100) = LogicaNormalizacion.fn_NormalizarNombreArchivoCSV(@nombreArchivo, 'json');

    IF (@ruta = '' OR @archivo = '')
    BEGIN
        RETURN;
    END;

    UPDATE p
    SET p.consorcio = c.id
    FROM #datosProveedores AS p
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
        SET g.consorcio = c.idEdificio
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
            SET @empresa = (SELECT empresa FROM #datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%BANCARIOS%')
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
            SET @empresa = (SELECT empresa FROM #datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%LIMPIEZA%')
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
            SET @empresa = (SELECT empresa FROM #datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%ADMINISTRACION%')
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
            SET @empresa = (SELECT empresa FROM #datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%SEGUROS%')
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
            SET @empresa = (SELECT empresa FROM #datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%PUBLICOS%' AND empresa LIKE '%AYSA%')
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
            SET @empresa = (SELECT empresa FROM #datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%PUBLICOS%' AND ( empresa LIKE '%EDENOR%' OR empresa LIKE '%EDESUR%'))
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
            SET @empresa = (SELECT empresa FROM #datosProveedores WHERE consorcio = @idConsorcio AND tipoGasto LIKE '%PUBLICOS%' AND ( empresa NOT LIKE '%EDENOR%' AND empresa NOT LIKE '%EDESUR%' AND empresa NOT LIKE '%AYSA%'))
            INSERT INTO Gastos.GastoOrdinario (mes, tipoGasto, empresaPersona, nroFactura, importeFactura, detalle, idConsorcio)
            VALUES (@mes, 'Servicios Publico', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoLuz/100, 'Internet', @idConsorcio)
            SET @numeroFactura = @numeroFactura + 1
        END
        
        SET @contador = @contador + 1
    END

    INSERT INTO Gastos.Expensa 
       (periodo, totalGastoOrdinario, totalGastoExtraordinario, primerVencimiento, segundoVencimiento, idConsorcio)
    SELECT s.Periodo, s.TotalOrd, s.TotalExtra, s.PrimerV, s.SegundoV, s.IdConsorcio
    FROM (
        SELECT 
            CONCAT(RIGHT('0' + CAST(gOrd.mes AS VARCHAR(2)),2), CAST(YEAR(GETDATE()) AS VARCHAR(4))) AS Periodo, 
            SUM(ISNULL(gOrd.importeFactura,0))AS TotalOrd, 
            SUM(ISNULL(gEOrd.importe,0)) AS TotalExtra, 
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