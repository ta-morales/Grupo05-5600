/*
Enunciado: creacion de scripts para cifrar
datos sensibles del sistema.
Fecha entrega:
Comision: 5600
Grupo: 05
Materia: Base de datos aplicadas
Integrantes:
    - ERMASI, Franco: 44613354
    - GATTI, Gonzalo: 46208638
    - MORALES, Tomas: 40.755.243

Nombre: 06_SPCifrado.sql
Proposito: Cifrar datos sensibles
Script a ejecutar antes: 00_CreacionDeTablas.sql 01_SPImportacionDatos.sql
*/

/*====================================================================
                EJECUTAR POR PARTES                     
====================================================================*/

USE master

USE Com5600G05
GO

ALTER TABLE Personas.Persona
ADD dniCifrado VARBINARY(MAX),
	nombreCifrado VARBINARY(MAX),
	apellidoCifrado VARBINARY(MAX),
	emailCifrado VARBINARY(MAX),
	telefonoCifrado VARBINARY(MAX),
	cbuCifrado VARBINARY(MAX);
GO

CREATE OR ALTER PROCEDURE Personas.sp_CifrarPersonas
AS
BEGIN

	BEGIN TRY
		SET NOCOUNT ON;

		DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576';

		UPDATE Personas.Persona
		SET dniCifrado      = EncryptByPassPhrase(@Frase, dni, 1, CONVERT(VARBINARY, idPersona)),
			nombreCifrado   = EncryptByPassPhrase(@Frase, nombre, 1, CONVERT(VARBINARY, idPersona)),
			apellidoCifrado = EncryptByPassPhrase(@Frase, apellido, 1, CONVERT(VARBINARY, idPersona)),
			emailCifrado    = EncryptByPassPhrase(@Frase, email, 1, CONVERT(VARBINARY, idPersona)),
			telefonoCifrado = EncryptByPassPhrase(@Frase, telefono, 1, CONVERT(VARBINARY, idPersona)),
			cbuCifrado      = EncryptByPassPhrase(@Frase, cbu_cvu, 1, CONVERT(VARBINARY, idPersona))
		WHERE dniCifrado IS NULL;

		UPDATE Personas.Persona
		SET dni = NULL,
			nombre = NULL,
			apellido = NULL,
			email = NULL,
			telefono = NULL,
			cbu_cvu = NULL
		WHERE dniCifrado IS NOT NULL;

		PRINT('Persona cifrada con exito');

	END TRY

	BEGIN CATCH

		RAISERROR('Se produjo un error al cifrar persona', 16, 1);
		RETURN;

	END CATCH
END
GO

CREATE OR ALTER PROCEDURE Personas.sp_ObtenerPersonasDescifradas
AS
BEGIN
    DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576';
    SELECT
        idPersona,
        CONVERT(VARCHAR(9),  DecryptByPassPhrase(@Frase, dniCifrado, 1, CONVERT(VARBINARY, idPersona))) AS dni,
        CONVERT(VARCHAR(50), DecryptByPassPhrase(@Frase, nombreCifrado, 1, CONVERT(VARBINARY, idPersona))) AS nombre,
        CONVERT(VARCHAR(50), DecryptByPassPhrase(@Frase, apellidoCifrado, 1, CONVERT(VARBINARY, idPersona))) AS apellido,
        CONVERT(VARCHAR(100),DecryptByPassPhrase(@Frase, emailCifrado, 1, CONVERT(VARBINARY, idPersona))) AS email,
        CONVERT(VARCHAR(10), DecryptByPassPhrase(@Frase, telefonoCifrado, 1, CONVERT(VARBINARY, idPersona))) AS telefono,
        CONVERT(VARCHAR(22), DecryptByPassPhrase(@Frase, cbuCifrado, 1, CONVERT(VARBINARY, idPersona))) AS cbu_cvu
    FROM Personas.Persona;
END
GO

CREATE OR ALTER FUNCTION Personas.fn_DesencriptarNombre
( @idPersona INT )
RETURNS VARCHAR(50)
AS
BEGIN
	DECLARE @valorTabla VARCHAR(50)
	SET @valorTabla = ( SELECT nombre FROM Personas.Persona WHERE idPersona = @idPersona)
	IF @valorTabla IS NULL
	BEGIN
		DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576'
		DECLARE @cifrado VARBINARY(MAX) 
		SET @cifrado = (SELECT nombreCifrado FROM Personas.Persona WHERE idPersona = @idPersona)
		RETURN CONVERT(VARCHAR(50),  DecryptByPassPhrase(@Frase, @cifrado, 1, CONVERT(VARBINARY, @idPersona)))
	END
	RETURN @valorTabla
END
GO

CREATE OR ALTER FUNCTION Personas.fn_DesencriptarApellido
( @idPersona VARBINARY(MAX) )
RETURNS VARCHAR(50)
AS
BEGIN
	DECLARE @valorTabla VARCHAR(50)
	SET @valorTabla = ( SELECT apellido FROM Personas.Persona WHERE idPersona = @idPersona)
	IF @valorTabla IS NULL
	BEGIN
		DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576'
		DECLARE @cifrado VARBINARY(MAX) 
		SET @cifrado = (SELECT apellidoCifrado FROM Personas.Persona WHERE idPersona = @idPersona)
		RETURN CONVERT(VARCHAR(50),  DecryptByPassPhrase(@Frase, @cifrado, 1, CONVERT(VARBINARY, @idPersona)))
	END
	RETURN @valorTabla
END
GO

CREATE OR ALTER FUNCTION Personas.fn_DesencriptarDNI
( @idPersona VARBINARY(MAX) )
RETURNS VARCHAR(9)
AS
BEGIN
	DECLARE @valorTabla VARCHAR(9)
	SET @valorTabla = ( SELECT dni FROM Personas.Persona WHERE idPersona = @idPersona)
	IF @valorTabla IS NULL
	BEGIN
		DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576'
		DECLARE @cifrado VARBINARY(MAX) 
		SET @cifrado = (SELECT dniCifrado FROM Personas.Persona WHERE idPersona = @idPersona)
		RETURN CONVERT(VARCHAR(9),  DecryptByPassPhrase(@Frase, @cifrado, 1, CONVERT(VARBINARY, @idPersona)))
	END
	RETURN @valorTabla
END
GO

CREATE OR ALTER FUNCTION Personas.fn_DesencriptarEmail
 ( @idPersona VARBINARY(MAX) )
RETURNS VARCHAR(100)
AS
BEGIN
	DECLARE @valorTabla VARCHAR(100)
	SET @valorTabla = ( SELECT email FROM Personas.Persona WHERE idPersona = @idPersona)
	IF @valorTabla IS NULL
	BEGIN
		DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576'
		DECLARE @cifrado VARBINARY(MAX) 
		SET @cifrado = (SELECT emailCifrado FROM Personas.Persona WHERE idPersona = @idPersona)
		RETURN CONVERT(VARCHAR(100),  DecryptByPassPhrase(@Frase, @cifrado, 1, CONVERT(VARBINARY, @idPersona)))
	END
	RETURN @valorTabla
END
GO

CREATE OR ALTER FUNCTION Personas.fn_DesencriptarTelefono
( @idPersona VARBINARY(MAX) )
RETURNS VARCHAR(10)
AS
BEGIN
	DECLARE @valorTabla VARCHAR(10)
	SET @valorTabla = ( SELECT telefono FROM Personas.Persona WHERE idPersona = @idPersona)
	IF @valorTabla IS NULL
	BEGIN
		DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576'
		DECLARE @cifrado VARBINARY(MAX) 
		SET @cifrado = (SELECT telefonoCifrado FROM Personas.Persona WHERE idPersona = @idPersona)
		RETURN CONVERT(VARCHAR(10),  DecryptByPassPhrase(@Frase, @cifrado, 1, CONVERT(VARBINARY, @idPersona)))
	END
	RETURN @valorTabla
END
GO

CREATE OR ALTER FUNCTION Personas.fn_DesencriptarClaveBancaria
( @idPersona VARBINARY(MAX) )
RETURNS VARCHAR(22)
AS
BEGIN
	DECLARE @valorTabla VARCHAR(22)
	SET @valorTabla = ( SELECT cbu_cvu FROM Personas.Persona WHERE idPersona = @idPersona)
	IF @valorTabla IS NULL
	BEGIN
		DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576'
		DECLARE @cifrado VARBINARY(MAX) 
		SET @cifrado = (SELECT cbuCifrado FROM Personas.Persona WHERE idPersona = @idPersona)
		RETURN CONVERT(VARCHAR(22),  DecryptByPassPhrase(@Frase, @cifrado, 1, CONVERT(VARBINARY, @idPersona)))
	END
	RETURN @valorTabla
END
GO

-- Cifrar tabla de unidad funcional (solo cbu)

ALTER TABLE Infraestructura.UnidadFuncional
ADD cbuCifrado VARBINARY(MAX);
GO

CREATE OR ALTER PROCEDURE Infraestructura.sp_CifrarUnidadFuncional
AS
BEGIN

	BEGIN TRY
		SET NOCOUNT ON;

		DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576';

		UPDATE Infraestructura.UnidadFuncional
		SET cbuCifrado  = EncryptByPassPhrase(@Frase, cbu_cvu, 1, CONVERT(VARBINARY, id))
		WHERE cbuCifrado IS NULL;

		UPDATE Infraestructura.UnidadFuncional
		SET cbu_cvu = NULL
		WHERE cbu_cvu IS NOT NULL;

		PRINT('Unidad funcional cifrada con exito');

	END TRY

	BEGIN CATCH

		RAISERROR('Se produjo un error al cifrar unidad funcional', 16, 1);
		RETURN;

	END CATCH

END
GO

CREATE OR ALTER PROCEDURE Infraestructura.sp_DescifrarUnidadFuncional
AS
BEGIN
    DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576';

    SELECT
		id,
		piso, 
		departamento,
		dimension,
		m2Cochera,
		m2Baulera,
		porcentajeParticipacion,
        CONVERT(VARCHAR(22), DecryptByPassPhrase(@Frase, cbuCifrado, 1, CONVERT(VARBINARY, id))) AS cbu_cvu,
		idConsorcio
    FROM Infraestructura.UnidadFuncional;
END
GO

-- Cifrar tabla de envio expensas (email y telefono)

ALTER TABLE Gastos.EnvioExpensa
ADD emailCifrado VARBINARY(MAX),
	telefonoCifrado VARBINARY(MAX);
GO

CREATE OR ALTER PROCEDURE Gastos.sp_CifrarEnvioExpensa
AS
BEGIN

	BEGIN TRY
		SET NOCOUNT ON;

		DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576';

		UPDATE Gastos.EnvioExpensa
		SET emailCifrado  = EncryptByPassPhrase(@Frase, email, 1, CONVERT(VARBINARY, id)),
			telefonoCifrado = EncryptByPassPhrase(@Frase, telefono, 1, CONVERT(VARBINARY, id))
		WHERE emailCifrado IS NULL OR telefonoCifrado IS NULL;

		UPDATE Gastos.EnvioExpensa
		SET email = NULL,
			telefono = NULL
		WHERE email IS NOT NULL OR telefono IS NOT NULL;

		PRINT('Envio expensa cifrada con exito');

	END TRY

	BEGIN CATCH

		RAISERROR('Se produjo un error al cifrar envio de expensa', 16, 1);
		RETURN;

	END CATCH

END
GO

CREATE OR ALTER PROCEDURE Gastos.sp_DescifrarEnvioExpensa
AS
BEGIN

	DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576';

    SELECT
		id,
		metodo, 
		CONVERT(VARCHAR(22), DecryptByPassPhrase(@Frase, emailCifrado, 1, CONVERT(VARBINARY, id))) AS email,
		CONVERT(VARCHAR(22), DecryptByPassPhrase(@Frase, telefonoCifrado, 1, CONVERT(VARBINARY, id))) AS telefono,
		fecha,
		estado,
		idPersona,
		idDetalle
    FROM Gastos.EnvioExpensa;

END
GO

CREATE OR ALTER TRIGGER Gastos.tg_GenerarEnvioExpensa
ON Gastos.DetalleExpensa
AFTER INSERT
AS
BEGIN
SET NOCOUNT ON;
INSERT INTO Gastos.EnvioExpensa
	  (metodo, email, telefono, fecha, estado, idPersona, idDetalle)
SELECT
	CASE
	  WHEN Personas.fn_DesencriptarEmail(p.idPersona)    IS NOT NULL THEN 'email'
	  WHEN Personas.fn_DesencriptarTelefono(p.idPersona) IS NOT NULL THEN 'telefono'
	  ELSE 'impreso'
	END AS metodo,
	CASE
	  WHEN Personas.fn_DesencriptarEmail(p.idPersona) IS NOT NULL
	  THEN Personas.fn_DesencriptarEmail(p.idPersona)
	  ELSE NULL
	END AS email,
	CASE
	  WHEN Personas.fn_DesencriptarTelefono(p.idPersona) IS NOT NULL
	  THEN Personas.fn_DesencriptarTelefono(p.idPersona)
	  ELSE NULL
	END AS telefono,
	  DATEADD(DAY, -5, ex.primerVencimiento) AS fecha,
	  'D' AS estado,
	  p.idPersona,
	  i.id AS idDetalle
	  FROM inserted i
	  INNER JOIN Personas.PersonaEnUF pe ON pe.idUF = i.idUF
	  INNER JOIN Personas.Persona     p  ON p.idPersona = pe.idPersona
	  INNER JOIN Gastos.Expensa       ex ON ex.id = i.idExpensa;
	END
GO

-- Cifrar tabla de pagos (solo cuenta bancaria)

ALTER TABLE Finanzas.Pagos
ADD cuentaBancariaCifrada VARBINARY(MAX);
GO

ALTER TABLE Finanzas.Pagos
DROP CONSTRAINT CK_Pagos_cuentaBancaria
GO

ALTER TABLE Finanzas.Pagos
ADD CONSTRAINT CK_Pagos_CuentaBancaria
	CHECK (cuentaBancaria IS NOT NULL OR cuentaBancariaCifrada IS NOT NULL)
GO

CREATE OR ALTER PROCEDURE Finanzas.sp_CifrarPagos
AS
BEGIN
	
	BEGIN TRY
		SET NOCOUNT ON;

		DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576';

		UPDATE Finanzas.Pagos
		SET cuentaBancariaCifrada = EncryptByPassPhrase(@Frase, cuentaBancaria, 1, CONVERT(VARBINARY, id))
		WHERE cuentaBancariaCifrada IS NULL

		UPDATE Finanzas.Pagos
		SET cuentaBancaria = NULL
		WHERE cuentaBancaria IS NOT NULL

		PRINT('Persona cifrada con exito');

	END TRY

	BEGIN CATCH

		RAISERROR('Se produjo un error al cifrar pagos', 16, 1);
		RETURN;

	END CATCH

END
GO

CREATE OR ALTER PROCEDURE Finanzas.sp_DescrifrarPagos
AS
BEGIN
	
	DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576';

	SELECT 
		id,
		fecha,
		monto,
		CONVERT(VARCHAR(22), DecryptByPassPhrase(@Frase, cuentaBancariaCifrada, 1, CONVERT(VARBINARY, id))) AS cuentaBancaria,
		valido,
		idExpensa,
		idUF
	FROM Finanzas.Pagos

END
GO

CREATE OR ALTER FUNCTION Finanzas.fn_DescrifrarCBUPagos
( @idPago INT )
RETURNS VARCHAR(22)
AS
BEGIN
	DECLARE @valorTabla VARCHAR(22)
	SET @valorTabla = ( SELECT cuentaBancaria FROM Finanzas.Pagos WHERE id = @idPago )
	IF @valorTabla IS NULL
	BEGIN
		DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576'
		DECLARE @cifrado VARBINARY(MAX) 
		SET @cifrado = (SELECT cuentaBancariaCifrada FROM Finanzas.Pagos WHERE id = @idPago)
		RETURN CONVERT(VARCHAR(22),  DecryptByPassPhrase(@Frase, @cifrado, 1, CONVERT(VARBINARY, @idPago)))
	END
	RETURN @valorTabla
END
GO

CREATE OR ALTER FUNCTION Infraestructura.fn_DescrifrarCBUUF
( @idUF INT )
RETURNS VARCHAR(22)
AS
BEGIN
	DECLARE @valorTabla VARCHAR(22)
	SET @valorTabla = ( SELECT cbu_cvu FROM Infraestructura.UnidadFuncional WHERE id = @idUF )
	IF @valorTabla IS NULL
	BEGIN
		DECLARE @Frase NVARCHAR(128) = 'MiClaveSecreta_576'
		DECLARE @cifrado VARBINARY(MAX) 
		SET @cifrado = (SELECT cbuCifrado FROM Infraestructura.UnidadFuncional WHERE id = @idUF)
		RETURN CONVERT(VARCHAR(50),  DecryptByPassPhrase(@Frase, @cifrado, 1, CONVERT(VARBINARY, @idUF)))
	END
	RETURN @valorTabla
END
GO
