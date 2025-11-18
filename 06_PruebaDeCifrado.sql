/*
Enunciado: scripts para ejecutar los sp de cifrado
y probar su resultado.
Fecha entrega:
Comision: 5600
Grupo: 05
Materia: Base de datos aplicadas
Integrantes:
    - ERMASI, Franco: 44613354
    - GATTI, Gonzalo: 46208638
    - MORALES, Tomas: 40.755.243

Nombre: 06_PruebaDeCifrado.sql
Proposito: probrar el cifrado de datos
Script a ejecutar antes: 00_CreacionDeTablas.sql 01_SPImportacionDatos.sql 06_CifradoDeDatos.sql
*/

USE master

USE Com5600G05
GO

EXEC Personas.sp_CifrarPersonas;

UPDATE Personas.Persona
SET dni = NULL,
    nombre = NULL,
    apellido = NULL,
    email = NULL,
    telefono = NULL,
    cbu_cvu = NULL
WHERE dniCifrado IS NOT NULL;
GO

EXEC Personas.sp_ObtenerPersonasDescifradas


SELECT * FROM Personas.Persona

EXEC Personas.sp_AgregarPersona
	@dni = '46208638',
	@nombre = 'Gonzalo',
	@apellido = 'Gatti',
	@email = 'gonzagatti@gmail.com',
	@telefono = '1134514885',
	@cbu_cvu = '2234123567665487656765'