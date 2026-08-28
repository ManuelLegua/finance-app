import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';

/// Una categoría del mes con lo presupuestado y lo realmente gastado
/// (FR-010 a FR-012).
///
/// `sobregirada` y `noPresupuestada` son **campos, no colores**: la
/// constitución prohíbe comunicar un estado solo por color, y tenerlos como
/// datos deja que cada pantalla los muestre con ícono y texto.
final class LineaCategoria {
  final Categoria categoria;

  /// Obligaciones guardadas de la categoría, más las cuotas vigentes si es
  /// `tarjetaCredito` (FR-016).
  final Dinero presupuestado;

  /// Suma de las transacciones reales de la categoría en el mes.
  final Dinero gastado;

  const LineaCategoria({
    required this.categoria,
    required this.presupuestado,
    required this.gastado,
  });

  /// Lo que queda. Negativa cuando hay sobregiro.
  Dinero get diferencia => presupuestado - gastado;

  /// Se gastó más de lo presupuestado (FR-011).
  ///
  /// Una categoría sin presupuesto **no** cuenta como sobregirada: no había
  /// nada que exceder. Ese caso es `noPresupuestada`.
  bool get sobregirada => presupuestado.esPositivo && gastado > presupuestado;

  /// Cuánto se pasó, en positivo. Cero si no hay sobregiro.
  Dinero get exceso => sobregirada ? diferencia.abs() : Dinero.cero;

  /// Hubo gasto en una categoría que no estaba presupuestada (FR-012).
  ///
  /// Se registra igual y se contabiliza en el total: la app informa, no
  /// bloquea (FR-014).
  bool get noPresupuestada => presupuestado.esCero && gastado.esPositivo;

  @override
  bool operator ==(Object other) =>
      other is LineaCategoria &&
      other.categoria == categoria &&
      other.presupuestado == presupuestado &&
      other.gastado == gastado;

  @override
  int get hashCode => Object.hash(categoria, presupuestado, gastado);

  @override
  String toString() =>
      'LineaCategoria(${categoria.slug}, presupuestado: '
      '${presupuestado.centavos} c, gastado: ${gastado.centavos} c)';
}
