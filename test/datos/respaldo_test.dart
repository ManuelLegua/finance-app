import 'dart:io';

import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/datos/esquema.dart';
import 'package:finanzas/datos/repositorios/repositorio_respaldo_sqlite.dart';
import 'package:finanzas/dominio/modelos/respaldo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helper_bd.dart';

/// Respaldo y restauración contra archivos de verdad (spec 005).
///
/// **Por qué acá no hay base en memoria**: toda la feature consiste en copiar,
/// renombrar y reemplazar el archivo de la base. Un `:memory:` no tiene
/// archivo que mover, así que estas pruebas montan bases reales en un
/// directorio temporal. `sqflite_common_ffi` corre SQLite de verdad en
/// Windows, así que el ida y vuelta completo se verifica sin emulador.
void main() {
  setUpAll(inicializarSqfliteFfi);

  late Directory directorioDeDatos;
  late Directory directorioTemporal;
  late BaseDatos baseDatos;
  late RepositorioRespaldoSqlite repoRespaldo;

  /// Monta una base en un archivo real, con o sin datos cargados.
  Future<void> montarBase({required bool conDatos}) async {
    directorioDeDatos = crearDirectorioTemporal();
    directorioTemporal = crearDirectorioTemporal();
    baseDatos = await abrirBaseEnArchivo(directorioDeDatos);
    if (conDatos) await sembrarDatosDeEjemplo(baseDatos.conexionActual!);
    repoRespaldo = RepositorioRespaldoSqlite(
      baseDatos,
      directorioTemporal: directorioTemporal,
    );
  }

  /// Abre un archivo ya generado **sin `version:`**, igual que hace la
  /// inspección: abrirlo con versión le dispararía migraciones al archivo que
  /// la prueba quiere leer tal como quedó.
  Future<Database> abrirArchivoGenerado(String ruta) async {
    final conexion = await databaseFactoryFfi.openDatabase(
      ruta,
      options: OpenDatabaseOptions(readOnly: true),
    );
    addTearDown(conexion.close);
    return conexion;
  }

  /// Deja la base sin una sola fila, para poder comprobar que restaurar las
  /// trae de vuelta. Simula el "reinstalé la app" del recorrido manual.
  Future<void> vaciarTodasLasTablas(Database conexion) async {
    final tablas = (await conexion.query(
      'sqlite_master',
      columns: <String>['name'],
      where: "type = 'table' AND name NOT LIKE 'sqlite_%'",
    )).map((fila) => fila['name']! as String);
    // `defer_foreign_keys` corre la verificación al commit: sin eso habría
    // que borrar en orden de dependencia (deuda antes que tarjeta), que es
    // una lista a mano más para desincronizarse.
    await conexion.transaction((transaccion) async {
      await transaccion.execute('PRAGMA defer_foreign_keys = ON');
      for (final tabla in tablas) {
        await transaccion.delete(tabla);
      }
    });
  }

  Future<int> filasEn(Database conexion, String tabla) async =>
      (await conexion.rawQuery('SELECT COUNT(*) AS total FROM $tabla'))
              .first['total']!
          as int;

  group('exportar', () {
    test(
      'el archivo generado trae las mismas filas que la base viva',
      () async {
        await montarBase(conDatos: true);

        final respaldo = await repoRespaldo.exportar();

        expect(File(respaldo.ruta).existsSync(), isTrue);
        expect(
          respaldo.nombrePropuesto,
          matches(RegExp(r'^finanzas-respaldo-\d{4}-\d{2}-\d{2}\.db$')),
        );

        final copia = await abrirArchivoGenerado(respaldo.ruta);

        // Una por spec: presupuesto y gastos (001), asociaciones aprendidas
        // (002) y cobros de ingreso (003). Es FR-002 en su forma verificable.
        final obligaciones = await copia.query('obligacion');
        expect(obligaciones, hasLength(1));
        expect(obligaciones.first['nombre'], 'Alquiler');
        expect(obligaciones.first['monto_centavos'], 90000);

        final transacciones = await copia.query('transaccion');
        expect(transacciones, hasLength(1));
        expect(transacciones.first['monto_centavos'], 4550);

        final deudas = await copia.query('deuda');
        expect(deudas, hasLength(1));
        expect(deudas.first['cuota_centavos'], 15000);
        expect(deudas.first['num_cuotas'], 12);

        final aportes = await copia.query('aporte_ahorro');
        expect(aportes, hasLength(1));
        expect(aportes.first['monto_centavos'], 30000);

        final cobros = await copia.query('cobro_ingreso');
        expect(cobros, hasLength(1));
        expect(cobros.first['monto_centavos'], 180000);

        final asociaciones = await copia.query('comercio_categoria');
        expect(asociaciones, hasLength(1));
        expect(asociaciones.first['comercio_normalizado'], 'TOTTUS');
      },
    );

    test(
      'una base recién creada y sin datos genera igual un archivo válido',
      () async {
        // FR-012: exportar apenas instalada la app no puede fallar por no tener
        // nada que exportar.
        await montarBase(conDatos: false);

        final respaldo = await repoRespaldo.exportar();
        final copia = await abrirArchivoGenerado(respaldo.ruta);

        expect(await filasEn(copia, 'obligacion'), 0);
        // Y es un respaldo legítimo, no un archivo vacío: lleva el esquema y su
        // versión, que es lo que la inspección va a mirar después.
        expect(await copia.getVersion(), greaterThan(0));
        final tablas = await copia.query(
          'sqlite_master',
          columns: <String>['name'],
          where: "type = 'table' AND name = 'obligacion'",
        );
        expect(tablas, hasLength(1));
      },
    );

    test('el diagnóstico viaja vacío', () async {
      // D4: el texto crudo de las notificaciones bancarias no tiene por qué
      // salir del teléfono. Acá también se comprobaba que viajara vacía
      // `suscripcion_premium`, para que nadie se fabricara acceso pagado
      // editando el archivo; esa tabla ya no existe (spec 004 revisada, D9).
      await montarBase(conDatos: true);

      final copia = await abrirArchivoGenerado(
        (await repoRespaldo.exportar()).ruta,
      );

      expect(await filasEn(copia, 'notificacion_diagnostico'), 0);

      // Lo demás sí viaja: vaciar de más sería peor que no exportar.
      expect(await filasEn(copia, 'obligacion'), 1);
      expect(await filasEn(copia, 'transaccion'), 1);
      expect(await filasEn(copia, 'tarjeta'), 1);
      expect(await filasEn(copia, 'deuda'), 1);
      expect(await filasEn(copia, 'aporte_ahorro'), 1);
      expect(await filasEn(copia, 'meta_ahorro'), 1);
      expect(await filasEn(copia, 'cobro_ingreso'), 1);
      expect(await filasEn(copia, 'comercio_categoria'), 1);
      expect(await filasEn(copia, 'configuracion'), 1);
    });

    test('no modifica la base viva', () async {
      // La mitad fácil de olvidar de D4: se vacía **la copia**, nunca el
      // original. Si esto se rompe, exportar le borraría al usuario su
      // diagnóstico sin avisar.
      await montarBase(conDatos: true);
      final viva = baseDatos.conexionActual!;

      await repoRespaldo.exportar();

      expect(await filasEn(viva, 'notificacion_diagnostico'), 1);
      expect(await filasEn(viva, 'obligacion'), 1);
      expect(await filasEn(viva, 'cobro_ingreso'), 1);
    });
  });

  group('restaurar', () {
    test('el ida y vuelta completo devuelve los datos idénticos', () async {
      // SC-001 en su forma verificable: exportar, perderlo todo, restaurar.
      await montarBase(conDatos: true);
      final respaldo = await repoRespaldo.exportar();

      await vaciarTodasLasTablas(baseDatos.conexionActual!);
      expect(await filasEn(baseDatos.conexionActual!, 'obligacion'), 0);

      await repoRespaldo.restaurar(respaldo.ruta);

      // La conexión de antes quedó cerrada en el reemplazo: lo que vale es la
      // que abrió el propio `restaurar`.
      final restaurada = baseDatos.conexionActual!;
      expect(await filasEn(restaurada, 'obligacion'), 1);
      expect(await filasEn(restaurada, 'transaccion'), 1);
      expect(await filasEn(restaurada, 'tarjeta'), 1);
      expect(await filasEn(restaurada, 'deuda'), 1);
      expect(await filasEn(restaurada, 'aporte_ahorro'), 1);
      expect(await filasEn(restaurada, 'meta_ahorro'), 1);
      expect(await filasEn(restaurada, 'cobro_ingreso'), 1);
      expect(await filasEn(restaurada, 'comercio_categoria'), 1);

      final cobros = await restaurada.query('cobro_ingreso');
      expect(cobros.first['monto_centavos'], 180000);
      final deudas = await restaurada.query('deuda');
      expect(deudas.first['cuota_centavos'], 15000);
      expect(deudas.first['num_cuotas'], 12);
    });

    test(
      'un respaldo de la versión 3 se restaura migrado y con sus datos',
      () async {
        // FR-010, y la razón de ser de D1: el archivo lleva su `user_version`
        // encima, así que `BaseDatos.abrir()` le aplica las migraciones que ya
        // existen. Si esto pasa sin código de migración nuevo, el formato
        // elegido era el correcto.
        await montarBase(conDatos: false);

        final directorioDelRespaldoViejo = crearDirectorioTemporal();
        final rutaRespaldoViejo = p.join(
          directorioDelRespaldoViejo.path,
          'finanzas-respaldo-2026-05-01.db',
        );
        await crearBaseEnVersion3(
          rutaRespaldoViejo,
          sembrar: (conexion) async {
            await conexion.insert('cobro_ingreso', <String, Object?>{
              'fecha': '2026-05-15',
              'mes_ordinal': 24328,
              'monto_centavos': 250000,
            });
            await conexion.insert('obligacion', <String, Object?>{
              'mes_ordinal': 24328,
              'nombre': 'Internet',
              'categoria': 'servicios',
              'monto_centavos': 12000,
              'tipo': 'fija',
            });
          },
        );

        final informe = await repoRespaldo.inspeccionar(rutaRespaldoViejo);
        expect(informe.resultado, ResultadoValidacionRespaldo.valido);
        expect(informe.versionDelArchivo, 3);
        expect(informe.requiereMigracion, isTrue);

        await repoRespaldo.restaurar(rutaRespaldoViejo);

        final restaurada = baseDatos.conexionActual!;
        expect(await restaurada.getVersion(), Esquema.version);
        // Lo que traía la v3 sigue ahí después de cruzar dos migraciones.
        final cobros = await restaurada.query('cobro_ingreso');
        expect(cobros, hasLength(1));
        expect(cobros.first['monto_centavos'], 250000);
        final obligaciones = await restaurada.query('obligacion');
        expect(obligaciones.first['nombre'], 'Internet');
      },
    );

    test('no sobreviven los sidecars del archivo anterior', () async {
      // D3 marca este como el modo de fallo más fácil de pasar por alto: un
      // `-wal` huérfano junto a un archivo principal distinto es corrupción
      // silenciosa, no un error visible.
      await montarBase(conDatos: true);
      final respaldo = await repoRespaldo.exportar();

      final rutaBase = await baseDatos.rutaEnUso();
      final wal = File('$rutaBase-wal')..writeAsStringSync('sidecar viejo');
      final shm = File('$rutaBase-shm')..writeAsStringSync('sidecar viejo');

      await repoRespaldo.restaurar(respaldo.ruta);

      expect(wal.existsSync(), isFalse);
      expect(shm.existsSync(), isFalse);
      // Y la base restaurada se lee sin problemas.
      expect(await filasEn(baseDatos.conexionActual!, 'obligacion'), 1);
    });

    test(
      'restaurar dos veces el mismo archivo deja el mismo resultado',
      () async {
        await montarBase(conDatos: true);
        final respaldo = await repoRespaldo.exportar();

        await repoRespaldo.restaurar(respaldo.ruta);
        final despuesDeLaPrimera = await filasEn(
          baseDatos.conexionActual!,
          'transaccion',
        );

        // El archivo elegido por el usuario no se consume al restaurarlo: se
        // copia. Si se moviera, esta segunda restauración fallaría.
        expect(File(respaldo.ruta).existsSync(), isTrue);
        await repoRespaldo.restaurar(respaldo.ruta);

        expect(
          await filasEn(baseDatos.conexionActual!, 'transaccion'),
          despuesDeLaPrimera,
        );
        expect(await filasEn(baseDatos.conexionActual!, 'obligacion'), 1);
      },
    );

    test(
      'un fallo a mitad del reemplazo deja la base como estaba y usable',
      () async {
        // FR-008: el todo-o-nada de D3. Se fuerza el fallo salteándose la
        // inspección a propósito y dándole un archivo que no es una base: el
        // reemplazo ya renombró el original cuando descubre que lo nuevo no
        // abre, que es exactamente el punto donde tiene que saber volver atrás.
        await montarBase(conDatos: true);

        final rutaBasura = p.join(
          crearDirectorioTemporal().path,
          'no-es-una-base.db',
        );
        File(rutaBasura).writeAsStringSync('esto no es SQLite, es un texto');

        await expectLater(
          repoRespaldo.restaurar(rutaBasura),
          throwsA(isA<ErrorPersistencia>()),
        );

        final base = baseDatos.conexionActual;
        expect(base, isNotNull, reason: 'la base tiene que quedar abierta');
        expect(await filasEn(base!, 'obligacion'), 1);
        expect(await filasEn(base, 'cobro_ingreso'), 1);
        expect(await filasEn(base, 'deuda'), 1);
        // Y la red de seguridad se soltó: no queda un `.previo` colgado.
        final rutaEnUso = await baseDatos.rutaEnUso();
        expect(File('$rutaEnUso.previo').existsSync(), isFalse);
      },
    );
  });
}
