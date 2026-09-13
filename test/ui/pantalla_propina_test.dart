import 'dart:async';

import 'package:finanzas/ui/estado/estado_propinas.dart';
import 'package:finanzas/ui/pantallas/propina/pantalla_propina.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../dobles/repositorios_en_memoria.dart';

/// La pantalla de apoyo (US2 y US3, spec 004 revisada).
///
/// Lo que se fija acá es lo que separa una propina de un paywall: que diga que
/// no desbloquea nada (FR-005), que no invente precios (FR-004, FR-011) y que
/// cancelar no produzca ningún reproche (FR-008).
void main() {
  late RepositorioPropinasEnMemoria repoPropinas;
  late EstadoPropinas estadoPropinas;

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<EstadoPropinas>.value(
        value: estadoPropinas,
        child: const MaterialApp(home: PantallaPropina()),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repoPropinas = RepositorioPropinasEnMemoria();
    estadoPropinas = EstadoPropinas(repoPropinas: repoPropinas);
  });

  group('los montos y lo que se dice de ellos', () {
    testWidgets('muestra cada monto con el precio que informa la tienda', (
      tester,
    ) async {
      await estadoPropinas.cargar();
      await montar(tester);

      expect(find.text('Un café'), findsOneWidget);
      expect(find.text('S/ 5.00'), findsOneWidget);
      expect(find.text('Un menú'), findsOneWidget);
      expect(find.text('S/ 15.00'), findsOneWidget);
    });

    testWidgets('dice que apoyar no desbloquea nada (FR-005)', (tester) async {
      await estadoPropinas.cargar();
      await montar(tester);

      expect(
        find.textContaining('no desbloquea ninguna funcionalidad'),
        findsOneWidget,
      );
    });

    testWidgets('sin tienda no muestra ningún precio y ofrece reintentar', (
      tester,
    ) async {
      repoPropinas.hayTienda = false;
      await estadoPropinas.cargar();
      await montar(tester);

      // Lo importante no es solo que aparezca el aviso, sino que **no** haya
      // quedado un precio viejo en pantalla (FR-011, SC-005).
      expect(find.textContaining('No pudimos consultar los montos'), findsOne);
      expect(find.text('S/ 5.00'), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('reintentar vuelve a consultar y muestra los montos', (
      tester,
    ) async {
      repoPropinas.hayTienda = false;
      await estadoPropinas.cargar();
      await montar(tester);

      repoPropinas.hayTienda = true;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('S/ 5.00'), findsOneWidget);
      expect(find.textContaining('No pudimos consultar'), findsNothing);
    });
  });

  group('apoyar', () {
    testWidgets('completar una compra agradece (FR-012)', (tester) async {
      await estadoPropinas.cargar();
      await montar(tester);

      await tester.tap(find.text('Apoyar').first);
      await tester.pumpAndSettle();

      expect(find.text('¡Gracias!'), findsOneWidget);
      expect(repoPropinas.apoyos.single.id, 'propina_cafe');
    });

    testWidgets('cancelar no muestra ningún error (FR-008)', (tester) async {
      repoPropinas.resultadoDeApoyar = ResultadoPropina.cancelada;
      await estadoPropinas.cargar();
      await montar(tester);

      await tester.tap(find.text('Apoyar').first);
      await tester.pumpAndSettle();

      // Ni agradecimiento ni reproche: el usuario cerró un diálogo y no pasó
      // nada. Los montos siguen ahí para cuando quiera.
      expect(find.text('¡Gracias!'), findsNothing);
      expect(find.textContaining('No se pudo completar'), findsNothing);
      expect(find.text('S/ 5.00'), findsOneWidget);
    });

    testWidgets('una compra rechazada explica el motivo y deja reintentar', (
      tester,
    ) async {
      repoPropinas.resultadoDeApoyar = ResultadoPropina.fallida;
      await estadoPropinas.cargar();
      await montar(tester);

      await tester.tap(find.text('Apoyar').first);
      await tester.pumpAndSettle();

      expect(find.text('No se pudo completar'), findsOneWidget);
      expect(find.text('Apoyar'), findsWidgets);
    });

    testWidgets('mientras Google confirma, ningún botón acepta otro toque', (
      tester,
    ) async {
      final confirmacion = Completer<void>();
      repoPropinas.confirmacionPendiente = confirmacion;
      await estadoPropinas.cargar();
      await montar(tester);

      await tester.tap(find.text('Apoyar').first);
      await tester.pump();

      expect(
        find.textContaining('Confirmando con Google Play'),
        findsOneWidget,
      );

      // El segundo toque no puede disparar una segunda compra: es plata real.
      await tester.tap(find.text('Apoyar').last, warnIfMissed: false);
      await tester.pump();
      expect(repoPropinas.vecesQueSeApoyo, 1);

      confirmacion.complete();
      await tester.pumpAndSettle();
      expect(find.text('¡Gracias!'), findsOneWidget);
    });

    testWidgets('se puede apoyar de nuevo después de agradecer (FR-007)', (
      tester,
    ) async {
      await estadoPropinas.cargar();
      await montar(tester);

      await tester.tap(find.text('Apoyar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();

      expect(find.text('¡Gracias!'), findsNothing);

      await tester.tap(find.text('Apoyar').first);
      await tester.pumpAndSettle();

      expect(repoPropinas.vecesQueSeApoyo, 2);
    });
  });
}
