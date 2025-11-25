/*
Enunciado: Test
Fecha entrega:
Comision: 5600
Grupo: 05
Materia: Base de datos aplicadas
Integrantes:
    - ERMASI, Franco: 44613354
    - GATTI, Gonzalo: 46208638
    - MORALES, Tomas: 40.755.243

Nombre: 08_Testing.sql
Proposito: Test de procedures.
Script a ejecutar antes: Los que se vayan a testear.
*/

USE Com5600G05;

/*====================================================================
                MODIFICAR TABLAS                        
====================================================================*/
-- Modificar solo dimensiones 
EXEC Infraestructura.sp_ModificarUnidadFuncional
    @idUF = 1,
    @dimension = 60.00,
    @m2Cochera = 14.00,
    @m2Baulera = 4.00;

-- Modificar CBU/CVU (validación: 22 dígitos)
EXEC Infraestructura.sp_ModificarUnidadFuncional
    @idUF = 137,
    @cbu_cvu = '2044613354400000000000';

-- Modificar piso/departamento (requiere que no exista duplicado en el consorcio)
EXEC Infraestructura.sp_ModificarUnidadFuncional
    @idUF = 1,
    @piso = '02',
    @departamento = 'B';

-- Modificar porcentaje de participación y reasignar a otro consorcio
EXEC Infraestructura.sp_ModificarUnidadFuncional
    @idUF = 1,
    @porcentajeParticipacion = 2.50,
    @idConsorcio = 1;


/*====================================================================
                AGREGAR A TABLAS                        
====================================================================*/
	-- Alta de Consorcio
EXEC Administracion.sp_AgregarConsorcio 
    @nombre = 'ConsorcioDemo',
    @direccion = 'Av. Siempre Viva 742 5600-05',
    @metrosTotales = 5000.00;

-- Alta de Unidad Funcional (usar un idConsorcio existente)
EXEC Infraestructura.sp_AgregarUnidadFuncional
    @piso = '01',
    @departamento = 'C',
    @dimension = 55.00,
    @m2Cochera = 12.00,
    @m2Baulera = 3.00,
    @porcentajeParticipacion = 2.20,
    @cbu_cvu = '2044613354400000000000',
    @idConsorcio = 6;

-- Alta de Persona
EXEC Personas.sp_AgregarPersona 
    @dni='44613354',
    @nombre='Franco',
    @apellido='Ermasi',
    @email=NULL,
    @telefono=1131688005,
    @cbu_cvu=2044613354400000000000;

-- Alta de relación Persona en UF (propietario)
EXEC Personas.sp_AgregarPersonaEnUF
    @dniPersona = '44613354',
    @idUF = 138,
    @inquilino = 1,
    @fechaDesde = '2025-11-07',
    @fechaHasta = NULL;

-- Alta de Gasto Ordinario
EXEC Gastos.AgregarGastoOrdinario
    @mes = 11,
    @tipoGasto = 'Limpieza',
    @empresaPersona = 'Limpieza S.A.',
    @nroFactura = '1237',
    @importeFactura = 150000.00,
    @detalle = ' ',
    @idConsorcio = 6;

-- Alta de Gasto Extraordinario
EXEC Gastos.sp_AgregarGastoExtraordinario
    @mes = 11,
    @detalle = 'Reparacion de espejos',
    @importe = 800000.00,
    @formaPago = 'Total',
    @nroCuotaAPagar = '',
    @nroTotalCuotas = '',
    @idConsorcio = 6;

-- Alta de Pago (requiere que exista expensa del período indicado)
EXEC Finanzas.sp_AgregarPago
    @fecha = '2025-11-15',
    @monto = 60000.00,
    @cuentaBancaria = '2044613354400000000000';




/*====================================================================
                VISUALIZAR TABLAS                        
====================================================================*/
SELECT * FROM Administracion.Consorcio
SELECT * FROM Infraestructura.UnidadFuncional
SELECT * FROM Personas.Persona
SELECT * FROM Personas.PersonaEnUF

SELECT idConsorcio, mes, SUM(importeFactura) as ImporteTotalExpensa FROM Gastos.GastoOrdinario
GROUP BY idConsorcio, mes

SELECT * FROM Gastos.GastoOrdinario

SELECT * FROM Gastos.GastoExtraordinario


SELECT idConsorcio,mes, SUM(importe) as ImporteTotal FROM Gastos.GastoExtraordinario
GROUP BY idConsorcio, mes

SELECT idConsorcio,mes, SUM(importeFactura) as ImporteTotal FROM Gastos.GastoOrdinario
GROUP BY idConsorcio, mes

SELECT * FROM Gastos.Expensa

SELECT * FROM Gastos.DetalleExpensa
order by idExpensa

SELECT * FROM Gastos.EnvioExpensa

SELECT * FROM Finanzas.Pagos
WHERE idUF = 1
ORDER BY fecha

SELECT iduf, sum(monto) as total FROM Finanzas.Pagos WHERE fecha like '2025-04-%' group by iduf order by iduf

/*====================================================================
                INFORMES                      
====================================================================*/
EXEC LogicaBD.sp_Informe01

EXEC LogicaBD.sp_Informe01 @mesInicio = 4, @mesFinal = 5, @nombreConsorcio = 'Azcuenaga', @piso = 'PB', @departamento = 'E'

EXEC LogicaBD.sp_Informe02

EXEC LogicaBD.sp_Informe03

EXEC LogicaBD.sp_Informe04 @nombreConsorcio = 'azcuenaga'

EXEC LogicaBD.sp_Informe05

EXEC LogicaBD.sp_Informe06
/*====================================================================
                PERMISOS USUARIOS                       
====================================================================*/
EXECUTE AS USER = 'u_admin_general';
EXECUTE AS LOGIN = 'lg_banco';
EXECUTE AS USER = 'u_admin_operativo';
EXECUTE AS USER = 'u_sistemas';
REVERT;

DECLARE @ruta VARCHAR(200) = 'C:\SQL_SERVER_IMPORTS'
EXEC LogicaBD.sp_ImportarPagos
  @rutaArchivo = @ruta,
  @nombreArchivo = 'pagos_consorcios.csv';




