import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/configuracion.dart';
import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:sqflite/sqflite.dart';

/// Ajustes de la app: regla de ahorro, porcentaje y días de gracia del cierre.
///
/// Fila única con `id = 1`. Si no existe, se crea con los valores por defecto:
/// el usuario no tiene que configurar nada antes de poder usar la app.
final class RepositorioConfiguracionSqlite implements RepositorioConfiguracion {
  static const String _tabla = 'configuracion';

  final Database _conexion;

  const RepositorioConfiguracionSqlite(this._conexion);

  @override
  Future<Configuracion> obtener() async {
    try {
      final filas = await _conexion.query(_tabla, where: 'id = 1', limit: 1);
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

  @override
  Future<void> guardar(Configuracion config) async {
    try {
      await _conexion.insert(_tabla, <String, Object?>{
        'id': 1,
        'regla': config.regla.slug,
        'porcentaje_bp': config.porcentajeBp,
        'dias_gracia_cierre': config.diasGraciaCierre,
        'captura_notificaciones_activa': config.capturaNotificacionesActiva
            ? 1
            : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('los ajustes', causa);
    }
  }

  static Configuracion _desdeFila(Map<String, Object?> fila) => Configuracion(
    regla: ReglaAhorro.desdeSlug(fila['regla']! as String),
    porcentajeBp: fila['porcentaje_bp']! as int,
    diasGraciaCierre: fila['dias_gracia_cierre']! as int,
    capturaNotificacionesActiva:
        (fila['captura_notificaciones_activa']! as int) == 1,
  );
}
