import 'package:finanzas/dominio/calculos/desglose_categorias.dart';
import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/dominio/modelos/transaccion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter_test/flutter_test.dart';

/// FR-009 a FR-012: acumulado por categoría, presupuestado contra gastado, y
/// las marcas de sobregiro y de gasto no presupuestado.
void main() {
  const agosto = Mes(2026, 8);

  Obligacion presupuesto(Categoria categoria, int centavos) => Obligacion(
    id: null,
    mes: agosto,
    nombre: categoria.etiqueta,
    categoria: categoria,
    monto: Dinero.deCentavos(centavos),
    tipo: TipoObligacion.variable,
  );

  Transaccion gasto(Categoria categoria, int centavos, {int dia = 15}) =>
      Transaccion(
        id: null,
        fecha: DateTime(2026, 8, dia),
        categoria: categoria,
        monto: Dinero.deCentavos(centavos),
        descripcion: '',
      );

  LineaCategoria lineaDe(List<LineaCategoria> lineas, Categoria categoria) =>
      lineas.firstWhere((linea) => linea.categoria == categoria);

  group('presupuestado contra gastado (FR-010)', () {
    test('comida S/ 45 de S/ 600 deja S/ 555 restantes', () {
      final lineas = calcularDesglose(
        obligaciones: [presupuesto(Categoria.comida, 60000)],
        transacciones: [gasto(Categoria.comida, 4500)],
      );

      final comida = lineaDe(lineas, Categoria.comida);
      expect(comida.presupuestado, const Dinero.deCentavos(60000));
      expect(comida.gastado, const Dinero.deCentavos(4500));
      expect(comida.diferencia, const Dinero.deCentavos(55500));
      expect(comida.sobregirada, isFalse);
    });

    test('varios gastos de una categoría se acumulan', () {
      final lineas = calcularDesglose(
        obligaciones: [presupuesto(Categoria.comida, 60000)],
        transacciones: [
          gasto(Categoria.comida, 4500),
          gasto(Categoria.comida, 3200),
          gasto(Categoria.comida, 1800),
        ],
      );

      expect(
        lineaDe(lineas, Categoria.comida).gastado,
        const Dinero.deCentavos(9500),
      );
    });

    test('varias obligaciones de una categoría se suman como presupuesto', () {
      final lineas = calcularDesglose(
        obligaciones: [
          presupuesto(Categoria.servicios, 12000),
          presupuesto(Categoria.servicios, 5000),
        ],
        transacciones: const [],
      );

      expect(
        lineaDe(lineas, Categoria.servicios).presupuestado,
        const Dinero.deCentavos(17000),
      );
    });
  });

  group('sobregiro (FR-011)', () {
    test('pasajes de S/ 200 con S/ 215 gastados se pasan por S/ 15', () {
      final lineas = calcularDesglose(
        obligaciones: [presupuesto(Categoria.pasajes, 20000)],
        transacciones: [
          gasto(Categoria.pasajes, 19000),
          gasto(Categoria.pasajes, 2500),
        ],
      );

      final pasajes = lineaDe(lineas, Categoria.pasajes);
      expect(pasajes.sobregirada, isTrue);
      // El exceso se expresa en positivo: es lo que hay que explicar.
      expect(pasajes.exceso, const Dinero.deCentavos(1500));
      expect(pasajes.diferencia, const Dinero.deCentavos(-1500));
    });

    test('gastar exactamente el presupuesto no es sobregiro', () {
      final lineas = calcularDesglose(
        obligaciones: [presupuesto(Categoria.comida, 60000)],
        transacciones: [gasto(Categoria.comida, 60000)],
      );

      final comida = lineaDe(lineas, Categoria.comida);
      expect(comida.sobregirada, isFalse);
      expect(comida.diferencia, Dinero.cero);
      expect(comida.exceso, Dinero.cero);
    });

    test('un centavo de más ya es sobregiro', () {
      final lineas = calcularDesglose(
        obligaciones: [presupuesto(Categoria.comida, 60000)],
        transacciones: [gasto(Categoria.comida, 60001)],
      );

      expect(lineaDe(lineas, Categoria.comida).sobregirada, isTrue);
      expect(
        lineaDe(lineas, Categoria.comida).exceso,
        const Dinero.deCentavos(1),
      );
    });
  });

  group('gasto sin presupuesto (FR-012)', () {
    test('se contabiliza y se marca como no presupuestado', () {
      final lineas = calcularDesglose(
        obligaciones: [presupuesto(Categoria.comida, 60000)],
        transacciones: [gasto(Categoria.otros, 8000)],
      );

      final otros = lineaDe(lineas, Categoria.otros);
      expect(otros.gastado, const Dinero.deCentavos(8000));
      expect(otros.presupuestado, Dinero.cero);
      expect(otros.noPresupuestada, isTrue);
      // No es "sobregiro": no había presupuesto que exceder.
      expect(otros.sobregirada, isFalse);
    });

    test('una categoría con presupuesto nunca se marca no presupuestada', () {
      final lineas = calcularDesglose(
        obligaciones: [presupuesto(Categoria.comida, 60000)],
        transacciones: [gasto(Categoria.comida, 4500)],
      );

      expect(lineaDe(lineas, Categoria.comida).noPresupuestada, isFalse);
    });
  });

  group('cuotas de deuda en la línea de tarjeta (FR-016)', () {
    test('entran como presupuestado de tarjetaCredito', () {
      // Las cuotas se derivan de las deudas (D3) y llegan ya sumadas.
      final lineas = calcularDesglose(
        obligaciones: const [],
        transacciones: const [],
        cuotasVigentes: const Dinero.deCentavos(23000),
      );

      final tarjeta = lineaDe(lineas, Categoria.tarjetaCredito);
      expect(tarjeta.presupuestado, const Dinero.deCentavos(23000));
      expect(tarjeta.gastado, Dinero.cero);
    });

    test('sin cuotas la categoría tarjeta no aparece', () {
      final lineas = calcularDesglose(
        obligaciones: [presupuesto(Categoria.comida, 60000)],
        transacciones: const [],
      );

      expect(
        lineas.where((linea) => linea.categoria == Categoria.tarjetaCredito),
        isEmpty,
      );
    });
  });

  group('categorías sin actividad (FR-047)', () {
    test('se omiten en vez de mostrarse en cero', () {
      final lineas = calcularDesglose(
        obligaciones: [presupuesto(Categoria.comida, 60000)],
        transacciones: [gasto(Categoria.pasajes, 2000)],
      );

      expect(lineas, hasLength(2));
      expect(
        lineas.map((linea) => linea.categoria),
        containsAll(<Categoria>[Categoria.comida, Categoria.pasajes]),
      );
    });

    test('un mes vacío devuelve lista vacía, no seis ceros', () {
      expect(
        calcularDesglose(obligaciones: const [], transacciones: const []),
        isEmpty,
      );
    });
  });

  group('exactitud (FR-046)', () {
    test('la suma de los gastados iguala el gasto real total', () {
      final transacciones = [
        gasto(Categoria.comida, 4500),
        gasto(Categoria.pasajes, 1200),
        gasto(Categoria.servicios, 12000),
        gasto(Categoria.comida, 3300),
        gasto(Categoria.otros, 999),
      ];

      final lineas = calcularDesglose(
        obligaciones: const [],
        transacciones: transacciones,
      );

      final sumaDeLineas = lineas.fold(
        Dinero.cero,
        (acumulado, linea) => acumulado + linea.gastado,
      );
      expect(sumaDeLineas, totalGastado(transacciones));
      expect(sumaDeLineas, const Dinero.deCentavos(21999));
    });

    test('mil gastos de un centavo suman exacto', () {
      final transacciones = List.generate(
        1000,
        (_) => gasto(Categoria.comida, 1),
      );

      expect(totalGastado(transacciones), const Dinero.deCentavos(1000));
    });
  });

  group('totalGastado', () {
    test('sin transacciones es cero, no null', () {
      expect(totalGastado(const []), Dinero.cero);
    });
  });
}
