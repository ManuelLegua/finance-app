import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/cobro_ingreso.dart';
import 'package:finanzas/dominio/repositorios/repositorio_cobros_ingreso.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:sqflite/sqflite.dart';

/// Cobros de ingreso sobre SQLite (spec 003, FR-001).
///
/// **No calcula el total del mes** (contracts/repositorios.md): eso lo
/// deriva `totalIngreso` en `lib/dominio/calculos/ingreso.dart`. Tampoco
/// aplica la regla de cierre — eso vive en `EstadoMes`.
final class RepositorioCobrosIngresoSqlite implements RepositorioCobrosIngreso {
  static const String _tabla = 'cobro_ingreso';

  final Database _conexion;

  const RepositorioCobrosIngresoSqlite(this._conexion);

  @override
  Future<List<CobroIngreso>> porMes(Mes mes) async {
    try {
      final filas = await _conexion.query(
        _tabla,
        where: 'mes_ordinal = ?',
        whereArgs: [mes.ordinal],
        orderBy: 'fecha ASC, id ASC',
      );
      return filas.map(_desdeFila).toList(growable: false);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('los cobros del mes', causa);
    }
  }

  @override
  Future<int> insertar(CobroIngreso cobro) async {
    try {
      return await _conexion.insert(_tabla, _aFila(cobro));
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el cobro de ingreso', causa);
    }
  }

  @override
  Future<void> actualizar(CobroIngreso cobro) async {
    final id = cobro.id;
    if (id == null) {
      throw ArgumentError.value(
        cobro,
        'cobro',
        'No se puede actualizar un cobro sin id; usá insertar()',
      );
    }
    try {
      await _conexion.update(
        _tabla,
        _aFila(cobro),
        where: 'id = ?',
        whereArgs: [id],
      );
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el cambio en el cobro', causa);
    }
  }

  @override
  Future<void> eliminar(int id) async {
    try {
      await _conexion.delete(_tabla, where: 'id = ?', whereArgs: [id]);
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el cambio en los cobros', causa);
    }
  }

  static Map<String, Object?> _aFila(CobroIngreso cobro) => <String, Object?>{
    'fecha': FormatoFecha.iso(cobro.fecha),
    'mes_ordinal': cobro.mes.ordinal,
    'monto_centavos': cobro.monto.centavos,
  };

  static CobroIngreso _desdeFila(Map<String, Object?> fila) => CobroIngreso(
    id: fila['id']! as int,
    fecha: FormatoFecha.desdeIso(fila['fecha']! as String),
    monto: Dinero.deCentavos(fila['monto_centavos']! as int),
  );
}
