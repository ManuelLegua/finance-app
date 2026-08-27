import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:flutter_test/flutter_test.dart';

/// FR-048: todo monto se presenta como `S/ 1,234.56`.
///
/// D2: el formato se produce a mano desde el entero de centavos. No se usa
/// `intl.NumberFormat`, que recibe `num` y obligaría a convertir a `double`
/// justo antes de mostrar la cifra.
void main() {
  group('formato básico', () {
    test('agrupa miles y siempre muestra dos decimales', () {
      expect(
        FormatoSoles.formatear(const Dinero.deCentavos(123456)),
        r'S/ 1,234.56',
      );
    });

    test('montos menores a mil no llevan separador', () {
      expect(
        FormatoSoles.formatear(const Dinero.deCentavos(4500)),
        r'S/ 45.00',
      );
      expect(
        FormatoSoles.formatear(const Dinero.deCentavos(99999)),
        r'S/ 999.99',
      );
    });

    test('cero se muestra como S/ 0.00, no vacío', () {
      expect(FormatoSoles.formatear(Dinero.cero), r'S/ 0.00');
    });

    test('rellena los decimales con cero', () {
      expect(FormatoSoles.formatear(const Dinero.deCentavos(100)), r'S/ 1.00');
      expect(FormatoSoles.formatear(const Dinero.deCentavos(105)), r'S/ 1.05');
      expect(FormatoSoles.formatear(const Dinero.deCentavos(150)), r'S/ 1.50');
    });

    test('montos de solo céntimos', () {
      expect(FormatoSoles.formatear(const Dinero.deCentavos(1)), r'S/ 0.01');
      expect(FormatoSoles.formatear(const Dinero.deCentavos(99)), r'S/ 0.99');
    });
  });

  group('negativos', () {
    test('el signo va antes del símbolo', () {
      expect(
        FormatoSoles.formatear(const Dinero.deCentavos(-35000)),
        r'-S/ 350.00',
      );
    });

    test('negativo de céntimos', () {
      expect(FormatoSoles.formatear(const Dinero.deCentavos(-1)), r'-S/ 0.01');
    });
  });

  group('límites de tamaño', () {
    test('siete cifras enteras se agrupan correctamente', () {
      // Edge case "montos grandes" de la spec.
      expect(
        FormatoSoles.formatear(const Dinero.deCentavos(999999999)),
        r'S/ 9,999,999.99',
      );
    });

    test('el salto a cada grupo de miles', () {
      expect(
        FormatoSoles.formatear(const Dinero.deCentavos(100000)),
        r'S/ 1,000.00',
      );
      expect(
        FormatoSoles.formatear(const Dinero.deCentavos(100000000)),
        r'S/ 1,000,000.00',
      );
    });
  });

  group('sin símbolo', () {
    test('devuelve solo la cifra, para columnas ya rotuladas', () {
      expect(
        FormatoSoles.formatearSinSimbolo(const Dinero.deCentavos(123456)),
        '1,234.56',
      );
      expect(
        FormatoSoles.formatearSinSimbolo(const Dinero.deCentavos(-100)),
        '-1.00',
      );
    });
  });

  group('exactitud', () {
    test('los montos que rompen el punto flotante se muestran exactos', () {
      // 0.1 + 0.2 en double da 0.30000000000000004.
      final suma = const Dinero.deCentavos(10) + const Dinero.deCentavos(20);
      expect(FormatoSoles.formatear(suma), r'S/ 0.30');
    });

    test('una suma larga de céntimos se muestra exacta', () {
      final total = List.filled(
        1000,
        const Dinero.deCentavos(1),
      ).fold(Dinero.cero, (acc, d) => acc + d);
      expect(FormatoSoles.formatear(total), r'S/ 10.00');
    });
  });
}
