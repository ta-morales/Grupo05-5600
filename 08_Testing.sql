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


/*====================================================================
                MODIFICAR TABLAS                        
====================================================================*/
-- Modificar solo dimensiones y anexos
EXEC Infraestructura.sp_ModificarUnidadFuncional
    @idUF = 1,
    @dimension = 60.00,
    @m2Cochera = 14.00,
    @m2Baulera = 4.00;

-- Modificar CBU/CVU (validación: 22 dígitos)
EXEC Infraestructura.sp_ModificarUnidadFuncional
    @idUF = 1,
    @cbu_cvu = '2044613354400000000002';

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
    @nombre = 'Consorcio Demo 5600-05',
    @direccion = 'Av. Siempre Viva 742 - 5600-05',
    @metrosTotales = 5000.00;

-- Alta de Unidad Funcional (usar un idConsorcio existente)
EXEC Infraestructura.sp_AgregarUnidadFuncional
    @piso = '01',
    @departamento = 'A',
    @dimension = 55.00,
    @m2Cochera = 12.00,
    @m2Baulera = 3.00,
    @porcentajeParticipacion = 2.20,
    @cbu_cvu = '2044613354400000000001',
    @idConsorcio = 1;

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
    @idUF = 1,
    @inquilino = 0,
    @fechaDesde = '2025-01-01',
    @fechaHasta = NULL;

-- Alta de Gasto Ordinario
EXEC Gastos.AgregarGastoOrdinario
    @mes = 3,
    @tipoGasto = 'Limpieza',
    @empresaPersona = 'Limpieza S.A.',
    @nroFactura = 'FAC-0001',
    @importeFactura = 150000.00,
    @detalle = '',
    @idConsorcio = 1;

-- Alta de Gasto Extraordinario
EXEC Gastos.sp_AgregarGastoExtraordinario
    @mes = 3,
    @detalle = 'Reparación de ascensor',
    @importe = 800000.00,
    @formaPago = 'Cuotas',
    @nroCuotaAPagar = 1,
    @nroTotalCuotas = 8,
    @idConsorcio = 1;

-- Alta de Pago (requiere que exista expensa del período indicado)
EXEC Finanzas.sp_AgregarPago
    @fecha = '2025-03-05',
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
order by idUF, idExpensa

SELECT * FROM Gastos.EnvioExpensa

SELECT * FROM Finanzas.Pagos
WHERE idUF = 1
ORDER BY fecha

SELECT iduf, sum(monto) as total FROM Finanzas.Pagos WHERE fecha like '2025-04-%' group by iduf order by iduf













