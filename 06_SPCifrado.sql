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
		SET dniCifrado      = EncryptByPassPhrase(@Frase, dni,      1, CONVERT(VARBINARY, idPersona)),
			nombreCifrado   = EncryptByPassPhrase(@Frase, nombre,   1, CONVERT(VARBINARY, idPersona)),
			apellidoCifrado = EncryptByPassPhrase(@Frase, apellido, 1, CONVERT(VARBINARY, idPersona)),
			emailCifrado    = EncryptByPassPhrase(@Frase, email,    1, CONVERT(VARBINARY, idPersona)),
			telefonoCifrado = EncryptByPassPhrase(@Frase, telefono, 1, CONVERT(VARBINARY, idPersona)),
			cbuCifrado      = EncryptByPassPhrase(@Frase, cbu_cvu,  1, CONVERT(VARBINARY, idPersona))
		WHERE dniCifrado IS NULL;

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
        CONVERT(VARCHAR(9),  DecryptByPassPhrase(@Frase, dniCifrado,      1, CONVERT(VARBINARY, idPersona))) AS dni,
        CONVERT(VARCHAR(50), DecryptByPassPhrase(@Frase, nombreCifrado,   1, CONVERT(VARBINARY, idPersona))) AS nombre,
        CONVERT(VARCHAR(50), DecryptByPassPhrase(@Frase, apellidoCifrado, 1, CONVERT(VARBINARY, idPersona))) AS apellido,
        CONVERT(VARCHAR(100),DecryptByPassPhrase(@Frase, emailCifrado,    1, CONVERT(VARBINARY, idPersona))) AS email,
        CONVERT(VARCHAR(10), DecryptByPassPhrase(@Frase, telefonoCifrado, 1, CONVERT(VARBINARY, idPersona))) AS telefono,
        CONVERT(VARCHAR(22), DecryptByPassPhrase(@Frase, cbuCifrado,      1, CONVERT(VARBINARY, idPersona))) AS cbu_cvu
    FROM Personas.Persona;
END
GO



