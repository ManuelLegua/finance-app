import 'package:finanzas/shared/tipos/mes.dart';

/// Qué meses tienen datos registrados (FR-051).
///
/// Sostiene el selector de mes y la detección de "mes nuevo" que dispara la
/// propuesta de precarga de obligaciones fijas (FR-006).
abstract interface class RepositorioMeses {
  /// Todo mes con ingreso, obligación, transacción o aporte, en orden
  /// cronológico.
  Future<List<Mes>> mesesRegistrados();

  /// Si el mes tiene algún dato guardado.
  Future<bool> tieneDatos(Mes mes);
}
