import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/datos/esquema.dart';
import 'package:finanzas/datos/migraciones.dart';
import 'package:finanzas/datos/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/dominio/modelos/configuracion.dart';
import 'package:finanzas/dominio/modelos/enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'helper_bd.dart';

void main() {
  setUpAll(inicializarSqfliteFfi);

  late BaseDatos bd;
  late Database db;

  setUp(() async {
    bd = await abrirBaseEnMemoria();
    db = await bd.abrir();
  });

  tearDown(() async {
    await bd.cerrar();
  });

  group('creación del esquema', () {
    test('crea las ocho tablas de data-model.md', () async {
      final filas = await db.query(
        'sqlite_master',
        columns: ['name'],
        where: "type = 'table' AND name NOT LIKE 'sqlite_%'",
      );
      final tablas = filas.map((f) => f['name']! as String).toSet();

      expect(tablas, containsAll(<String>[
        'ingreso',
        'obligacion',
        'transaccion',
        'tarjeta',
        'deuda',
        'aporte_ahorro',
        'meta_ahorro',
        'configuracion',
      ]));
    });

    test('crea los índices por mes, que sostienen las consultas', () async {
      final filas = await db.query(
        'sqlite_master',
        columns: ['name'],
        where: "type = 'index' AND name LIKE 'idx_%'",
      );
      final indices = filas.map((f) => f['name']! as String).toSet();

      expect(indices, containsAll(<String>[
        'idx_obligacion_mes',
        'idx_transaccion_mes',
        'idx_deuda_tarjeta',
        'idx_aporte_mes',
      ]));
    });

    test('la versión del esquema queda en 1', () async {
      final version = await db.getVersion();
      expect(version, 1);
      expect(version, Esquema.version);
    });
  });

  group('integridad', () {
    test('las claves foráneas están activas en la conexión', () async {
      final filas = await db.rawQuery('PRAGMA foreign_keys');
      expect(filas.first.values.first, 1);
    });

    test('una deuda no puede apuntar a una tarjeta inexistente', () async {
      expect(
        () => db.insert('deuda', <String, Object?>{
          'descripcion': 'Celular',
          'tarjeta_id': 999,
          'cuota_centavos': 15000,
          'num_cuotas': 12,
          'mes_inicio_ordinal': 24319,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('los montos en cero o negativos se rechazan', () async {
      expect(
        () => db.insert('ingreso', <String, Object?>{
          'mes_ordinal': 24319,
          'monto_centavos': 0,
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => db.insert('ingreso', <String, Object?>{
          'mes_ordinal': 24319,
          'monto_centavos': -100,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('una deuda necesita al menos una cuota', () async {
      final tarjetaId = await db.insert('tarjeta', <String, Object?>{
        'nombre': 'BCP Visa',
        'entidad': 'BCP',
        'tipo': 'credito',
      });
      expect(
        () => db.insert('deuda', <String, Object?>{
          'descripcion': 'Celular',
          'tarjeta_id': tarjetaId,
          'cuota_centavos': 15000,
          'num_cuotas': 0,
          'mes_inicio_ordinal': 24319,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('el tipo de tarjeta es un conjunto cerrado', () async {
      expect(
        () => db.insert('tarjeta', <String, Object?>{
          'nombre': 'Rara',
          'entidad': 'BCP',
          'tipo': 'prepago',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('la configuración admite una sola fila', () async {
      await db.insert('configuracion', <String, Object?>{
        'id': 1,
        'regla': 'porcentaje',
        'porcentaje_bp': 2000,
        'dias_gracia_cierre': 5,
      });
      expect(
        () => db.insert('configuracion', <String, Object?>{
          'id': 2,
          'regla': 'remanente',
          'porcentaje_bp': 0,
          'dias_gracia_cierre': 5,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('los montos se guardan como enteros, nunca como REAL', () async {
      await db.insert('ingreso', <String, Object?>{
        'mes_ordinal': 24319,
        'monto_centavos': 300000,
      });
      final filas = await db.rawQuery(
        'SELECT typeof(monto_centavos) AS t FROM ingreso',
      );
      expect(filas.first['t'], 'integer');
    });
  });

  group('configuración por defecto', () {
    test('se crea sola con 20% y 5 días de gracia', () async {
      final repo = RepositorioConfiguracion(db);
      final config = await repo.obtener();

      expect(config.regla, ReglaAhorro.porcentajeIngreso);
      expect(config.porcentajeBp, 2000);
      expect(config.diasGraciaCierre, 5);
      expect(config, Configuracion.porDefecto);
    });

    test('lo guardado se relee igual', () async {
      final repo = RepositorioConfiguracion(db);
      await repo.guardar(
        Configuracion.porDefecto.copiarCon(
          regla: ReglaAhorro.remanente,
          diasGraciaCierre: 0,
        ),
      );

      final releida = await repo.obtener();
      expect(releida.regla, ReglaAhorro.remanente);
      expect(releida.diasGraciaCierre, 0);
    });
  });

  group('migraciones', () {
    test('no hay pasos pendientes en la versión 1', () {
      expect(Migraciones.pasos, isEmpty);
    });

    test('preservan los datos existentes', () async {
      // Simula un salto de versión con un paso aditivo, que es la única forma
      // admitida: nunca se borra ni se recrea una tabla con datos (D10).
      await db.insert('ingreso', <String, Object?>{
        'mes_ordinal': 24319,
        'monto_centavos': 300000,
      });

      await db.execute('ALTER TABLE ingreso ADD COLUMN nota TEXT');

      final filas = await db.query('ingreso');
      expect(filas, hasLength(1));
      expect(filas.first['monto_centavos'], 300000);
      expect(filas.first['nota'], isNull);
    });

    test('una versión sin migración definida falla en vez de romper datos',
        () async {
      await expectLater(
        Migraciones.aplicar(db, desde: 1, hasta: 2),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('apertura fallida', () {
    test('una base ilegible da ErrorPersistencia, no una base vacía', () async {
      // Es el caso que más importa comunicar bien: arrancar con datos vacíos
      // haría creer al usuario que perdió su historial.
      final rota = BaseDatos(
        rutaOverride: '/ruta/que/no/existe/en/ningun/lado/finanzas.db',
      );
      await expectLater(rota.abrir(), throwsA(isA<ErrorPersistencia>()));
    });

    test('el mensaje del error no expone SQL crudo', () {
      final error = ErrorPersistencia.alAbrir(Exception('SQLITE_CORRUPT'));
      expect(error.mensaje, isNot(contains('SQLITE')));
      expect(error.mensaje, contains('dispositivo'));
      expect(error.detalle, isNotNull);
    });
  });
}
