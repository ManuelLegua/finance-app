import 'dart:async';

import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/cascaron.dart';
import 'package:finanzas/ui/estado/estado_ahorro.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/estado/estado_suscripcion.dart';
import 'package:finanzas/ui/estado/estado_tarjetas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../dobles/repositorios_en_memoria.dart';

/// El paywall y la guarda de acceso premium (US1, spec 004).
///
/// Se monta el cascarón entero a propósito: lo que la spec pide (FR-001,
/// FR-002) es que **tocar Deudas o Ahorro** lleve al aviso en vez de a la
/// pantalla real, y eso solo se prueba de verdad navegando como el usuario.
void main() {
  late EstadoMes estadoMes;
  late EstadoAhorro estadoAhorro;
  late RepositorioConfiguracionEnMemoria repoConfiguracion;
  late RepositorioSuscripcionEnMemoria repoSuscripcion;
  late EstadoSuscripcionPremium estadoSuscripcion;
  late EstadoTarjetas estadoTarjetas;

  const agosto = Mes(2026, 8);
  final quinceDeAgosto = DateTime(2026, 8, 15);

  EstadoSuscripcion vigente() => EstadoSuscripcion(
    situacion: SituacionSuscripcion.activa,
    plan: PlanSuscripcion.mensual,
    vigenteHasta: DateTime(2026, 9, 15),
    ultimaVerificacion: quinceDeAgosto,
  );

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<RepositorioConfiguracion>.value(value: repoConfiguracion),
          ChangeNotifierProvider<EstadoMes>.value(value: estadoMes),
          ChangeNotifierProvider<EstadoAhorro>.value(value: estadoAhorro),
          ChangeNotifierProvider<EstadoSuscripcionPremium>.value(
            value: estadoSuscripcion,
          ),
          ChangeNotifierProvider<EstadoTarjetas>.value(value: estadoTarjetas),
        ],
        child: const MaterialApp(home: Cascaron()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> irA(WidgetTester tester, String destino) async {
    await tester.tap(find.text(destino).last);
    await tester.pumpAndSettle();
  }

  /// El botón de compra del plan pedido. Se busca dentro de su ficha porque
  /// los dos planes ofrecen el mismo texto.
  Finder botonDe(String plan) => find.descendant(
    of: find.widgetWithText(Card, 'Plan $plan'),
    matching: find.widgetWithText(FilledButton, 'Empezar gratis'),
  );

  Future<void> elegirPlan(WidgetTester tester, String plan) async {
    await tester.tap(botonDe(plan));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    repoConfiguracion = RepositorioConfiguracionEnMemoria();
    estadoMes = EstadoMes(
      repoCobrosIngreso: RepositorioCobrosIngresoEnMemoria(),
      repoObligaciones: RepositorioObligacionesEnMemoria(),
      repoConfiguracion: repoConfiguracion,
      repoTransacciones: RepositorioTransaccionesEnMemoria(),
      repoDeudas: RepositorioDeudasEnMemoria(),
      ahora: () => quinceDeAgosto,
      mesInicial: agosto,
    );
    await estadoMes.cargar();
    estadoAhorro = EstadoAhorro(
      repoAhorro: RepositorioAhorroEnMemoria(),
      repoConfiguracion: repoConfiguracion,
      ahora: () => quinceDeAgosto,
    );
    await estadoAhorro.cargar(agosto);
    estadoTarjetas = EstadoTarjetas(
      repoTarjetas: RepositorioTarjetasEnMemoria(),
    );
    await estadoTarjetas.cargar();
    repoSuscripcion = RepositorioSuscripcionEnMemoria();
    estadoSuscripcion = EstadoSuscripcionPremium(
      repoSuscripcion: repoSuscripcion,
    );
  });

  group('sin suscripción, las pantallas premium avisan (FR-001, FR-002)', () {
    testWidgets('Deudas muestra el aviso, no la pantalla real', (tester) async {
      await estadoSuscripcion.cargar();
      await montar(tester);

      await irA(tester, 'Deudas');

      expect(
        find.textContaining('Deudas es parte de Finanzas'),
        findsOneWidget,
      );
      // El panorama de deudas de 001 no se ve por ningún lado.
      expect(find.text('Total adeudado'), findsNothing);
    });

    testWidgets('Ahorro muestra el aviso, no la pantalla real', (tester) async {
      await estadoSuscripcion.cargar();
      await montar(tester);

      await irA(tester, 'Ahorro');

      expect(
        find.textContaining('Ahorro es parte de Finanzas'),
        findsOneWidget,
      );
      expect(find.text('Aportes de este mes'), findsNothing);
    });

    testWidgets('explica qué desbloquea, con las tres funcionalidades', (
      tester,
    ) async {
      await estadoSuscripcion.cargar();
      await montar(tester);

      await irA(tester, 'Deudas');

      expect(find.textContaining('Deudas en cuotas'), findsWidgets);
      expect(find.textContaining('Ahorro'), findsWidgets);
      expect(find.textContaining('notificaciones'), findsWidgets);
    });

    testWidgets('muestra ambos precios y el mes de prueba (FR-005)', (
      tester,
    ) async {
      await estadoSuscripcion.cargar();
      await montar(tester);

      await irA(tester, 'Deudas');

      // Los precios salen de la tienda, no del código: son los del doble.
      expect(find.textContaining('S/ 19.90'), findsOneWidget);
      expect(find.textContaining('S/ 179.90'), findsOneWidget);
      expect(find.textContaining('primer mes es gratis'), findsOneWidget);
    });

    testWidgets('el aviso se explica con texto, no solo con un candado', (
      tester,
    ) async {
      await estadoSuscripcion.cargar();
      await montar(tester);

      await irA(tester, 'Deudas');

      // Principio IV: ningún estado se comunica solo por ícono o color.
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.textContaining('suscripción'), findsWidgets);
    });

    testWidgets('irse sin suscribirse no cobra ni pide nada', (tester) async {
      await estadoSuscripcion.cargar();
      await montar(tester);

      await irA(tester, 'Deudas');
      await irA(tester, 'Gastos');

      expect(repoSuscripcion.vecesQueSeCompro, 0);
      expect(estadoSuscripcion.premiumActivo, isFalse);
    });
  });

  group('con suscripción vigente se ve la pantalla real', () {
    testWidgets('Deudas deja de mostrar el aviso', (tester) async {
      repoSuscripcion.fijar(vigente());
      await estadoSuscripcion.cargar();
      await montar(tester);

      await irA(tester, 'Deudas');

      expect(find.textContaining('Deudas es parte de Finanzas'), findsNothing);
    });

    testWidgets('Ahorro deja de mostrar el aviso', (tester) async {
      repoSuscripcion.fijar(vigente());
      await estadoSuscripcion.cargar();
      await montar(tester);

      await irA(tester, 'Ahorro');

      expect(find.text('Aportes de este mes'), findsOneWidget);
    });

    testWidgets('en gracia también concede acceso (FR-013)', (tester) async {
      repoSuscripcion.fijar(
        EstadoSuscripcion(
          situacion: SituacionSuscripcion.enGracia,
          plan: PlanSuscripcion.mensual,
          vigenteHasta: null,
          ultimaVerificacion: quinceDeAgosto,
        ),
      );
      await estadoSuscripcion.cargar();
      await montar(tester);

      await irA(tester, 'Ahorro');

      expect(find.text('Aportes de este mes'), findsOneWidget);
    });
  });

  group('las pantallas gratis nunca avisan de pago (FR-004)', () {
    testWidgets('Resumen, Presupuesto y Gastos se ven sin suscripción', (
      tester,
    ) async {
      await estadoSuscripcion.cargar();
      await montar(tester);

      for (final destino in ['Presupuesto', 'Gastos', 'Resumen']) {
        await irA(tester, destino);
        expect(
          find.textContaining('parte de Finanzas Premium'),
          findsNothing,
          reason: '$destino no debería mostrar el paywall',
        );
      }
    });
  });

  group('sin conexión no se inventan precios', () {
    testWidgets('lo explica y ofrece reintentar', (tester) async {
      repoSuscripcion.hayConexion = false;
      await estadoSuscripcion.cargar();
      await montar(tester);

      await irA(tester, 'Deudas');

      expect(
        find.textContaining('No pudimos consultar los planes'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.textContaining('S/ 19.90'), findsNothing);
    });

    testWidgets('reintentar con conexión ya muestra los precios', (
      tester,
    ) async {
      repoSuscripcion.hayConexion = false;
      await estadoSuscripcion.cargar();
      await montar(tester);
      await irA(tester, 'Deudas');

      repoSuscripcion.hayConexion = true;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('S/ 19.90'), findsOneWidget);
    });
  });

  group('comprar desbloquea sin reiniciar la app (FR-007, SC-002)', () {
    testWidgets('elegir el plan mensual deja ver Deudas al instante', (
      tester,
    ) async {
      repoSuscripcion.resultadoDeComprar = vigente();
      await estadoSuscripcion.cargar();
      await montar(tester);
      await irA(tester, 'Deudas');

      await elegirPlan(tester, 'mensual');

      // Sin volver a montar nada: el mismo árbol que mostraba el aviso ahora
      // muestra la pantalla real (Acceptance Scenario 2).
      expect(find.textContaining('Deudas es parte de Finanzas'), findsNothing);
      expect(estadoSuscripcion.premiumActivo, isTrue);
      expect(estadoSuscripcion.plan, PlanSuscripcion.mensual);
    });

    testWidgets('y Ahorro queda accesible en la misma sesión', (tester) async {
      repoSuscripcion.resultadoDeComprar = vigente();
      await estadoSuscripcion.cargar();
      await montar(tester);
      await irA(tester, 'Deudas');

      await elegirPlan(tester, 'mensual');
      await irA(tester, 'Ahorro');

      expect(find.text('Aportes de este mes'), findsOneWidget);
    });

    testWidgets('el plan anual también desbloquea', (tester) async {
      repoSuscripcion.resultadoDeComprar = vigente();
      await estadoSuscripcion.cargar();
      await montar(tester);
      await irA(tester, 'Ahorro');

      await elegirPlan(tester, 'anual');

      expect(estadoSuscripcion.premiumActivo, isTrue);
      expect(estadoSuscripcion.plan, PlanSuscripcion.anual);
    });
  });

  group('cancelar la compra no es un error (FR-008)', () {
    testWidgets('no desbloquea nada y no muestra ningún fallo', (tester) async {
      // Sin resultado, el doble entiende que el usuario cerró el diálogo de
      // Google Play antes de confirmar.
      repoSuscripcion.resultadoDeComprar = null;
      await estadoSuscripcion.cargar();
      await montar(tester);
      await irA(tester, 'Deudas');

      await elegirPlan(tester, 'mensual');

      expect(
        find.textContaining('Deudas es parte de Finanzas'),
        findsOneWidget,
      );
      expect(estadoSuscripcion.premiumActivo, isFalse);
      // Cancelar es un flujo esperado: ni banner, ni cartel de problema.
      expect(estadoSuscripcion.error, isNull);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('problema'), findsNothing);
    });

    testWidgets('se puede volver a intentar después de cancelar', (
      tester,
    ) async {
      repoSuscripcion.resultadoDeComprar = null;
      await estadoSuscripcion.cargar();
      await montar(tester);
      await irA(tester, 'Deudas');
      await elegirPlan(tester, 'mensual');

      repoSuscripcion.resultadoDeComprar = vigente();
      await elegirPlan(tester, 'mensual');

      expect(estadoSuscripcion.premiumActivo, isTrue);
      expect(repoSuscripcion.vecesQueSeCompro, 2);
    });
  });

  group('mientras Google confirma la compra', () {
    testWidgets('un doble toque no dispara dos compras', (tester) async {
      final confirmacion = Completer<void>();
      repoSuscripcion.confirmacionPendiente = confirmacion;
      repoSuscripcion.resultadoDeComprar = vigente();
      await estadoSuscripcion.cargar();
      await montar(tester);
      await irA(tester, 'Deudas');

      await tester.tap(botonDe('mensual'));
      await tester.pump();
      // El segundo toque cae sobre un botón ya deshabilitado.
      await tester.tap(botonDe('mensual'), warnIfMissed: false);
      await tester.pump();
      confirmacion.complete();
      await tester.pumpAndSettle();

      expect(repoSuscripcion.vecesQueSeCompro, 1);
      expect(estadoSuscripcion.premiumActivo, isTrue);
    });

    testWidgets('se dice con texto que la compra está en curso', (
      tester,
    ) async {
      final confirmacion = Completer<void>();
      repoSuscripcion.confirmacionPendiente = confirmacion;
      repoSuscripcion.resultadoDeComprar = vigente();
      await estadoSuscripcion.cargar();
      await montar(tester);
      await irA(tester, 'Deudas');

      await tester.tap(botonDe('mensual'));
      await tester.pump();

      // Principio IV: un botón grisado no alcanza para explicar la espera.
      expect(find.textContaining('Confirmando'), findsOneWidget);

      confirmacion.complete();
      await tester.pumpAndSettle();
    });
  });

  group('el estado de la suscripción se consulta desde el aviso (FR-009)', () {
    testWidgets('una suscripción vencida se explica en el propio aviso', (
      tester,
    ) async {
      repoSuscripcion.fijar(
        EstadoSuscripcion(
          situacion: SituacionSuscripcion.vencida,
          plan: PlanSuscripcion.mensual,
          vigenteHasta: DateTime(2026, 8, 1),
          ultimaVerificacion: quinceDeAgosto,
        ),
      );
      await estadoSuscripcion.cargar();
      await montar(tester);

      await irA(tester, 'Deudas');

      expect(find.text(SituacionSuscripcion.vencida.etiqueta), findsOneWidget);
    });

    testWidgets('sin suscripción previa el aviso no repite el estado', (
      tester,
    ) async {
      await estadoSuscripcion.cargar();
      await montar(tester);

      await irA(tester, 'Deudas');

      // "Nunca suscripto" no aporta nada arriba de un aviso que ya explica
      // que hay que suscribirse.
      expect(find.text(SituacionSuscripcion.nunca.etiqueta), findsNothing);
    });
  });
}
