import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter_test/flutter_test.dart';

/// D5: el mes se identifica por un ordinal entero `anio * 12 + (mes - 1)`.
/// Toda la aritmética de vigencia de cuotas y de historial se apoya acá.
void main() {
  group('construcción y validación', () {
    test('guarda año y mes', () {
      const agosto = Mes(2026, 8);
      expect(agosto.anio, 2026);
      expect(agosto.mes, 8);
    });

    test('rechaza meses fuera de 1..12', () {
      // `Mes` es un valor const, así que la invariante se expresa con assert:
      // un constructor const no puede tener cuerpo que lance ArgumentError.
      expect(() => Mes(2026, 0), throwsAssertionError);
      expect(() => Mes(2026, 13), throwsAssertionError);
      expect(() => Mes(2026, -1), throwsAssertionError);
    });

    test('acepta los extremos del año', () {
      expect(const Mes(2026, 1).mes, 1);
      expect(const Mes(2026, 12).mes, 12);
    });
  });

  group('ordinal', () {
    test('es anio * 12 + (mes - 1)', () {
      expect(const Mes(2026, 1).ordinal, 2026 * 12);
      expect(const Mes(2026, 8).ordinal, 2026 * 12 + 7);
    });

    test('ida y vuelta desde el ordinal', () {
      const original = Mes(2026, 8);
      expect(Mes.deOrdinal(original.ordinal), original);
    });

    test('meses consecutivos tienen ordinales consecutivos', () {
      expect(
        const Mes(2026, 12).ordinal + 1,
        const Mes(2027, 1).ordinal,
      );
    });
  });

  group('aritmética', () {
    test('siguiente y anterior dentro del año', () {
      expect(const Mes(2026, 8).siguiente, const Mes(2026, 9));
      expect(const Mes(2026, 8).anterior, const Mes(2026, 7));
    });

    test('siguiente cruza el fin de año', () {
      expect(const Mes(2026, 12).siguiente, const Mes(2027, 1));
    });

    test('anterior cruza el inicio de año', () {
      expect(const Mes(2027, 1).anterior, const Mes(2026, 12));
    });

    test('mas(n) avanza n meses, incluso varios años', () {
      // Deuda de 12 cuotas que arranca en agosto 2026: la última es julio 2027.
      expect(const Mes(2026, 8).mas(11), const Mes(2027, 7));
      expect(const Mes(2026, 8).mas(24), const Mes(2028, 8));
    });

    test('mas(0) devuelve el mismo mes', () {
      expect(const Mes(2026, 8).mas(0), const Mes(2026, 8));
    });

    test('mas con negativo retrocede', () {
      expect(const Mes(2026, 2).mas(-3), const Mes(2025, 11));
    });

    test('diferencia cuenta meses entre dos fechas', () {
      expect(const Mes(2027, 7).diferencia(const Mes(2026, 8)), 11);
      expect(const Mes(2026, 8).diferencia(const Mes(2026, 8)), 0);
      expect(const Mes(2026, 8).diferencia(const Mes(2026, 9)), -1);
    });
  });

  group('desde fecha', () {
    test('toma año y mes, ignorando el día', () {
      expect(Mes.deFecha(DateTime(2026, 8, 27)), const Mes(2026, 8));
      expect(Mes.deFecha(DateTime(2026, 8, 1)), const Mes(2026, 8));
      expect(Mes.deFecha(DateTime(2026, 8, 31)), const Mes(2026, 8));
    });

    test('un gasto del último día del mes pertenece a ese mes', () {
      // FR-008: la transacción se asigna al mes de su fecha.
      expect(Mes.deFecha(DateTime(2026, 7, 31)), const Mes(2026, 7));
      expect(Mes.deFecha(DateTime(2026, 8, 1)), const Mes(2026, 8));
    });
  });

  group('orden e igualdad', () {
    test('la igualdad es por valor', () {
      expect(const Mes(2026, 8), const Mes(2026, 8));
      expect(const Mes(2026, 8).hashCode, const Mes(2026, 8).hashCode);
      expect(const Mes(2026, 8) == const Mes(2026, 9), isFalse);
    });

    test('compara cronológicamente', () {
      expect(const Mes(2026, 8) < const Mes(2026, 9), isTrue);
      expect(const Mes(2027, 1) > const Mes(2026, 12), isTrue);
      expect(const Mes(2026, 8) <= const Mes(2026, 8), isTrue);
      expect(const Mes(2026, 8) >= const Mes(2026, 8), isTrue);
    });

    test('ordenar una lista da orden cronológico', () {
      final meses = <Mes>[
        const Mes(2027, 1),
        const Mes(2026, 8),
        const Mes(2026, 12),
      ]..sort();
      expect(meses, const [Mes(2026, 8), Mes(2026, 12), Mes(2027, 1)]);
    });
  });

  group('presentación', () {
    test('toString es legible y estable', () {
      expect(const Mes(2026, 8).toString(), '2026-08');
      expect(const Mes(2026, 12).toString(), '2026-12');
    });
  });
}
