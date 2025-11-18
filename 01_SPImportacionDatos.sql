
/*
Enunciado: creacion de procedures, funciones y triggers para importar 
los archivos maestros, normalizar los datos e insertar los mismos en
las tablas.
Fecha entrega:
Comision: 5600
Grupo: 05
Materia: Base de datos aplicadas
Integrantes:
    - ERMASI, Franco: 44613354
    - GATTI, Gonzalo: 46208638
    - MORALES, Tomas: 40.755.243

Nombre: 01_SPImportacionDatos.sql
Proposito: Crear objetos para importar los datos de los archivos
(datos varios.xlsx - UF por consorcio.txt - Inquilino-propietarios-UF.csv - Inquilino-propietarios-datos.csv - Servicios.Servicios.json - pagos_consorcios.csv)
Script a ejecutar antes: 00_CreacionDeTablas.sql
*/


USE Com5600G05
GO

IF SCHEMA_ID('LogicaNormalizacion') IS NULL EXEC('CREATE SCHEMA LogicaNormalizacion');
IF SCHEMA_ID('LogicaBD') IS NULL EXEC('CREATE SCHEMA LogicaBD');
GO


/*====================================================================
                CREACION DE FUNCIONES DE NORMALIZACION                         
====================================================================*/

-- Normaliza nombre y extension de archivo
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

-- Normaliza ruta (quita comillas, usa '\', remueve barra final).
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

-- Convierte nombre de mes a numerico.
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

--Convierte texto a decimal
CREATE OR ALTER FUNCTION LogicaNormalizacion.fn_ToDecimal
(
    @s VARCHAR(200)
)
RETURNS DECIMAL(10,2)
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
        -- Solo hay punto: si parece separador de miles (grupos de 3), quitar puntos; si no, dejar como decimal
        IF @n LIKE '%.[0-9][0-9][0-9]' AND @n NOT LIKE '%.%.[0-9][0-9]'
            SET @tmp = REPLACE(@n, '.', '');
        ELSE
            SET @tmp = @n;
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

CREATE OR ALTER FUNCTION LogicaBD.fn_EsFeriado
( @fecha DATE )
RETURNS BIT 
AS
BEGIN
	DECLARE @obj INT
	DECLARE @url VARCHAR(100)
	DECLARE @retorno VARCHAR(8000)

	SET @url = 'https://argentinaferiados-api.vercel.app/2025'

	EXEC sp_OACreate 'MSXML2.XMLHTTP', @obj OUTPUT

	EXEC sp_OAMethod @obj, 'open', NULL, 'GET', @url, 'false'

	EXEC sp_OAMethod @obj, 'send'

	EXEC sp_OAMethod @obj, 'responseText', @retorno OUTPUT

	EXEC sp_OADestroy @obj

	DECLARE @fechaBusc DATE = DATEFROMPARTS(2025,11,21)
	DECLARE @esFeriado BIT = 0

	IF EXISTS (
		SELECT 1
		FROM OPENJSON(@retorno)
		WITH(
			fecha VARCHAR(10) '$.fecha',
			tipo VARCHAR(20) '$.tipo',
			motivo VARCHAR(200) '$.nombre'
		) AS F
		WHERE CAST(F.fecha AS DATE) = @fecha
	)
		SET @esFeriado = 1
	RETURN @esFeriado
END
GO

CREATE OR ALTER FUNCTION LogicaBD.fn_ObtenerFechaVencimiento
( @fecha DATE )
RETURNS DATE
AS
BEGIN
    DECLARE @esFeriado BIT
    SET @esFeriado = 
                CASE 
                    WHEN LogicaBD.fn_EsFeriado(@fecha) = 1 
                        OR DATEPART(WEEKDAY, @fecha) IN (1,6)
                    THEN 0
                    ELSE 1
                END
    DECLARE @fechaFinal DATE = @fecha
    WHILE @esFeriado = 0
    BEGIN
        SET @fechaFinal = DATEADD(DAY, 1, @fechaFinal)
        SET @esFeriado = 
                CASE 
                    WHEN LogicaBD.fn_EsFeriado(@fechaFinal) = 1 
                        OR DATEPART(WEEKDAY, @fechaFinal) IN (1,6)
                    THEN 1
                    ELSE 0
                END
    END
    RETURN @fechaFinal
END
GO

CREATE OR ALTER PROCEDURE LogicaBD.sp_AsociarPagosPorCuenta
    @cuentaBancaria VARCHAR(22)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE p
    SET 
        p.idUF  = uf.id,
        p.valido = 1
    FROM Finanzas.Pagos p
    INNER JOIN Infraestructura.UnidadFuncional uf
        ON uf.cbu_cvu = @cuentaBancaria
       AND p.cuentaBancaria = @cuentaBancaria
    WHERE p.idUF IS NULL;
END
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


/*====================================================================
                        CREACION DE TRIGGERS                         
====================================================================*/
--Genera tabla DetalleExpensa
/*CREATE OR ALTER TRIGGER Gastos.tg_CrearDetalleExpensa 
ON Gastos.Expensa
AFTER INSERT
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
		FROM inserted as ex 
        INNER JOIN Infraestructura.UnidadFuncional AS uf
            ON ex.idConsorcio = uf.idConsorcio
        INNER JOIN Administracion.Consorcio con
            ON con.id = uf.idConsorcio
	)
	
	INSERT INTO Gastos.DetalleExpensa
		(montoBase, montoCochera, montoBaulera, montoTotal, idExpensa, idUF)
	SELECT
		[Total Base],
		MontoCochera,
		MontoBaulera,
		[Total],
		[ID EX],
		[ID UF]
	FROM cteDeudaAPrimerVenc

END
GO*/



/*====================================================================
                        CREACION DE PROCEDIMIENTOS                         
====================================================================*/

-- Importa desde Excel a tabla Consorcio.
CREATE OR ALTER PROCEDURE LogicaBD.sp_InsertaConsorcioProveedor 
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
    FROM #ConsorciosStage s
	WHERE NOT EXISTS (
		SELECT 1 
		FROM Administracion.Consorcio c
		WHERE c.direccion = LEFT(s.domicilio, 100)
	);

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

-- Importa desde archivo de texto a tabla UnidadFuncionales
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
	nroUF VARCHAR(10),
	piso VARCHAR(10),
	dpto VARCHAR(10),
	coeficiente VARCHAR(10),
	m2UF VARCHAR(10),
	baulera CHAR(2),
	cochera CHAR(2),
	m2Baulera VARCHAR(10),
	m2Cochera VARCHAR(10)
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
	WHERE nombreConsorcio IS NULL OR LTRIM(RTRIM(nombreConsorcio)) = '' OR nroUF IS NULL 
		OR piso IS NULL OR dpto IS NULL OR coeficiente IS NULL OR m2UF IS NULL;

	UPDATE #temporalUF
	SET nombreConsorcio = LTRIM(RTRIM(nombreConsorcio)),
		nroUF = LTRIM(RTRIM(nroUF)),
		piso = LTRIM(RTRIM(piso)),
		dpto = LTRIM(RTRIM(dpto)),
		coeficiente = LTRIM(RTRIM(coeficiente)),
		m2UF = LTRIM(RTRIM(m2UF)),
		baulera = NULLIF(LTRIM(RTRIM(baulera)),''),
		cochera = NULLIF(LTRIM(RTRIM(cochera)),''),
		m2Baulera = REPLACE(LTRIM(RTRIM(m2Baulera)), '', 0),
		m2Cochera = REPLACE(LTRIM(RTRIM(m2Cochera)), '', 0)

	

	INSERT INTO Infraestructura.UnidadFuncional
	(piso, departamento, dimension, m2Cochera, m2Baulera, porcentajeParticipacion, idConsorcio)
	SELECT
	CAST(t.piso AS CHAR(2)) AS piso,
	CAST(t.dpto AS CHAR(1)) AS departamento,
	CAST(t.m2UF AS DECIMAL(5,2)) AS dimension,
	CASE WHEN UPPER(t.cochera) IN ('SI', 'SÍ') THEN CAST(LogicaNormalizacion.fn_ToDecimal(t.m2Cochera) AS DECIMAL(5,2)) ELSE 0 END,
	CASE WHEN UPPER(t.baulera) IN ('SI', 'SÍ') THEN CAST(LogicaNormalizacion.fn_ToDecimal(t.m2Baulera) AS DECIMAL(5,2)) ELSE 0 END,
	CAST(LogicaNormalizacion.fn_ToDecimal(t.coeficiente) AS DECIMAL(4,2)) AS porcentajeParticipacion,
	c.id
	FROM #temporalUF t
	INNER JOIN Administracion.Consorcio c ON LTRIM(RTRIM(LOWER(c.nombre))) = LTRIM(RTRIM(LOWER(t.nombreConsorcio)))
	WHERE c.id IS NOT NULL
		AND NOT EXISTS (
			SELECT 1
			FROM Infraestructura.UnidadFuncional uf
			WHERE uf.idConsorcio = c.id
			AND uf.piso = CAST(t.piso AS CHAR(2))
			AND uf.departamento = CAST(t.dpto AS CHAR(1))
		);
END
GO

-- Importa desde archivo csv a tabla temporal de relacion persona con uf
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
            FIELDTERMINATOR = ''|'',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''65001'',
            FIRSTROW = 2
        )';
    
    EXEC sp_executesql @sql;

	UPDATE iuf
	SET iuf.cbu_cvu = CAST(t.cvu AS CHAR(22))
	FROM #temporalInquilinosPropietariosCSV t
		INNER JOIN Administracion.Consorcio ac ON LTRIM(RTRIM(LOWER(ac.nombre))) = LTRIM(RTRIM(LOWER(t.consorcio)))
		INNER JOIN Infraestructura.UnidadFuncional iuf ON iuf.idConsorcio = ac.id AND LTRIM(RTRIM(iuf.piso)) = LTRIM(RTRIM(t.piso)) 
				AND LTRIM(RTRIM(iuf.departamento)) = LTRIM(RTRIM(UPPER(t.dpto)))
	WHERE t.cvu IS NOT NULL AND (iuf.cbu_cvu IS NULL OR iuf.cbu_cvu <> t.cvu);

	IF (OBJECT_ID('tempdb..#temporalInquilinosPropietariosCSV') IS NOT NULL)
	  BEGIN
		DROP TABLE #temporalInquilinosPropietariosCSV;
	  END
	END
GO

-- Importa desde archivo csv a tabla persona y a personaEnUF
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
        inquilino char(1)
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
        email = NULLIF(LOWER(LTRIM(RTRIM(email))), ''),
        telefono = NULLIF(LTRIM(RTRIM(telefono)), ''),
        cvu = NULLIF(LTRIM(RTRIM(cvu)), ''),
        inquilino = LTRIM(RTRIM(inquilino));

    DELETE FROM #temporalInquilinosCSV 
    WHERE nombre IS NULL OR apellido IS NULL OR dni IS NULL OR cvu IS NULL OR inquilino IS NULL 
        OR telefono LIKE '%[^0-9]%' OR LEN(telefono) <> 10 OR LEN(cvu) <> 22
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
		SET 
			cvu = REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(REPLACE(cvu,CHAR(13),''))), ' ', ''), '.', ''), CHAR(9), ''),
			dni = REPLACE(REPLACE(LTRIM(RTRIM(REPLACE(dni,CHAR(13),''))), ' ', ''), '.', ''),
			email = LOWER(LTRIM(RTRIM(email)));

	DELETE FROM #temporalInquilinosCSV
		WHERE inquilino NOT IN ('0','1');

    INSERT INTO Personas.Persona (dni, nombre, apellido, email, telefono, cbu_cvu)
	SELECT S.dni, S.nombre, S.apellido, S.email, S.telefono, CAST(S.cvu AS CHAR(22))
	FROM #temporalInquilinosCSV S
	WHERE NOT EXISTS (SELECT 1 FROM Personas.Persona T WHERE T.dni = S.dni)
	  AND NOT EXISTS (SELECT 1 FROM Personas.Persona T WHERE T.cbu_cvu = S.cvu)
	  AND (S.email IS NULL OR NOT EXISTS (SELECT 1 FROM Personas.Persona T WHERE T.email = LOWER(LTRIM(RTRIM(S.email)))));

    -- Materializamos los potenciales nuevos vínculos para reutilizarlos en múltiples sentencias
    IF OBJECT_ID('tempdb..#Nuevos') IS NOT NULL DROP TABLE #Nuevos;
    CREATE TABLE #Nuevos(
      idPersona INT,
      idUF INT,
      inquilino BIT
    );
    INSERT INTO #Nuevos(idPersona, idUF, inquilino)
    SELECT DISTINCT 
	  P.idPersona,
      UF.id,
      CAST(T.inquilino AS bit) AS inquilino
    FROM #temporalInquilinosCSV T
	JOIN Personas.Persona P ON P.dni = T.dni 
    JOIN Infraestructura.UnidadFuncional UF ON UF.cbu_cvu = T.cvu;

    -- Cerrar activo del mismo rol en la misma UF si es OTRO DNI
    UPDATE pe
      SET pe.fechaHasta = CASE 
                            WHEN CAST(GETDATE() AS DATE) > pe.fechaDesde 
                              THEN CAST(GETDATE() AS DATE)
                            ELSE DATEADD(DAY, 1, pe.fechaDesde) -- evita violar CK (>)
                          END
    FROM Personas.PersonaEnUF pe
    JOIN #Nuevos n
      ON n.idUF = pe.idUF
     AND n.inquilino = pe.inquilino
    WHERE pe.fechaHasta IS NULL
      AND pe.idPersona <> n.idPersona;

    -- Insertar solo si esa misma persona no está activa en ese rol/UF
    INSERT INTO Personas.PersonaEnUF (idPersona, idUF, inquilino, fechaDesde, fechaHasta)
    SELECT n.idPersona, n.idUF, n.inquilino, CAST(GETDATE() AS DATE), NULL
    FROM #Nuevos n
    WHERE NOT EXISTS (
      SELECT 1
      FROM Personas.PersonaEnUF x
      WHERE x.idUF = n.idUF
        AND x.inquilino = n.inquilino
        AND x.fechaHasta IS NULL
        AND x.idPersona = n.idPersona
    );

    DROP TABLE #Nuevos;
END
GO

-- Importa desde archivo json a tabla GastosExtraordinarios
CREATE OR ALTER PROCEDURE LogicaBD.sp_InsertarGastosExtraordinarios
@idCons INT,
@mesGasto INT
AS
BEGIN
    DECLARE @idConsGastoExt INT = ( SELECT MIN(idConsorcio) FROM Gastos.GastoExtraordinario )

    IF @idConsGastoExt IS NULL
    BEGIN
        DECLARE @idMin INT = (SELECT MIN(id) FROM Administracion.Consorcio)
        DECLARE @idMax INT = (SELECT MAX(id) FROM Administracion.Consorcio)

        SET @idConsGastoExt = ( SELECT FLOOR(RAND() * (@idMax - @idMin + 1)) + @idMin )
        INSERT INTO Gastos.GastoExtraordinario(mes, detalle, importe, formaPago, nroCuotaAPagar, nroTotalCuotas, idConsorcio)
            VALUES (1, '', 1, 'Total', NULL, NULL, @idConsGastoExt)
    END

    IF @idConsGastoExt != @idCons
    BEGIN
        RETURN;
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
                                                ELSE CONCAT('Construccion de ', @estructura, ' agregada al complejo.'
												)
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

-- Importa desde archivo json a tabla GastosOrdinarios
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

	IF OBJECT_ID('tempdb..##datosProveedores') IS NULL
	BEGIN
	  RAISERROR('##datosProveedores no existe. Ejecute sp_InsertarEnConsorcio primero.', 16, 1);
	  RETURN;
	END

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
		DECLARE @huboGastoOrdinarioNuevo BIT = 0
        
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

			SET @huboGastoOrdinarioNuevo = 1
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

			SET @huboGastoOrdinarioNuevo = 1
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

			SET @huboGastoOrdinarioNuevo = 1
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

			SET @huboGastoOrdinarioNuevo = 1
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

			SET @huboGastoOrdinarioNuevo = 1
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

			SET @huboGastoOrdinarioNuevo = 1
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

			SET @huboGastoOrdinarioNuevo = 1
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
            VALUES (@mes, 'Servicios Publico', ISNULL(@empresa, 'Desconocido'), @numeroFactura, @gastoNet/100, 'Internet', @idConsorcio)
            SET @numeroFactura = @numeroFactura + 1

			SET @huboGastoOrdinarioNuevo = 1
        END
        
		IF @huboGastoOrdinarioNuevo = 1
		BEGIN
			EXEC LogicaBD.sp_InsertarGastosExtraordinarios @idCons = @idConsorcio, @mesGasto = @mes
		END

        SET @contador = @contador + 1
    END    

	DELETE FROM Gastos.GastoExtraordinario
    WHERE id = 1
END
GO

--Importa desde archivo Excel a tabla Pagos
CREATE OR ALTER PROCEDURE LogicaBD.sp_ImportarPagos
@rutaArchivo VARCHAR(100),
@nombreArchivo VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #temporalPagos (
        id CHAR(5),
        fecha VARCHAR(10),
        cvu VARCHAR(22),
        monto VARCHAR(50)
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
            id    = LTRIM(RTRIM(id)),
            fecha = LTRIM(RTRIM(fecha)),
            cvu   = LTRIM(RTRIM(cvu  )),
            monto = LogicaNormalizacion.fn_ToDecimal(monto);

	UPDATE #temporalPagos
        SET cvu = NULL
        WHERE cvu LIKE '%[^0-9]%' OR LEN(cvu) <> 22;

	DELETE FROM #temporalPagos
		WHERE NULLIF(fecha,'') IS NULL
			OR NULLIF(cvu,'') IS NULL
			OR NULLIF(monto,'') IS NULL
			OR NULLIF(id, '') IS NULL;


    INSERT INTO Finanzas.Pagos
		(
		 id,
		 fecha,
         monto,
         cuentaBancaria,
         valido,
         idExpensa,
         idUF) 
    SELECT 
		tP.id,
        TRY_CONVERT(DATE, tP.fecha, 103), 
        tP.monto, 
        tP.cvu, 
         CASE
             WHEN uf.id IS NULL OR e.id IS NULL OR tP.cvu IS NULL THEN 0
             ELSE 1
        END AS valido, 
        e.id, 
        uf.id
    FROM #temporalPagos as tP
    LEFT JOIN Infraestructura.UnidadFuncional as uf	ON uf.cbu_cvu = tP.cvu
    LEFT JOIN Administracion.Consorcio as c	ON uf.idConsorcio = c.id
    LEFT JOIN Gastos.Expensa e ON e.idConsorcio = c.id
       AND e.periodo = CAST(
            RIGHT('0' + CAST(MONTH(TRY_CONVERT(DATE, tP.fecha, 103)) AS VARCHAR(2)),2)
            + CAST(YEAR(TRY_CONVERT(DATE, tP.fecha, 103)) AS VARCHAR(4)) as CHAR(6)
		)
	WHERE NOT EXISTS (
        SELECT 1
        FROM Finanzas.Pagos p
        WHERE p.id = tP.id
    );
END
GO

/*====================================================================
                        CREACION DE EXPENSA                         
====================================================================*/

-- Genera la tabla de expensas
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
            COALESCE(O.mes, E.mes) AS mes,
            COALESCE(O.idConsorcio, E.idConsorcio) AS idConsorcio,
            ISNULL(O.SumaOrd, 0) AS SumaOrd,
            ISNULL(E.SumaExtra, 0) AS SumaExtra
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
        DATEFROMPARTS(YEAR(GETDATE()), U.mes, 10) AS PrimerV,
        DATEFROMPARTS(YEAR(GETDATE()), U.mes, 15) AS SegundoV,
        U.idConsorcio
    FROM U
    WHERE NOT EXISTS (
        SELECT 1
        FROM Gastos.Expensa ex
        WHERE ex.periodo = CONCAT(RIGHT('0' + CAST(U.mes AS VARCHAR(2)), 2), CAST(YEAR(GETDATE()) AS VARCHAR(4)))
          AND ex.idConsorcio = U.idConsorcio
    );

    
    WITH cteFechasVenc AS
    (
        SELECT 
            id,
            LogicaBD.fn_ObtenerFechaVencimiento(primerVencimiento) as [PrimerVenc],
            LogicaBD.fn_ObtenerFechaVencimiento(segundoVencimiento) as [SegundoVenc]
        FROM (
            SELECT DISTINCT
                id,
                primerVencimiento,
                segundoVencimiento
            FROM Gastos.Expensa
        ) AS sub1
    )
    UPDATE ex
    SET
        primerVencimiento = PrimerVenc,
        segundoVencimiento = SegundoVenc
    FROM Gastos.Expensa as ex INNER JOIN cteFechasVenc as cte 
        ON ex.id = cte.id
END
GO


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
		(Total + SaldoArrastrado) AS montoTotal,
		[ID EX],
		[ID UF],
		CASE
			WHEN (SaldoArrastrado + InteresArrastrado + Total) <= 0 THEN 'P'
			ELSE 'D'
		END AS estado
	FROM cteArrastre a

END
GO