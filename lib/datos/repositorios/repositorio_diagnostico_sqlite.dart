import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/notificacion_diagnostico.dart';
import 'package:finanzas/dominio/repositorios/repositorio_diagnostico.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:sqflite/sqflite.dart';

/// Registro de diagnóstico sobre SQLite (spec 002, FR-018).
final class RepositorioDiagnosticoSqlite implements RepositorioDiagnostico {
  static const String _tabla = 'notificacion_diagnostico';

  final Database _conexion;

  const RepositorioDiagnosticoSqlite(this._conexion);

  @override
  Future<List<NotificacionDiagnostico>> todos() async {
    try {
      final filas = await _conexion.query(
        _tabla,
        orderBy: 'fecha DESC, id DESC',
      );
      return filas.map(_desdeFila).toList(growable: false);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('el registro de diagnóstico', causa);
    }
  }

  @override
  Future<int> insertar(NotificacionDiagnostico entrada) async {
    try {
      return await _conexion.insert(_tabla, <String, Object?>{
        'origen_paquete': entrada.origenPaquete,
        'motivo': entrada.motivo.slug,
        'texto_crudo': entrada.textoCrudo,
        'fecha': entrada.fecha.toIso8601String(),
      });
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('la nota de diagnóstico', causa);
    }
  }

  @override
  Future<void> eliminar(int id) async {
    try {
      await _conexion.delete(_tabla, where: 'id = ?', whereArgs: [id]);
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el cambio en el diagnóstico', causa);
    }
  }

  @override
  Future<void> vaciar() async {
    try {
      await _conexion.delete(_tabla);
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el borrado del diagnóstico', causa);
    }
  }

  static NotificacionDiagnostico _desdeFila(Map<String, Object?> fila) =>
      NotificacionDiagnostico(
        id: fila['id']! as int,
        origenPaquete: fila['origen_paquete']! as String,
        motivo: MotivoDiagnostico.desdeSlug(fila['motivo']! as String),
        textoCrudo: fila['texto_crudo']! as String,
        fecha: DateTime.parse(fila['fecha']! as String),
      );
}
