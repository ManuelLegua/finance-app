import 'package:finanzas/shared/tipos/dinero.dart';

/// Los totales de un mes y su estado de déficit (FR-025 a FR-030).
///
/// Es un **derivado**: no se persiste, se recalcula cada vez a partir del
/// ingreso, las obligaciones guardadas y las cuotas de deuda vigentes.
final class ResumenMes {
  /// `null` cuando el mes no tiene ingreso registrado, que no es lo mismo que
  /// un sueldo de S/ 0.00 (HU2 escenario 4).
  final Dinero? ingreso;

  /// Obligaciones guardadas más cuotas de deuda vigentes (FR-016, FR-025).
  final Dinero totalComprometido;

  /// Suma de las transacciones reales del mes (FR-009).
  final Dinero gastoRealTotal;

  const ResumenMes({
    required this.ingreso,
    required this.totalComprometido,
    required this.gastoRealTotal,
  });

  bool get ingresoRegistrado => ingreso != null;

  /// Ingreso menos comprometido (FR-026). Guía la decisión de ahorro al
  /// inicio del mes.
  Dinero get disponibleProyectado =>
      (ingreso ?? Dinero.cero) - totalComprometido;

  /// Ingreso menos gasto efectivo (FR-027). Refleja lo que ya ocurrió.
  ///
  /// Convive con el proyectado a propósito: la app muestra ambos y no fuerza
  /// a elegir uno.
  Dinero get disponibleReal => (ingreso ?? Dinero.cero) - gastoRealTotal;

  /// Los compromisos superan al ingreso (FR-028).
  ///
  /// Un disponible de exactamente cero **no** es déficit (FR-030), y sin
  /// ingreso registrado tampoco: no hay contra qué comparar.
  bool get enDeficit => ingresoRegistrado && totalComprometido > ingreso!;

  /// Cuánto falta para cubrir los compromisos, en positivo. Cero si no hay
  /// déficit.
  Dinero get faltante => enDeficit ? disponibleProyectado.abs() : Dinero.cero;

  @override
  bool operator ==(Object other) =>
      other is ResumenMes &&
      other.ingreso == ingreso &&
      other.totalComprometido == totalComprometido &&
      other.gastoRealTotal == gastoRealTotal;

  @override
  int get hashCode => Object.hash(ingreso, totalComprometido, gastoRealTotal);

  @override
  String toString() =>
      'ResumenMes(ingreso: $ingreso, comprometido: $totalComprometido, '
      'gastoReal: $gastoRealTotal)';
}
