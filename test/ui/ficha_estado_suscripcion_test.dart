import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/ui/estado/estado_suscripcion.dart';
import 'package:finanzas/ui/pantallas/suscripcion/ficha_estado_suscripcion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../dobles/repositorios_en_memoria.dart';

/// La ficha de estado de la suscripción (US2, spec 004).
///
/// FR-009 pide que el usuario pueda consultar en un lugar fijo si está en
/// prueba gratis, activa y hasta cuándo, o no activa, y con qué plan. La
/// ficha es ese lugar; acá se prueba sola, sin la pantalla que la contenga.
void main() {
  final quinceDeAgosto = DateTime(2026, 8, 15);
  final quinceDeSetiembre = DateTime(2026, 9, 15);

  Future<void> montar(WidgetTester tester, EstadoSuscripcion inicial) async {
    final repoSuscripcion = RepositorioSuscripcionEnMemoria(inicial: inicial);
    final estadoSuscripcion = EstadoSuscripcionPremium(
      repoSuscripcion: repoSuscripcion,
    );
    await estadoSuscripcion.cargar();

    await tester.pumpWidget(
      ChangeNotifierProvider<EstadoSuscripcionPremium>.value(
        value: estadoSuscripcion,
        child: const MaterialApp(
          home: Scaffold(body: FichaEstadoSuscripcion()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  EstadoSuscripcion conSituacion(
    SituacionSuscripcion situacion, {
    PlanSuscripcion? plan = PlanSuscripcion.mensual,
    DateTime? vigenteHasta,
  }) => EstadoSuscripcion(
    situacion: situacion,
    plan: plan,
    vigenteHasta: vigenteHasta,
    ultimaVerificacion: quinceDeAgosto,
  );

  group('dice en qué situación está, con todas las letras (FR-009)', () {
    testWidgets('en prueba gratis, con plan y fecha del primer cobro', (
      tester,
    ) async {
      await montar(
        tester,
        conSituacion(
          SituacionSuscripcion.enPrueba,
          vigenteHasta: quinceDeSetiembre,
        ),
      );

      // Acceptance Scenario 5: en prueba, qué plan cobrará y desde cuándo.
      expect(find.text(SituacionSuscripcion.enPrueba.etiqueta), findsOneWidget);
      expect(find.textContaining('plan mensual'), findsOneWidget);
      expect(find.textContaining('15/09/2026'), findsOneWidget);
    });

    testWidgets('activa, con el plan anual y la fecha de renovación', (
      tester,
    ) async {
      await montar(
        tester,
        conSituacion(
          SituacionSuscripcion.activa,
          plan: PlanSuscripcion.anual,
          vigenteHasta: quinceDeSetiembre,
        ),
      );

      expect(find.text(SituacionSuscripcion.activa.etiqueta), findsOneWidget);
      expect(find.textContaining('plan anual'), findsOneWidget);
      expect(find.textContaining('15/09/2026'), findsOneWidget);
    });

    testWidgets('sin suscripción, dice que lo premium está bloqueado', (
      tester,
    ) async {
      await montar(
        tester,
        conSituacion(SituacionSuscripcion.nunca, plan: null),
      );

      expect(find.text(SituacionSuscripcion.nunca.etiqueta), findsOneWidget);
      expect(find.textContaining('bloquead'), findsOneWidget);
    });

    testWidgets('vencida, aclarando que los datos siguen guardados', (
      tester,
    ) async {
      await montar(
        tester,
        conSituacion(
          SituacionSuscripcion.vencida,
          vigenteHasta: DateTime(2026, 8, 1),
        ),
      );

      expect(find.text(SituacionSuscripcion.vencida.etiqueta), findsOneWidget);
      // FR-011: perder el acceso no es perder los datos, y hay que decirlo.
      expect(find.textContaining('siguen guardados'), findsOneWidget);
    });

    testWidgets('cancelada, también con los datos a salvo', (tester) async {
      await montar(tester, conSituacion(SituacionSuscripcion.cancelada));

      expect(
        find.text(SituacionSuscripcion.cancelada.etiqueta),
        findsOneWidget,
      );
      expect(find.textContaining('siguen guardados'), findsOneWidget);
    });

    testWidgets('en gracia, explicando que el acceso sigue (FR-013)', (
      tester,
    ) async {
      await montar(tester, conSituacion(SituacionSuscripcion.enGracia));

      expect(find.text(SituacionSuscripcion.enGracia.etiqueta), findsOneWidget);
      expect(find.textContaining('acceso'), findsOneWidget);
    });

    testWidgets('sin fecha conocida no se inventa ninguna', (tester) async {
      await montar(tester, conSituacion(SituacionSuscripcion.activa));

      expect(find.text(SituacionSuscripcion.activa.etiqueta), findsOneWidget);
      expect(find.textContaining('/2026'), findsNothing);
    });
  });

  group('ningún estado se comunica solo por color (Principio IV)', () {
    testWidgets('cada situación trae ícono y texto', (tester) async {
      for (final situacion in SituacionSuscripcion.values) {
        await montar(
          tester,
          conSituacion(situacion, vigenteHasta: quinceDeSetiembre),
        );

        expect(
          find.text(situacion.etiqueta),
          findsOneWidget,
          reason: '${situacion.slug} debería nombrarse en texto',
        );
        expect(
          find.byType(Icon),
          findsOneWidget,
          reason: '${situacion.slug} debería llevar un ícono que acompañe',
        );
      }
    });
  });
}
