import 'package:finanzas/dominio/modelos/configuracion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/pantallas/presupuesto/pantalla_presupuesto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../dobles/repositorios_en_memoria.dart';

/// Reglas de presentación de la pantalla de presupuesto (HU1).
///
/// Usa dobles en memoria y no SQLite: `sqflite_common_ffi` no completa dentro
/// del reloj falso de `testWidgets` y la prueba se colgaría en vez de fallar.
/// Lo que se verifica acá es cómo se ve la pantalla dado un estado, no cómo se
/// guarda — eso lo cubre `test/datos/` contra la base real.
void main() {
  late RepositorioIngresoEnMemoria repoIngreso;
  late RepositorioObligacionesEnMemoria repoObligaciones;
  late EstadoMes estado;

  const agosto = Mes(2026, 8);
  final quinceDeAgosto = DateTime(2026, 8, 15);

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<EstadoMes>.value(
          value: estado,
          child: const PantallaPresupuesto(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    repoIngreso = RepositorioIngresoEnMemoria();
    repoObligaciones = RepositorioObligacionesEnMemoria();
    estado = EstadoMes(
      repoIngreso: repoIngreso,
      repoObligaciones: repoObligaciones,
      repoConfiguracion: RepositorioConfiguracionEnMemoria(),
      repoTransacciones: RepositorioTransaccionesEnMemoria(),
      ahora: () => quinceDeAgosto,
      mesInicial: agosto,
    );
    await estado.cargar();
  });

  group('ingreso', () {
    testWidgets('un mes sin ingreso lo pide en vez de mostrar S/ 0.00', (
      tester,
    ) async {
      await montar(tester);

      expect(
        find.text('Todavía no registraste tu sueldo de este mes.'),
        findsOneWidget,
      );
      expect(find.text('Registrar'), findsOneWidget);
      // El comprometido sí vale S/ 0.00 y se muestra: lo que no puede pasar
      // es que el ingreso ausente se presente como un sueldo de S/ 0.00
      // (HU2 escenario 4).
      expect(find.text('Comprometido'), findsOneWidget);
      expect(find.text(r'S/ 0.00'), findsOneWidget);
    });

    testWidgets('con ingreso registrado lo muestra formateado', (tester) async {
      await estado.guardarIngreso(const Dinero.deCentavos(300000));
      await montar(tester);

      expect(find.text(r'S/ 3,000.00'), findsOneWidget);
      expect(find.text('Corregir'), findsOneWidget);
    });
  });

  group('validación de montos (FR-005)', () {
    Future<void> abrirFormulario(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Obligación'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre').first,
        'Alquiler',
      );
    }

    testWidgets('un monto vacío se rechaza y no guarda nada', (tester) async {
      await montar(tester);
      await abrirFormulario(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();

      expect(find.text('Escribí un monto.'), findsOneWidget);
      expect(estado.obligaciones, isEmpty);
    });

    testWidgets('un monto en cero se rechaza', (tester) async {
      await montar(tester);
      await abrirFormulario(tester);

      await tester.enterText(find.byType(TextFormField).last, '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();

      expect(estado.obligaciones, isEmpty);
    });

    testWidgets('un monto válido se guarda y aparece en la lista', (
      tester,
    ) async {
      await montar(tester);
      await abrirFormulario(tester);

      await tester.enterText(find.byType(TextFormField).last, '900.00');
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();

      expect(estado.obligaciones, hasLength(1));
      expect(find.text('Alquiler'), findsOneWidget);
      expect(find.text(r'S/ 900.00'), findsWidgets);
    });
  });

  group('categorías', () {
    testWidgets('tarjeta de crédito no aparece entre las elegibles', (
      tester,
    ) async {
      // Ese compromiso lo derivan las deudas: registrarlo a mano duplicaría
      // el monto del presupuesto (D3).
      await montar(tester);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Obligación'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<Categoria>));
      await tester.pumpAndSettle();

      expect(find.text('Tarjeta de crédito'), findsNothing);
      expect(find.text('Departamento'), findsWidgets);
      expect(find.text('Comida'), findsWidgets);
    });
  });

  group('mes cerrado', () {
    testWidgets('no ofrece acciones de escritura y explica por qué', (
      tester,
    ) async {
      await estado.irAMes(const Mes(2026, 5));
      await montar(tester);

      expect(find.text('Mes cerrado'), findsOneWidget);
      expect(
        find.widgetWithText(FloatingActionButton, 'Obligación'),
        findsNothing,
      );
      expect(find.text('Registrar'), findsNothing);
      // La restricción se comunica con texto e ícono, no solo deshabilitando
      // controles ni con color (FR-058).
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  group('errores de persistencia', () {
    testWidgets('un fallo al guardar se muestra, no se traga', (tester) async {
      repoObligaciones.errorEnLaProximaEscritura = Exception('disco lleno');
      await montar(tester);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Obligación'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre').first,
        'Alquiler',
      );
      await tester.enterText(find.byType(TextFormField).last, '900.00');
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ocurrió un problema'), findsOneWidget);
      expect(estado.obligaciones, isEmpty);
    });
  });

  group('días de gracia configurables', () {
    testWidgets('con la ventana abierta, el mes anterior admite registrar', (
      tester,
    ) async {
      final tresDeAgosto = DateTime(2026, 8, 3);
      estado = EstadoMes(
        repoIngreso: RepositorioIngresoEnMemoria(),
        repoObligaciones: RepositorioObligacionesEnMemoria(),
        repoConfiguracion: RepositorioConfiguracionEnMemoria(
          Configuracion.porDefecto.copiarCon(diasGraciaCierre: 5),
        ),
        repoTransacciones: RepositorioTransaccionesEnMemoria(),
        ahora: () => tresDeAgosto,
        mesInicial: const Mes(2026, 7),
      );
      await estado.cargar();
      await montar(tester);

      expect(find.text('Plazo para pagos rezagados'), findsOneWidget);
      expect(
        find.widgetWithText(FloatingActionButton, 'Obligación'),
        findsOneWidget,
      );
    });
  });
}
