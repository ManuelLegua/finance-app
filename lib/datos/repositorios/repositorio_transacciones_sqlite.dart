import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/transaccion.dart';
import 'package:finanzas/dominio/repositorios/repositorio_transacciones.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:sqflite/sqflite.dart';

/// Gastos reales sobre SQLite.
///
/// `mes_ordinal` se deriva de la fecha en **toda** ruta de escritura: no hay
/// forma de que una fila quede con un mes que no corresponde a su fecha
/// (FR-008). La columna existe solo para poder indexar las consultas por mes.
final class RepositorioTransaccionesSqlite implements RepositorioTransacciones {
  static const String _tabla = 'transaccion';

  final Database _conexion;

  const RepositorioTransaccionesSqlite(this._conexion);

  @override
  Future<List<Transaccion>> porMes(Mes mes) async {
    try {
      final filas = await _conexion.query(
        _tabla,
        where: 'mes_ordinal = ?',
        whereArgs: [mes.ordinal],
        // Lo último anotado queda arriba cuando comparten fecha.
        orderBy: 'fecha DESC, id DESC',
      );
      return filas.map(_desdeFila).toList(growable: false);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('los gastos del mes', causa);
    }
  }

  @override
  Future<int> insertar(Transaccion transaccion) async {
    try {
      return await _conexion.insert(_tabla, _aFila(transaccion));
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el gasto', causa);
    }
  }

  @override
  Future<void> actualizar(Transaccion transaccion) async {
    final id = transaccion.id;
    if (id == null) {
      throw ArgumentError.value(
        transaccion,
        'transaccion',
        'No se puede actualizar una transacción sin id; usá insertar()',
      );
    }
    try {
      await _conexion.update(
        _tabla,
        _aFila(transaccion),
        where: 'id = ?',
        whereArgs: [id],
      );
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el cambio en el gasto', causa);
    }
  }

  @override
  Future<void> eliminar(int id) async {
    try {
      await _conexion.delete(_tabla, where: 'id = ?', whereArgs: [id]);
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el cambio en los gastos', causa);
    }
  }

  static Map<String, Object?> _aFila(Transaccion transaccion) =>
      <String, Object?>{
        'fecha': FormatoFecha.iso(transaccion.fecha),
        'mes_ordinal': transaccion.mes.ordinal,
        'categoria': transaccion.categoria.slug,
        'monto_centavos': transaccion.monto.centavos,
        'descripcion': transaccion.descripcion,
      };

  static Transaccion _desdeFila(Map<String, Object?> fila) => Transaccion(
    id: fila['id']! as int,
    fecha: FormatoFecha.desdeIso(fila['fecha']! as String),
    categoria: Categoria.desdeSlug(fila['categoria']! as String),
    monto: Dinero.deCentavos(fila['monto_centavos']! as int),
    descripcion: fila['descripcion']! as String,
  );
}
