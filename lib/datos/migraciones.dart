import 'package:sqflite/sqflite.dart';

/// Migraciones incrementales del esquema.
///
/// D10: cada paso lleva de una versión a la siguiente y **nunca borra ni
/// recrea tablas con datos**. La constitución exige que toda migración
/// preserve la información del usuario, y estos datos no tienen respaldo: la
/// spec descarta backup y exportación en esta versión, así que una migración
/// destructiva sería una pérdida irreversible.
///
/// Para agregar una migración: subir `Esquema.version`, añadir la entrada al
/// mapa con la versión de destino como clave, y cubrirla con una prueba en
/// `test/datos/base_datos_test.dart`.
abstract final class Migraciones {
  /// Clave: versión a la que se llega. Valor: los pasos para llegar.
  ///
  /// Vacío mientras el esquema esté en la versión 1: no hay nada instalado
  /// desde lo cual migrar.
  static const Map<int, List<String>> pasos = <int, List<String>>{};

  /// Aplica los pasos necesarios para ir de [desde] a [hasta].
  static Future<void> aplicar(
    DatabaseExecutor conexion, {
    required int desde,
    required int hasta,
  }) async {
    for (var version = desde + 1; version <= hasta; version++) {
      final sentencias = pasos[version];
      if (sentencias == null) {
        throw StateError(
          'Falta la migración a la versión $version. La base quedó sin tocar '
          'a propósito: es preferible fallar al abrir que aplicar un cambio '
          'de esquema a medias.',
        );
      }
      for (final sentencia in sentencias) {
        await conexion.execute(sentencia);
      }
    }
  }
}
