import 'package:finanzas/dominio/calculos/resumen_mes.dart';
import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter_test/flutter_test.dart';

/// FR-025 a FR-030: totales del mes, disponible y estado de déficit.
///
/// Los tres casos que exige la constitución están cubiertos: el normal, el
/// límite (disponible exactamente cero) y el adverso (déficit).
void main() {
  const agosto = Mes(2026, 8);

  Obligacion obligacionDe(int centavos) => Obligacion(
    id: null,
    mes: agosto,
    nombre: 'x',
    categoria: Categoria.servicios,
    monto: Dinero.deCentavos(centavos),
    tipo: TipoObligacion.fija,
  );

  group('caso normal', () {
    test('ingreso 3,000 y presupuesto 1,800 dejan 1,200 disponibles', () {
      final resumen = calcularResumenMes(
        ingreso: const Dinero.deCentavos(300000),
        obligaciones: [obligacionDe(180000)],
      );

      expect(resumen.ingreso, const Dinero.deCentavos(300000));
      expect(resumen.totalComprometido, const Dinero.deCentavos(180000));
      expect(resumen.disponibleProyectado, const Dinero.deCentavos(120000));
      expect(resumen.enDeficit, isFalse);
      expect(resumen.faltante, Dinero.cero);
    });

    test('suma varias obligaciones', () {
      final resumen = calcularResumenMes(
        ingreso: const Dinero.deCentavos(300000),
        obligaciones: [
          obligacionDe(90000),
          obligacionDe(12000),
          obligacionDe(20000),
          obligacionDe(60000),
        ],
      );

      expect(resumen.totalComprometido, const Dinero.deCentavos(182000));
      expect(resumen.disponibleProyectado, const Dinero.deCentavos(118000));
    });
  });

  group('déficit (FR-028)', () {
    test('ingreso 2,000 y presupuesto 2,350 faltan 350', () {
      final resumen = calcularResumenMes(
        ingreso: const Dinero.deCentavos(200000),
        obligaciones: [obligacionDe(235000)],
      );

      expect(resumen.enDeficit, isTrue);
      // El faltante se expresa en positivo: es lo que hay que conseguir.
      expect(resumen.faltante, const Dinero.deCentavos(35000));
      expect(resumen.disponibleProyectado, const Dinero.deCentavos(-35000));
    });

    test('un solo centavo de más ya es déficit', () {
      final resumen = calcularResumenMes(
        ingreso: const Dinero.deCentavos(300000),
        obligaciones: [obligacionDe(300001)],
      );

      expect(resumen.enDeficit, isTrue);
      expect(resumen.faltante, const Dinero.deCentavos(1));
    });
  });

  group('límite: saldo exactamente cero (FR-030)', () {
    test('el presupuesto que iguala al ingreso NO es déficit', () {
      final resumen = calcularResumenMes(
        ingreso: const Dinero.deCentavos(300000),
        obligaciones: [obligacionDe(300000)],
      );

      expect(resumen.disponibleProyectado, Dinero.cero);
      expect(resumen.enDeficit, isFalse);
      expect(resumen.faltante, Dinero.cero);
    });
  });

  group('mes sin ingreso registrado', () {
    test('lo señala en vez de tratarlo como ingreso cero', () {
      final resumen = calcularResumenMes(
        ingreso: null,
        obligaciones: [obligacionDe(90000)],
      );

      // HU2 escenario 4: la app pide registrar el ingreso en vez de mostrar
      // totales en cero como si fueran válidos.
      expect(resumen.ingresoRegistrado, isFalse);
      expect(resumen.ingreso, isNull);
      expect(resumen.totalComprometido, const Dinero.deCentavos(90000));
    });

    test('sin ingreso no se declara déficit: no hay contra qué comparar', () {
      final resumen = calcularResumenMes(
        ingreso: null,
        obligaciones: [obligacionDe(90000)],
      );

      expect(resumen.enDeficit, isFalse);
      expect(resumen.faltante, Dinero.cero);
    });

    test('un mes completamente vacío no rompe', () {
      final resumen = calcularResumenMes(ingreso: null, obligaciones: const []);

      expect(resumen.ingresoRegistrado, isFalse);
      expect(resumen.totalComprometido, Dinero.cero);
      expect(resumen.disponibleProyectado, Dinero.cero);
      expect(resumen.enDeficit, isFalse);
    });
  });

  group('cuotas de deuda vigentes (FR-016)', () {
    test('se suman al comprometido junto con las obligaciones', () {
      // Las cuotas llegan ya sumadas: se derivan de las deudas en US4 (D3),
      // no se guardan como obligaciones.
      final resumen = calcularResumenMes(
        ingreso: const Dinero.deCentavos(300000),
        obligaciones: [obligacionDe(180000)],
        cuotasVigentes: const Dinero.deCentavos(23000),
      );

      expect(resumen.totalComprometido, const Dinero.deCentavos(203000));
      expect(resumen.disponibleProyectado, const Dinero.deCentavos(97000));
    });

    test('las cuotas solas pueden provocar el déficit', () {
      final resumen = calcularResumenMes(
        ingreso: const Dinero.deCentavos(100000),
        obligaciones: [obligacionDe(90000)],
        cuotasVigentes: const Dinero.deCentavos(23000),
      );

      expect(resumen.enDeficit, isTrue);
      expect(resumen.faltante, const Dinero.deCentavos(13000));
    });
  });

  group('disponible real (FR-027)', () {
    test('es el ingreso menos el gasto efectivo, no el presupuestado', () {
      final resumen = calcularResumenMes(
        ingreso: const Dinero.deCentavos(300000),
        obligaciones: [obligacionDe(180000)],
        gastoRealTotal: const Dinero.deCentavos(45000),
      );

      // Proyectado y real conviven: uno guía la decisión de ahorro a inicio
      // de mes, el otro refleja lo ocurrido.
      expect(resumen.disponibleProyectado, const Dinero.deCentavos(120000));
      expect(resumen.disponibleReal, const Dinero.deCentavos(255000));
    });

    test('sin gastos registrados el real iguala al ingreso', () {
      final resumen = calcularResumenMes(
        ingreso: const Dinero.deCentavos(300000),
        obligaciones: [obligacionDe(180000)],
      );

      expect(resumen.disponibleReal, const Dinero.deCentavos(300000));
    });

    test('gastar de más deja el real negativo', () {
      final resumen = calcularResumenMes(
        ingreso: const Dinero.deCentavos(300000),
        obligaciones: const [],
        gastoRealTotal: const Dinero.deCentavos(320000),
      );

      expect(resumen.disponibleReal, const Dinero.deCentavos(-20000));
    });
  });

  group('exactitud', () {
    test('montos de siete cifras se calculan sin perder centavos', () {
      final resumen = calcularResumenMes(
        ingreso: const Dinero.deCentavos(999999999),
        obligaciones: [obligacionDe(123456789)],
      );

      expect(resumen.disponibleProyectado, const Dinero.deCentavos(876543210));
    });

    test('muchas obligaciones de un centavo suman exacto', () {
      final resumen = calcularResumenMes(
        ingreso: const Dinero.deCentavos(100000),
        obligaciones: List.generate(1000, (_) => obligacionDe(1)),
      );

      expect(resumen.totalComprometido, const Dinero.deCentavos(1000));
    });
  });

  group('igualdad por valor', () {
    test('dos resúmenes con los mismos datos son iguales', () {
      ResumenMes construir() => calcularResumenMes(
        ingreso: const Dinero.deCentavos(300000),
        obligaciones: [obligacionDe(180000)],
      );

      expect(construir(), construir());
    });
  });
}
