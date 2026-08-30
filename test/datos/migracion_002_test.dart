import 'package:finanzas/datos/esquema.dart';
import 'package:finanzas/datos/migraciones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helper_bd.dart';

/// Migración v1 → v2 (spec 002): agrega `consumo_pendiente`,
/// `comercio_categoria`, `notificacion_diagnostico` y la columna
/// `captura_notificaciones_activa` en `configuracion`, sin tocar los datos
/// que una base de la versión 1 (solo 001) ya tenía guardados.
///
/// A diferencia de `base_datos_test.dart`, que abre siempre la base en la
/// versión actual vía `BaseDatos`, acá se reconstruye a mano el esquema tal
/// como era en la versión 1 — es la única forma de probar de verdad el
/// camino de `onUpgrade`, no solo que el DDL de la versión 2 sea válido.
void main() {
  setUpAll(inicializarSqfliteFfi);

  /// DDL de la versión 1 (previa a esta feature), congelado a propósito: si
  /// `esquema.dart` cambia después, esta prueba debe seguir representando lo
  /// que una base real de esa época tenía guardado.
  const configuracionV1 = '''
    CREATE TABLE configuracion (
      id                  INTEGER PRIMARY KEY CHECK (id = 1),
      regla               TEXT    NOT NULL CHECK (regla IN ('porcentaje','remanente')),
      porcentaje_bp       INTEGER NOT NULL DEFAULT 2000
                            CHECK (porcentaje_bp BETWEEN 0 AND 10000),
      dias_gracia_cierre  INTEGER NOT NULL DEFAULT 5
                            CHECK (dias_gracia_cierre BETWEEN 0 AND 28)
    )
  ''';

  const ingresoV1 = '''
    CREATE TABLE ingreso (
      mes_ordinal     INTEGER PRIMARY KEY,
      monto_centavos  INTEGER NOT NULL CHECK (monto_centavos > 0)
    )
  ''';

  Future<Database> abrirBaseEnVersion1() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (conexion, version) async {
        final lote = conexion.batch();
        lote.execute(ingresoV1);
        lote.execute(configuracionV1);
        await lote.commit(noResult: true);
      },
    ),
  );

  test(
    'agrega las tablas y la columna nuevas sin perder datos existentes',
    () async {
      final conexion = await abrirBaseEnVersion1();
      addTearDown(conexion.close);

      // Datos guardados con la app en la versión 1, antes de esta feature.
      await conexion.insert('ingreso', <String, Object?>{
        'mes_ordinal': 24331,
        'monto_centavos': 300000,
      });
      await conexion.insert('configuracion', <String, Object?>{
        'id': 1,
        'regla': 'porcentaje',
        'porcentaje_bp': 2000,
        'dias_gracia_cierre': 5,
      });

      await Migraciones.aplicar(conexion, desde: 1, hasta: Esquema.version);

      final tablas = (await conexion.query(
        'sqlite_master',
        columns: ['name'],
        where: "type = 'table' AND name NOT LIKE 'sqlite_%'",
      )).map((fila) => fila['name']! as String).toSet();
      expect(
        tablas,
        containsAll(<String>[
          'consumo_pendiente',
          'comercio_categoria',
          'notificacion_diagnostico',
        ]),
      );

      final ingresos = await conexion.query('ingreso');
      expect(ingresos, hasLength(1));
      expect(ingresos.first['monto_centavos'], 300000);

      final config = await conexion.query('configuracion');
      expect(config, hasLength(1));
      expect(config.first['regla'], 'porcentaje');
      // La columna nueva llega con su valor por defecto, no vacía ni nula.
      expect(config.first['captura_notificaciones_activa'], 0);
    },
  );

  test('el índice único de deduplicación queda activo tras migrar', () async {
    final conexion = await abrirBaseEnVersion1();
    addTearDown(conexion.close);

    await Migraciones.aplicar(conexion, desde: 1, hasta: Esquema.version);

    await conexion.insert('consumo_pendiente', <String, Object?>{
      'origen_paquete': 'com.ejemplo.banco',
      'notificacion_id': 'abc-1',
      'monto_centavos': 4500,
      'comercio': 'Comercio de prueba',
      'fecha': '2026-08-30',
      'capturado_en': '2026-08-30T10:00:00.000',
    });

    expect(
      () => conexion.insert('consumo_pendiente', <String, Object?>{
        'origen_paquete': 'com.ejemplo.banco',
        'notificacion_id': 'abc-1',
        'monto_centavos': 9900,
        'comercio': 'Otro comercio',
        'fecha': '2026-08-30',
        'capturado_en': '2026-08-30T10:05:00.000',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
}
