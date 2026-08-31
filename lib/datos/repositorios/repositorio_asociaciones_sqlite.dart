import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/asociacion_comercio.dart';
import 'package:finanzas/dominio/repositorios/repositorio_asociaciones.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:sqflite/sqflite.dart';

/// Asociaciones comercio → categoría sobre SQLite (spec 002, FR-029 a
/// FR-034).
final class RepositorioAsociacionesSqlite implements RepositorioAsociaciones {
  static const String _tabla = 'comercio_categoria';

  final Database _conexion;

  const RepositorioAsociacionesSqlite(this._conexion);

  @override
  Future<Categoria?> categoriaDe(String comercioNormalizado) async {
    try {
      final filas = await _conexion.query(
        _tabla,
        columns: ['categoria'],
        where: 'comercio_normalizado = ?',
        whereArgs: [comercioNormalizado],
        limit: 1,
      );
      if (filas.isEmpty) return null;
      return Categoria.desdeSlug(filas.first['categoria']! as String);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('la asociación del comercio', causa);
    }
  }

  @override
  Future<void> asociar(String comercioNormalizado, Categoria categoria) async {
    try {
      await _conexion.insert(_tabla, <String, Object?>{
        'comercio_normalizado': comercioNormalizado,
        'categoria': categoria.slug,
        'actualizado_en': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('la asociación del comercio', causa);
    }
  }

  @override
  Future<List<AsociacionComercio>> todas() async {
    try {
      final filas = await _conexion.query(
        _tabla,
        orderBy: 'comercio_normalizado ASC',
      );
      return filas.map(_desdeFila).toList(growable: false);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('las asociaciones aprendidas', causa);
    }
  }

  @override
  Future<void> eliminar(String comercioNormalizado) async {
    try {
      await _conexion.delete(
        _tabla,
        where: 'comercio_normalizado = ?',
        whereArgs: [comercioNormalizado],
      );
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el borrado de la asociación', causa);
    }
  }

  static AsociacionComercio _desdeFila(Map<String, Object?> fila) =>
      AsociacionComercio(
        comercioNormalizado: fila['comercio_normalizado']! as String,
        categoria: Categoria.desdeSlug(fila['categoria']! as String),
        actualizadoEn: DateTime.parse(fila['actualizado_en']! as String),
      );
}
