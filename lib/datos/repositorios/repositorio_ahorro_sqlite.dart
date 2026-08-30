import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/aporte_ahorro.dart';
import 'package:finanzas/dominio/repositorios/repositorio_ahorro.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:sqflite/sqflite.dart';

/// Metas y aportes de ahorro sobre SQLite.
///
/// **No calcula reglas financieras** (contracts/repositorios.md): suma con
/// `SUM()` solo totales planos de filas guardadas. Combinar esos totales con
/// el disponible o con la regla elegida es trabajo de
/// `lib/dominio/calculos/ahorro.dart`.
final class RepositorioAhorroSqlite implements RepositorioAhorro {
  static const String _tablaMetas = 'meta_ahorro';
  static const String _tablaAportes = 'aporte_ahorro';

  final Database _conexion;

  const RepositorioAhorroSqlite(this._conexion);

  @override
  Future<Dinero?> metaDeMes(Mes mes) async {
    try {
      final filas = await _conexion.query(
        _tablaMetas,
        columns: ['monto_centavos'],
        where: 'mes_ordinal = ?',
        whereArgs: [mes.ordinal],
        limit: 1,
      );
      if (filas.isEmpty) return null;
      return Dinero.deCentavos(filas.first['monto_centavos']! as int);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('la meta de ahorro', causa);
    }
  }

  @override
  Future<void> guardarMeta(Mes mes, Dinero monto) async {
    try {
      await _conexion.insert(_tablaMetas, <String, Object?>{
        'mes_ordinal': mes.ordinal,
        'monto_centavos': monto.centavos,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('la meta de ahorro', causa);
    }
  }

  @override
  Future<void> eliminarMeta(Mes mes) async {
    try {
      await _conexion.delete(
        _tablaMetas,
        where: 'mes_ordinal = ?',
        whereArgs: [mes.ordinal],
      );
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar(
        'el cambio en la meta de ahorro',
        causa,
      );
    }
  }

  @override
  Future<List<(Mes, Dinero)>> metasHasta(Mes mes) async {
    try {
      final filas = await _conexion.query(
        _tablaMetas,
        where: 'mes_ordinal <= ?',
        whereArgs: [mes.ordinal],
        orderBy: 'mes_ordinal ASC',
      );
      return filas
          .map(
            (fila) => (
              Mes.deOrdinal(fila['mes_ordinal']! as int),
              Dinero.deCentavos(fila['monto_centavos']! as int),
            ),
          )
          .toList(growable: false);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('las metas de ahorro', causa);
    }
  }

  @override
  Future<List<AporteAhorro>> aportesPorMes(Mes mes) async {
    try {
      final filas = await _conexion.query(
        _tablaAportes,
        where: 'mes_ordinal = ?',
        whereArgs: [mes.ordinal],
        orderBy: 'fecha DESC, id DESC',
      );
      return filas.map(_desdeFila).toList(growable: false);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('los aportes del mes', causa);
    }
  }

  @override
  Future<Dinero> acumuladoHistorico() async {
    try {
      final filas = await _conexion.rawQuery(
        'SELECT SUM(monto_centavos) AS total FROM $_tablaAportes',
      );
      final total = filas.first['total'] as int?;
      return Dinero.deCentavos(total ?? 0);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('el acumulado de ahorro', causa);
    }
  }

  @override
  Future<List<(Mes, Dinero)>> historialPorMes(Mes desde, Mes hasta) async {
    try {
      final filas = await _conexion.rawQuery(
        'SELECT mes_ordinal, SUM(monto_centavos) AS total FROM $_tablaAportes '
        'WHERE mes_ordinal BETWEEN ? AND ? '
        'GROUP BY mes_ordinal ORDER BY mes_ordinal ASC',
        [desde.ordinal, hasta.ordinal],
      );
      return filas
          .map(
            (fila) => (
              Mes.deOrdinal(fila['mes_ordinal']! as int),
              Dinero.deCentavos(fila['total']! as int),
            ),
          )
          .toList(growable: false);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('el historial de ahorro', causa);
    }
  }

  @override
  Future<int> insertarAporte(AporteAhorro aporte) async {
    try {
      return await _conexion.insert(_tablaAportes, _aFila(aporte));
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el aporte de ahorro', causa);
    }
  }

  @override
  Future<void> actualizarAporte(AporteAhorro aporte) async {
    final id = aporte.id;
    if (id == null) {
      throw ArgumentError.value(
        aporte,
        'aporte',
        'No se puede actualizar un aporte sin id; usá insertarAporte()',
      );
    }
    try {
      await _conexion.update(
        _tablaAportes,
        _aFila(aporte),
        where: 'id = ?',
        whereArgs: [id],
      );
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el cambio en el aporte', causa);
    }
  }

  @override
  Future<void> eliminarAporte(int id) async {
    try {
      await _conexion.delete(_tablaAportes, where: 'id = ?', whereArgs: [id]);
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el cambio en los aportes', causa);
    }
  }

  static Map<String, Object?> _aFila(AporteAhorro aporte) => <String, Object?>{
    'fecha': FormatoFecha.iso(aporte.fecha),
    'mes_ordinal': aporte.mes.ordinal,
    'monto_centavos': aporte.monto.centavos,
  };

  static AporteAhorro _desdeFila(Map<String, Object?> fila) => AporteAhorro(
    id: fila['id']! as int,
    fecha: FormatoFecha.desdeIso(fila['fecha']! as String),
    monto: Dinero.deCentavos(fila['monto_centavos']! as int),
  );
}
