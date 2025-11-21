/*
Enunciado: scripts para la creacion y asignacion
de roles y permisos de ejecucion.
Fecha entrega:
Comision: 5600
Grupo: 05
Materia: Base de datos aplicadas
Integrantes:
    - ERMASI, Franco: 44613354
    - GATTI, Gonzalo: 46208638
    - MORALES, Tomas: 40.755.243

Nombre: 05_CreacionDeRoles.sql
Proposito: Crear roles y dar permisos.
Script a ejecutar antes: 00_CreacionDeTablas 01_SPImportacionDatos.sql 03_CreacionSPParaModificado 04_ReportesApi.sql
*/

USE Com5600G05
GO

--Crear roles
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_AdminGeneral')
    CREATE ROLE rol_AdminGeneral;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_AdminBancario')
    CREATE ROLE rol_AdminBancario;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_AdminOperativo')
    CREATE ROLE rol_AdminOperativo;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_Sistemas')
    CREATE ROLE rol_Sistemas;

-- Permisos sobre actualizacion de datos de UF (SP pertenece al esquema Infraestructura)
GRANT EXECUTE ON Infraestructura.sp_ModificarUnidadFuncional TO rol_AdminGeneral;

GRANT EXECUTE ON Infraestructura.sp_ModificarUnidadFuncional TO rol_AdminOperativo;


-- Permisos sobre importacion de informacion bancaria
GRANT EXECUTE ON LogicaBD.sp_ImportarPagos TO rol_AdminBancario;


-- Permisos sobre generacion de reportes
GRANT EXECUTE ON LogicaBD.sp_Informe01 TO rol_AdminGeneral;
GRANT EXECUTE ON LogicaBD.sp_Informe02 TO rol_AdminGeneral;
GRANT EXECUTE ON LogicaBD.sp_Informe03 TO rol_AdminGeneral;
GRANT EXECUTE ON LogicaBD.sp_Informe04 TO rol_AdminGeneral;
GRANT EXECUTE ON LogicaBD.sp_Informe05 TO rol_AdminGeneral;
GRANT EXECUTE ON LogicaBD.sp_Informe06 TO rol_AdminGeneral;

GRANT EXECUTE ON LogicaBD.sp_Informe01 TO rol_AdminBancario;
GRANT EXECUTE ON LogicaBD.sp_Informe02 TO rol_AdminBancario;
GRANT EXECUTE ON LogicaBD.sp_Informe03 TO rol_AdminBancario;
GRANT EXECUTE ON LogicaBD.sp_Informe04 TO rol_AdminBancario;
GRANT EXECUTE ON LogicaBD.sp_Informe05 TO rol_AdminBancario;
GRANT EXECUTE ON LogicaBD.sp_Informe06 TO rol_AdminBancario;

GRANT EXECUTE ON LogicaBD.sp_Informe01 TO rol_AdminOperativo;
GRANT EXECUTE ON LogicaBD.sp_Informe02 TO rol_AdminOperativo;
GRANT EXECUTE ON LogicaBD.sp_Informe03 TO rol_AdminOperativo;
GRANT EXECUTE ON LogicaBD.sp_Informe04 TO rol_AdminOperativo;
GRANT EXECUTE ON LogicaBD.sp_Informe05 TO rol_AdminOperativo;
GRANT EXECUTE ON LogicaBD.sp_Informe06 TO rol_AdminOperativo;

GRANT EXECUTE ON LogicaBD.sp_Informe01 TO rol_Sistemas;
GRANT EXECUTE ON LogicaBD.sp_Informe02 TO rol_Sistemas;
GRANT EXECUTE ON LogicaBD.sp_Informe03 TO rol_Sistemas;
GRANT EXECUTE ON LogicaBD.sp_Informe04 TO rol_Sistemas;
GRANT EXECUTE ON LogicaBD.sp_Informe05 TO rol_Sistemas;
GRANT EXECUTE ON LogicaBD.sp_Informe06 TO rol_Sistemas;

-- Usuarios de ejemplo y asignacion a roles (contenidos en la BD)
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'u_admin_general')
    CREATE USER u_admin_general WITHOUT LOGIN;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'u_admin_bancario')
    CREATE USER u_admin_bancario WITHOUT LOGIN;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'u_admin_operativo')
    CREATE USER u_admin_operativo WITHOUT LOGIN;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'u_sistemas')
    CREATE USER u_sistemas WITHOUT LOGIN;

-- Asignacion de usuarios a roles
ALTER ROLE rol_AdminGeneral  ADD MEMBER u_admin_general;
ALTER ROLE rol_AdminBancario ADD MEMBER u_admin_bancario;
ALTER ROLE rol_AdminOperativo ADD MEMBER u_admin_operativo;
ALTER ROLE rol_Sistemas      ADD MEMBER u_sistemas;
