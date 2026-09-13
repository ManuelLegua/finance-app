import 'dart:io';

import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/datos/esquema.dart';
import 'package:finanzas/dominio/calculos/validacion_respaldo.dart';
import 'package:finanzas/dominio/modelos/respaldo.dart';
import 'package:finanzas/dominio/repositorios/repositorio_respaldo.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Respaldo y restauración sobre el archivo de la base (spec 005).
///
/// El respaldo **es** el propio archivo SQLite (D1): eso hace que restaurar
/// uno viejo en una app nueva salga gratis, porque el archivo lleva su
/// `user_version` encima y `BaseDatos.abrir()` le aplica las migraciones que
/// ya existen. No hay una segunda escalera de versiones que mantener.
final class RepositorioRespaldoSqlite implements RepositorioRespaldo {
  RepositorioRespaldoSqlite(this._baseDatos, {Directory? directorioTemporal})
    : _directorioTemporal = directorioTemporal ?? Directory.systemTemp;

  final BaseDatos _baseDatos;

  /// Dónde nacen los archivos que esta clase genera y los candidatos que
  /// copia para inspeccionar. En Android es el directorio privado de caché de
  /// la app; en las pruebas, un temporal que se borra al terminar.
  final Directory _directorioTemporal;

  /// Cómo se llama la copia de trabajo del archivo que el usuario eligió.
  /// Vive en el temporal y se borra apenas deja de hacer falta.
  static const String _nombreDelCandidato = 'candidato-de-respaldo.db';

  /// La red de seguridad de D3: el archivo actual se corre a un lado con
  /// este sufijo y solo se borra cuando la base nueva ya abrió bien.
  static const String _sufijoDelArchivoPrevio = '.previo';

  /// Lo que se vacía **en la copia** antes de entregarla (D4).
  ///
  /// `notificacion_diagnostico` porque no es dato que el usuario haya cargado
  /// y puede contener el texto crudo de notificaciones bancarias: el archivo
  /// está pensado para salir del teléfono.
  ///
  /// Acá también figuraba `suscripcion_premium`, para que un archivo editado a
  /// mano no fuera una vía para fabricarse acceso pagado. Salió junto con la
  /// tabla: la spec 004 se revisó a propina voluntaria, ya no hay acceso que
  /// fabricarse, y la migración v4 → v5 borra la tabla incluso si viene dentro
  /// de un respaldo viejo.
  static const List<String> _tablasQueNoViajan = <String>[
    'notificacion_diagnostico',
  ];

  @override
  Future<ArchivoRespaldo> exportar() async {
    final nombrePropuesto = _nombreParaLaFecha(DateTime.now());
    final rutaDestino = p.join(_directorioTemporal.path, nombrePropuesto);

    try {
      final conexion = await _baseDatos.abrir();
      // Sin esto, lo último que escribió el usuario podría vivir todavía en
      // el `-wal` y no en el archivo que se está por copiar.
      await conexion.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');

      await _copiarArchivo(await _baseDatos.rutaEnUso(), rutaDestino);
      await _vaciarLoQueNoViaja(rutaDestino);

      return ArchivoRespaldo(
        ruta: rutaDestino,
        nombrePropuesto: nombrePropuesto,
      );
    } on Object catch (causa) {
      // FR-005: nunca queda un archivo a medio escribir. Si algo falló, lo
      // que haya alcanzado a copiarse se descarta antes de informar el error.
      await _borrarSiExiste(rutaDestino);
      throw ErrorPersistencia.alGuardar('el archivo de respaldo', causa);
    }
  }

  @override
  Future<InformeRespaldo> inspeccionar(String rutaCandidato) async {
    final rutaCopia = p.join(_directorioTemporal.path, _nombreDelCandidato);
    try {
      // El candidato se copia antes de mirarlo: es un archivo del usuario, y
      // abrirlo en su lugar podría dejarle sidecars al lado de algo que ni
      // siquiera es una base (D2).
      await _copiarArchivo(rutaCandidato, rutaCopia);
      return await _informarSobre(rutaCopia);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('los datos del archivo elegido', causa);
    } finally {
      await _borrarSiExiste(rutaCopia);
    }
  }

  @override
  Future<void> restaurar(String rutaCandidato) async {
    final rutaEnUso = await _baseDatos.rutaEnUso();
    final rutaPrevia = '$rutaEnUso$_sufijoDelArchivoPrevio';
    final rutaCopia = p.join(_directorioTemporal.path, _nombreDelCandidato);

    // Paso 1: el candidato se copia, **no se mueve**. El archivo que el
    // usuario eligió sigue siendo suyo y tiene que poder restaurarlo otra vez.
    await _copiarArchivo(rutaCandidato, rutaCopia);

    // Paso 2 y 3: cerrar y correr el archivo actual a un lado. Renombrar,
    // nunca borrar: esto es la red de seguridad de todo el procedimiento.
    await _baseDatos.cerrar();
    final archivoEnUso = File(rutaEnUso);
    final habiaBaseAnterior = archivoEnUso.existsSync();
    if (habiaBaseAnterior) {
      await _borrarSiExiste(rutaPrevia);
      await archivoEnUso.rename(rutaPrevia);
    }

    try {
      // Paso 4: copiar y borrar, en vez de renombrar. El directorio temporal
      // puede estar en otro sistema de archivos que el de la base, y ahí un
      // rename falla.
      await File(rutaCopia).copy(rutaEnUso);
      await _borrarSiExiste(rutaCopia);
      await _baseDatos.borrarSidecars();

      // Paso 5: reabrir. Si el respaldo venía de una versión anterior, las
      // migraciones que ya existen corren solas acá (D1, FR-010) — incluida
      // la v4 → v5, que borra la tabla de suscripción que pueda traer un
      // archivo viejo. Antes ese descarte se hacía a mano justo acá; ahora lo
      // hace la migración, que además cubre el caso de restaurar sin abrir
      // esta pantalla.
      await _baseDatos.abrir();

      // Paso 6: recién ahora se puede soltar la red de seguridad.
      await _borrarSiExiste(rutaPrevia);
    } on Object catch (causa) {
      await _volverAtras(
        rutaEnUso: rutaEnUso,
        rutaPrevia: rutaPrevia,
        habiaBaseAnterior: habiaBaseAnterior,
      );
      throw ErrorPersistencia(
        'No se pudo restaurar el respaldo. Tus datos quedaron como estaban.',
        causa,
      );
    }
  }

  /// Junta los tres hechos que pide `validarRespaldo` y arma el informe.
  ///
  /// El archivo se abre **sin `version:`**: abrirlo con versión le dispararía
  /// las migraciones a un candidato que quizá se termine rechazando, es decir
  /// modificaría un archivo antes de haberlo aceptado (D2).
  Future<InformeRespaldo> _informarSobre(String rutaCopia) async {
    var integridadOk = false;
    var tablasEsperadasPresentes = false;
    var versionDelArchivo = 0;

    Database? copia;
    try {
      copia = await _baseDatos.fabrica.openDatabase(
        rutaCopia,
        options: OpenDatabaseOptions(singleInstance: false, readOnly: true),
      );

      final integridad = await copia.rawQuery('PRAGMA integrity_check');
      integridadOk =
          integridad.length == 1 && integridad.first.values.first == 'ok';

      if (integridadOk) {
        final tablas = (await copia.query(
          'sqlite_master',
          columns: <String>['name'],
          where: "type = 'table'",
        )).map((fila) => fila['name']! as String).toSet();
        tablasEsperadasPresentes = Esquema.tablasImprescindibles.every(
          tablas.contains,
        );
        versionDelArchivo = await copia.getVersion();
      }
    } on Object {
      // No se pudo ni abrir: no es una base SQLite. Es exactamente lo que
      // `corrupto` significa de cara al usuario, así que no se propaga.
      integridadOk = false;
    } finally {
      await copia?.close();
    }

    return InformeRespaldo(
      resultado: validarRespaldo(
        integridadOk: integridadOk,
        tablasEsperadasPresentes: tablasEsperadasPresentes,
        versionDelArchivo: versionDelArchivo,
        versionSoportada: Esquema.version,
      ),
      versionDelArchivo: versionDelArchivo,
      versionSoportada: Esquema.version,
    );
  }

  /// Deja todo como estaba antes de intentar el reemplazo, y la base abierta
  /// y usable (FR-008).
  Future<void> _volverAtras({
    required String rutaEnUso,
    required String rutaPrevia,
    required bool habiaBaseAnterior,
  }) async {
    await _baseDatos.cerrar();
    await _borrarSiExiste(rutaEnUso);
    await _baseDatos.borrarSidecars();

    final archivoPrevio = File(rutaPrevia);
    if (habiaBaseAnterior && archivoPrevio.existsSync()) {
      await archivoPrevio.rename(rutaEnUso);
    }

    await _baseDatos.abrir();
  }

  /// `finanzas-respaldo-AAAA-MM-DD.db`.
  ///
  /// La fecha se arma a mano en vez de con `intl`: el nombre termina en el
  /// selector de archivos del usuario y tiene que ser el mismo en cualquier
  /// dispositivo, sin depender del formato regional que tenga configurado.
  static String _nombreParaLaFecha(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return 'finanzas-respaldo-${fecha.year}-$mes-$dia.db';
  }

  static Future<void> _copiarArchivo(String origen, String destino) async {
    await _borrarSiExiste(destino);
    await File(origen).copy(destino);
  }

  static Future<void> _borrarSiExiste(String ruta) async {
    final archivo = File(ruta);
    if (archivo.existsSync()) await archivo.delete();
  }

  /// Vacía en [rutaCopia] las tablas que no viajan, y consolida su WAL para
  /// que el archivo quede autocontenido: si se lo entregara con un `-wal` al
  /// lado, el usuario se llevaría medio respaldo.
  Future<void> _vaciarLoQueNoViaja(String rutaCopia) async {
    final copia = await _baseDatos.fabrica.openDatabase(
      rutaCopia,
      // Sin `version:` a propósito: esto no es la base de la app, y abrirla
      // con versión le dispararía migraciones a un archivo que solo hay que
      // limpiar. `singleInstance: false` evita que sqflite devuelva una
      // conexión cacheada de una exportación anterior a la misma ruta.
      options: OpenDatabaseOptions(singleInstance: false),
    );
    try {
      for (final tabla in _tablasQueNoViajan) {
        await copia.delete(tabla);
      }
      await copia.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } finally {
      await copia.close();
    }
  }
}
