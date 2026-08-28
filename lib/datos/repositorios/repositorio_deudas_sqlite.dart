import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/deuda.dart';
import 'package:finanzas/dominio/repositorios/repositorio_deudas.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:sqflite/sqflite.dart';

/// Deudas en cuotas sobre SQLite.
///
/// **No hay tabla de cuotas** (D3): lo que cada mes recibe se deriva de estas
/// filas. Por eso corregir una deuda es una sola escritura y todos los meses
/// quedan correctos al recalcularse (FR-023).
final class RepositorioDeudasSqlite implements RepositorioDeudas {
  static const String _tabla = 'deuda';

  final Database _conexion;

  const RepositorioDeudasSqlite(this._conexion);

  @override
  Future<List<Deuda>> todas() => _consultar();

  @override
  Future<List<Deuda>> activas() =>
      _consultar(where: 'mes_saldada_ordinal IS NULL');

  @override
  Future<List<Deuda>> porTarjeta(int tarjetaId) =>
      _consultar(where: 'tarjeta_id = ?', whereArgs: [tarjetaId]);

  @override
  Future<int> insertar(Deuda deuda) async {
    try {
      return await _conexion.insert(_tabla, _aFila(deuda));
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar(
        'la deuda "${deuda.descripcion}"',
        causa,
      );
    }
  }

  @override
  Future<void> actualizar(Deuda deuda) async {
    final id = deuda.id;
    if (id == null) {
      throw ArgumentError.value(
        deuda,
        'deuda',
        'No se puede actualizar una deuda sin id; usá insertar()',
      );
    }
    try {
      await _conexion.update(
        _tabla,
        _aFila(deuda),
        where: 'id = ?',
        whereArgs: [id],
      );
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar(
        'la deuda "${deuda.descripcion}"',
        causa,
      );
    }
  }

  @override
  Future<void> marcarSaldada(int id, Mes mes) async {
    try {
      // Solo fija el mes: no toca las transacciones reales ya registradas.
      await _conexion.update(
        _tabla,
        <String, Object?>{'mes_saldada_ordinal': mes.ordinal},
        where: 'id = ?',
        whereArgs: [id],
      );
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el saldado de la deuda', causa);
    }
  }

  @override
  Future<void> eliminar(int id) async {
    try {
      await _conexion.delete(_tabla, where: 'id = ?', whereArgs: [id]);
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el cambio en las deudas', causa);
    }
  }

  Future<List<Deuda>> _consultar({
    String? where,
    List<Object?>? whereArgs,
  }) async {
    try {
      final filas = await _conexion.query(
        _tabla,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'mes_inicio_ordinal ASC, id ASC',
      );
      return filas.map(_desdeFila).toList(growable: false);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('las deudas', causa);
    }
  }

  static Map<String, Object?> _aFila(Deuda deuda) => <String, Object?>{
    'descripcion': deuda.descripcion,
    'tarjeta_id': deuda.tarjetaId,
    'cuota_centavos': deuda.cuotaMensual.centavos,
    'num_cuotas': deuda.numCuotas,
    'mes_inicio_ordinal': deuda.mesInicio.ordinal,
    'mes_saldada_ordinal': deuda.mesSaldadaAnticipada?.ordinal,
  };

  static Deuda _desdeFila(Map<String, Object?> fila) {
    final saldada = fila['mes_saldada_ordinal'] as int?;
    return Deuda(
      id: fila['id']! as int,
      descripcion: fila['descripcion']! as String,
      tarjetaId: fila['tarjeta_id']! as int,
      cuotaMensual: Dinero.deCentavos(fila['cuota_centavos']! as int),
      numCuotas: fila['num_cuotas']! as int,
      mesInicio: Mes.deOrdinal(fila['mes_inicio_ordinal']! as int),
      mesSaldadaAnticipada: saldada == null ? null : Mes.deOrdinal(saldada),
    );
  }
}
