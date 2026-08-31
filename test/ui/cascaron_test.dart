import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/cascaron.dart';
import 'package:finanzas/ui/estado/estado_ahorro.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/estado/estado_suscripcion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../dobles/repositorios_en_memoria.dart';

/// Navegación del cascarón (D16): barra inferior para lo frecuente, drawer
/// para lo ocasional.
void main() {
  late EstadoMes estado;
  late EstadoAhorro estadoAhorro;
  late RepositorioConfiguracionEnMemoria repoConfiguracion;
  late EstadoSuscripcionPremium estadoSuscripcion;

  const agosto = Mes(2026, 8);
  final quinceDeAgosto = DateTime(2026, 8, 15);

  Future<void> montar(WidgetTester tester) async {
    // Un alto generoso evita que el ListView de las pantallas desborde y
    // ensucie la prueba con errores de layout ajenos a la navegación.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<RepositorioConfiguracion>.value(value: repoConfiguracion),
          ChangeNotifierProvider<EstadoMes>.value(value: estado),
          ChangeNotifierProvider<EstadoAhorro>.value(value: estadoAhorro),
          ChangeNotifierProvider<EstadoSuscripcionPremium>.value(
            value: estadoSuscripcion,
          ),
        ],
        child: const MaterialApp(home: Cascaron()),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    repoConfiguracion = RepositorioConfiguracionEnMemoria();
    estado = EstadoMes(
      repoCobrosIngreso: RepositorioCobrosIngresoEnMemoria(),
      repoObligaciones: RepositorioObligacionesEnMemoria(),
      repoConfiguracion: repoConfiguracion,
      repoTransacciones: RepositorioTransaccionesEnMemoria(),
      repoDeudas: RepositorioDeudasEnMemoria(),
      ahora: () => quinceDeAgosto,
      mesInicial: agosto,
    );
    await estado.cargar();
    estadoAhorro = EstadoAhorro(
      repoAhorro: RepositorioAhorroEnMemoria(),
      repoConfiguracion: repoConfiguracion,
      ahora: () => quinceDeAgosto,
    );
    await estadoAhorro.cargar(agosto);
    // Estas pruebas son de navegación, no de la suscripción: con una vigente,
    // Deudas y Ahorro muestran su pantalla real y no el paywall de la spec
    // 004, que tiene sus propias pruebas en `pantalla_paywall_test.dart`.
    estadoSuscripcion = EstadoSuscripcionPremium(
      repoSuscripcion: RepositorioSuscripcionEnMemoria(
        inicial: EstadoSuscripcion(
          situacion: SituacionSuscripcion.activa,
          plan: PlanSuscripcion.mensual,
          vigenteHasta: null,
          ultimaVerificacion: quinceDeAgosto,
        ),
      ),
    );
    await estadoSuscripcion.cargar();
  });

  group('barra inferior', () {
    testWidgets('muestra exactamente cinco destinos', (tester) async {
      await montar(tester);

      // Material 3 admite de tres a cinco; con seis, "Presupuesto" se partía
      // en dos líneas en una pantalla de 1080 px (D16).
      expect(find.byType(NavigationDestination), findsNWidgets(5));
    });

    testWidgets('las etiquetas frecuentes están presentes', (tester) async {
      await montar(tester);

      for (final etiqueta in [
        'Resumen',
        'Presupuesto',
        'Gastos',
        'Deudas',
        'Ahorro',
      ]) {
        expect(find.text(etiqueta), findsWidgets, reason: 'falta $etiqueta');
      }
    });

    testWidgets('tocar un destino cambia la pantalla', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Ahorro').last);
      await tester.pumpAndSettle();

      expect(find.text('Aportes de este mes'), findsOneWidget);
    });
  });

  group('drawer', () {
    testWidgets('no ocupa lugar en la barra pero es alcanzable', (
      tester,
    ) async {
      await montar(tester);

      // Cerrado, sus destinos no están en pantalla.
      expect(find.text('Ajustes'), findsNothing);

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      expect(find.text('Categorías'), findsOneWidget);
      expect(find.text('Tarjetas'), findsOneWidget);
      expect(find.text('Ajustes'), findsOneWidget);
    });

    testWidgets('el encabezado muestra el mes en curso', (tester) async {
      await montar(tester);

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      // El mes también sale en el selector del resumen, que queda detrás:
      // se busca solo dentro del drawer.
      expect(
        find.descendant(
          of: find.byType(NavigationDrawer),
          matching: find.text('Agosto 2026'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('navegar por el drawer lleva a la pantalla y lo cierra', (
      tester,
    ) async {
      await montar(tester);

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();

      // El título del AppBar pasa a ser el del destino elegido.
      expect(find.text('Plazo para pagos rezagados'), findsOneWidget);
    });

    testWidgets('volver a la barra deja el drawer sin selección', (
      tester,
    ) async {
      await montar(tester);

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resumen').last);
      await tester.pumpAndSettle();

      expect(find.text('Plazo para pagos rezagados'), findsNothing);
    });
  });

  group('ajustes', () {
    testWidgets('los días de gracia se guardan y persisten', (tester) async {
      await montar(tester);

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();

      expect(find.text('5 días'), findsOneWidget);

      // Arrastrar el deslizador hasta el extremo izquierdo: cero días.
      await tester.drag(find.byType(Slider), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect((await repoConfiguracion.obtener()).diasGraciaCierre, 0);
      expect(
        find.text('El mes anterior queda cerrado apenas empieza el nuevo.'),
        findsOneWidget,
      );
    });
  });
}
