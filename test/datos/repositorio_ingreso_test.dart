import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/repositorios/repositorio_ingreso_sqlite.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helper_bd.dart';

void main() {
  setUpAll(inicializarSqfliteFfi);

  late BaseDatos baseDatos;
  late RepositorioIngresoSqlite repo;

  const agosto = Mes(2026, 8);
  const julio = Mes(2026, 7);

  setUp(() async {
    baseDatos = await abrirBaseEnMemoria();
    repo = RepositorioIngresoSqlite(await baseDatos.abrir());
  });

  tearDown(() async => baseDatos.cerrar());

  group('obtener', () {
    test('un mes sin ingreso devuelve null, no cero', () async {
      // Distinción central: "no registrado" no es "gana S/ 0.00". La app pide
      // registrar el ingreso en vez de mostrar totales en cero como válidos
      // (HU2 escenario 4).
      expect(await repo.obtener(agosto), isNull);
    });

    test('devuelve el monto guardado', () async {
      await repo.guardar(agosto, const Dinero.deCentavos(300000));
      expect(await repo.obtener(agosto), const Dinero.deCentavos(300000));
    });

    test('los meses no se pisan entre sí', () async {
      await repo.guardar(agosto, const Dinero.deCentavos(300000));
      await repo.guardar(julio, const Dinero.deCentavos(280000));

      expect(await repo.obtener(agosto), const Dinero.deCentavos(300000));
      expect(await repo.obtener(julio), const Dinero.deCentavos(280000));
    });
  });

  group('guardar', () {
    test('reemplaza el ingreso del mes en vez de duplicarlo', () async {
      await repo.guardar(agosto, const Dinero.deCentavos(300000));
      await repo.guardar(agosto, const Dinero.deCentavos(320000));

      expect(await repo.obtener(agosto), const Dinero.deCentavos(320000));
      expect(await repo.mesesConIngreso(), hasLength(1));
    });

    test('persiste el monto exacto al centavo', () async {
      await repo.guardar(agosto, const Dinero.deCentavos(123456));
      expect(await repo.obtener(agosto), const Dinero.deCentavos(123456));
    });

    test('admite montos de siete cifras', () async {
      await repo.guardar(agosto, const Dinero.deCentavos(999999999));
      expect(await repo.obtener(agosto), const Dinero.deCentavos(999999999));
    });
  });

  group('eliminar', () {
    test('deja el mes como no registrado', () async {
      await repo.guardar(agosto, const Dinero.deCentavos(300000));
      await repo.eliminar(agosto);
      expect(await repo.obtener(agosto), isNull);
    });

    test('eliminar un mes sin ingreso no falla', () async {
      // No-op silencioso: el usuario ya no ve ese registro.
      await expectLater(repo.eliminar(agosto), completes);
    });
  });

  group('mesesConIngreso', () {
    test('devuelve los meses en orden cronológico', () async {
      await repo.guardar(agosto, const Dinero.deCentavos(300000));
      await repo.guardar(const Mes(2026, 6), const Dinero.deCentavos(280000));
      await repo.guardar(julio, const Dinero.deCentavos(290000));

      expect(await repo.mesesConIngreso(), const [
        Mes(2026, 6),
        Mes(2026, 7),
        Mes(2026, 8),
      ]);
    });

    test('sin ingresos devuelve lista vacía', () async {
      expect(await repo.mesesConIngreso(), isEmpty);
    });
  });
}
