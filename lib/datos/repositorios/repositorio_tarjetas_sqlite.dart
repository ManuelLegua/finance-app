import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/tarjeta.dart';
import 'package:finanzas/dominio/repositorios/repositorio_tarjetas.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:sqflite/sqflite.dart';

/// Tarjetas sobre SQLite (FR-059).
final class RepositorioTarjetasSqlite implements RepositorioTarjetas {
  static const String _tabla = 'tarjeta';

  final Database _conexion;

  const RepositorioTarjetasSqlite(this._conexion);

  @override
  Future<List<Tarjeta>> todas() => _consultar();

  @override
  Future<List<Tarjeta>> deCredito() =>
      _consultar(where: 'tipo = ?', whereArgs: [TipoTarjeta.credito.slug]);

  @override
  Future<int> insertar(Tarjeta tarjeta) async {
    try {
      return await _conexion.insert(_tabla, _aFila(tarjeta));
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar(
        'la tarjeta "${tarjeta.nombre}"',
        causa,
      );
    }
  }

  @override
  Future<void> actualizar(Tarjeta tarjeta) async {
    final id = tarjeta.id;
    if (id == null) {
      throw ArgumentError.value(
        tarjeta,
        'tarjeta',
        'No se puede actualizar una tarjeta sin id; usá insertar()',
      );
    }
    try {
      await _conexion.update(
        _tabla,
        _aFila(tarjeta),
        where: 'id = ?',
        whereArgs: [id],
      );
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar(
        'la tarjeta "${tarjeta.nombre}"',
        causa,
      );
    }
  }

  @override
  Future<void> eliminar(int id) async {
    // Se comprueba antes de borrar en vez de dejar que falle la clave
    // foránea: el mensaje del motor no le dice nada al usuario, y borrar en
    // cascada eliminaría deudas que él nunca pidió eliminar.
    final deudas = await _conexion.query(
      'deuda',
      columns: ['id'],
      where: 'tarjeta_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (deudas.isNotEmpty) {
      throw ErrorPersistencia.integridad(
        'Esa tarjeta tiene deudas registradas. Eliminá o reasigná las deudas '
        'antes de borrarla.',
      );
    }

    try {
      await _conexion.delete(_tabla, where: 'id = ?', whereArgs: [id]);
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el cambio en las tarjetas', causa);
    }
  }

  Future<List<Tarjeta>> _consultar({
    String? where,
    List<Object?>? whereArgs,
  }) async {
    try {
      final filas = await _conexion.query(
        _tabla,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'nombre ASC',
      );
      return filas.map(_desdeFila).toList(growable: false);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('las tarjetas', causa);
    }
  }

  static Map<String, Object?> _aFila(Tarjeta tarjeta) => <String, Object?>{
    'nombre': tarjeta.nombre,
    'entidad': tarjeta.entidad,
    'tipo': tarjeta.tipo.slug,
  };

  static Tarjeta _desdeFila(Map<String, Object?> fila) => Tarjeta(
    id: fila['id']! as int,
    nombre: fila['nombre']! as String,
    entidad: fila['entidad']! as String,
    tipo: TipoTarjeta.desdeSlug(fila['tipo']! as String),
  );
}
