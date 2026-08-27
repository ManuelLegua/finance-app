import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:sqflite/sqflite.dart';

/// Las obligaciones presupuestadas de cada mes (FR-002).
///
/// Devuelve **solo lo guardado**. Las cuotas de deuda no aparecen acá: se
/// derivan en la capa de cálculo (D3), y no existe tabla de cuotas.
final class RepositorioObligaciones {
  static const String _tabla = 'obligacion';

  final Database _conexion;

  const RepositorioObligaciones(this._conexion);

  Future<List<Obligacion>> porMes(Mes mes) => _consultar(
    where: 'mes_ordinal = ?',
    whereArgs: [mes.ordinal],
    que: 'las obligaciones del mes',
  );

  /// Solo las fijas: es el insumo de la precarga del mes siguiente (FR-006).
  Future<List<Obligacion>> fijasDeMes(Mes mes) => _consultar(
    where: 'mes_ordinal = ? AND tipo = ?',
    whereArgs: [mes.ordinal, TipoObligacion.fija.slug],
    que: 'las obligaciones fijas',
  );

  /// Inserta y devuelve el id asignado.
  Future<int> insertar(Obligacion obligacion) async {
    try {
      return await _conexion.insert(_tabla, _aFila(obligacion));
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar(
        'la obligación "${obligacion.nombre}"',
        causa,
      );
    }
  }

  /// Confirma la precarga completa en una sola transacción.
  ///
  /// Es atómico a propósito (FR-006): media precarga guardada dejaría al
  /// usuario con un presupuesto que nunca terminó de revisar.
  Future<void> insertarLote(List<Obligacion> obligaciones) async {
    if (obligaciones.isEmpty) return;
    try {
      await _conexion.transaction((transaccionBd) async {
        for (final obligacion in obligaciones) {
          await transaccionBd.insert(_tabla, _aFila(obligacion));
        }
      });
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('las obligaciones precargadas', causa);
    }
  }

  /// Actualiza una obligación ya guardada.
  ///
  /// Si el id no existe es un no-op silencioso: el usuario ya no ve ese
  /// registro y no hay nada que informarle.
  Future<void> actualizar(Obligacion obligacion) async {
    final id = obligacion.id;
    if (id == null) {
      throw ArgumentError.value(
        obligacion,
        'obligacion',
        'No se puede actualizar una obligación sin id; usá insertar()',
      );
    }
    try {
      await _conexion.update(
        _tabla,
        _aFila(obligacion),
        where: 'id = ?',
        whereArgs: [id],
      );
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar(
        'la obligación "${obligacion.nombre}"',
        causa,
      );
    }
  }

  Future<void> eliminar(int id) async {
    try {
      await _conexion.delete(_tabla, where: 'id = ?', whereArgs: [id]);
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el cambio en el presupuesto', causa);
    }
  }

  Future<List<Obligacion>> _consultar({
    required String where,
    required List<Object?> whereArgs,
    required String que,
  }) async {
    try {
      final filas = await _conexion.query(
        _tabla,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'id ASC',
      );
      return filas.map(_desdeFila).toList(growable: false);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer(que, causa);
    }
  }

  static Map<String, Object?> _aFila(Obligacion obligacion) =>
      <String, Object?>{
        'mes_ordinal': obligacion.mes.ordinal,
        'nombre': obligacion.nombre,
        'categoria': obligacion.categoria.slug,
        'monto_centavos': obligacion.monto.centavos,
        'tipo': obligacion.tipo.slug,
      };

  static Obligacion _desdeFila(Map<String, Object?> fila) => Obligacion(
    id: fila['id']! as int,
    mes: Mes.deOrdinal(fila['mes_ordinal']! as int),
    nombre: fila['nombre']! as String,
    categoria: Categoria.desdeSlug(fila['categoria']! as String),
    monto: Dinero.deCentavos(fila['monto_centavos']! as int),
    tipo: TipoObligacion.desdeSlug(fila['tipo']! as String),
  );
}
