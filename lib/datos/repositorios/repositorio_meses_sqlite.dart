import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/repositorios/repositorio_meses.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:sqflite/sqflite.dart';

/// Meses con datos, reuniendo las cuatro tablas que llevan `mes_ordinal`.
///
/// Las deudas no entran: una deuda no "pertenece" a un mes, aporta cuotas a
/// varios y sus cuotas se derivan (D3). Un mes cuya única actividad fuera una
/// cuota de deuda no es un mes que el usuario haya registrado.
final class RepositorioMesesSqlite implements RepositorioMeses {
  static const String _mesesConDatos = '''
    SELECT mes_ordinal FROM cobro_ingreso
    UNION SELECT mes_ordinal FROM obligacion
    UNION SELECT mes_ordinal FROM transaccion
    UNION SELECT mes_ordinal FROM aporte_ahorro
  ''';

  final Database _conexion;

  const RepositorioMesesSqlite(this._conexion);

  @override
  Future<List<Mes>> mesesRegistrados() async {
    try {
      final filas = await _conexion.rawQuery(
        'SELECT DISTINCT mes_ordinal FROM ($_mesesConDatos) '
        'ORDER BY mes_ordinal ASC',
      );
      return filas
          .map((fila) => Mes.deOrdinal(fila['mes_ordinal']! as int))
          .toList(growable: false);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('los meses registrados', causa);
    }
  }

  @override
  Future<bool> tieneDatos(Mes mes) async {
    try {
      final filas = await _conexion.rawQuery(
        'SELECT 1 FROM ($_mesesConDatos) WHERE mes_ordinal = ? LIMIT 1',
        [mes.ordinal],
      );
      return filas.isNotEmpty;
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('los datos del mes', causa);
    }
  }
}
