import 'package:finanzas/datos/base_datos.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Infraestructura de las pruebas de datos.
///
/// D8: se corre contra SQLite **real** vía `sqflite_common_ffi`, no contra un
/// doble. Los `CHECK`, las claves foráneas y el comportamiento de las
/// transacciones son justamente lo que hay que verificar, y un mock los
/// daría por buenos. Además permite correr la suite en Windows sin emulador.

/// Se llama una vez por archivo de prueba, antes de abrir ninguna base.
void inicializarSqfliteFfi() {
  sqfliteFfiInit();
}

/// Abre una base en memoria con el esquema ya creado.
///
/// Cada prueba recibe una base limpia: nada se filtra de un test al siguiente.
Future<BaseDatos> abrirBaseEnMemoria() async {
  final bd = BaseDatos(
    rutaOverride: inMemoryDatabasePath,
    factoryOverride: databaseFactoryFfi,
  );
  await bd.abrir();
  return bd;
}
