/*
Enunciado: creacion de tablas, esquemas e indices del sistema.
Fecha entrega:
Comision: 5600
Grupo: 05
Materia: Base de datos aplicadas
Integrantes:
    - ERMASI, Franco: 44613354
    - GATTI, Gonzalo: 46208638
    - MORALES, Tomas: 40.755.243

Nombre: 00_CreacionDeTablas.sql
Proposito: Crear esquemas, tablas, condiciones e indices base.
Script a ejecutar antes: Ninguno.
*/


/*====================================================================
          CREACIÓN DE BASE DE DATOS Y CONFIGURACION INICIAL                        
====================================================================*/

IF DB_ID('auxiliarDB') IS NULL
BEGIN
    CREATE DATABASE auxiliarDB
END
GO

USE auxiliarDB
GO

IF DB_ID('Com5600G05') IS NOT NULL
BEGIN
    ALTER DATABASE Com5600G05
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE; 

    DROP DATABASE Com5600G05
END
GO

IF DB_ID('Com5600G05') IS NULL
    CREATE DATABASE Com5600G05;
GO

USE Com5600G05
GO

IF DB_ID('auxiliarDB') IS NOT NULL
    DROP DATABASE auxiliarDB;
GO

-- 
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;

/*====================================================================
                        CREACIÓN DE ESQUEMAS                         
====================================================================*/

-- Incluye UnidadFuncional
IF SCHEMA_ID('Infraestructura') IS NULL
BEGIN
    EXEC('CREATE SCHEMA Infraestructura');
END


-- Incluye Consorcio
IF SCHEMA_ID('Administracion') IS NULL
BEGIN
    EXEC('CREATE SCHEMA Administracion');
END

-- Incluye Persona, PersonaEnUF
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

-- Esquema para logica de negocio (triggers, etc.)
IF SCHEMA_ID('LogicaBD') IS NULL
BEGIN
    EXEC('CREATE SCHEMA LogicaBD');
END



/*====================================================================
                        CREACIÓN DE TABLAS                         
====================================================================*/

-- Incluye Consorcio
IF OBJECT_ID('Administracion.Consorcio', 'U') IS NULL
BEGIN
    CREATE TABLE Administracion.Consorcio(
        id INT IDENTITY(1, 1),
        nombre VARCHAR(100) NOT NULL,
        direccion VARCHAR(100) NOT NULL UNIQUE,
        metrosTotales DECIMAL(8,2) NOT NULL,
        CONSTRAINT pk_Consorcio PRIMARY KEY (id)
    )
END

-- Incluye UnidadFuncional
IF OBJECT_ID('Infraestructura.UnidadFuncional', 'U') IS NULL
BEGIN
    CREATE TABLE Infraestructura.UnidadFuncional(
        id INT IDENTITY(1,1),
        piso CHAR(2) NOT NULL CHECK (piso LIKE 'PB' OR piso BETWEEN '01' AND '99'),
        departamento CHAR(1) NOT NULL CHECK (departamento LIKE '[A-Z]'),
        dimension DECIMAL(5,2) NOT NULL,
        m2Cochera DECIMAL(5,2),
        m2Baulera DECIMAL(5,2),
        porcentajeParticipacion DECIMAL(4,2) NOT NULL CHECK (porcentajeParticipacion > 0 AND porcentajeParticipacion <= 100),
        cbu_cvu CHAR(22) NULL CHECK (cbu_cvu NOT LIKE '%[^0-9]%' AND LEN(cbu_cvu)=22),
        idConsorcio INT,
        CONSTRAINT pk_UF PRIMARY KEY (id),
        CONSTRAINT fk_UF_Consorcio FOREIGN KEY (idConsorcio) REFERENCES Administracion.Consorcio(id),
        CONSTRAINT uq_UF_EdifPisoDpto UNIQUE (idConsorcio, piso, departamento)
    )
END

-- Incluye Persona, PersonaEnUF
IF OBJECT_ID('Personas.Persona', 'U') IS NULL
BEGIN
    CREATE TABLE Personas.Persona(
		idPersona int IDENTITY(1,1),
        dni VARCHAR(9) CHECK (dni NOT LIKE '%[^0-9]%' AND LEN(dni) BETWEEN 7 AND 9),
        nombre VARCHAR(50),
        apellido VARCHAR(50),
        email VARCHAR(100) CHECK (email LIKE '%@%'),
        telefono VARCHAR(10) CHECK (telefono NOT LIKE '%[^0-9]%'),
        cbu_cvu CHAR(22) CHECK (cbu_cvu NOT LIKE '%[^0-9]%' AND LEN(cbu_cvu)=22),

        CONSTRAINT pk_Persona PRIMARY KEY (idPersona)
    )
END

-- Indice unico sobre emails (permite muchos null)
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'UX_Persona_Email' 
      AND object_id = OBJECT_ID('Personas.Persona')
)
BEGIN
    CREATE UNIQUE INDEX UX_Persona_Email
    ON Personas.Persona(email)
    WHERE email IS NOT NULL;
END;

CREATE UNIQUE INDEX UX_Persona_CBU
ON Personas.Persona(cbu_cvu)
WHERE cbu_cvu IS NOT NULL;

CREATE UNIQUE INDEX UX_Persona_dni
ON Personas.Persona(dni)
WHERE dni IS NOT NULL;


IF OBJECT_ID('Personas.PersonaEnUF', 'U') IS NULL
BEGIN
    CREATE TABLE Personas.PersonaEnUF(
        idPersonaUF INT IDENTITY(1,1),
		idPersona INT NOT NULL,
        idUF INT NOT NULL,
        inquilino BIT NOT NULL,
        fechaDesde DATE DEFAULT GETDATE() NOT NULL,
        fechaHasta DATE NULL,

        CONSTRAINT pk_PersonaEnUF PRIMARY KEY (idPersonaUF),

        CONSTRAINT fk_PersonaUF_Persona FOREIGN KEY (idPersona) REFERENCES Personas.Persona(idPersona),
        CONSTRAINT fk_PersonaUF_UF FOREIGN KEY (idUF) REFERENCES Infraestructura.UnidadFuncional(id),

        -- Coherencia temporal 
        CONSTRAINT CK_PersonaEnUF_Rango CHECK (fechaHasta IS NULL OR fechaHasta > fechaDesde),
        -- Persona, uf y fechaDesde no se repite 
        CONSTRAINT UQ_PersonaUF_Desde UNIQUE (idPersona, idUF, fechaDesde)
    )
END

-- Solo una relacion activa por persona-UF 
CREATE UNIQUE INDEX UX_PersonaEnUF_Activa 
ON Personas.PersonaEnUF(idPersona, idUF) 
WHERE fechaHasta IS NULL;


-- Incluye Expensa, DetalleExpensa, GastoOrdinario, GastoExtraordinario, EnvioExpensa
IF OBJECT_ID('Gastos.Expensa', 'U') IS NULL
BEGIN
    CREATE TABLE Gastos.Expensa (
        id INT IDENTITY(1,1),
        periodo CHAR(6) CHECK (LEN(periodo) = 6 AND periodo LIKE '[0-9][0-9][0-9][0-9][0-9][0-9]'),
        totalGastoOrdinario DECIMAL(10,2) CHECK (totalGastoOrdinario >= 0),
        totalGastoExtraordinario DECIMAL(10,2) CHECK (totalGastoExtraordinario >= 0),
        primerVencimiento DATE NOT NULL,
        segundoVencimiento DATE NOT NULL,
        idConsorcio INT,
        CONSTRAINT pk_Expensa PRIMARY KEY (id),
        CONSTRAINT fk_Expensa_Consorcio FOREIGN KEY (idConsorcio) REFERENCES Administracion.Consorcio(id),
        CONSTRAINT uq_Expensa_PeriodoConsorcio UNIQUE (periodo, idConsorcio)
    )
END

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
        nroCuotaAPagar INT CHECK (nroCuotaAPagar > 0),
        nroTotalCuotas INT CHECK (nroTotalCuotas > 0),
        idConsorcio INT,
        CONSTRAINT pk_GastoExtraordinario PRIMARY KEY (id),
        CONSTRAINT fk_GastoExtraordinario_Consorcio FOREIGN KEY (idConsorcio) REFERENCES Administracion.Consorcio(id)
    )
END

IF OBJECT_ID('Gastos.DetalleExpensa', 'U') IS NULL
BEGIN
    CREATE TABLE Gastos.DetalleExpensa (
        id INT IDENTITY(1,1),
        montoBase DECIMAL(10,2),
		saldoAFavor DECIMAL(10, 2),
        deuda DECIMAL(10,2),
        intereses DECIMAL (10,2),
        montoCochera DECIMAL(8,2),
        montoBaulera DECIMAL(8,2),
        montoTotal DECIMAL(20,2),
        estado CHAR(1) NOT NULL CHECK (estado IN ('P', 'E', 'D')),
        idExpensa INT,
        idUF INT,
        CONSTRAINT pk_DetalleExpensa PRIMARY KEY (id),
        CONSTRAINT fk_Detalle_Expensa FOREIGN KEY (idExpensa) REFERENCES Gastos.Expensa(id),
        CONSTRAINT fk_Detalle_UF FOREIGN KEY (idUF) REFERENCES Infraestructura.UnidadFuncional(id)
    )
END

-- Unico detalle por expensa/UF (para evitar duplicados)
CREATE UNIQUE INDEX UX_DetalleExpensa_ExpensaUF
ON Gastos.DetalleExpensa(idExpensa, idUF);


IF OBJECT_ID('Gastos.EnvioExpensa', 'U') IS NULL
BEGIN
    CREATE TABLE Gastos.EnvioExpensa (
        id INT IDENTITY(1, 1),
        rol VARCHAR(10),
        metodo VARCHAR(8) NOT NULL CHECK (metodo IN ('email', 'telefono', 'impreso')),
        email VARCHAR(100) NULL CHECK (email LIKE '%@%'),
        telefono VARCHAR(10) NULL CHECK (telefono NOT LIKE '%[^0-9]%'),
        fecha DATE NOT NULL,
        estado CHAR(1) NOT NULL CHECK (estado IN ('P', 'E', 'D')),
        idPersona INT,
        idExpensa INT,

        CONSTRAINT pk_EnvioExpensa PRIMARY KEY (id),
        CONSTRAINT fk_Envio_Persona FOREIGN KEY (idPersona) REFERENCES Personas.Persona(idPersona),
        CONSTRAINT fk_Envio_Expensa FOREIGN KEY (idExpensa) REFERENCES Gastos.Expensa(id),
		CONSTRAINT CK_EnvioExpensa_MetodoDatos
		  CHECK (
				(metodo='email'    AND email LIKE '%@%' AND telefono IS NULL)
			 OR (metodo='telefono' AND telefono NOT LIKE '%[^0-9]%' AND LEN(telefono)=10 AND email IS NULL)
			 OR (metodo='impreso'  AND email IS NULL AND telefono IS NULL)
		  )
)
END

IF OBJECT_ID('Finanzas.Pagos', 'U') IS NULL
BEGIN
	CREATE TABLE Finanzas.Pagos (
		id INT,
		fecha DATE NOT NULL,
		monto DECIMAL(10,2) NOT NULL CHECK(monto >0),
		cuentaBancaria VARCHAR(22) NOT NULL,
		valido BIT NOT NULL,
		idExpensa INT ,
		idUF INT ,

		CONSTRAINT pk_Pagos PRIMARY KEY (id),
		CONSTRAINT fk_Pagos_Expensa FOREIGN KEY (idExpensa) REFERENCES Gastos.Expensa(id),
		CONSTRAINT fk_Pagos_UF FOREIGN KEY (idUF) REFERENCES Infraestructura.UnidadFuncional(id)
	)
END