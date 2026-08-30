import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/consumo_pendiente.dart';
import 'package:finanzas/dominio/modelos/resumen_pendientes.dart';
import 'package:finanzas/dominio/repositorios/repositorio_pendientes.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:sqflite/sqflite.dart';

/// Consumos pendientes sobre SQLite (spec 002).
final class RepositorioPendientesSqlite implements RepositorioPendientes {
  static const String _tabla = 'consumo_pendiente';

  final Database _conexion;

  const RepositorioPendientesSqlite(this._conexion);

  @override
  Future<List<ConsumoPendiente>> todos() async {
    try {
      final filas = await _conexion.query(
        _tabla,
        orderBy: 'fecha DESC, id DESC',
      );
      return filas.map(_desdeFila).toList(growable: false);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('los consumos pendientes', causa);
    }
  }

  @override
  Future<ResumenPendientes> resumen() async {
    try {
      final filas = await _conexion.rawQuery(
        'SELECT COUNT(*) AS cantidad, COALESCE(SUM(monto_centavos), 0) AS total '
        'FROM $_tabla',
      );
      final fila = filas.first;
      return ResumenPendientes(
        cantidad: fila['cantidad']! as int,
        montoTotal: Dinero.deCentavos(fila['total']! as int),
      );
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('el resumen de pendientes', causa);
    }
  }

  @override
  Future<int> insertar(ConsumoPendiente pendiente) async {
    try {
      final id = await _conexion.insert(
        _tabla,
        _aFila(pendiente),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      // `ConflictAlgorithm.ignore` devuelve 0 cuando la fila ya existía
      // (D-N5): se busca el id real en vez de duplicarla.
      if (id != 0) return id;
      final filas = await _conexion.query(
        _tabla,
        columns: ['id'],
        where: 'origen_paquete = ? AND notificacion_id = ?',
        whereArgs: [pendiente.origenPaquete, pendiente.notificacionId],
        limit: 1,
      );
      return filas.first['id']! as int;
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el consumo pendiente', causa);
    }
  }

  @override
  Future<void> eliminar(int id) async {
    try {
      await _conexion.delete(_tabla, where: 'id = ?', whereArgs: [id]);
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el cambio en los pendientes', causa);
    }
  }

  static Map<String, Object?> _aFila(ConsumoPendiente pendiente) =>
      <String, Object?>{
        'origen_paquete': pendiente.origenPaquete,
        'notificacion_id': pendiente.notificacionId,
        'monto_centavos': pendiente.monto.centavos,
        'comercio': pendiente.comercio,
        'fecha': FormatoFecha.iso(pendiente.fecha),
        'categoria_propuesta': pendiente.categoriaPropuesta?.slug,
        'capturado_en': pendiente.capturadoEn.toIso8601String(),
      };

  static ConsumoPendiente _desdeFila(Map<String, Object?> fila) {
    final categoriaSlug = fila['categoria_propuesta'] as String?;
    return ConsumoPendiente(
      id: fila['id']! as int,
      origenPaquete: fila['origen_paquete']! as String,
      notificacionId: fila['notificacion_id']! as String,
      monto: Dinero.deCentavos(fila['monto_centavos']! as int),
      comercio: fila['comercio']! as String,
      fecha: FormatoFecha.desdeIso(fila['fecha']! as String),
      categoriaPropuesta: categoriaSlug == null
          ? null
          : Categoria.desdeSlug(categoriaSlug),
      capturadoEn: DateTime.parse(fila['capturado_en']! as String),
    );
  }
}
