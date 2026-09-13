import 'package:finanzas/datos/esquema.dart';
import 'package:finanzas/datos/migraciones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helper_bd.dart';

/// Migración v4 → v5 (spec 004 revisada): se va `suscripcion_premium`.
///
/// **Es el único paso destructivo del proyecto**, así que lo que esta prueba
/// fija no es tanto que la tabla desaparezca —eso es una línea de SQL— sino
/// que **no se lleve nada puesto**: ni una fila de las que el usuario cargó
/// con la app en la versión anterior. Esa es la parte que D10 protege y la
/// que se rompería sin querer.
///
/// Reemplaza a `migracion_004_test.dart`, que verificaba las restricciones de
/// una tabla que ya no existe en ninguna versión instalada.
void main() {
  setUpAll(inicializarSqfliteFfi);

  /// Una base tal como la dejaba la app en la versión 3 (specs 001, 002, 003).
  ///
  /// Es `Esquema.creacion` entero, sin excepciones: la v4 agregó
  /// `suscripcion_premium` y la v5 la borra, así que el conjunto de tablas de
  /// la v3 y el de la v5 terminaron siendo el mismo.
  Future<Database> abrirBaseEnVersion3() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 3,
      onCreate: (conexion, version) async {
        final lote = conexion.batch();
        for (final sentencia in Esquema.creacion) {
          lote.execute(sentencia);
        }
        await lote.commit(noResult: true);
      },
    ),
  );

  Future<Set<String>> tablasDe(Database conexion) async =>
      (await conexion.query(
        'sqlite_master',
        columns: ['name'],
        where: "type = 'table' AND name NOT LIKE 'sqlite_%'",
      )).map((fila) => fila['name']! as String).toSet();

  Future<void> sembrarDatosDelUsuario(Database conexion) async {
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
  }

  Future<void> esperarDatosIntactos(Database conexion) async {
    final cobros = await conexion.query('cobro_ingreso');
    expect(cobros, hasLength(1));
    expect(cobros.first['monto_centavos'], 300000);

    final tarjetas = await conexion.query('tarjeta');
    expect(tarjetas, hasLength(1));
    expect(tarjetas.first['nombre'], 'Visa BCP');

    final asociaciones = await conexion.query('comercio_categoria');
    expect(asociaciones, hasLength(1));
    expect(asociaciones.first['categoria'], 'alimentacion');
  }

  test('una base v4 con suscripción llega a la v5 sin la tabla y con todo lo '
      'demás intacto', () async {
    final conexion = await abrirBaseEnVersion3();
    addTearDown(conexion.close);
    await sembrarDatosDelUsuario(conexion);

    // Primero se llega a la v4 de verdad, con su tabla y una fila adentro:
    // es el estado en el que está el teléfono de quien ya tenía la app.
    await Migraciones.aplicar(conexion, desde: 3, hasta: 4);
    await conexion.insert('suscripcion_premium', <String, Object?>{
      'id': 1,
      'situacion': 'activa',
      'plan': 'mensual',
      'vigente_hasta': '2026-10-15',
      'ultima_verificacion': '2026-09-15',
    });
    expect(await tablasDe(conexion), contains('suscripcion_premium'));

    await Migraciones.aplicar(conexion, desde: 4, hasta: 5);

    expect(await tablasDe(conexion), isNot(contains('suscripcion_premium')));
    await esperarDatosIntactos(conexion);
  });

  test('una base v3 que nunca vio la tabla también migra sin romperse', () async {
    final conexion = await abrirBaseEnVersion3();
    addTearDown(conexion.close);
    await sembrarDatosDelUsuario(conexion);

    // El `DROP TABLE IF EXISTS` existe por esto: un respaldo de la v1, v2 o v3
    // pasa por el mismo paso y ahí la tabla nunca existió (spec 005, FR-010).
    await Migraciones.aplicar(conexion, desde: 3, hasta: Esquema.version);

    expect(await tablasDe(conexion), isNot(contains('suscripcion_premium')));
    await esperarDatosIntactos(conexion);
  });

  test('una instalación nueva nunca crea la tabla', () async {
    final conexion = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: Esquema.version,
        onCreate: (conexion, version) async {
          final lote = conexion.batch();
          for (final sentencia in Esquema.creacion) {
            lote.execute(sentencia);
          }
          await lote.commit(noResult: true);
        },
      ),
    );
    addTearDown(conexion.close);

    // No es que se cree y se borre: `Esquema.creacion` ya no la menciona,
    // igual que no menciona la tabla `ingreso` de la v1.
    expect(await tablasDe(conexion), isNot(contains('suscripcion_premium')));
  });
}
