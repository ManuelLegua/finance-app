import 'package:finanzas/dominio/calculos/presupuesto.dart';
import 'package:finanzas/dominio/modelos/linea_categoria.dart';
import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/dominio/modelos/transaccion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';

export 'package:finanzas/dominio/modelos/linea_categoria.dart';

/// Compara lo presupuestado con lo realmente gastado, categoría por categoría
/// (FR-009 a FR-012).
///
/// Solo devuelve las categorías con presupuesto **o** gasto en el mes: las que
/// no tienen ninguno se omiten en vez de mostrarse en cero (FR-047), porque
/// una fila en `S/ 0.00` ocupa lugar y no dice nada.
///
/// Las líneas quedan ordenadas de mayor a menor `gastado` (FR-044), y cada
/// una lleva su peso sobre [ingreso] en puntos base (FR-045).
List<LineaCategoria> calcularDesglose({
  required List<Obligacion> obligaciones,
  required List<Transaccion> transacciones,
  Dinero cuotasVigentes = Dinero.cero,
  Dinero? ingreso,
}) {
  final presupuestadoPorCategoria = totalPorCategoria(obligaciones);
  if (cuotasVigentes.esPositivo) {
    // Las cuotas se derivan de las deudas (D3) y llegan ya sumadas: entran
    // como presupuesto de tarjeta de crédito, que es la única categoría cuyo
    // compromiso no se escribe a mano.
    final yaPresupuestado =
        presupuestadoPorCategoria[Categoria.tarjetaCredito] ?? Dinero.cero;
    presupuestadoPorCategoria[Categoria.tarjetaCredito] =
        yaPresupuestado + cuotasVigentes;
  }

  final gastadoPorCategoria = _totalPorCategoria(transacciones);

  final conActividad = <Categoria>{
    ...presupuestadoPorCategoria.keys,
    ...gastadoPorCategoria.keys,
  };

  final lineas = [
    for (final categoria in Categoria.values)
      if (conActividad.contains(categoria))
        LineaCategoria(
          categoria: categoria,
          presupuestado: presupuestadoPorCategoria[categoria] ?? Dinero.cero,
          gastado: gastadoPorCategoria[categoria] ?? Dinero.cero,
          pesoIngresoBp: _pesoIngresoBp(
            gastado: gastadoPorCategoria[categoria] ?? Dinero.cero,
            ingreso: ingreso,
          ),
        ),
  ];

  lineas.sort((a, b) => b.gastado.compareTo(a.gastado));
  return lineas;
}

/// Puntos base de [gastado] sobre [ingreso], redondeados al más cercano
/// (medio hacia arriba). Cero si no hay ingreso o es cero: no hay división
/// por cero, solo un peso que aún no se puede calcular.
int _pesoIngresoBp({required Dinero gastado, required Dinero? ingreso}) {
  if (ingreso == null || !ingreso.esPositivo) {
    return 0;
  }
  final producto = gastado.centavos * 10000;
  return (producto + ingreso.centavos ~/ 2) ~/ ingreso.centavos;
}

/// Gasto real del mes (FR-009).
///
/// Es la misma suma que alimenta `disponibleReal` en el resumen, para que no
/// existan dos maneras de calcularla que puedan discrepar.
Dinero totalGastado(List<Transaccion> transacciones) => transacciones.fold(
  Dinero.cero,
  (acumulado, transaccion) => acumulado + transaccion.monto,
);

Map<Categoria, Dinero> _totalPorCategoria(List<Transaccion> transacciones) {
  final totales = <Categoria, Dinero>{};
  for (final transaccion in transacciones) {
    final acumulado = totales[transaccion.categoria] ?? Dinero.cero;
    totales[transaccion.categoria] = acumulado + transaccion.monto;
  }
  return totales;
}
