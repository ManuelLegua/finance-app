import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/datos/repositorios/repositorio_obligaciones.dart';
import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helper_bd.dart';

void main() {
  setUpAll(inicializarSqfliteFfi);

  late BaseDatos bd;
  late RepositorioObligaciones repo;

  const agosto = Mes(2026, 8);
  const julio = Mes(2026, 7);

  setUp(() async {
    bd = await abrirBaseEnMemoria();
    repo = RepositorioObligaciones(await bd.abrir());
  });

  tearDown(() async => bd.cerrar());

  Obligacion crear({
    Mes mes = agosto,
    String nombre = 'Alquiler',
    Categoria categoria = Categoria.departamento,
    int centavos = 90000,
    TipoObligacion tipo = TipoObligacion.fija,
    int? id,
  }) =>
      Obligacion(
        id: id,
        mes: mes,
        nombre: nombre,
        categoria: categoria,
        monto: Dinero.deCentavos(centavos),
        tipo: tipo,
      );

  group('insertar y leer', () {
    test('devuelve el id asignado', () async {
      final id = await repo.insertar(crear());
      expect(id, greaterThan(0));
    });

    test('porMes devuelve lo guardado con todos sus campos', () async {
      await repo.insertar(crear());
      final obligaciones = await repo.porMes(agosto);

      expect(obligaciones, hasLength(1));
      final o = obligaciones.single;
      expect(o.nombre, 'Alquiler');
      expect(o.categoria, Categoria.departamento);
      expect(o.monto, const Dinero.deCentavos(90000));
      expect(o.tipo, TipoObligacion.fija);
      expect(o.mes, agosto);
      expect(o.id, isNotNull);
    });

    test('porMes no mezcla meses', () async {
      await repo.insertar(crear(mes: agosto, nombre: 'Alquiler agosto'));
      await repo.insertar(crear(mes: julio, nombre: 'Alquiler julio'));

      expect((await repo.porMes(agosto)).single.nombre, 'Alquiler agosto');
      expect((await repo.porMes(julio)).single.nombre, 'Alquiler julio');
    });

    test('un mes sin obligaciones devuelve lista vacía', () async {
      expect(await repo.porMes(agosto), isEmpty);
    });

    test('el monto sobrevive exacto al centavo', () async {
      await repo.insertar(crear(centavos: 123456));
      expect((await repo.porMes(agosto)).single.monto,
          const Dinero.deCentavos(123456));
    });
  });

  group('fijasDeMes', () {
    test('devuelve solo las fijas, insumo de la precarga', () async {
      await repo.insertar(crear(nombre: 'Alquiler', tipo: TipoObligacion.fija));
      await repo.insertar(
        crear(nombre: 'Comida', tipo: TipoObligacion.variable),
      );

      final fijas = await repo.fijasDeMes(agosto);
      expect(fijas, hasLength(1));
      expect(fijas.single.nombre, 'Alquiler');
    });
  });

  group('actualizar', () {
    test('cambia el monto y los totales se releen recalculados', () async {
      final id = await repo.insertar(crear(centavos: 90000));
      await repo.actualizar(crear(id: id, centavos: 95000));

      expect((await repo.porMes(agosto)).single.monto,
          const Dinero.deCentavos(95000));
    });

    test('cambia nombre, categoría y tipo', () async {
      final id = await repo.insertar(crear());
      await repo.actualizar(crear(
        id: id,
        nombre: 'Internet',
        categoria: Categoria.servicios,
        tipo: TipoObligacion.variable,
      ));

      final o = (await repo.porMes(agosto)).single;
      expect(o.nombre, 'Internet');
      expect(o.categoria, Categoria.servicios);
      expect(o.tipo, TipoObligacion.variable);
    });

    test('actualizar sin id es un error de programación', () async {
      await expectLater(
        repo.actualizar(crear()),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('actualizar un id inexistente es no-op silencioso', () async {
      await expectLater(repo.actualizar(crear(id: 999)), completes);
      expect(await repo.porMes(agosto), isEmpty);
    });
  });

  group('eliminar', () {
    test('quita la obligación del mes', () async {
      final id = await repo.insertar(crear());
      await repo.eliminar(id);
      expect(await repo.porMes(agosto), isEmpty);
    });

    test('eliminar un id inexistente no falla', () async {
      await expectLater(repo.eliminar(999), completes);
    });
  });

  group('insertarLote', () {
    test('inserta todas las obligaciones de la precarga', () async {
      await repo.insertarLote([
        crear(nombre: 'Alquiler'),
        crear(nombre: 'Luz', categoria: Categoria.servicios, centavos: 12000),
        crear(nombre: 'Agua', categoria: Categoria.servicios, centavos: 5000),
      ]);

      expect(await repo.porMes(agosto), hasLength(3));
    });

    test('es atómico: si una falla no entra ninguna', () async {
      // FR-006: la precarga confirma un conjunto. Media precarga guardada
      // dejaría al usuario con un presupuesto que no revisó.
      await expectLater(
        repo.insertarLote([
          crear(nombre: 'Alquiler'),
          crear(nombre: '   '), // viola el CHECK de nombre no vacío
        ]),
        throwsA(isA<ErrorPersistencia>()),
      );

      expect(await repo.porMes(agosto), isEmpty);
    });

    test('un lote vacío no hace nada', () async {
      await expectLater(repo.insertarLote(const []), completes);
      expect(await repo.porMes(agosto), isEmpty);
    });
  });
}
