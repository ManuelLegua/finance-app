import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/repositorios/repositorio_diagnostico_sqlite.dart';
import 'package:finanzas/datos/repositorios/repositorio_pendientes_sqlite.dart';
import 'package:finanzas/dominio/modelos/consumo_pendiente.dart';
import 'package:finanzas/dominio/modelos/notificacion_diagnostico.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helper_bd.dart';

/// Pendientes y diagnóstico contra SQLite real (spec 002).
void main() {
  setUpAll(inicializarSqfliteFfi);

  late BaseDatos baseDatos;
  late RepositorioPendientesSqlite repoPendientes;
  late RepositorioDiagnosticoSqlite repoDiagnostico;

  ConsumoPendiente pendiente({
    String origenPaquete = 'com.ejemplo.banco',
    String notificacionId = 'notif-1',
    int centavos = 4500,
    String comercio = 'Comercio de prueba',
    DateTime? fecha,
    Categoria? categoriaPropuesta,
  }) => ConsumoPendiente(
    id: null,
    origenPaquete: origenPaquete,
    notificacionId: notificacionId,
    monto: Dinero.deCentavos(centavos),
    comercio: comercio,
    fecha: fecha ?? DateTime(2026, 8, 10),
    categoriaPropuesta: categoriaPropuesta,
    capturadoEn: DateTime(2026, 8, 10, 12),
  );

  setUp(() async {
    baseDatos = await abrirBaseEnMemoria();
    final conexion = await baseDatos.abrir();
    repoPendientes = RepositorioPendientesSqlite(conexion);
    repoDiagnostico = RepositorioDiagnosticoSqlite(conexion);
  });

  tearDown(() async => baseDatos.cerrar());

  group('insertar y leer', () {
    test('devuelve el id asignado y conserva todos los campos', () async {
      final id = await repoPendientes.insertar(
        pendiente(categoriaPropuesta: Categoria.comida),
      );
      expect(id, greaterThan(0));

      final guardado = (await repoPendientes.todos()).single;
      expect(guardado.id, id);
      expect(guardado.origenPaquete, 'com.ejemplo.banco');
      expect(guardado.notificacionId, 'notif-1');
      expect(guardado.monto, const Dinero.deCentavos(4500));
      expect(guardado.comercio, 'Comercio de prueba');
      expect(guardado.fecha, DateTime(2026, 8, 10));
      expect(guardado.categoriaPropuesta, Categoria.comida);
    });

    test(
      'sin categoría propuesta se relee como null, no como una por defecto',
      () async {
        await repoPendientes.insertar(pendiente());

        expect(
          (await repoPendientes.todos()).single.categoriaPropuesta,
          isNull,
        );
      },
    );

    test('ordena del más reciente al más antiguo (FR-021)', () async {
      await repoPendientes.insertar(
        pendiente(
          notificacionId: 'a',
          comercio: 'Viejo',
          fecha: DateTime(2026, 8, 1),
        ),
      );
      await repoPendientes.insertar(
        pendiente(
          notificacionId: 'b',
          comercio: 'Nuevo',
          fecha: DateTime(2026, 8, 20),
        ),
      );

      final comercios = (await repoPendientes.todos())
          .map((pendiente) => pendiente.comercio)
          .toList();
      expect(comercios, ['Nuevo', 'Viejo']);
    });
  });

  group('deduplicación (D-N5, FR-015, FR-016)', () {
    test(
      'la misma notificación reeditada no produce una segunda fila',
      () async {
        final primero = await repoPendientes.insertar(
          pendiente(notificacionId: 'misma'),
        );
        final segundo = await repoPendientes.insertar(
          // Mismo origen y notificación, distinto monto: es la misma
          // notificación actualizada por el banco, no un consumo nuevo.
          pendiente(notificacionId: 'misma', centavos: 9900),
        );

        expect(segundo, primero);
        expect(await repoPendientes.todos(), hasLength(1));
      },
    );

    test(
      'dos consumos idénticos pero de notificaciones distintas se conservan',
      () async {
        await repoPendientes.insertar(pendiente(notificacionId: 'uno'));
        await repoPendientes.insertar(pendiente(notificacionId: 'dos'));

        expect(await repoPendientes.todos(), hasLength(2));
      },
    );

    test('el mismo id de notificación en otro origen no colisiona', () async {
      await repoPendientes.insertar(
        pendiente(origenPaquete: 'com.banco.a', notificacionId: '1'),
      );
      await repoPendientes.insertar(
        pendiente(origenPaquete: 'com.banco.b', notificacionId: '1'),
      );

      expect(await repoPendientes.todos(), hasLength(2));
    });
  });

  group('resumen (FR-022)', () {
    test('sin pendientes es cero, no null', () async {
      final resumen = await repoPendientes.resumen();
      expect(resumen.cantidad, 0);
      expect(resumen.montoTotal, Dinero.cero);
    });

    test('suma cantidad y monto', () async {
      await repoPendientes.insertar(
        pendiente(notificacionId: 'a', centavos: 4500),
      );
      await repoPendientes.insertar(
        pendiente(notificacionId: 'b', centavos: 3300),
      );

      final resumen = await repoPendientes.resumen();
      expect(resumen.cantidad, 2);
      expect(resumen.montoTotal, const Dinero.deCentavos(7800));
    });
  });

  group('eliminar (FR-025)', () {
    test('borra la fila sin dejar rastro', () async {
      final id = await repoPendientes.insertar(pendiente());
      await repoPendientes.eliminar(id);

      expect(await repoPendientes.todos(), isEmpty);
    });

    test('un id inexistente es no-op, no un error', () async {
      await repoPendientes.eliminar(999);
      expect(await repoPendientes.todos(), isEmpty);
    });
  });

  group('diagnóstico (FR-018)', () {
    NotificacionDiagnostico entrada({
      MotivoDiagnostico motivo = MotivoDiagnostico.formatoNoReconocido,
      String texto = 'Texto que no se pudo interpretar',
      DateTime? fecha,
    }) => NotificacionDiagnostico(
      id: null,
      origenPaquete: 'com.ejemplo.banco',
      motivo: motivo,
      textoCrudo: texto,
      fecha: fecha ?? DateTime(2026, 8, 10, 9),
    );

    test('guarda y relee el texto crudo y el motivo', () async {
      await repoDiagnostico.insertar(
        entrada(motivo: MotivoDiagnostico.monedaExtranjera, texto: 'USD 12.00'),
      );

      final guardada = (await repoDiagnostico.todos()).single;
      expect(guardada.motivo, MotivoDiagnostico.monedaExtranjera);
      expect(guardada.textoCrudo, 'USD 12.00');
    });

    test('ordena de la más reciente a la más antigua', () async {
      await repoDiagnostico.insertar(
        entrada(texto: 'vieja', fecha: DateTime(2026, 8, 1)),
      );
      await repoDiagnostico.insertar(
        entrada(texto: 'nueva', fecha: DateTime(2026, 8, 20)),
      );

      final textos = (await repoDiagnostico.todos())
          .map((entrada) => entrada.textoCrudo)
          .toList();
      expect(textos, ['nueva', 'vieja']);
    });

    test('vaciar borra todo el registro', () async {
      await repoDiagnostico.insertar(entrada(texto: 'una'));
      await repoDiagnostico.insertar(entrada(texto: 'otra'));

      await repoDiagnostico.vaciar();

      expect(await repoDiagnostico.todos(), isEmpty);
    });
  });
}
