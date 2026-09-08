import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/cascaron.dart';
import 'package:finanzas/ui/estado/estado_ahorro.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/estado/estado_respaldo.dart';
import 'package:finanzas/ui/estado/estado_suscripcion.dart';
import 'package:finanzas/ui/estado/estado_tarjetas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../dobles/repositorios_en_memoria.dart';

/// Restaurar una suscripción ya comprada, sin pagar de nuevo (US5, spec 004).
///
/// El caso que le da sentido a esta historia es el dispositivo nuevo: no hay
/// nada guardado en el SQLite local, `situacion` arranca en `nunca`, y sin
/// embargo la cuenta de Google sí tiene la suscripción. Por eso la acción de
/// restaurar tiene que estar disponible **desde ese estado**, no solo cuando
/// ya hubo una suscripción antes en este dispositivo (a diferencia de
/// `FichaEstadoSuscripcion`, que con `nunca` no dice nada).
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
          ChangeNotifierProvider<EstadoRespaldo>(
            create: (_) =>
                EstadoRespaldo(repoRespaldo: RepositorioRespaldoEnMemoria()),
          ),
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

  Future<void> irAAjustes(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
  }

  Future<void> tocarRestaurar(WidgetTester tester) async {
    await tester.tap(find.text('Restaurar suscripción'));
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
    // Dispositivo nuevo: nada guardado todavía, como si se acabara de
    // instalar la app (Acceptance Scenario 1).
    repoSuscripcion = RepositorioSuscripcionEnMemoria();
    estadoSuscripcion = EstadoSuscripcionPremium(
      repoSuscripcion: repoSuscripcion,
    );
  });

  group('restaurar encuentra una suscripción activa (FR-014)', () {
    testWidgets(
      'desde el paywall desbloquea sin pasar por el flujo de compra',
      (tester) async {
        repoSuscripcion.resultadoDeRestaurar = vigente();
        await estadoSuscripcion.cargar();
        await montar(tester);
        await irA(tester, 'Deudas');

        await tocarRestaurar(tester);

        // Mismo árbol, sin reiniciar nada (mismo criterio que comprar).
        expect(
          find.textContaining('Deudas es parte de Finanzas'),
          findsNothing,
        );
        expect(estadoSuscripcion.premiumActivo, isTrue);
        // Ninguna compra se disparó: esto no pasó por Google Play Billing.
        expect(repoSuscripcion.vecesQueSeCompro, 0);
      },
    );

    testWidgets('también está disponible desde Ajustes', (tester) async {
      repoSuscripcion.resultadoDeRestaurar = vigente();
      await estadoSuscripcion.cargar();
      await montar(tester);
      await irAAjustes(tester);

      await tocarRestaurar(tester);

      expect(estadoSuscripcion.premiumActivo, isTrue);

      await irA(tester, 'Ahorro');
      expect(find.text('Aportes de este mes'), findsOneWidget);
    });
  });

  group('restaurar sin encontrar nada informa con claridad (FR-015, '
      'Acceptance Scenario 2)', () {
    testWidgets('lo dice con texto y no deja creer que la app falló', (
      tester,
    ) async {
      // Sin fijar resultadoDeRestaurar: el doble entiende que esta cuenta
      // de Google no tiene ninguna suscripción.
      await estadoSuscripcion.cargar();
      await montar(tester);
      await irA(tester, 'Deudas');

      await tocarRestaurar(tester);

      expect(
        find.textContaining('No encontramos ninguna suscripción'),
        findsOneWidget,
      );
      expect(estadoSuscripcion.premiumActivo, isFalse);
      // No es un error de la app: no se habla de un problema inesperado.
      expect(find.textContaining('problema'), findsNothing);
    });
  });
}
