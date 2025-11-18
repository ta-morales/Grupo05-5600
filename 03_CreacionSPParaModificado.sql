/*
Enunciado: creacion de procedure para modificar las
unidades funcionales
Fecha entrega:
Comision: 5600
Grupo: 05
Materia: Base de datos aplicadas
Integrantes:
    - ERMASI, Franco: 44613354
    - GATTI, Gonzalo: 46208638
    - MORALES, Tomas: 40.755.243

  Nombre: 04_CreacionSPParaModificado.sql
  Proposito: Creacion de stored procedure para modificar unidades funcionales
  Script a ejecutar antes: 00_CreacionDeTablas.sql 01_SPImportacionDatos.sql
*/

USE master

USE Com5600G05
GO

CREATE OR ALTER PROCEDURE Infraestructura.sp_ModificarUnidadFuncional
	@idUF INT,
	@piso CHAR(2) = NULL,
	@departamento CHAR(1) = NULL,
	@dimension DECIMAL(5,2) = NULL,
	@m2Cochera DECIMAL(5,2) = NULL,
	@m2Baulera DECIMAL(5,2) = NULL,
	@porcentajeParticipacion DECIMAL(4,2) = NULL,
	@cbu_cvu CHAR(22) = NULL,
	@idConsorcio INT = NULL
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;

		IF NOT EXISTS (
			SELECT 1
			FROM Infraestructura.UnidadFuncional
			WHERE id = @idUF
		)
		BEGIN
			PRINT('La id de la unidad funcional que quiere modificar no existe');
			RAISERROR('.', 16, 1);
		END

		DECLARE
			@pisoNuevo CHAR(2),
			@dptoNuevo CHAR(1),
			@idConsNuevo INT;

		SELECT
			@pisoNuevo  = ISNULL(@piso, piso),
			@dptoNuevo  = ISNULL(@departamento, departamento),
			@idConsNuevo = ISNULL(@idConsorcio, idConsorcio)
		FROM Infraestructura.UnidadFuncional
		WHERE id = @idUF;

		IF @piso IS NOT NULL
		   AND @piso NOT LIKE 'PB'
		   AND (@piso < '01' OR @piso > '99')
		BEGIN
			PRINT('Piso no valido');
			RAISERROR('.', 16, 1);
		END;

		IF @departamento IS NOT NULL
		   AND @departamento NOT LIKE '[A-Z]'
		BEGIN
			PRINT('Departamento no valido');
			RAISERROR('.', 16, 1);
		END;

		IF @porcentajeParticipacion IS NOT NULL
		   AND (@porcentajeParticipacion <= 0 OR @porcentajeParticipacion > 100)
		BEGIN
			PRINT('Porcentaje de participacion no valido');
			RAISERROR('.', 16, 1);
		END;

		IF @cbu_cvu IS NOT NULL
		   AND (@cbu_cvu LIKE '%[^0-9]%' OR LEN(@cbu_cvu) <> 22)
		BEGIN
			PRINT('CBU/CVU no valido');
			RAISERROR('.', 16, 1);
		END;

		IF EXISTS (
			SELECT 1
			FROM Infraestructura.UnidadFuncional
			WHERE idConsorcio = @idConsNuevo
			  AND piso         = @pisoNuevo
			  AND departamento = @dptoNuevo
			  AND id <> @idUF
		)
		BEGIN
			PRINT('Ya existe una UF con ese consorcio, piso y departamento');
			RAISERROR('.', 16, 1);
		END;

		IF @idConsorcio IS NOT NULL
		   AND NOT EXISTS (
				SELECT 1
				FROM Administracion.Consorcio
				WHERE id = @idConsorcio
		   )
		BEGIN
			PRINT('Id de consorcio no valido');
			RAISERROR('.', 16, 1);
		END;

		UPDATE Infraestructura.UnidadFuncional
		SET piso = ISNULL(@piso, piso),
			departamento = ISNULL(@departamento, departamento),
			dimension = ISNULL(@dimension, dimension),
			m2Cochera = ISNULL(@m2Cochera, m2Cochera),
			m2Baulera = ISNULL(@m2Baulera, m2Baulera),
			porcentajeParticipacion = ISNULL(@porcentajeParticipacion, porcentajeParticipacion),
			cbu_cvu = CASE WHEN @cbu_cvu IS NULL THEN cbu_cvu ELSE @cbu_cvu END,
			idConsorcio = ISNULL(@idConsorcio, idConsorcio)
		WHERE id = @idUF;

		PRINT('Unidad funcional modificada exitosamente');

	END TRY

	BEGIN CATCH

		IF ERROR_SEVERITY()>10
		BEGIN	
			RAISERROR('Algo salio mal al intentar modificar la unidad funcional', 16, 1);
			RETURN;
		END

	END CATCH

END
GO