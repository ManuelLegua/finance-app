import 'package:finanzas/dominio/modelos/estado_suscripcion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Principio III: la regla que decide si el usuario accede a algo por lo que
/// paga se prueba antes de implementarse, aunque sea un getter corto.
///
/// D2 de research.md: la vigencia sale **solo** de `situacion`, la que Google
/// Play ya evaluó. No se recalcula comparando `vigenteHasta` contra la fecha
/// del dispositivo, porque dos relojes desincronizados (el del teléfono y el
/// de Google) no deben decidir un acceso pago.
void main() {
  /// Fecha fija: ninguna prueba de este archivo puede depender del reloj.
  final momentoCualquiera = DateTime(2026, 3, 15);

  EstadoSuscripcion conSituacion(
    SituacionSuscripcion situacion, {
    PlanSuscripcion? plan,
    DateTime? vigenteHasta,
  }) => EstadoSuscripcion(
    situacion: situacion,
    plan: plan,
    vigenteHasta: vigenteHasta,
    ultimaVerificacion: momentoCualquiera,
  );

  group('estaVigente concede acceso premium', () {
    test('en prueba gratis', () {
      expect(
        conSituacion(
          SituacionSuscripcion.enPrueba,
          plan: PlanSuscripcion.mensual,
        ).estaVigente,
        isTrue,
      );
    });

    test('activa', () {
      expect(
        conSituacion(
          SituacionSuscripcion.activa,
          plan: PlanSuscripcion.anual,
        ).estaVigente,
        isTrue,
      );
    });

    test(
      'en gracia: el margen tras un cobro fallido lo fija Google (FR-013)',
      () {
        expect(
          conSituacion(
            SituacionSuscripcion.enGracia,
            plan: PlanSuscripcion.mensual,
          ).estaVigente,
          isTrue,
        );
      },
    );
  });

  group('estaVigente niega acceso premium', () {
    test('nunca suscripto', () {
      expect(conSituacion(SituacionSuscripcion.nunca).estaVigente, isFalse);
    });

    test('vencida', () {
      expect(
        conSituacion(
          SituacionSuscripcion.vencida,
          plan: PlanSuscripcion.mensual,
        ).estaVigente,
        isFalse,
      );
    });

    test('cancelada', () {
      expect(
        conSituacion(
          SituacionSuscripcion.cancelada,
          plan: PlanSuscripcion.anual,
        ).estaVigente,
        isFalse,
      );
    });
  });

  group('la vigencia no depende de fechas (D2)', () {
    test('una suscripción activa con vigenteHasta ya pasado sigue vigente', () {
      // Si el getter comparara contra una fecha, esto daría false. No lo hace:
      // mientras Google diga "activa", el acceso está concedido.
      final estado = conSituacion(
        SituacionSuscripcion.activa,
        plan: PlanSuscripcion.mensual,
        vigenteHasta: DateTime(2020, 1, 1),
      );
      expect(estado.estaVigente, isTrue);
    });

    test(
      'una vencida con vigenteHasta en el futuro sigue sin estar vigente',
      () {
        final estado = conSituacion(
          SituacionSuscripcion.vencida,
          plan: PlanSuscripcion.mensual,
          vigenteHasta: DateTime(2099, 1, 1),
        );
        expect(estado.estaVigente, isFalse);
      },
    );

    test('sin vigenteHasta la vigencia se sigue decidiendo por situación', () {
      expect(conSituacion(SituacionSuscripcion.activa).estaVigente, isTrue);
      expect(conSituacion(SituacionSuscripcion.vencida).estaVigente, isFalse);
    });
  });

  group('las seis situaciones están cubiertas', () {
    test('ninguna queda sin decidir', () {
      // Si mañana se agrega una situación al enum, esta prueba falla y obliga
      // a decidir explícitamente si concede acceso o no.
      final vigentes = SituacionSuscripcion.values
          .where((situacion) => conSituacion(situacion).estaVigente)
          .toSet();
      expect(vigentes, {
        SituacionSuscripcion.enPrueba,
        SituacionSuscripcion.activa,
        SituacionSuscripcion.enGracia,
      });
      expect(SituacionSuscripcion.values, hasLength(6));
    });
  });

  group('estado inicial', () {
    test('nunca suscripto es el punto de partida, sin plan ni vencimiento', () {
      final inicial = EstadoSuscripcion.nunca(
        ultimaVerificacion: momentoCualquiera,
      );
      expect(inicial.situacion, SituacionSuscripcion.nunca);
      expect(inicial.plan, isNull);
      expect(inicial.vigenteHasta, isNull);
      expect(inicial.estaVigente, isFalse);
    });
  });

  group('OfertaSuscripcion', () {
    test('el precio es el texto que informa Google Play, no un Dinero', () {
      const oferta = OfertaSuscripcion(
        plan: PlanSuscripcion.mensual,
        precioFormateado: 'S/ 19.90 al mes',
        duracionPruebaDias: 30,
      );
      expect(oferta.precioFormateado, 'S/ 19.90 al mes');
      expect(oferta.duracionPruebaDias, 30);
      // Principio II no aplica acá: no es un monto que la app calcule ni
      // guarde, así que nunca se convierte a Dinero ni se opera con él.
      expect(oferta.precioFormateado, isA<String>());
    });
  });
}
