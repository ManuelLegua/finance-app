import 'dart:io';

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

  Database? _conexion;

  /// Ruta explícita, para las pruebas (`:memory:`). En la app queda `null` y
  /// la ruta la resuelve `getDatabasesPath()`.
  final String? rutaOverride;

  /// Fábrica explícita, para que las pruebas inyecten `sqflite_common_ffi` y
  /// corran contra SQLite real en Windows sin emulador.
  final DatabaseFactory? factoryOverride;

  BaseDatos({this.rutaOverride, this.factoryOverride});

  bool get estaAbierta => _conexion != null;

  /// La conexión viva, o `null` si todavía no se abrió o está reemplazándose.
  ///
  /// La expone para que el árbol de providers pueda reconstruirse con la
  /// conexión nueva después de restaurar un respaldo (spec 005): los
  /// repositorios reciben un `Database` concreto, y el de antes queda cerrado.
  Database? get conexionActual => _conexion;

  /// La fábrica en uso: la real de `sqflite` en la app, la de
  /// `sqflite_common_ffi` en las pruebas.
  ///
  /// La necesita `RepositorioRespaldoSqlite` para abrir un archivo candidato
  /// **aparte** de esta base, sin `version:` (D2 de la spec 005). Abrir *esta*
  /// base sigue siendo responsabilidad exclusiva de [abrir].
  DatabaseFactory get fabrica => factoryOverride ?? databaseFactory;

  /// La ruta del archivo en uso.
  ///
  /// Es la que el intercambio de la spec 005 necesita conocer para poder
  /// renombrar, reemplazar y reabrir; sigue resolviéndose en un solo lugar.
  Future<String> rutaEnUso() async =>
      rutaOverride ?? p.join(await fabrica.getDatabasesPath(), nombreArchivo);

  Future<Database> abrir() async {
    final abierta = _conexion;
    if (abierta != null) return abierta;

    try {
      final ruta = await rutaEnUso();

      _conexion = await fabrica.openDatabase(
        ruta,
        options: OpenDatabaseOptions(
          version: Esquema.version,
          onConfigure: _configurar,
          onCreate: _crear,
          onUpgrade: _migrar,
        ),
      );
      return _conexion!;
    } on Object catch (causa) {
      // Se propaga envuelto a propósito. Arrancar con una base vacía haría
      // creer al usuario que perdió su historial cuando el archivo sigue ahí.
      throw ErrorPersistencia.alAbrir(causa);
    }
  }

  Future<void> cerrar() async {
    await _conexion?.close();
    _conexion = null;
  }

  /// Borra los `-wal` y `-shm` que hayan quedado al lado del archivo en uso.
  ///
  /// Se llama con la base **cerrada**, en medio del intercambio de la spec
  /// 005: un `finanzas.db-wal` sobreviviente junto a un archivo principal
  /// distinto es corrupción silenciosa, no un error visible, y es el modo de
  /// fallo más fácil de pasar por alto de todo el diseño (D3).
  Future<void> borrarSidecars() async {
    final ruta = await rutaEnUso();
    for (final sufijo in _sufijosSidecar) {
      final sidecar = File('$ruta$sufijo');
      if (sidecar.existsSync()) await sidecar.delete();
    }
  }

  static const List<String> _sufijosSidecar = <String>['-wal', '-shm'];

  /// SQLite no activa las claves foráneas por defecto, y hay que hacerlo en
  /// **cada** conexión, no una sola vez al crear.
  static Future<void> _configurar(Database conexion) async {
    await conexion.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _crear(Database conexion, int version) async {
    final lote = conexion.batch();
    for (final sentencia in Esquema.creacion) {
      lote.execute(sentencia);
    }
    await lote.commit(noResult: true);
  }

  static Future<void> _migrar(Database conexion, int desde, int hasta) =>
      Migraciones.aplicar(conexion, desde: desde, hasta: hasta);
}
