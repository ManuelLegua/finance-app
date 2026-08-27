import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:flutter_test/flutter_test.dart';

/// Principio II (no negociable): el dinero es un entero de centavos.
///
/// Estas pruebas se escriben antes que `Dinero` y cubren el caso normal, el
/// límite (cero exacto) y el adverso (negativos, que aparecen en déficit).
void main() {
  group('construcción', () {
    test('desde centavos guarda el entero tal cual', () {
      expect(const Dinero.deCentavos(123456).centavos, 123456);
    });

    test('desde soles y céntimos compone el entero', () {
      expect(Dinero.deSoles(1234, 56).centavos, 123456);
      expect(Dinero.deSoles(0, 5).centavos, 5);
      expect(Dinero.deSoles(3000).centavos, 300000);
    });

    test('cero es cero', () {
      expect(Dinero.cero.centavos, 0);
    });

    test('rechaza céntimos fuera de 0..99', () {
      expect(() => Dinero.deSoles(10, 100), throwsArgumentError);
      expect(() => Dinero.deSoles(10, -1), throwsArgumentError);
    });
  });

  group('aritmética entera', () {
    test('suma y resta son exactas', () {
      const a = Dinero.deCentavos(300000); // S/ 3,000.00
      const b = Dinero.deCentavos(180000); // S/ 1,800.00
      expect((a - b).centavos, 120000); // S/ 1,200.00
      expect((a + b).centavos, 480000);
    });

    test('la resta puede dar negativo: es el déficit', () {
      const ingreso = Dinero.deCentavos(200000); // S/ 2,000.00
      const comprometido = Dinero.deCentavos(235000); // S/ 2,350.00
      final disponible = ingreso - comprometido;
      expect(disponible.centavos, -35000); // faltan S/ 350.00
      expect(disponible.esNegativo, isTrue);
    });

    test('multiplicar por una cantidad de cuotas es exacto', () {
      const cuota = Dinero.deCentavos(15000); // S/ 150.00
      expect((cuota * 12).centavos, 180000); // S/ 1,800.00
      expect((cuota * 0).centavos, 0);
    });

    test('sumar una lista larga no acumula error', () {
      // Con double, 1000 sumas de 0.01 no dan exactamente 10.00.
      final total = List.filled(
        1000,
        const Dinero.deCentavos(1),
      ).fold(Dinero.cero, (acc, d) => acc + d);
      expect(total.centavos, 1000);
    });

    test('la negación invierte el signo', () {
      expect((-const Dinero.deCentavos(500)).centavos, -500);
    });

    test('abs devuelve la magnitud, para expresar faltantes en positivo', () {
      expect(const Dinero.deCentavos(-35000).abs().centavos, 35000);
      expect(const Dinero.deCentavos(35000).abs().centavos, 35000);
    });
  });

  group('porcentaje en puntos base', () {
    test('20% de S/ 3,000.00 es S/ 600.00', () {
      const ingreso = Dinero.deCentavos(300000);
      expect(ingreso.porPuntosBase(2000).centavos, 60000);
    });

    test('0% da cero y 100% da el total', () {
      const ingreso = Dinero.deCentavos(300000);
      expect(ingreso.porPuntosBase(0).centavos, 0);
      expect(ingreso.porPuntosBase(10000).centavos, 300000);
    });

    test('redondea al centavo más cercano, medio hacia arriba', () {
      // 33.33% de S/ 10.00 = 333.3 centavos -> 333
      expect(const Dinero.deCentavos(1000).porPuntosBase(3333).centavos, 333);
      // 12.5% de S/ 1.00 = 12.5 centavos -> 13 (half-up)
      expect(const Dinero.deCentavos(100).porPuntosBase(1250).centavos, 13);
      // 12.4% de S/ 1.00 = 12.4 centavos -> 12
      expect(const Dinero.deCentavos(100).porPuntosBase(1240).centavos, 12);
    });

    test('rechaza puntos base fuera de 0..10000', () {
      const ingreso = Dinero.deCentavos(300000);
      expect(() => ingreso.porPuntosBase(-1), throwsArgumentError);
      expect(() => ingreso.porPuntosBase(10001), throwsArgumentError);
    });
  });

  group('comparación', () {
    const menor = Dinero.deCentavos(100);
    const mayor = Dinero.deCentavos(200);

    test('ordena por centavos', () {
      expect(menor < mayor, isTrue);
      expect(mayor > menor, isTrue);
      expect(menor <= const Dinero.deCentavos(100), isTrue);
      expect(mayor >= const Dinero.deCentavos(200), isTrue);
    });

    test('la igualdad es por valor', () {
      expect(const Dinero.deCentavos(100), const Dinero.deCentavos(100));
      expect(
        const Dinero.deCentavos(100).hashCode,
        const Dinero.deCentavos(100).hashCode,
      );
    });

    test('compareTo permite ordenar listas', () {
      final montos = <Dinero>[mayor, Dinero.cero, menor]..sort();
      expect(montos, [Dinero.cero, menor, mayor]);
    });
  });

  group('predicados de estado', () {
    test('cero exacto no es negativo ni positivo', () {
      expect(Dinero.cero.esCero, isTrue);
      expect(Dinero.cero.esNegativo, isFalse);
      expect(Dinero.cero.esPositivo, isFalse);
    });

    test('distingue positivo de negativo', () {
      expect(const Dinero.deCentavos(1).esPositivo, isTrue);
      expect(const Dinero.deCentavos(-1).esNegativo, isTrue);
    });
  });

  group('límites', () {
    test('soporta montos de siete cifras', () {
      final maximo = Dinero.deSoles(9999999, 99);
      expect(maximo.centavos, 999999999);
    });
  });
}
