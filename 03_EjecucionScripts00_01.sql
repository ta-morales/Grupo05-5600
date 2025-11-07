/* ============================ Ejecución con rutas locales ============================ */
USE Grupo05_5600;

DECLARE @ruta VARCHAR(200) = 'H:\Users\Morrones\Downloads\consorcios'

EXEC LogicaBD.sp_ImportarConsorciosYEdificios;

EXEC LogicaBD.sp_ImportarInquilinosPropietarios
  @rutaArchivo = @ruta,
  @nombreArchivo = 'Inquilino-propietarios-UF.csv';

EXEC LogicaBD.sp_InsertarUnidadesFuncionales
  @rutaArchivo = @ruta,
  @nombreArchivo = 'UF por consorcio.txt'

EXEC LogicaBD.sp_ImportarDatosInquilinos
  @rutaArchivo = @ruta,
  @nombreArchivo = 'Inquilino-propietarios-datos.csv';

EXEC LogicaBD.sp_ImportarGastosOrdinarios
  @rutaArchivo = @ruta,
  @nombreArchivo = 'Servicios.Servicios.json';

EXEC LogicaBD.sp_ImportarPagos
  @rutaArchivo = @ruta,
  @nombreArchivo = 'pagos_consorcios.csv';