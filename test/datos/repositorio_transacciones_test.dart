import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/repositorios/repositorio_transacciones_sqlite.dart';
import 'package:finanzas/dominio/modelos/transaccion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helper_bd.dart';

void main() {
  setUpAll(inicializarSqfliteFfi);

  late BaseDatos baseDatos;
  late RepositorioTransaccionesSqlite repo;

  const agosto = Mes(2026, 8);
  const julio = Mes(2026, 7);

  setUp(() async {
    baseDatos = await abrirBaseEnMemoria();
    repo = RepositorioTransaccionesSqlite(await baseDatos.abrir());
  });

  tearDown(() async => baseDatos.cerrar());

  Transaccion gasto({
    int dia = 15,
    int mes = 8,
    int centavos = 4500,
    Categoria categoria = Categoria.comida,
    String descripcion = 'Almuerzo',
    int? id,
  }) => Transaccion(
    id: id,
    fecha: DateTime(2026, mes, dia),
    categoria: categoria,
    monto: Dinero.deCentavos(centavos),
    descripcion: descripcion,
  );

  group('insertar y leer', () {
    test('devuelve el id asignado', () async {
      expect(await repo.insertar(gasto()), greaterThan(0));
    });

    test('porMes devuelve la transacción con todos sus campos', () async {
      await repo.insertar(gasto());
      final transacciones = await repo.porMes(agosto);

      expect(transacciones, hasLength(1));
      final registrada = transacciones.single;
      expect(registrada.monto, const Dinero.deCentavos(4500));
      expect(registrada.categoria, Categoria.comida);
      expect(registrada.descripcion, 'Almuerzo');
      expect(registrada.fecha, DateTime(2026, 8, 15));
      expect(registrada.id, isNotNull);
    });

    test('un mes sin gastos devuelve lista vacía', () async {
      expect(await repo.porMes(agosto), isEmpty);
    });

    test('la descripción puede quedar vacía', () async {
      await repo.insertar(gasto(descripcion: ''));
      expect((await repo.porMes(agosto)).single.descripcion, '');
    });

    test('el monto sobrevive exacto al centavo', () async {
      await repo.insertar(gasto(centavos: 123456));
      expect(
        (await repo.porMes(agosto)).single.monto,
        const Dinero.deCentavos(123456),
      );
    });
  });

  group('asignación al mes de la fecha (FR-008)', () {
    test(
      'un gasto se guarda en el mes de su fecha, no en el abierto',
      () async {
        await repo.insertar(gasto(mes: 7, dia: 31));

        expect(await repo.porMes(agosto), isEmpty);
        expect(await repo.porMes(julio), hasLength(1));
      },
    );

    test('el último día del mes pertenece a ese mes', () async {
      await repo.insertar(gasto(mes: 7, dia: 31));
      await repo.insertar(gasto(mes: 8, dia: 1));

      expect(await repo.porMes(julio), hasLength(1));
      expect(await repo.porMes(agosto), hasLength(1));
    });

    test('cambiar la fecha reubica la transacción de mes', () async {
      final id = await repo.insertar(gasto(mes: 8, dia: 15));
      await repo.actualizar(gasto(id: id, mes: 7, dia: 20));

      expect(await repo.porMes(agosto), isEmpty);
      expect(await repo.porMes(julio), hasLength(1));
    });
  });

  group('orden del listado (FR-013)', () {
    test('de la fecha más reciente a la más antigua', () async {
      await repo.insertar(gasto(dia: 3, descripcion: 'primero'));
      await repo.insertar(gasto(dia: 20, descripcion: 'tercero'));
      await repo.insertar(gasto(dia: 11, descripcion: 'segundo'));

      final descripciones = (await repo.porMes(agosto))
          .map((transaccion) => transaccion.descripcion)
          .toList();
      expect(descripciones, ['tercero', 'segundo', 'primero']);
    });

    test('dos gastos del mismo día ordenan por id descendente', () async {
      // Desempate estable: el último registrado aparece primero, que es lo
      // que el usuario acaba de anotar.
      await repo.insertar(gasto(dia: 10, descripcion: 'anterior'));
      await repo.insertar(gasto(dia: 10, descripcion: 'reciente'));

      expect((await repo.porMes(agosto)).first.descripcion, 'reciente');
    });
  });

  group('actualizar', () {
    test('cambia monto, categoría y descripción', () async {
      final id = await repo.insertar(gasto());
      await repo.actualizar(
        gasto(
          id: id,
          centavos: 5200,
          categoria: Categoria.pasajes,
          descripcion: 'Taxi',
        ),
      );

      final actualizada = (await repo.porMes(agosto)).single;
      expect(actualizada.monto, const Dinero.deCentavos(5200));
      expect(actualizada.categoria, Categoria.pasajes);
      expect(actualizada.descripcion, 'Taxi');
    });

    test('sin id es un error de programación', () async {
      await expectLater(
        repo.actualizar(gasto()),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('un id inexistente es no-op silencioso', () async {
      await expectLater(repo.actualizar(gasto(id: 999)), completes);
      expect(await repo.porMes(agosto), isEmpty);
    });
  });

  group('eliminar', () {
    test('quita la transacción del mes', () async {
      final id = await repo.insertar(gasto());
      await repo.eliminar(id);
      expect(await repo.porMes(agosto), isEmpty);
    });

    test('un id inexistente no falla', () async {
      await expectLater(repo.eliminar(999), completes);
    });
  });
}
