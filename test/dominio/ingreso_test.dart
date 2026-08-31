import 'package:finanzas/dominio/calculos/ingreso.dart';
import 'package:finanzas/dominio/modelos/cobro_ingreso.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:flutter_test/flutter_test.dart';

/// `totalIngreso`: el ingreso del mes es la suma de sus cobros, nunca un dato
/// guardado directamente (FR-003, FR-005). Mismas tres categorías que exige
/// el Principio III: caso normal, límite y adverso.
void main() {
  CobroIngreso cobro(int centavos, {DateTime? fecha}) => CobroIngreso(
    id: null,
    fecha: fecha ?? DateTime(2026, 8, 10),
    monto: Dinero.deCentavos(centavos),
  );

  group('caso normal', () {
    test('dos cobros suman el total exacto', () {
      final total = totalIngreso([
        cobro(96000, fecha: DateTime(2026, 8, 15)),
        cobro(104000, fecha: DateTime(2026, 8, 30)),
      ]);

      expect(total, const Dinero.deCentavos(200000));
    });

    test('no depende del orden de la lista', () {
      final ascendente = totalIngreso([cobro(96000), cobro(104000)]);
      final descendente = totalIngreso([cobro(104000), cobro(96000)]);

      expect(ascendente, descendente);
    });

    test(
      'un único cobro da el mismo resultado que un ingreso único (SC-003)',
      () {
        expect(totalIngreso([cobro(200000)]), const Dinero.deCentavos(200000));
      },
    );
  });

  group('límite: sin cobros', () {
    test('una lista vacía da null, nunca Dinero.cero (FR-005)', () {
      expect(totalIngreso(const []), isNull);
      expect(totalIngreso(const []), isNot(Dinero.cero));
    });
  });

  group('caso adverso', () {
    test('corregir un cobro no arrastra el monto viejo', () {
      // Simula lo que hace EstadoMes tras actualizarCobro: recalcula sobre
      // la lista ya corregida, no sobre la anterior.
      final antes = totalIngreso([cobro(96000), cobro(104000)]);
      final despues = totalIngreso([cobro(96000), cobro(100000)]);

      expect(antes, const Dinero.deCentavos(200000));
      expect(despues, const Dinero.deCentavos(196000));
    });

    test('eliminar uno de dos cobros deja el total como el restante', () {
      final total = totalIngreso([cobro(96000)]);
      expect(total, const Dinero.deCentavos(96000));
    });
  });
}
