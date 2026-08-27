import '../../core/dinero.dart';
import '../../core/mes.dart';

/// Lo que el usuario percibe en un mes (FR-001).
///
/// Un ingreso por mes: la spec asume un sueldo mensual único, sin
/// gratificaciones ni extraordinarios en esta versión.
///
/// La **ausencia** de un ingreso no es lo mismo que un ingreso de cero. Un mes
/// sin registrar hace que la app pida registrarlo, en vez de mostrar totales
/// en cero como si fueran válidos (HU2 escenario 4). Por eso los repositorios
/// devuelven `Dinero?` y no `Dinero`.
final class Ingreso {
  final Mes mes;
  final Dinero monto;

  const Ingreso({required this.mes, required this.monto});

  @override
  bool operator ==(Object other) =>
      other is Ingreso && other.mes == mes && other.monto == monto;

  @override
  int get hashCode => Object.hash(mes, monto);

  @override
  String toString() => 'Ingreso($mes, ${monto.centavos} c)';
}
