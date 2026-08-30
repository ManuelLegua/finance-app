import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/datos/repositorios/repositorio_ahorro_sqlite.dart';
import 'package:finanzas/dominio/modelos/aporte_ahorro.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../builders/aporte_ahorro_builder.dart';
import 'helper_bd.dart';

void main() {
  setUpAll(inicializarSqfliteFfi);

  late BaseDatos baseDatos;
  late RepositorioAhorroSqlite repositorio;

  const junio = Mes(2026, 6);
  const julio = Mes(2026, 7);
  const agosto = Mes(2026, 8);

  setUp(() async {
    baseDatos = await abrirBaseEnMemoria();
    final conexion = await baseDatos.abrir();
    repositorio = RepositorioAhorroSqlite(conexion);
  });

  tearDown(() async => baseDatos.cerrar());

  AporteAhorro aporte({int? id, DateTime? fecha, int montoCentavos = 30000}) =>
      AporteAhorroBuilder(
        id: id,
        fecha: fecha,
        centavos: montoCentavos,
      ).build();

  group('metas', () {
    test('metaDeMes distingue "sin meta" de una meta guardada', () async {
      expect(await repositorio.metaDeMes(agosto), isNull);

      await repositorio.guardarMeta(agosto, const Dinero.deCentavos(50000));
      expect(
        await repositorio.metaDeMes(agosto),
        const Dinero.deCentavos(50000),
      );
    });

    test('guardarMeta reemplaza la meta existente del mismo mes', () async {
      await repositorio.guardarMeta(agosto, const Dinero.deCentavos(50000));
      await repositorio.guardarMeta(agosto, const Dinero.deCentavos(70000));

      expect(
        await repositorio.metaDeMes(agosto),
        const Dinero.deCentavos(70000),
      );
    });

    test('eliminarMeta la deja sin meta de nuevo', () async {
      await repositorio.guardarMeta(agosto, const Dinero.deCentavos(50000));
      await repositorio.eliminarMeta(agosto);

      expect(await repositorio.metaDeMes(agosto), isNull);
    });

    test(
      'metasHasta devuelve en orden cronológico, hasta el mes inclusive',
      () async {
        await repositorio.guardarMeta(agosto, const Dinero.deCentavos(70000));
        await repositorio.guardarMeta(junio, const Dinero.deCentavos(30000));
        await repositorio.guardarMeta(julio, const Dinero.deCentavos(50000));

        final metas = await repositorio.metasHasta(julio);

        expect(metas, [
          (junio, const Dinero.deCentavos(30000)),
          (julio, const Dinero.deCentavos(50000)),
        ]);
      },
    );
  });

  group('aportes', () {
    test('aportesPorMes filtra por mes', () async {
      await repositorio.insertarAporte(aporte(fecha: DateTime(2026, 8, 5)));
      await repositorio.insertarAporte(aporte(fecha: DateTime(2026, 7, 20)));

      final deAgosto = await repositorio.aportesPorMes(agosto);
      expect(deAgosto, hasLength(1));
      expect(deAgosto.single.mes, agosto);
    });

    test(
      'acumuladoHistorico suma con SUM() entero, exacto al centavo',
      () async {
        await repositorio.insertarAporte(
          aporte(fecha: DateTime(2026, 6, 1), montoCentavos: 33333),
        );
        await repositorio.insertarAporte(
          aporte(fecha: DateTime(2026, 8, 1), montoCentavos: 66667),
        );

        expect(
          await repositorio.acumuladoHistorico(),
          const Dinero.deCentavos(100000),
        );
      },
    );

    test('acumuladoHistorico es cero sin ningún aporte', () async {
      expect(await repositorio.acumuladoHistorico(), Dinero.cero);
    });

    test('historialPorMes agrupa por mes dentro del rango', () async {
      await repositorio.insertarAporte(
        aporte(fecha: DateTime(2026, 6, 10), montoCentavos: 30000),
      );
      await repositorio.insertarAporte(
        aporte(fecha: DateTime(2026, 6, 20), montoCentavos: 20000),
      );
      await repositorio.insertarAporte(
        aporte(fecha: DateTime(2026, 8, 1), montoCentavos: 55000),
      );

      final historial = await repositorio.historialPorMes(junio, agosto);

      expect(historial, [
        (junio, const Dinero.deCentavos(50000)),
        (agosto, const Dinero.deCentavos(55000)),
      ]);
    });

    test('un mes sin aportes no aparece en historialPorMes', () async {
      // Los meses sin datos los completa el dominio, no el repositorio
      // (contracts/repositorios.md).
      final historial = await repositorio.historialPorMes(junio, agosto);
      expect(historial, isEmpty);
    });

    test('actualizarAporte cambia monto y fecha', () async {
      final id = await repositorio.insertarAporte(
        aporte(fecha: DateTime(2026, 8, 5), montoCentavos: 30000),
      );
      await repositorio.actualizarAporte(
        aporte(id: id, fecha: DateTime(2026, 7, 5), montoCentavos: 45000),
      );

      expect(await repositorio.aportesPorMes(agosto), isEmpty);
      final deJulio = await repositorio.aportesPorMes(julio);
      expect(deJulio.single.monto, const Dinero.deCentavos(45000));
    });

    test('actualizar sin id lanza ArgumentError', () async {
      expect(() => repositorio.actualizarAporte(aporte()), throwsArgumentError);
    });

    test('eliminarAporte lo quita del mes y del acumulado', () async {
      final id = await repositorio.insertarAporte(aporte(montoCentavos: 30000));
      await repositorio.eliminarAporte(id);

      expect(await repositorio.aportesPorMes(agosto), isEmpty);
      expect(await repositorio.acumuladoHistorico(), Dinero.cero);
    });
  });

  group('errores', () {
    test('un monto en cero es rechazado por el CHECK de la base', () async {
      await expectLater(
        repositorio.insertarAporte(aporte(montoCentavos: 0)),
        throwsA(isA<ErrorPersistencia>()),
      );
    });
  });
}
