import 'package:sqflite/sqflite.dart';

import '../../dominio/modelos/configuracion.dart';
import '../../dominio/modelos/enums.dart';
import '../error_persistencia.dart';

/// Ajustes de la app: regla de ahorro, porcentaje y días de gracia del cierre.
///
/// Fila única con `id = 1`. Si no existe, se crea con los valores por defecto:
/// el usuario no tiene que configurar nada antes de poder usar la app.
final class RepositorioConfiguracion {
  static const String _tabla = 'configuracion';

  final Database _db;

  const RepositorioConfiguracion(this._db);

  Future<Configuracion> obtener() async {
    try {
      final filas = await _db.query(_tabla, where: 'id = 1', limit: 1);
      if (filas.isEmpty) {
        await guardar(Configuracion.porDefecto);
        return Configuracion.porDefecto;
      }
      return _desdeFila(filas.first);
    } on ErrorPersistencia {
      rethrow;
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('los ajustes', causa);
    }
  }

  Future<void> guardar(Configuracion config) async {
    try {
      await _db.insert(
        _tabla,
        <String, Object?>{
          'id': 1,
          'regla': config.regla.slug,
          'porcentaje_bp': config.porcentajeBp,
          'dias_gracia_cierre': config.diasGraciaCierre,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('los ajustes', causa);
    }
  }

  static Configuracion _desdeFila(Map<String, Object?> fila) => Configuracion(
        regla: ReglaAhorro.desdeSlug(fila['regla']! as String),
        porcentajeBp: fila['porcentaje_bp']! as int,
        diasGraciaCierre: fila['dias_gracia_cierre']! as int,
      );
}
