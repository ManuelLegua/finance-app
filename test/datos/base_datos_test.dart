import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/datos/esquema.dart';
import 'package:finanzas/datos/migraciones.dart';
import 'package:finanzas/datos/repositorios/repositorio_configuracion_sqlite.dart';
import 'package:finanzas/dominio/modelos/configuracion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'helper_bd.dart';

void main() {
  setUpAll(inicializarSqfliteFfi);

  late BaseDatos baseDatos;
  late Database conexion;

  setUp(() async {
    baseDatos = await abrirBaseEnMemoria();
    conexion = await baseDatos.abrir();
  });

  tearDown(() async {
    await baseDatos.cerrar();
  });

  group('creación del esquema', () {
    test('crea las tablas de data-model.md', () async {
      final filas = await conexion.query(
        'sqlite_master',
        columns: ['name'],
        where: "type = 'table' AND name NOT LIKE 'sqlite_%'",
      );
      final tablas = filas.map((fila) => fila['name']! as String).toSet();

      expect(
        tablas,
        containsAll(<String>[
          'obligacion',
          'transaccion',
          'tarjeta',
          'deuda',
          'aporte_ahorro',
          'meta_ahorro',
          'configuracion',
          // Spec 002: captura de notificaciones bancarias.
          'consumo_pendiente',
          'comercio_categoria',
          'notificacion_diagnostico',
          // Spec 003: cobros parciales de ingreso. `ingreso` (v1) no aparece
          // acá: una instalación nueva ya no la crea (D-C5 de research.md).
          'cobro_ingreso',
          // La spec 004 no aporta ninguna tabla: se revisó a propina
          // voluntaria y una propina no deja estado (D8). La
          // `suscripcion_premium` que agregaba en la v4 la borra la v5, así
          // que una instalación nueva ya no la crea.
        ]),
      );
    });

    test('crea los índices por mes, que sostienen las consultas', () async {
      final filas = await conexion.query(
        'sqlite_master',
        columns: ['name'],
        where: "type = 'index' AND name LIKE 'idx_%'",
      );
      final indices = filas.map((fila) => fila['name']! as String).toSet();

      expect(
        indices,
        containsAll(<String>[
          'idx_obligacion_mes',
          'idx_transaccion_mes',
          'idx_deuda_tarjeta',
          'idx_aporte_mes',
          'idx_pendiente_notificacion',
          'idx_pendiente_fecha',
          'idx_diagnostico_fecha',
        ]),
      );
    });

    test('la versión del esquema queda en la actual', () async {
      final version = await conexion.getVersion();
      expect(version, Esquema.version);
    });
  });

  group('integridad', () {
    test('las claves foráneas están activas en la conexión', () async {
      final filas = await conexion.rawQuery('PRAGMA foreign_keys');
      expect(filas.first.values.first, 1);
    });

    test('una deuda no puede apuntar a una tarjeta inexistente', () async {
      expect(
        () => conexion.insert('deuda', <String, Object?>{
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
        () => conexion.insert('cobro_ingreso', <String, Object?>{
          'fecha': '2026-08-01',
          'mes_ordinal': 24319,
          'monto_centavos': 0,
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => conexion.insert('cobro_ingreso', <String, Object?>{
          'fecha': '2026-08-01',
          'mes_ordinal': 24319,
          'monto_centavos': -100,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('una deuda necesita al menos una cuota', () async {
      final tarjetaId = await conexion.insert('tarjeta', <String, Object?>{
        'nombre': 'BCP Visa',
        'entidad': 'BCP',
        'tipo': 'credito',
      });
      expect(
        () => conexion.insert('deuda', <String, Object?>{
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
        () => conexion.insert('tarjeta', <String, Object?>{
          'nombre': 'Rara',
          'entidad': 'BCP',
          'tipo': 'prepago',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('la configuración admite una sola fila', () async {
      await conexion.insert('configuracion', <String, Object?>{
        'id': 1,
        'regla': 'porcentaje',
        'porcentaje_bp': 2000,
        'dias_gracia_cierre': 5,
      });
      expect(
        () => conexion.insert('configuracion', <String, Object?>{
          'id': 2,
          'regla': 'remanente',
          'porcentaje_bp': 0,
          'dias_gracia_cierre': 5,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('los montos se guardan como enteros, nunca como REAL', () async {
      await conexion.insert('cobro_ingreso', <String, Object?>{
        'fecha': '2026-08-01',
        'mes_ordinal': 24319,
        'monto_centavos': 300000,
      });
      final filas = await conexion.rawQuery(
        'SELECT typeof(monto_centavos) AS t FROM cobro_ingreso',
      );
      expect(filas.first['t'], 'integer');
    });
  });

  group('configuración por defecto', () {
    test('se crea sola con 20% y 5 días de gracia', () async {
      final repo = RepositorioConfiguracionSqlite(conexion);
      final config = await repo.obtener();

      expect(config.regla, ReglaAhorro.porcentajeIngreso);
      expect(config.porcentajeBp, 2000);
      expect(config.diasGraciaCierre, 5);
      expect(config, Configuracion.porDefecto);
    });

    test(
      // Spec 002: la captura de notificaciones empieza inactiva hasta que el
      // usuario la active a propósito (HU1) — nunca activada por sorpresa.
      'la captura de notificaciones empieza inactiva',
      () async {
        final repo = RepositorioConfiguracionSqlite(conexion);
        final config = await repo.obtener();

        expect(config.capturaNotificacionesActiva, isFalse);
      },
    );

    test('activar la captura se guarda y persiste', () async {
      final repo = RepositorioConfiguracionSqlite(conexion);
      await repo.guardar(
        Configuracion.porDefecto.copiarCon(capturaNotificacionesActiva: true),
      );

      final releida = await repo.obtener();
      expect(releida.capturaNotificacionesActiva, isTrue);
    });

    test('lo guardado se relee igual', () async {
      final repo = RepositorioConfiguracionSqlite(conexion);
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
    test('hay un paso definido por cada versión hasta la actual', () {
      for (var version = 2; version <= Esquema.version; version++) {
        expect(
          Migraciones.pasos.containsKey(version),
          isTrue,
          reason: 'Falta el paso de migración a la versión $version',
        );
      }
    });

    test('preservan los datos existentes', () async {
      // Simula un salto de versión con un paso aditivo, que es la única forma
      // admitida: nunca se borra ni se recrea una tabla con datos (D10).
      await conexion.insert('cobro_ingreso', <String, Object?>{
        'fecha': '2026-08-01',
        'mes_ordinal': 24319,
        'monto_centavos': 300000,
      });

      await conexion.execute('ALTER TABLE cobro_ingreso ADD COLUMN nota TEXT');

      final filas = await conexion.query('cobro_ingreso');
      expect(filas, hasLength(1));
      expect(filas.first['monto_centavos'], 300000);
      expect(filas.first['nota'], isNull);
    });

    test(
      'una versión sin migración definida falla en vez de romper datos',
      () async {
        const sinDefinir = Esquema.version + 1;
        await expectLater(
          Migraciones.aplicar(
            conexion,
            desde: Esquema.version,
            hasta: sinDefinir,
          ),
          throwsA(isA<StateError>()),
        );
      },
    );
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
