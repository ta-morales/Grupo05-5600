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


CREATE ROLE rol_AdminGeneral;
CREATE ROLE rol_AdminBancario;
CREATE ROLE rol_AdminOperativo;
CREATE ROLE rol_Sistemas;


-- Permisos sobre actualizacion de datos de UF
GRANT EXECUTE ON LogicaBD.sp_ModificarUnidadFuncional TO rol_AdminGeneral;

GRANT EXECUTE ON LogicaBD.sp_ModificarUnidadFuncional TO rol_AdminOperativo;


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