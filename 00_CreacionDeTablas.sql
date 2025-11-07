
-- CREACION DE BBDD --

IF DB_ID('auxiliarDB') IS NULL
BEGIN
	CREATE DATABASE auxiliarDB
END
GO

USE auxiliarDB
GO

IF DB_ID('Grupo05_5600') IS NOT NULL
BEGIN
	ALTER DATABASE Grupo05_5600
	SET SINGLE_USER
	WITH ROLLBACK IMMEDIATE;	

	DROP DATABASE Grupo05_5600
END
GO

IF DB_ID('Grupo05_5600') IS NULL
    CREATE DATABASE Grupo05_5600;
GO

USE Grupo05_5600
GO

IF DB_ID('auxiliarDB') IS NOT NULL
    DROP DATABASE auxiliarDB;
GO


------------------ CREACION DE ESQUEMAS ------------------

-- Incluye Edificio, UnidadFuncional
IF SCHEMA_ID('Infraestructura') IS NULL
BEGIN
	EXEC('CREATE SCHEMA Infraestructura');
END


-- Incluye Consorcio
IF SCHEMA_ID('Administracion') IS NULL
BEGIN
	EXEC('CREATE SCHEMA Administracion');
END

-- Incluye Perona, PersonaEnUF
IF SCHEMA_ID('Personas') IS NULL
BEGIN
	EXEC('CREATE SCHEMA Personas');
END


-- Incluye Expensa, DetalleExpensa, GastoOrdinario, GastoExtraordinario, EnvioExpensa
IF SCHEMA_ID('Gastos') IS NULL
BEGIN
	EXEC('CREATE SCHEMA Gastos');
END

-- Incluye Pago, MovimientoBancario
IF SCHEMA_ID('Finanzas') IS NULL
BEGIN
	EXEC('CREATE SCHEMA Finanzas');
END
	
IF SCHEMA_ID('LogicaNormalizacion') IS NULL
BEGIN
	EXEC('CREATE SCHEMA LogicaNormalizacion');
END


------------------ CREACION DE TABLAS ------------------

-- Incluye Edificio, UnidadFuncional
IF OBJECT_ID('Infraestructura.Edificio', 'U') IS NULL
BEGIN
	CREATE TABLE Infraestructura.Edificio(
		id INT IDENTITY(1,1),
		direccion VARCHAR(100) NOT NULL,
		metrosTotales DECIMAL(8,2) NOT NULL,
		CONSTRAINT pk_Edificio PRIMARY KEY (id)
	)
END

IF OBJECT_ID('Infraestructura.UnidadFuncional', 'U') IS NULL
BEGIN
	CREATE TABLE Infraestructura.UnidadFuncional(
		id INT IDENTITY (1,1),
		piso CHAR(2) CHECK (piso LIKE 'PB' OR piso BETWEEN '01' AND '99'),
		departamento CHAR(1) CHECK (departamento LIKE '[A-Z]'),
		dimension DECIMAL(5,2) NOT NULL CHECK (dimension > 0),
		m2Cochera DECIMAL(5,2) CHECK (m2Cochera >= 0),
		m2Baulera DECIMAL(5,2) CHECK (m2Baulera >= 0),
		porcentajeParticipacion DECIMAL(4,2) NOT NULL CHECK (porcentajeParticipacion > 0 AND porcentajeParticipacion <= 100),
		cbu_cvu CHAR(22) NOT NULL CHECK (cbu_cvu NOT LIKE '%[^0-9]%' AND LEN(cbu_cvu)=22),
		idEdificio INT,
		CONSTRAINT pk_UF PRIMARY KEY (id),
		CONSTRAINT fk_UF_Edificio FOREIGN KEY (idEdificio) REFERENCES Infraestructura.Edificio(id)
	)
END

-- Evita duplicar la UF en un edicio
CREATE UNIQUE INDEX UX_UF_EdificioPisoDto
ON Infraestructura.UnidadFuncional(idEdificio, piso, departamento);

-- Incluye Consorcio
IF OBJECT_ID('Administracion.Consorcio', 'U') IS NULL
BEGIN
	CREATE TABLE Administracion.Consorcio(
		id INT IDENTITY(1,1),
		nombre VARCHAR(100) NOT NULL,
		idEdificio INT,
		CONSTRAINT pk_Consorcio PRIMARY KEY (id),
		CONSTRAINT fk_Consorcio_Edificio FOREIGN KEY (idEdificio) REFERENCES Infraestructura.Edificio(id)
	)
END

-- Incluye Persona, PersonaEnUF
IF OBJECT_ID('Personas.Persona', 'U') IS NULL
BEGIN
	CREATE TABLE Personas.Persona(
		dni VARCHAR(9) CHECK (dni NOT LIKE '%[^0-9]%' AND LEN(dni) BETWEEN 7 AND 9),
		nombre VARCHAR(50) NOT NULL,
		apellido VARCHAR(50) NOT NULL,
		email VARCHAR(100) NULL CHECK (email IS NULL OR email LIKE '%@%'),
		email_trim AS LOWER(LTRIM(RTRIM(email))),
		telefono VARCHAR(10) NOT NULL CHECK (telefono NOT LIKE '%[^0-9]%' AND LEN(telefono)=10),
		cbu_cvu CHAR(22) NOT NULL UNIQUE CHECK (cbu_cvu NOT LIKE '%[^0-9]%' AND LEN(cbu_cvu)=22),
		CONSTRAINT pk_Persona PRIMARY KEY (dni)
	)
END

CREATE UNIQUE INDEX UX_Persona_EmailTrim
ON Personas.Persona(email_trim)
WHERE email_trim IS NOT NULL;

IF OBJECT_ID('Personas.PersonaEnUF', 'U') IS NULL
BEGIN
	CREATE TABLE Personas.PersonaEnUF(
		idPersonaUF int IDENTITY(1,1),
		dniPersona VARCHAR(9) CHECK (dniPersona NOT LIKE '%[^0-9]%') NOT NULL,
		idUF INT NOT NULL,
		inquilino BIT NOT NULL,
		fechaDesde DATE DEFAULT GETDATE() NOT NULL,
		fechaHasta DATE NULL,

		CONSTRAINT pk_PersonaEnUF PRIMARY KEY (idPersonaUF),

		CONSTRAINT fk_PersonaUF_Persona FOREIGN KEY (dniPersona) REFERENCES Personas.Persona(dni),
		CONSTRAINT fk_PersonaUF_UF FOREIGN KEY (idUF) REFERENCES Infraestructura.UnidadFuncional(id),

		-- Coherencia temporal 
		CONSTRAINT CK_PersonaEnUF_Rango CHECK (fechaHasta IS NULL OR fechaHasta > fechaDesde),
		-- Persona, uf y fechaDesde no se repite 
		CONSTRAINT UQ_PersonaUF_Desde UNIQUE (dniPersona, idUF, fechaDesde)
	)
END

-- Solo UNA relación activa por persona-UF 
CREATE UNIQUE INDEX UX_PersonaEnUF_Activa 
ON Personas.PersonaEnUF(dniPersona, idUF) 
WHERE fechaHasta IS NULL;

-- Incluye Expensa, DetalleExpensa, GastoOrdinario, GastoExtraordinario, EnvioExpensa
IF OBJECT_ID('Gastos.Expensa', 'U') IS NULL
BEGIN
	CREATE TABLE Gastos.Expensa (
		id INT IDENTITY(1,1),
		periodo CHAR(6) CHECK (LEN(periodo) = 6 AND periodo LIKE '[0-9][0-9][0-9][0-9][0-9][0-9]'),
		totalGastoOrdinario DECIMAL(12,2) CHECK (totalGastoOrdinario >= 0),
		totalGastoExtraordinario DECIMAL(12,2) CHECK (totalGastoExtraordinario >= 0),
		primerVencimiento DATE NOT NULL,
		segundoVencimiento DATE NOT NULL,
		idConsorcio INT,
		CONSTRAINT pk_Expensa PRIMARY KEY (id),
		CONSTRAINT fk_Expensa_Consorcio FOREIGN KEY (idConsorcio) REFERENCES Administracion.Consorcio(id)
	)
END

-- Expensa única por consorcio y periodo
CREATE UNIQUE INDEX UX_Expensa_ConsorcioPeriodo
ON Gastos.Expensa(idConsorcio, periodo);

/*
Basado en los archivos, GastoOrdinario, quizas deberia ser que cada campo sea el tipoDeGasto, y periodo (mes+año)?
*/
IF OBJECT_ID('Gastos.GastoOrdinario', 'U') IS NULL
BEGIN
	CREATE TABLE Gastos.GastoOrdinario (
		id INT IDENTITY(1,1),
		mes INT NOT NULL CHECK (mes >= 1 AND mes <= 12),
		tipoGasto VARCHAR(50) CHECK 
			(tipoGasto IN 
				(	'Mantenimiento de cuenta bancaria', 'Limpieza', 
					'Administracion/Honorarios', 'Seguro',
					'Generales', 'Servicios Publico')
				),
		empresaPersona VARCHAR(100),
		nroFactura VARCHAR(20),
		importeFactura DECIMAL(8,2),
		sueldoEmpleadoDomestico DECIMAL(10,2),
		detalle VARCHAR(200),
		idConsorcio INT,
		CONSTRAINT pk_GastoOrdinario PRIMARY KEY (id),
		CONSTRAINT fk_GastoOrdinario_Consorcio FOREIGN KEY (idConsorcio) REFERENCES Administracion.Consorcio(id)
	)
END

IF OBJECT_ID('Gastos.GastoExtraordinario', 'U') IS NULL
BEGIN
	CREATE TABLE Gastos.GastoExtraordinario (
		id INT IDENTITY(1, 1),
		mes INT NOT NULL CHECK (mes >= 1 AND mes <= 12),
		detalle VARCHAR(200) NOT NULL,
		importe DECIMAL(10,2) NOT NULL,
		formaPago VARCHAR(6) CHECK (formaPago IN ('Cuotas','Total')) NOT NULL,
		nroCuotaAPagar INT CHECK (nroCuotaAPagar > 0) NOT NULL,
		nroTotalCuotas INT CHECK (nroTotalCuotas > 0) NOT NULL,
		idConsorcio INT,
		CONSTRAINT pk_GastoExtraordinario PRIMARY KEY (id),
		CONSTRAINT fk_GastoExtraordinario_Consorcio FOREIGN KEY (idConsorcio) REFERENCES Administracion.Consorcio(id)
	)
END

IF OBJECT_ID('Gastos.DetalleExpensa', 'U') IS NULL
BEGIN
	CREATE TABLE Gastos.DetalleExpensa (
		id INT IDENTITY(1, 1),
		montoBase DECIMAL(10,2) CHECK (montoBase > 0),
		deuda DECIMAL(10,2),
		intereses DECIMAL (10,2),
		montoCochera DECIMAL(8,2),
		montoBaulera DECIMAL(8,2),
		montoTotal DECIMAL(20,2) CHECK (montoTotal > 0),
		estado CHAR(1) NOT NULL CHECK (estado IN ('P', 'E', 'D')),
		idExpensa INT,
		idUF INT,
		CONSTRAINT pk_DetalleExpensa PRIMARY KEY (id),
		CONSTRAINT fk_Detalle_Expensa FOREIGN KEY (idExpensa) REFERENCES Gastos.Expensa(id),
		CONSTRAINT fk_Detalle_UF FOREIGN KEY (idUF) REFERENCES Infraestructura.UnidadFuncional(id)
	)
END

-- Unico detalle por expensa/UF (evita duplicados)
CREATE UNIQUE INDEX UX_DetalleExpensa_ExpensaUF
ON Gastos.DetalleExpensa(idExpensa, idUF);

IF OBJECT_ID('Gastos.EnvioExpensa', 'U') IS NULL
BEGIN
	CREATE TABLE Gastos.EnvioExpensa (
		id INT IDENTITY(1, 1),
		rol VARCHAR(10),
		metodo VARCHAR(8) CHECK (metodo IN ('email', 'telefono', 'impreso')),
		email VARCHAR(100) NULL CHECK (email LIKE '%@%'),
		telefono VARCHAR(10) NOT NULL CHECK (telefono NOT LIKE '%[^0-9]%'),
		fecha DATE NOT NULL,
		estado CHAR(1) NOT NULL CHECK (estado IN ('P', 'E', 'D')),
		dniPersona VARCHAR(9),
		idExpensa INT,
		CONSTRAINT pk_EnvioExpensa PRIMARY KEY (id),
		CONSTRAINT fk_Envio_Persona FOREIGN KEY (dniPersona) REFERENCES Personas.Persona(dni),
		CONSTRAINT fk_Envio_Expensa FOREIGN KEY (idExpensa) REFERENCES Gastos.Expensa(id)
	)
END

IF OBJECT_ID('Finanzas.Pagos', 'U') IS NULL
BEGIN
	CREATE TABLE Finanzas.Pagos (
		id INT IDENTITY(1, 1),
		fecha DATE NOT NULL,
		monto DECIMAL(10,2) NOT NULL CHECK(monto >0),
		cuentaBancaria VARCHAR(22) NOT NULL,
		valido BIT NOT NULL,
		idExpensa INT,
		idUF INT,
		CONSTRAINT pk_Pagos PRIMARY KEY (id),
		CONSTRAINT fk_Pagos_Expensa FOREIGN KEY (idExpensa) REFERENCES Gastos.Expensa(id),
		CONSTRAINT fk_Pagos_UF FOREIGN KEY (idUF) REFERENCES Infraestructura.UnidadFuncional(id)
	)
END
