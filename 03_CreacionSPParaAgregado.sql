/*
Enunciado: creacion de procedures para dar de alta a los
diferentes agentes del sistema, desde consorcios hasta
gastos.
Fecha entrega:
Comision: 5600
Grupo: 05
Materia: Base de datos aplicadas
Integrantes:
    - ERMASI, Franco: 44613354
    - GATTI, Gonzalo: 46208638
    - MORALES, Tomas: 40.755.243

  Nombre: 04_CreacionSPParaAgregado.sql
  Proposito: CREACION DE STORED PROCEDURE PARA INSERCION DE DATOS
  Script a ejecutar antes: 00_CreacionDeTablas.sql
*/

USE master

USE Com5600G05
GO

-- Inserta datos en Tabla Tabla Consorcios
CREATE OR ALTER PROCEDURE Administracion.sp_AgregarConsorcio
	@nombre VARCHAR(100),
	@direccion VARCHAR(100),
	@metrosTotales DECIMAL(8,2)
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;
			DECLARE @ID INT;

		SET @nombre = LTRIM(RTRIM(@nombre));
		SET	@direccion = LTRIM(RTRIM(@direccion));

			--Validamos que no exista el mismo consorcio--
		SELECT @ID = id
		FROM Administracion.Consorcio
		WHERE nombre = @nombre

		IF @ID IS NOT NULL
		BEGIN 
			PRINT('Ya existe un consorcio con el nombre ingresado');
			RAISERROR('.', 16, 1);
		END

		IF @nombre = '' OR @nombre LIKE '%[^a-zA-Z ]%' OR LEN(@nombre) > 100
		BEGIN
			PRINT('El nombre del consorcio es invalido');
			RAISERROR('.', 16, 1);
		END

		IF @direccion = '' OR LEN(@direccion) > 100
		BEGIN
			PRINT('La direccion del consorcio es invalida');
			RAISERROR('.', 16, 1);
		END

		IF @metrosTotales IS NULL OR @metrosTotales <= 0 OR @metrosTotales > 999999.99
		BEGIN
			PRINT('Los metros totales debe ser un valor entre 0 y 999999.99');
			RETURN;
		END

		INSERT INTO Administracion.Consorcio(nombre, direccion, metrosTotales)
		VALUES (@nombre, @direccion, @metrosTotales);

		PRINT('Consorcio agregado correctamente');

		SET @ID = SCOPE_IDENTITY();
		SELECT @ID AS id;
	END TRY

	BEGIN CATCH
		IF ERROR_SEVERITY()>10
		BEGIN	
			RAISERROR('Algo salio mal en el registro del consorcio', 16, 1);
			RETURN;
		END
	END CATCH
END
GO

-- Inserta datos en Tabla Unidad funcional
CREATE OR ALTER PROCEDURE Infraestructura.sp_AgregarUnidadFuncional
	@piso CHAR(2),
	@departamento CHAR(1),
	@dimension DECIMAL(5,2),
	@m2Cochera DECIMAL(5,2),
	@m2Baulera DECIMAL(5,2),
	@porcentajeParticipacion DECIMAL(4,2),
	@cbu_cvu CHAR(22),
	@idConsorcio INT
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;
		DECLARE 
			@ID INT,
			@existeConsorcio INT;

		SET @piso = UPPER(LTRIM(RTRIM(@piso)));
		SET @departamento = UPPER(LTRIM(RTRIM(@departamento)));
		SET @dimension = ROUND(@dimension, 2);
		SET @m2Cochera = ROUND(ISNULL(@m2Cochera, 0), 2);
		SET @m2Baulera = ROUND(ISNULL(@m2Baulera, 0), 2);
		SET @porcentajeParticipacion = ROUND(@porcentajeParticipacion, 2);
		SET @cbu_cvu = REPLACE(LTRIM(RTRIM(@cbu_cvu)), ' ', '');

		IF @idConsorcio IS NULL OR @idConsorcio <= 0
		BEGIN
			PRINT('ID de consorcio invalido');
			RAISERROR('.', 16, 1);
		END

		SELECT @existeConsorcio = id
		FROM Administracion.Consorcio
		WHERE id = @idConsorcio

		IF @existeConsorcio IS NULL
		BEGIN
			PRINT('No existe el consorcio al cual se le quiere asignar la unidad funcional');
			RAISERROR('.', 16, 1);
		END
		
		IF @piso IS NULL OR @piso = '' OR NOT (@piso = 'PB' OR (@piso NOT LIKE '%[^0-9]%' AND LEN(@piso) BETWEEN 1 AND 2)) 
		BEGIN
			PRINT('Piso invalido');
			RAISERROR('.', 16, 1);
		END
   
		IF @departamento IS NULL OR @departamento = '' OR @departamento LIKE '%[^A-Z]%' OR LEN(@departamento) <> 1
		BEGIN
			PRINT('Departamento invalido');
			RAISERROR('.', 16, 1);
		END

		IF @dimension IS NULL OR @dimension <= 0 OR @dimension > 999.99
		BEGIN
			PRINT('Dimension invalida');
			RAISERROR('.', 16, 1);
		END

		IF @m2Cochera < 0 or @m2Cochera > 999.99
		BEGIN
			PRINT('Dimension de cochera invalida');
			RAISERROR('.', 16, 1);
		END

		IF @m2Baulera < 0 or @m2Baulera > 999.99
		BEGIN
			PRINT('Dimension de baulera invalida');
			RAISERROR('.', 16, 1);
		END

		IF @porcentajeParticipacion IS NULL OR @porcentajeParticipacion <= 0 OR @porcentajeParticipacion > 100
		BEGIN
			PRINT('Porcentaje de participacion invalida');
			RAISERROR('.', 16, 1);
		END

		IF @cbu_cvu IS NULL OR LEN(@cbu_cvu) <> 22 OR @cbu_cvu LIKE '%[^0-9]%'
		BEGIN
			PRINT('Cbu/cvu invalido');
			RAISERROR('.', 16, 1);
		END

		SELECT @ID = id
		FROM Infraestructura.UnidadFuncional
		WHERE piso = @piso AND departamento = @departamento AND idConsorcio = @idConsorcio;
		
		IF @ID IS NOT NULL
		BEGIN
			PRINT('Ya existe una unidad funcional con los datos asignados');
			RAISERROR('.', 16, 1);
		END

		INSERT INTO Infraestructura.UnidadFuncional(piso, departamento, dimension, m2Cochera, m2Baulera, porcentajeParticipacion, cbu_cvu, idConsorcio)
		VALUES (@piso, @departamento, @dimension, @m2Cochera, @m2Baulera, @porcentajeParticipacion, @cbu_cvu, @idConsorcio)

		PRINT('Unidad funcional insertada exitosamente');

		SET @ID = SCOPE_IDENTITY();
		SELECT @ID AS id;
	END TRY

	BEGIN CATCH
		IF ERROR_SEVERITY()>10
		BEGIN	
			RAISERROR('Algo salio mal en el registro de la unidad funcional', 16, 1);
			RETURN;
		END
	END CATCH
END
GO

-- Inserta datos en Tabla Tabla Persona
CREATE OR ALTER PROCEDURE Personas.sp_AgregarPersona
	@dni VARCHAR(9),
	@nombre VARCHAR(50),
	@apellido VARCHAR(50),
	@email VARCHAR(100),
	@telefono VARCHAR(10),
	@cbu_cvu CHAR(22)
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;
		DECLARE 
			@ID VARCHAR(9),
			@emailRepetido VARCHAR(100);

		SET @dni = REPLACE(REPLACE(LTRIM(RTRIM(@dni)),' ',''),'.','');
		SET @nombre = CONCAT(UPPER(LEFT(LTRIM(RTRIM(@nombre)),1)), LOWER(SUBSTRING(LTRIM(RTRIM(@nombre)),2,100)));
		SET @apellido = CONCAT(UPPER(LEFT(LTRIM(RTRIM(@apellido)),1)), LOWER(SUBSTRING(LTRIM(RTRIM(@apellido)),2,100)));
		SET @email = NULLIF(LOWER(LTRIM(RTRIM(@email))), '');
		SET @telefono = NULLIF(LTRIM(RTRIM(@telefono)), '');
		SET @cbu_cvu = NULLIF(LTRIM(RTRIM(@cbu_cvu)), '');

		IF @dni IS NULL OR @dni = '' OR @dni LIKE '%[^0-9]%' OR LEN(@dni) NOT BETWEEN 7 AND 9
		BEGIN 
			PRINT('DNI invalido');
			RAISERROR('.', 16, 1);
		END

		SELECT @ID = idPersona
		FROM Personas.Persona
		WHERE dni = @dni

		IF @ID IS NOT NULL
		BEGIN
			PRINT('Ya existe una persona con este DNI');
			RAISERROR('.', 16, 1);
		END

		IF @email IS NOT NULL AND (LEN(@email) > 100 OR @email NOT LIKE '%@%')
		BEGIN 
			PRINT('Email invalido');
			RAISERROR('.', 16, 1);
		END

		SELECT @emailRepetido = email
		FROM Personas.Persona
		WHERE email = @email

		IF @emailRepetido IS NOT NULL
		BEGIN
			PRINT('Email repetido');
			RAISERROR('.', 16, 1);
		END

		IF @nombre = '' OR LEN(@nombre) > 50 OR @nombre LIKE '%[^a-zA-Z ]%'
		BEGIN 
			PRINT('Nombre invalido');
			RAISERROR('.', 16, 1);
		END

		IF @apellido = '' OR LEN(@apellido) > 50 OR @apellido LIKE '%[^a-zA-Z ]%'
		BEGIN 
			PRINT('Apellido invalido');
			RAISERROR('.', 16, 1);
		END

		IF @telefono IS NOT NULL AND (@telefono LIKE '%[^0-9]%' OR LEN(@telefono) <> 10)
		BEGIN 
			PRINT('Telefono invalido');
			RAISERROR('.', 16, 1);
		END

		IF @cbu_cvu IS NULL OR LEN(@cbu_cvu) <> 22 OR @cbu_cvu LIKE '%[^0-9]%'
		BEGIN 
			PRINT('Cbu/cvu invalido');
			RAISERROR('.', 16, 1);
		END

		INSERT INTO Personas.Persona(dni, nombre, apellido, email, telefono, cbu_cvu)
		VALUES (@dni, @nombre, @apellido, @email, @telefono, @cbu_cvu)

		PRINT('Persona insertada exitosamente');

		SET @ID = SCOPE_IDENTITY();
		SELECT @ID AS id;
	END TRY
		
	BEGIN CATCH
		IF ERROR_SEVERITY()>10
		BEGIN	
			RAISERROR('Algo salio mal en el registro de persona',16,1);
			RETURN;
		END
	END CATCH
END
GO


-- Inserta datos en Tabla Tabla Persona En UF
CREATE OR ALTER PROCEDURE Personas.sp_AgregarPersonaEnUF
	@dniPersona VARCHAR(9),
	@idUF INT,
	@inquilino BIT,
	@fechaDesde DATE,
	@fechaHasta DATE
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;
		DECLARE 
			@ID INT,
			@unidadFuncionalExiste INT,
			@IDPersona INT;
		
		SET @dniPersona = REPLACE(REPLACE(LTRIM(RTRIM(@dniPersona)),' ',''),'.','');

		IF @idUF IS NULL OR @idUF <= 0
		BEGIN
			PRINT('ID de unidad funcional invalida');
			RAISERROR('.', 16, 1);
		END

		SELECT @unidadFuncionalExiste = id
		FROM Infraestructura.UnidadFuncional
		WHERE id = @idUF

		IF @unidadFuncionalExiste IS NULL
		BEGIN
			PRINT('La unidad funcional donde se quiere asignar a la persona no existe');
			RAISERROR('.', 16, 1);
		END

		IF @dniPersona IS NULL OR @dniPersona = '' OR @dniPersona LIKE '%[^0-9]%' OR LEN(@dniPersona) NOT BETWEEN 7 AND 9
        BEGIN
			PRINT('DNI invalido');
			RAISERROR('.', 16, 1);
		END

		SELECT @IDPersona = idPersona
		FROM Personas.Persona
		WHERE dni = @dniPersona

		IF @IDPersona IS NULL
		BEGIN
			PRINT('La persona no existe');
			RAISERROR('.', 16, 1);
		END

		IF @inquilino NOT IN (0,1)
		BEGIN
			PRINT('Bit de inquilino invalido');
			RAISERROR('.', 16, 1);
		END

		IF @fechaDesde IS NULL
		BEGIN
			PRINT('Fecha desde invalida');
			RAISERROR('.', 16, 1);
		END

		IF @fechaHasta IS NOT NULL AND @fechaHasta < @fechaDesde
		BEGIN
			PRINT('Fecha hasta invalida');
			RAISERROR('.', 16, 1);
		END

		SELECT @ID = idPersonaUF
		FROM Personas.PersonaEnUF
		WHERE idPersona = @IDPersona AND fechaDesde = @fechaDesde

		IF @ID IS NOT NULL
		BEGIN
			PRINT('Persona en unidad funcional ya existe');
			RAISERROR('.', 16, 1);
		END

		INSERT INTO Personas.PersonaEnUF (idPersona, idUF, inquilino, fechaDesde, fechaHasta)
		VALUES (@IDPersona, @idUF, @inquilino, @fechaDesde, @fechaHasta)

		PRINT('Persona en unidad funcional insertada exitosamente');

		SET @ID = SCOPE_IDENTITY();
		SELECT @ID AS id;
	END TRY

	BEGIN CATCH
		IF ERROR_SEVERITY()>10
		BEGIN	
			RAISERROR('Algo salio mal en el registro de persona en unidad funcional',16,1);
			RETURN;
		END
	END CATCH
END
GO

-- Inserta datos en Tabla Tabla Gasto Ordinario
CREATE OR ALTER PROCEDURE Gastos.AgregarGastoOrdinario
	@mes INT,
	@tipoGasto VARCHAR(50),
	@empresaPersona VARCHAR(100),
	@nroFactura VARCHAR(20),
	@importeFactura DECIMAL(8, 2),
	@detalle VARCHAR(200),
	@idConsorcio INT
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;
		DECLARE
			@ID INT,
			@consorcioExiste INT;

		SET @tipoGasto      = NULLIF(LTRIM(RTRIM(@tipoGasto)), '');
		SET @empresaPersona = NULLIF(LTRIM(RTRIM(@empresaPersona)), '');
		SET @nroFactura     = NULLIF(UPPER(LTRIM(RTRIM(@nroFactura))), '');
		SET @detalle        = NULLIF(LTRIM(RTRIM(@detalle)), '');
		SET @importeFactura = ROUND(@importeFactura, 2);

		IF @idConsorcio IS NULL OR @idConsorcio <= 0
		BEGIN
			PRINT('ID de consorcio invalido');
			RAISERROR('.', 16, 1);
		END

		SELECT @consorcioExiste = id
		FROM Administracion.Consorcio
		WHERE id = @idConsorcio

		IF @consorcioExiste IS NULL
		BEGIN
			PRINT('El consorcio al cual quiere añadir el gasto ordinario no existe');
			RAISERROR('.', 16, 1);
		END

		SELECT @ID = id
		FROM Gastos.GastoOrdinario
		WHERE nroFactura = @nroFactura

		IF @ID IS NOT NULL
		BEGIN
			PRINT('El gasto ordinario ya existe');
			RAISERROR('.', 16, 1);
		END


		IF @mes IS NULL OR @mes < 1 OR @mes > 12
		BEGIN
			PRINT('Mes invalido');
			RAISERROR('.', 16, 1);
		END

		IF @tipoGasto IS NULL OR @tipoGasto NOT IN (
                'Mantenimiento de cuenta bancaria','Limpieza',
                'Administracion/Honorarios','Seguro',
                'Generales','Servicios Publico'
           )
		BEGIN
			PRINT('Tipo de gasto invalido');
			RAISERROR('.', 16, 1);
		END

		IF @nroFactura IS NULL OR LEN(@nroFactura) > 20 OR @nroFactura LIKE '%[^A-Z0-9/-]%'
		BEGIN
			PRINT('Numero de factura invalido');
			RAISERROR('.', 16, 1);
		END

		IF @importeFactura IS NULL OR @importeFactura <= 0 OR @importeFactura > 999999.99
		BEGIN
			PRINT('Importe de factura invalido');
			RAISERROR('.', 16, 1);
		END

		IF @detalle IS NOT NULL AND LEN(@detalle) > 200
		BEGIN
			PRINT('Detalle de factura invalido');
			RAISERROR('.', 16, 1);
		END

		INSERT INTO Gastos.GastoOrdinario(mes, tipoGasto, empresaPersona, nroFactura, importeFactura, detalle, idConsorcio)
		VALUES (@mes, @tipoGasto, @empresaPersona, @nroFactura, @importeFactura, @detalle, @idConsorcio)

		PRINT('Gasto ordinario insertado exitosamente');

		SET @ID = SCOPE_IDENTITY();
		SELECT @ID AS id;
	END TRY

	BEGIN CATCH
		IF ERROR_SEVERITY()>10
		BEGIN	
			RAISERROR('Algo salio mal en el registro de gasto ordinario',16,1);
			RETURN;
		END
	END CATCH
END
GO

CREATE OR ALTER PROCEDURE Gastos.sp_AgregarGastoExtraordinario
	@mes INT,
	@detalle VARCHAR(200),
	@importe DECIMAL(10,2),
	@formaPago VARCHAR(6),
	@nroCuotaAPagar INT,
	@nroTotalCuotas INT,
	@idConsorcio INT
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;
		DECLARE 
			@ID INT,
			@consorcioExiste INT;

		SET @detalle   = LTRIM(RTRIM(@detalle));
        SET @formaPago = CASE WHEN UPPER(LTRIM(RTRIM(@formaPago)))='CUOTAS' THEN 'Cuotas' ELSE 'Total' END;

		SELECT @ID = id
		FROM Gastos.GastoExtraordinario
		WHERE mes = @mes AND idConsorcio = @idConsorcio AND detalle = @detalle

		IF @ID IS NOT NULL
		BEGIN
			PRINT('El pago extraordinario con este detalle ya existe');
			RAISERROR('.', 16, 1);
		END

		IF @idConsorcio IS NULL OR @idConsorcio <= 0
		BEGIN
		 PRINT('Consorcio invalido');
		 RAISERROR('.', 16, 1);
		END

		SELECT @consorcioExiste = id
		FROM Administracion.Consorcio
		WHERE id = @idConsorcio

		IF @consorcioExiste IS NULL
		BEGIN
		 PRINT('El consorcio al cual quiere asignar el gasto extraordinario no existe');
		 RAISERROR('.', 16, 1);
		END

		IF @mes IS NULL OR @mes < 1 OR @mes > 12
		BEGIN
		 PRINT('Mes invalido');
		 RAISERROR('.', 16, 1);
		END

		IF @detalle = '' OR LEN(@detalle) > 200 OR @detalle IS NULL
		BEGIN
		 PRINT('Detalle invalido');
		 RAISERROR('.', 16, 1);
		END
            
		IF @importe IS NULL OR @importe <= 0 OR @importe > 99999999.99
		BEGIN
		 PRINT('Importe invalido');
		 RAISERROR('.', 16, 1);
		END

		IF @formaPago NOT IN ('Cuotas','Total')
		BEGIN
		 PRINT('Forma de pago invalida');
		 RAISERROR('.', 16, 1);
		END

		IF @formaPago='Cuotas'
        BEGIN
            IF @nroTotalCuotas IS NULL OR @nroTotalCuotas <= 0
				BEGIN
					PRINT('El numero total de cuotas debe ser mayor a cero')
					RAISERROR('.', 16, 1);
				END

            IF @nroCuotaAPagar IS NULL OR @nroCuotaAPagar <= 0 OR @nroCuotaAPagar > @nroTotalCuotas
                BEGIN
					PRINT('El numero de cuota a pagar debe estar entre 1 y el numero total de cuotas')
					RAISERROR('.', 16, 1);
				END
        END
        ELSE  -- 'Total'
        BEGIN
            SET @nroCuotaAPagar = 1;
            SET @nroTotalCuotas = 1;
        END

		INSERT INTO Gastos.GastoExtraordinario
            (mes, detalle, importe, formaPago, nroCuotaAPagar, nroTotalCuotas, idConsorcio)
        VALUES
            (@mes, @detalle, @importe, @formaPago, @nroCuotaAPagar, @nroTotalCuotas, @idConsorcio);

		PRINT('Gasto extraordinario insertado exitosamente');

        SET @ID = SCOPE_IDENTITY();
        SELECT @ID AS id;
	END TRY

	BEGIN CATCH
		IF ERROR_SEVERITY()>10
		BEGIN	
			RAISERROR('Algo salio mal en el registro de gasto extraordinario', 16, 1);
			RETURN;
		END
	END CATCH
END
GO

CREATE OR ALTER PROCEDURE Finanzas.sp_AgregarPago
	@fecha DATE,
	@monto DECIMAL(10, 2),
	@cuentaBancaria VARCHAR(22)
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;
		DECLARE 
			@ID INT,
			@idExpensa INT,
			@idUF INT;

			IF @cuentaBancaria IS NULL
			BEGIN
			 PRINT('Cuenta bancara invalida');
			 RAISERROR('.', 16, 1);
			END

			IF NOT EXISTS (
				SELECT 1 
				FROM Personas.Persona 
				WHERE cbu_cvu = @cuentaBancaria
			)
			BEGIN
				PRINT('La cuenta bancaria indicada no le pertenece a ninguna persona registrada.');
				RAISERROR('.', 16, 1);
			END;

			SELECT @idExpensa = id
			FROM Gastos.Expensa
			WHERE periodo = CAST(
				RIGHT('0' + CAST(MONTH(@fecha) AS VARCHAR(2)),2)
				+ CAST(YEAR(@fecha) AS VARCHAR(4)) as CHAR(6)
			)

			IF @idExpensa IS NULL
			BEGIN
				PRINT('La expensa para la cual proviene el pago no existe');
				RAISERROR('.', 16, 1);
			END

			SELECT @idUF = id
			FROM Infraestructura.UnidadFuncional
			WHERE cbu_cvu = @cuentaBancaria;

			IF @monto IS NULL OR @monto <= 0 OR @monto > 99999999.99
			BEGIN
				PRINT('Monto invalido');
				RAISERROR('.', 16, 1);
			END

			SELECT @ID = ISNULL(MAX(p.id), 0) + 1
			FROM Finanzas.Pagos p;

			INSERT INTO Finanzas.Pagos 
				(id, fecha, monto, cuentaBancaria, valido, idExpensa, idUF)
			VALUES (
				@ID,
				@fecha,
				@monto,
				@cuentaBancaria,
				CASE 
					WHEN @idUF IS NOT NULL THEN 1
					ELSE 0
				END,
				@idExpensa,
				@idUF
			)

			PRINT('Pago insertado exitosamente');

			SELECT @ID AS id;
	END TRY

	BEGIN CATCH
		IF ERROR_SEVERITY()>10
		BEGIN	
			RAISERROR('Algo salio mal en el registro de pago', 16, 1);
			RETURN;
		END
	END CATCH
END
GO

