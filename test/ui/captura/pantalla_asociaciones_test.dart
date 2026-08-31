import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/ui/estado/estado_asociaciones.dart';
import 'package:finanzas/ui/pantallas/captura/pantalla_asociaciones.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../dobles/repositorios_en_memoria.dart';

/// Consultar, corregir y eliminar asociaciones aprendidas (spec 002, FR-034).
void main() {
  late RepositorioAsociacionesEnMemoria repoAsociaciones;
  late EstadoAsociaciones estado;

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<EstadoAsociaciones>.value(
          value: estado,
          child: const PantallaAsociaciones(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repoAsociaciones = RepositorioAsociacionesEnMemoria();
    estado = EstadoAsociaciones(repoAsociaciones: repoAsociaciones);
  });

  testWidgets('sin asociaciones comunica que todavía no aprendió nada', (
    tester,
  ) async {
    await estado.cargar();
    await montar(tester);

    expect(find.text('Todavía no aprendió ningún comercio'), findsOneWidget);
  });

  testWidgets('lista el comercio y la categoría de cada asociación', (
    tester,
  ) async {
    await repoAsociaciones.asociar('TOTTUS', Categoria.comida);
    await estado.cargar();
    await montar(tester);

    expect(find.text('TOTTUS'), findsOneWidget);
    expect(find.text('Comida'), findsOneWidget);
  });

  testWidgets('corregir la categoría la reemplaza sin duplicar la fila', (
    tester,
  ) async {
    await repoAsociaciones.asociar('TOTTUS', Categoria.comida);
    await estado.cargar();
    await montar(tester);

    await tester.tap(find.text('TOTTUS'));
    await tester.pumpAndSettle();
    expect(find.text('Corregir categoría'), findsOneWidget);

    await tester.tap(find.text('Comida').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otros').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(await repoAsociaciones.categoriaDe('TOTTUS'), Categoria.otros);
    expect(find.text('Otros'), findsOneWidget);
    expect(find.text('Comida'), findsNothing);
  });

  testWidgets('eliminar pide confirmación y borra la asociación (FR-034)', (
    tester,
  ) async {
    await repoAsociaciones.asociar('TOTTUS', Categoria.comida);
    await estado.cargar();
    await montar(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('¿Olvidar esta asociación?'), findsOneWidget);

    await tester.tap(find.text('Olvidar'));
    await tester.pumpAndSettle();

    expect(estado.asociaciones, isEmpty);
    expect(find.text('Todavía no aprendió ningún comercio'), findsOneWidget);
  });

  testWidgets('un fallo al eliminar se muestra, no se traga en silencio', (
    tester,
  ) async {
    await repoAsociaciones.asociar('TOTTUS', Categoria.comida);
    await estado.cargar();
    await montar(tester);

    repoAsociaciones.errorEnLaProximaEscritura = Exception('disco lleno');
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Olvidar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ocurrió un problema'), findsOneWidget);
    // No se perdió la asociación: el fallo no se tragó en silencio.
    expect(estado.asociaciones, hasLength(1));
  });
}
