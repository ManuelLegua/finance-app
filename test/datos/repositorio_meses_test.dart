import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/repositorios/repositorio_cobros_ingreso_sqlite.dart';
import 'package:finanzas/datos/repositorios/repositorio_meses_sqlite.dart';
import 'package:finanzas/dominio/modelos/cobro_ingreso.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helper_bd.dart';

/// `RepositorioMeses` no tenía ninguna prueba propia hasta ahora — se agrega
/// junto con el cambio de fuente de la spec 003 (D-C6: la unión pasa de
/// `ingreso` a `cobro_ingreso`).
void main() {
  setUpAll(inicializarSqfliteFfi);

  late BaseDatos baseDatos;
  late RepositorioMesesSqlite repoMeses;
  late RepositorioCobrosIngresoSqlite repoCobros;

  setUp(() async {
    baseDatos = await abrirBaseEnMemoria();
    final conexion = await baseDatos.abrir();
    repoMeses = RepositorioMesesSqlite(conexion);
    repoCobros = RepositorioCobrosIngresoSqlite(conexion);
  });

  tearDown(() async => baseDatos.cerrar());

  group('mesesRegistrados', () {
    test('sin datos devuelve lista vacía', () async {
      expect(await repoMeses.mesesRegistrados(), isEmpty);
    });

    test('un mes con cobros de ingreso cuenta como mes con datos', () async {
      await repoCobros.insertar(
        CobroIngreso(
          id: null,
          fecha: DateTime(2026, 8, 15),
          monto: const Dinero.deCentavos(200000),
        ),
      );

      expect(await repoMeses.mesesRegistrados(), const [Mes(2026, 8)]);
    });

    test('no duplica un mes con más de un cobro', () async {
      await repoCobros.insertar(
        CobroIngreso(
          id: null,
          fecha: DateTime(2026, 8, 15),
          monto: const Dinero.deCentavos(96000),
        ),
      );
      await repoCobros.insertar(
        CobroIngreso(
          id: null,
          fecha: DateTime(2026, 8, 30),
          monto: const Dinero.deCentavos(104000),
        ),
      );

      expect(await repoMeses.mesesRegistrados(), const [Mes(2026, 8)]);
    });
  });

  group('tieneDatos', () {
    test('un mes con un cobro de ingreso tiene datos', () async {
      await repoCobros.insertar(
        CobroIngreso(
          id: null,
          fecha: DateTime(2026, 8, 15),
          monto: const Dinero.deCentavos(200000),
        ),
      );

      expect(await repoMeses.tieneDatos(const Mes(2026, 8)), isTrue);
    });

    test('un mes sin nada devuelve false', () async {
      expect(await repoMeses.tieneDatos(const Mes(2026, 8)), isFalse);
    });
  });
}
