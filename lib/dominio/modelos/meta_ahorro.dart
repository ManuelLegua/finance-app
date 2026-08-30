import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// Meta de ahorro propia de un mes (FR-035).
///
/// D12: la meta es **por mes**, no global. Con una meta única el historial
/// evaluaría los meses pasados contra la meta de hoy, y meses ya cumplidos
/// aparecerían como incumplidos apenas la meta subiera.
final class MetaAhorro {
  final Mes mes;
  final Dinero monto;

  const MetaAhorro({required this.mes, required this.monto});

  @override
  bool operator ==(Object other) =>
      other is MetaAhorro && other.mes == mes && other.monto == monto;

  @override
  int get hashCode => Object.hash(mes, monto);

  @override
  String toString() => 'MetaAhorro($mes, ${monto.centavos} c)';
}
