import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:sqflite/sqflite.dart';

/// El ingreso mensual (FR-001). Un registro por mes.
///
/// **No valida el cierre del mes**: eso lo decide `cierre_mes.dart` y lo
/// aplica la capa de estado. Duplicar la regla acá crearía dos verdades que se
/// desincronizan (contracts/repositorios.md).
final class RepositorioIngreso {
  static const String _tabla = 'ingreso';

  final Database _conexion;

  const RepositorioIngreso(this._conexion);

  /// El ingreso del mes, o `null` si no se registró.
  ///
  /// `null` y `Dinero.cero` son cosas distintas: el primero hace que la app
  /// pida registrar el ingreso, el segundo sería un sueldo de S/ 0.00.
  Future<Dinero?> obtener(Mes mes) async {
    try {
      final filas = await _conexion.query(
        _tabla,
        columns: ['monto_centavos'],
        where: 'mes_ordinal = ?',
        whereArgs: [mes.ordinal],
        limit: 1,
      );
      if (filas.isEmpty) return null;
      return Dinero.deCentavos(filas.first['monto_centavos']! as int);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('los ingresos', causa);
    }
  }

  Future<void> guardar(Mes mes, Dinero monto) async {
    try {
      await _conexion.insert(_tabla, <String, Object?>{
        'mes_ordinal': mes.ordinal,
        'monto_centavos': monto.centavos,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el ingreso del mes', causa);
    }
  }

  /// Quita el ingreso del mes. Si no había, no hace nada.
  Future<void> eliminar(Mes mes) async {
    try {
      await _conexion.delete(
        _tabla,
        where: 'mes_ordinal = ?',
        whereArgs: [mes.ordinal],
      );
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el cambio en el ingreso', causa);
    }
  }

  /// Meses con ingreso registrado, en orden cronológico.
  Future<List<Mes>> mesesConIngreso() async {
    try {
      final filas = await _conexion.query(
        _tabla,
        columns: ['mes_ordinal'],
        orderBy: 'mes_ordinal ASC',
      );
      return filas
          .map((fila) => Mes.deOrdinal(fila['mes_ordinal']! as int))
          .toList(growable: false);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('los meses registrados', causa);
    }
  }
}
