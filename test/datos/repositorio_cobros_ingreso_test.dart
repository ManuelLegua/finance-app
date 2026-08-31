import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/repositorios/repositorio_cobros_ingreso_sqlite.dart';
import 'package:finanzas/dominio/modelos/cobro_ingreso.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helper_bd.dart';

void main() {
  setUpAll(inicializarSqfliteFfi);

  late BaseDatos baseDatos;
  late RepositorioCobrosIngresoSqlite repo;

  const agosto = Mes(2026, 8);
  const julio = Mes(2026, 7);

  CobroIngreso cobro({int centavos = 200000, DateTime? fecha}) => CobroIngreso(
    id: null,
    fecha: fecha ?? DateTime(2026, 8, 15),
    monto: Dinero.deCentavos(centavos),
  );

  setUp(() async {
    baseDatos = await abrirBaseEnMemoria();
    repo = RepositorioCobrosIngresoSqlite(await baseDatos.abrir());
  });

  tearDown(() async => baseDatos.cerrar());

  group('porMes', () {
    test('un mes sin cobros devuelve lista vacía, no null', () async {
      expect(await repo.porMes(agosto), isEmpty);
    });

    test('devuelve los cobros del mes, de fecha ascendente (FR-008)', () async {
      await repo.insertar(
        cobro(centavos: 104000, fecha: DateTime(2026, 8, 30)),
      );
      await repo.insertar(cobro(centavos: 96000, fecha: DateTime(2026, 8, 15)));

      final cobros = await repo.porMes(agosto);
      expect(cobros, hasLength(2));
      expect(cobros.first.monto, const Dinero.deCentavos(96000));
      expect(cobros.last.monto, const Dinero.deCentavos(104000));
    });

    test('los meses no se mezclan entre sí', () async {
      await repo.insertar(
        cobro(centavos: 300000, fecha: DateTime(2026, 8, 10)),
      );
      await repo.insertar(
        cobro(centavos: 280000, fecha: DateTime(2026, 7, 10)),
      );

      expect(await repo.porMes(agosto), hasLength(1));
      expect(await repo.porMes(julio), hasLength(1));
    });

    test(
      'dos cobros de la misma fecha son válidos y se conservan ambos',
      () async {
        await repo.insertar(
          cobro(centavos: 96000, fecha: DateTime(2026, 8, 15)),
        );
        await repo.insertar(
          cobro(centavos: 104000, fecha: DateTime(2026, 8, 15)),
        );

        expect(await repo.porMes(agosto), hasLength(2));
      },
    );
  });

  group('insertar', () {
    test('devuelve el id asignado y persiste el monto exacto', () async {
      final id = await repo.insertar(cobro(centavos: 123456));
      expect(id, greaterThan(0));

      final guardado = (await repo.porMes(agosto)).single;
      expect(guardado.id, id);
      expect(guardado.monto, const Dinero.deCentavos(123456));
    });

    test('admite montos de siete cifras', () async {
      await repo.insertar(cobro(centavos: 999999999));
      expect(
        (await repo.porMes(agosto)).single.monto,
        const Dinero.deCentavos(999999999),
      );
    });
  });

  group('actualizar', () {
    test('corrige un cobro sin tocar los demás del mismo mes', () async {
      await repo.insertar(cobro(centavos: 96000, fecha: DateTime(2026, 8, 15)));
      final segundoId = await repo.insertar(
        cobro(centavos: 104000, fecha: DateTime(2026, 8, 30)),
      );

      await repo.actualizar(
        CobroIngreso(
          id: segundoId,
          fecha: DateTime(2026, 8, 30),
          monto: const Dinero.deCentavos(100000),
        ),
      );

      final cobros = await repo.porMes(agosto);
      expect(cobros, hasLength(2));
      expect(cobros.first.monto, const Dinero.deCentavos(96000));
      expect(cobros.last.monto, const Dinero.deCentavos(100000));
    });

    test('sin id lanza ArgumentError', () async {
      expect(() => repo.actualizar(cobro()), throwsArgumentError);
    });
  });

  group('eliminar', () {
    test('borra el cobro sin dejar rastro', () async {
      final id = await repo.insertar(cobro());
      await repo.eliminar(id);
      expect(await repo.porMes(agosto), isEmpty);
    });

    test('eliminar uno de dos deja el otro intacto', () async {
      final primerId = await repo.insertar(
        cobro(centavos: 96000, fecha: DateTime(2026, 8, 15)),
      );
      await repo.insertar(
        cobro(centavos: 104000, fecha: DateTime(2026, 8, 30)),
      );

      await repo.eliminar(primerId);

      final restantes = await repo.porMes(agosto);
      expect(restantes, hasLength(1));
      expect(restantes.single.monto, const Dinero.deCentavos(104000));
    });

    test('un id inexistente es no-op, no un error', () async {
      await expectLater(repo.eliminar(999), completes);
    });
  });
}
