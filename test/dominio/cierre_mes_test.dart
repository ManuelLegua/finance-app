import 'package:finanzas/core/mes.dart';
import 'package:finanzas/dominio/calculos/cierre_mes.dart';
import 'package:finanzas/dominio/modelos/estado_cierre.dart';
import 'package:flutter_test/flutter_test.dart';

/// FR-052 y FR-055 – FR-058: los meses pasados son de solo lectura, con una
/// ventana de gracia para registrar pagos rezagados.
///
/// D13: el estado se deriva de la fecha, no se persiste, y `hoy` entra como
/// parámetro. Por eso estas pruebas fijan fechas concretas en vez de tocar el
/// reloj del sistema, que es lo que las vuelve estables.
void main() {
  // Agosto de 2026. El mes en curso durante todas las pruebas.
  const enCurso = Mes(2026, 8);
  const anterior = Mes(2026, 7);
  const viejo = Mes(2026, 5);
  const futuro = Mes(2026, 9);

  group('mes en curso', () {
    final hoy = DateTime(2026, 8, 15);

    test('está abierto', () {
      expect(
        estadoDe(enCurso, hoy: hoy, diasGraciaCierre: 5).situacion,
        SituacionMes.abierto,
      );
    });

    test('admite registrar y editar', () {
      expect(puedeRegistrarEn(enCurso, hoy: hoy, diasGraciaCierre: 5), isTrue);
      expect(puedeEditarEn(enCurso, hoy: hoy), isTrue);
    });

    test('sigue abierto el primer día del mes', () {
      final primero = DateTime(2026, 8, 1);
      expect(puedeEditarEn(enCurso, hoy: primero), isTrue);
    });

    test('sigue abierto el último día del mes', () {
      final ultimo = DateTime(2026, 8, 31);
      expect(puedeEditarEn(enCurso, hoy: ultimo), isTrue);
    });
  });

  group('mes anterior dentro de la ventana de gracia', () {
    final diaTres = DateTime(2026, 8, 3);

    test('queda en gracia', () {
      expect(
        estadoDe(anterior, hoy: diaTres, diasGraciaCierre: 5).situacion,
        SituacionMes.enGracia,
      );
    });

    test('admite registrar el pago rezagado (FR-055)', () {
      expect(
        puedeRegistrarEn(anterior, hoy: diaTres, diasGraciaCierre: 5),
        isTrue,
      );
    });

    test('NO admite editar ni eliminar, ni siquiera en gracia (FR-056)', () {
      expect(puedeEditarEn(anterior, hoy: diaTres), isFalse);
    });

    test('el último día de la ventana todavía admite registrar', () {
      final diaCinco = DateTime(2026, 8, 5);
      expect(
        puedeRegistrarEn(anterior, hoy: diaCinco, diasGraciaCierre: 5),
        isTrue,
      );
    });

    test('el día siguiente a la ventana ya no admite registrar', () {
      final diaSeis = DateTime(2026, 8, 6);
      expect(
        puedeRegistrarEn(anterior, hoy: diaSeis, diasGraciaCierre: 5),
        isFalse,
      );
      expect(
        estadoDe(anterior, hoy: diaSeis, diasGraciaCierre: 5).situacion,
        SituacionMes.cerrado,
      );
    });
  });

  group('sin ventana de gracia', () {
    test('con 0 días el mes anterior queda cerrado desde el día 1', () {
      final primero = DateTime(2026, 8, 1);
      expect(
        estadoDe(anterior, hoy: primero, diasGraciaCierre: 0).situacion,
        SituacionMes.cerrado,
      );
      expect(
        puedeRegistrarEn(anterior, hoy: primero, diasGraciaCierre: 0),
        isFalse,
      );
    });
  });

  group('meses anteriores al anterior', () {
    final diaTres = DateTime(2026, 8, 3);

    test('están cerrados aunque la ventana esté abierta', () {
      expect(
        estadoDe(viejo, hoy: diaTres, diasGraciaCierre: 5).situacion,
        SituacionMes.cerrado,
      );
    });

    test('no admiten registrar ni editar (FR-052)', () {
      expect(puedeRegistrarEn(viejo, hoy: diaTres, diasGraciaCierre: 5),
          isFalse);
      expect(puedeEditarEn(viejo, hoy: diaTres), isFalse);
    });

    test('una ventana enorme no reabre meses viejos', () {
      expect(
        puedeRegistrarEn(viejo, hoy: diaTres, diasGraciaCierre: 28),
        isFalse,
      );
    });
  });

  group('meses futuros', () {
    final hoy = DateTime(2026, 8, 15);

    test('se tratan como abiertos: el usuario puede planificar', () {
      expect(
        estadoDe(futuro, hoy: hoy, diasGraciaCierre: 5).situacion,
        SituacionMes.abierto,
      );
      expect(puedeEditarEn(futuro, hoy: hoy), isTrue);
    });
  });

  group('cruce de año', () {
    test('en enero, diciembre del año anterior entra en gracia', () {
      final dosDeEnero = DateTime(2027, 1, 2);
      expect(
        estadoDe(const Mes(2026, 12), hoy: dosDeEnero, diasGraciaCierre: 5)
            .situacion,
        SituacionMes.enGracia,
      );
    });

    test('en enero, noviembre ya está cerrado', () {
      final dosDeEnero = DateTime(2027, 1, 2);
      expect(
        estadoDe(const Mes(2026, 11), hoy: dosDeEnero, diasGraciaCierre: 5)
            .situacion,
        SituacionMes.cerrado,
      );
    });
  });

  group('motivo legible', () {
    final diaTres = DateTime(2026, 8, 3);

    test('el mes abierto no necesita motivo', () {
      final estado = estadoDe(enCurso, hoy: diaTres, diasGraciaCierre: 5);
      expect(estado.motivo, isNull);
    });

    test('la gracia explica que lo registrado quedará inmutable', () {
      // FR-058: se comunica con texto, no solo con color.
      final estado = estadoDe(anterior, hoy: diaTres, diasGraciaCierre: 5);
      expect(estado.motivo, isNotNull);
      expect(estado.motivo, contains('editar'));
    });

    test('el mes cerrado explica por qué no se puede modificar', () {
      final estado = estadoDe(viejo, hoy: diaTres, diasGraciaCierre: 5);
      expect(estado.motivo, isNotNull);
      expect(estado.motivo, contains('cerrado'));
    });
  });

  group('validación de la configuración', () {
    test('rechaza días de gracia fuera de 0..28', () {
      final hoy = DateTime(2026, 8, 3);
      expect(
        () => estadoDe(anterior, hoy: hoy, diasGraciaCierre: -1),
        throwsArgumentError,
      );
      expect(
        () => estadoDe(anterior, hoy: hoy, diasGraciaCierre: 29),
        throwsArgumentError,
      );
    });
  });
}
