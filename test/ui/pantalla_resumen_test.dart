import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/estado/estado_ahorro.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/pantallas/resumen_mes/pantalla_resumen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../builders/obligacion_builder.dart';
import '../dobles/repositorios_en_memoria.dart';

/// Reglas de presentación del resumen del mes (HU2).
void main() {
  late RepositorioIngresoEnMemoria repoIngreso;
  late RepositorioObligacionesEnMemoria repoObligaciones;
  late EstadoMes estado;
  late EstadoAhorro estadoAhorro;

  const agosto = Mes(2026, 8);
  final quinceDeAgosto = DateTime(2026, 8, 15);

  EstadoMes crearEstado({Mes mes = agosto}) => EstadoMes(
    repoIngreso: repoIngreso,
    repoObligaciones: repoObligaciones,
    repoConfiguracion: RepositorioConfiguracionEnMemoria(),
    repoTransacciones: RepositorioTransaccionesEnMemoria(),
    repoDeudas: RepositorioDeudasEnMemoria(),
    ahora: () => quinceDeAgosto,
    mesInicial: mes,
  );

  Obligacion obligacionDe(int centavos, {Mes mes = agosto}) =>
      ObligacionBuilder(mes: mes, centavos: centavos).build();

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<EstadoMes>.value(value: estado),
              ChangeNotifierProvider<EstadoAhorro>.value(value: estadoAhorro),
            ],
            child: const PantallaResumen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repoIngreso = RepositorioIngresoEnMemoria();
    repoObligaciones = RepositorioObligacionesEnMemoria();
    estadoAhorro = EstadoAhorro(
      repoAhorro: RepositorioAhorroEnMemoria(),
      repoConfiguracion: RepositorioConfiguracionEnMemoria(),
      ahora: () => quinceDeAgosto,
    );
  });

  group('caso normal', () {
    testWidgets('muestra ingreso, comprometido y disponible', (tester) async {
      await repoIngreso.guardar(agosto, const Dinero.deCentavos(300000));
      await repoObligaciones.insertar(obligacionDe(180000));
      estado = crearEstado();
      await estado.cargar();
      await montar(tester);

      // El ingreso aparece dos veces: como ingreso y como disponible real,
      // que sin gastos registrados vale lo mismo.
      expect(find.text(r'S/ 3,000.00'), findsNWidgets(2));
      expect(find.text(r'S/ 1,800.00'), findsOneWidget);
      // El disponible también: destacado arriba y en el desglose.
      expect(find.text(r'S/ 1,200.00'), findsNWidgets(2));
      expect(find.text('Disponible este mes'), findsOneWidget);
    });
  });

  group('déficit (FR-028, FR-029)', () {
    testWidgets('se comunica con texto e ícono, no solo con color', (
      tester,
    ) async {
      await repoIngreso.guardar(agosto, const Dinero.deCentavos(200000));
      await repoObligaciones.insertar(obligacionDe(235000));
      estado = crearEstado();
      await estado.cargar();
      await montar(tester);

      // El mensaje se lee sin distinguir colores.
      expect(find.text('Tus compromisos superan tu ingreso'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      // Y dice el faltante exacto.
      expect(find.textContaining(r'S/ 350.00'), findsWidgets);
      expect(find.text('Te falta'), findsOneWidget);
    });
  });

  group('límite: saldo exactamente cero (FR-030)', () {
    testWidgets('no se reporta como déficit', (tester) async {
      await repoIngreso.guardar(agosto, const Dinero.deCentavos(300000));
      await repoObligaciones.insertar(obligacionDe(300000));
      estado = crearEstado();
      await estado.cargar();
      await montar(tester);

      expect(find.text('Tus compromisos superan tu ingreso'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.text('Disponible este mes'), findsOneWidget);
      // El disponible en cero se muestra, y no se declara déficit: es
      // exactamente lo que exige FR-030. La cantidad de ceros en pantalla
      // depende de cuántas categorías haya, así que no se cuenta.
      expect(find.text(r'S/ 0.00'), findsWidgets);
    });
  });

  group('mes sin ingreso (HU2 escenario 4)', () {
    testWidgets('pide registrarlo en vez de mostrar totales en cero', (
      tester,
    ) async {
      await repoObligaciones.insertar(obligacionDe(90000));
      estado = crearEstado();
      await estado.cargar();
      await montar(tester);

      expect(find.text('Falta registrar tu ingreso'), findsOneWidget);
      // No se muestra un disponible que sería engañoso.
      expect(find.text('Disponible este mes'), findsNothing);
      // Los totales que dependen del ingreso salen como ausentes, no en cero.
      expect(find.text('sin registrar'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
    });
  });

  group('selector de mes', () {
    testWidgets('muestra el mes en curso y permite navegar', (tester) async {
      estado = crearEstado();
      await estado.cargar();
      await montar(tester);

      expect(find.text('Agosto 2026'), findsOneWidget);

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();

      expect(find.text('Julio 2026'), findsOneWidget);
    });

    testWidgets('rotula con texto que un mes pasado está cerrado', (
      tester,
    ) async {
      estado = crearEstado(mes: const Mes(2026, 5));
      await estado.cargar();
      await montar(tester);

      expect(find.text('Mes cerrado · solo lectura'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  group('disponible real (FR-027)', () {
    testWidgets('sin gastos registrados iguala al ingreso', (tester) async {
      await repoIngreso.guardar(agosto, const Dinero.deCentavos(300000));
      await repoObligaciones.insertar(obligacionDe(180000));
      estado = crearEstado();
      await estado.cargar();
      await montar(tester);

      expect(find.text('Disponible real'), findsOneWidget);
      expect(find.text('Gasto real'), findsOneWidget);
      // Ingreso y disponible real coinciden hasta que US3 registre gastos.
      expect(find.text(r'S/ 3,000.00'), findsNWidgets(2));
    });
  });
}
