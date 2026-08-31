import 'package:finanzas/datos/esquema.dart';
import 'package:finanzas/datos/migraciones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helper_bd.dart';

/// Migración v2 → v3 (spec 003): agrega `cobro_ingreso` y copia cada
/// `ingreso` ya guardado como un cobro equivalente, sin tocar ni borrar la
/// tabla `ingreso` original (D-C2 de research.md).
///
/// Igual que `migracion_002_test.dart`: se reconstruye a mano el esquema tal
/// como era en la versión 2, para probar de verdad el camino de `onUpgrade`.
void main() {
  setUpAll(inicializarSqfliteFfi);

  /// DDL de `ingreso` congelado en la forma que tenía en la versión 2 (previa
  /// a esta feature): un monto único por mes.
  const ingresoV2 = '''
    CREATE TABLE ingreso (
      mes_ordinal     INTEGER PRIMARY KEY,
      monto_centavos  INTEGER NOT NULL CHECK (monto_centavos > 0)
    )
  ''';

  Future<Database> abrirBaseEnVersion2() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 2,
      onCreate: (conexion, version) async {
        await conexion.execute(ingresoV2);
      },
    ),
  );

  test('crea cobro_ingreso y copia cada ingreso existente sin borrar la tabla original', () async {
    final conexion = await abrirBaseEnVersion2();
    addTearDown(conexion.close);

    // Dos meses con ingreso registrado en la versión 2, antes de esta feature.
    // 2026 * 12 + (8 - 1) = 24319 → agosto 2026.
    await conexion.insert('ingreso', <String, Object?>{
      'mes_ordinal': 24319,
      'monto_centavos': 200000,
    });
    // 2026 * 12 + (7 - 1) = 24318 → julio 2026.
    await conexion.insert('ingreso', <String, Object?>{
      'mes_ordinal': 24318,
      'monto_centavos': 180000,
    });

    await Migraciones.aplicar(conexion, desde: 2, hasta: Esquema.version);

    final cobros = await conexion.query(
      'cobro_ingreso',
      orderBy: 'mes_ordinal ASC',
    );
    expect(cobros, hasLength(2));
    expect(cobros[0]['mes_ordinal'], 24318);
    expect(cobros[0]['monto_centavos'], 180000);
    expect(cobros[0]['fecha'], '2026-07-01');
    expect(cobros[1]['mes_ordinal'], 24319);
    expect(cobros[1]['monto_centavos'], 200000);
    expect(cobros[1]['fecha'], '2026-08-01');

    // La tabla ingreso no se borra ni se toca (D-C2): sigue con sus
    // dos filas originales, intactas.
    final ingresos = await conexion.query('ingreso', orderBy: 'mes_ordinal');
    expect(ingresos, hasLength(2));
    expect(ingresos[0]['monto_centavos'], 180000);
    expect(ingresos[1]['monto_centavos'], 200000);
  });

  test('un mes sin ningún cobro previo no genera filas de más', () async {
    final conexion = await abrirBaseEnVersion2();
    addTearDown(conexion.close);

    await Migraciones.aplicar(conexion, desde: 2, hasta: Esquema.version);

    expect(await conexion.query('cobro_ingreso'), isEmpty);
  });
}
