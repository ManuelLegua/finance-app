import 'package:finanzas/datos/esquema.dart';
import 'package:finanzas/datos/migraciones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helper_bd.dart';

/// Migración v3 → v4 (spec 004): agrega `suscripcion_premium` sin tocar nada
/// de lo que una base de la versión 3 (specs 001, 002 y 003) ya tenía.
///
/// **Por qué acá el esquema v3 no está congelado a mano**, a diferencia de
/// `migracion_002_test.dart`: el paso v4 es puramente aditivo —una tabla
/// nueva, ningún `ALTER`, ninguna copia de datos—, así que "la versión 3" es
/// exactamente el esquema actual menos esa tabla. Reproducir a mano las trece
/// tablas de la v3 duplicaría 150 líneas de DDL que se desincronizarían al
/// primer cambio, sin probar nada que esto no pruebe.
void main() {
  setUpAll(inicializarSqfliteFfi);

  Future<Database> abrirBaseEnVersion3() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 3,
      onCreate: (conexion, version) async {
        final lote = conexion.batch();
        for (final sentencia in Esquema.creacion) {
          if (sentencia == Esquema.suscripcionPremium) continue;
          lote.execute(sentencia);
        }
        await lote.commit(noResult: true);
      },
    ),
  );

  test('agrega suscripcion_premium sin perder datos existentes', () async {
    final conexion = await abrirBaseEnVersion3();
    addTearDown(conexion.close);

    // Datos guardados con la app en la versión 3, antes de esta feature: uno
    // de cada spec previa, que es lo que no se puede perder.
    await conexion.insert('cobro_ingreso', <String, Object?>{
      'fecha': '2026-08-15',
      'mes_ordinal': 24331,
      'monto_centavos': 300000,
    });
    await conexion.insert('tarjeta', <String, Object?>{
      'nombre': 'Visa BCP',
      'entidad': 'BCP',
      'tipo': 'credito',
    });
    await conexion.insert('comercio_categoria', <String, Object?>{
      'comercio_normalizado': 'TOTTUS',
      'categoria': 'alimentacion',
      'actualizado_en': '2026-08-20',
    });

    await Migraciones.aplicar(conexion, desde: 3, hasta: Esquema.version);

    final tablas = (await conexion.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table' AND name NOT LIKE 'sqlite_%'",
    )).map((fila) => fila['name']! as String).toSet();
    expect(tablas, contains('suscripcion_premium'));

    // Y lo de antes sigue exactamente igual.
    final cobros = await conexion.query('cobro_ingreso');
    expect(cobros, hasLength(1));
    expect(cobros.first['monto_centavos'], 300000);

    final tarjetas = await conexion.query('tarjeta');
    expect(tarjetas, hasLength(1));
    expect(tarjetas.first['nombre'], 'Visa BCP');

    final asociaciones = await conexion.query('comercio_categoria');
    expect(asociaciones, hasLength(1));
    expect(asociaciones.first['categoria'], 'alimentacion');
  });

  test(
    'la tabla nueva nace vacía: nunca suscripto es la ausencia de fila',
    () async {
      final conexion = await abrirBaseEnVersion3();
      addTearDown(conexion.close);

      await Migraciones.aplicar(conexion, desde: 3, hasta: Esquema.version);

      // Migrar no siembra ninguna fila a propósito: el repositorio devuelve
      // "nunca suscripto" mientras no exista, sin necesidad de escribir en una
      // migración algo que la app puede derivar.
      final filas = await conexion.query('suscripcion_premium');
      expect(filas, isEmpty);
    },
  );

  test('la tabla admite una sola fila (id = 1)', () async {
    final conexion = await abrirBaseEnVersion3();
    addTearDown(conexion.close);

    await Migraciones.aplicar(conexion, desde: 3, hasta: Esquema.version);

    await conexion.insert('suscripcion_premium', <String, Object?>{
      'id': 1,
      'situacion': 'activa',
      'plan': 'mensual',
      'vigente_hasta': '2026-09-30',
      'ultima_verificacion': '2026-08-30',
    });

    expect(
      () => conexion.insert('suscripcion_premium', <String, Object?>{
        'id': 2,
        'situacion': 'activa',
        'plan': 'anual',
        'vigente_hasta': '2027-08-30',
        'ultima_verificacion': '2026-08-30',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('situación y plan son conjuntos cerrados', () async {
    final conexion = await abrirBaseEnVersion3();
    addTearDown(conexion.close);

    await Migraciones.aplicar(conexion, desde: 3, hasta: Esquema.version);

    expect(
      () => conexion.insert('suscripcion_premium', <String, Object?>{
        'id': 1,
        'situacion': 'inventada',
        'ultima_verificacion': '2026-08-30',
      }),
      throwsA(isA<DatabaseException>()),
    );

    expect(
      () => conexion.insert('suscripcion_premium', <String, Object?>{
        'id': 1,
        'situacion': 'activa',
        'plan': 'semanal',
        'ultima_verificacion': '2026-08-30',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
}
