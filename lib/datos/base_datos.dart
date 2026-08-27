import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/datos/esquema.dart';
import 'package:finanzas/datos/migraciones.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Apertura y ciclo de vida de la base local.
///
/// Principio I: la base vive en el almacenamiento privado de la app. No hay
/// red, no hay sincronización, nada sale del dispositivo.
final class BaseDatos {
  static const String nombreArchivo = 'finanzas.db';

  Database? _db;

  /// Ruta explícita, para las pruebas (`:memory:`). En la app queda `null` y
  /// la ruta la resuelve `getDatabasesPath()`.
  final String? rutaOverride;

  /// Fábrica explícita, para que las pruebas inyecten `sqflite_common_ffi` y
  /// corran contra SQLite real en Windows sin emulador.
  final DatabaseFactory? factoryOverride;

  BaseDatos({this.rutaOverride, this.factoryOverride});

  bool get estaAbierta => _db != null;

  Future<Database> abrir() async {
    final abierta = _db;
    if (abierta != null) return abierta;

    try {
      final fabrica = factoryOverride ?? databaseFactory;
      final ruta = rutaOverride ??
          p.join(await fabrica.getDatabasesPath(), nombreArchivo);

      _db = await fabrica.openDatabase(
        ruta,
        options: OpenDatabaseOptions(
          version: Esquema.version,
          onConfigure: _configurar,
          onCreate: _crear,
          onUpgrade: _migrar,
        ),
      );
      return _db!;
    } on Object catch (causa) {
      // Se propaga envuelto a propósito. Arrancar con una base vacía haría
      // creer al usuario que perdió su historial cuando el archivo sigue ahí.
      throw ErrorPersistencia.alAbrir(causa);
    }
  }

  Future<void> cerrar() async {
    await _db?.close();
    _db = null;
  }

  /// SQLite no activa las claves foráneas por defecto, y hay que hacerlo en
  /// **cada** conexión, no una sola vez al crear.
  static Future<void> _configurar(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _crear(Database db, int version) async {
    final lote = db.batch();
    for (final sentencia in Esquema.creacion) {
      lote.execute(sentencia);
    }
    await lote.commit(noResult: true);
  }

  static Future<void> _migrar(Database db, int desde, int hasta) =>
      Migraciones.aplicar(db, desde: desde, hasta: hasta);
}
