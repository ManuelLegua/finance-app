import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/estado/estado_pendientes.dart';
import 'package:finanzas/ui/pantallas/captura/pantalla_pendientes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../dobles/repositorios_en_memoria.dart';

/// Reglas de presentación de la bandeja de pendientes (spec 002, FR-021,
/// FR-022, FR-023, FR-025, FR-028).
void main() {
  late RepositorioPendientesEnMemoria repoPendientes;
  late RepositorioTransaccionesEnMemoria repoTransacciones;
  late EstadoPendientes estado;

  ConsumoPendiente pendiente({
    required String notificacionId,
    int centavos = 4500,
    String comercio = 'Comercio de prueba',
    DateTime? fecha,
    Categoria? categoriaPropuesta,
  }) => ConsumoPendiente(
    id: null,
    origenPaquete: 'com.ejemplo.banco',
    notificacionId: notificacionId,
    monto: Dinero.deCentavos(centavos),
    comercio: comercio,
    fecha: fecha ?? DateTime(2026, 8, 10),
    categoriaPropuesta: categoriaPropuesta,
    capturadoEn: DateTime(2026, 8, 10, 12),
  );

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<EstadoPendientes>.value(
          value: estado,
          child: const PantallaPendientes(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repoPendientes = RepositorioPendientesEnMemoria();
    repoTransacciones = RepositorioTransaccionesEnMemoria();
    estado = EstadoPendientes(
      repoPendientes: repoPendientes,
      repoTransacciones: repoTransacciones,
    );
  });

  group('sin pendientes', () {
    testWidgets('invita a esperar, no muestra una lista vacía', (tester) async {
      await estado.cargar();
      await montar(tester);

      expect(
        find.textContaining('Nada esperando confirmación'),
        findsOneWidget,
      );
    });
  });

  group('orden y total (FR-021, FR-022)', () {
    testWidgets('lista del más reciente al más antiguo con el total', (
      tester,
    ) async {
      await repoPendientes.insertar(
        pendiente(
          notificacionId: 'a',
          comercio: 'Primero',
          fecha: DateTime(2026, 8, 1),
          centavos: 1000,
        ),
      );
      await repoPendientes.insertar(
        pendiente(
          notificacionId: 'b',
          comercio: 'Segundo',
          fecha: DateTime(2026, 8, 15),
          centavos: 2000,
        ),
      );
      await estado.cargar();
      await montar(tester);

      final titulos = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((fila) => (fila.title! as Text).data)
          .toList();
      expect(titulos, ['Segundo', 'Primero']);
      expect(find.text(r'S/ 30.00'), findsOneWidget);
      expect(find.text('2 consumos por confirmar'), findsOneWidget);
    });
  });

  group('confirmar de un toque (FR-023)', () {
    testWidgets('un pendiente con categoría se confirma sin abrir formulario', (
      tester,
    ) async {
      await repoPendientes.insertar(
        pendiente(notificacionId: 'a', categoriaPropuesta: Categoria.comida),
      );
      await estado.cargar();
      await montar(tester);

      await tester.tap(
        find.byWidgetPredicate((widget) => widget is PopupMenuButton),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(estado.pendientes, isEmpty);
      expect(await repoTransacciones.porMes(const Mes(2026, 8)), hasLength(1));
    });
  });

  group('descartar (FR-025)', () {
    testWidgets('pide confirmación antes de descartar', (tester) async {
      await repoPendientes.insertar(pendiente(notificacionId: 'a'));
      await estado.cargar();
      await montar(tester);

      await tester.tap(
        find.byWidgetPredicate((widget) => widget is PopupMenuButton),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Descartar este consumo?'), findsOneWidget);

      await tester.tap(find.text('Descartar').last);
      await tester.pumpAndSettle();

      expect(estado.pendientes, isEmpty);
      expect(await repoTransacciones.porMes(const Mes(2026, 8)), isEmpty);
    });
  });

  group('cantidad inusual (FR-028)', () {
    testWidgets('avisa con texto e ícono cuando hay demasiados', (
      tester,
    ) async {
      for (var i = 0; i < 21; i++) {
        await repoPendientes.insertar(pendiente(notificacionId: 'p$i'));
      }
      await estado.cargar();
      await montar(tester);

      expect(find.byIcon(Icons.event_busy_outlined), findsOneWidget);
      expect(find.textContaining('Son bastantes sin revisar'), findsOneWidget);
    });
  });
}
