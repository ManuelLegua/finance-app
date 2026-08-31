import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/repositorios/repositorio_asociaciones_sqlite.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helper_bd.dart';

/// Asociaciones comercio → categoría contra SQLite real (spec 002, FR-029 a
/// FR-034).
void main() {
  setUpAll(inicializarSqfliteFfi);

  late BaseDatos baseDatos;
  late RepositorioAsociacionesSqlite repo;

  setUp(() async {
    baseDatos = await abrirBaseEnMemoria();
    final conexion = await baseDatos.abrir();
    repo = RepositorioAsociacionesSqlite(conexion);
  });

  tearDown(() async => baseDatos.cerrar());

  group('categoriaDe (FR-030, FR-033)', () {
    test(
      'un comercio nunca visto es null, no una categoría por defecto',
      () async {
        expect(await repo.categoriaDe('TOTTUS'), isNull);
      },
    );

    test('un comercio asociado devuelve su categoría', () async {
      await repo.asociar('TOTTUS', Categoria.comida);
      expect(await repo.categoriaDe('TOTTUS'), Categoria.comida);
    });
  });

  group('asociar (FR-029, FR-031)', () {
    test(
      'sobre un comercio ya asociado reemplaza la categoría, no la duplica',
      () async {
        await repo.asociar('TOTTUS', Categoria.comida);
        await repo.asociar('TOTTUS', Categoria.otros);

        expect(await repo.categoriaDe('TOTTUS'), Categoria.otros);
        expect(await repo.todas(), hasLength(1));
      },
    );
  });

  group('todas (FR-034)', () {
    test('lista las asociaciones guardadas', () async {
      await repo.asociar('TOTTUS', Categoria.comida);
      await repo.asociar('UBER', Categoria.pasajes);

      final asociaciones = await repo.todas();
      expect(asociaciones, hasLength(2));
      expect(
        asociaciones.map((asociacion) => asociacion.comercioNormalizado),
        containsAll(['TOTTUS', 'UBER']),
      );
    });
  });

  group('eliminar (FR-034)', () {
    test('borra la asociación sin dejar rastro', () async {
      await repo.asociar('TOTTUS', Categoria.comida);

      await repo.eliminar('TOTTUS');

      expect(await repo.categoriaDe('TOTTUS'), isNull);
      expect(await repo.todas(), isEmpty);
    });

    test('un comercio inexistente es no-op, no un error', () async {
      await repo.eliminar('NUNCA_ASOCIADO');
      expect(await repo.todas(), isEmpty);
    });
  });
}
