import 'package:finanzas/dominio/modelos/transaccion.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// Acceso a los gastos reales (FR-007).
abstract interface class RepositorioTransacciones {
  /// Las transacciones del mes, de la fecha más reciente a la más antigua
  /// (FR-013). Dos del mismo día desempatan por id descendente, para que lo
  /// recién anotado quede arriba.
  Future<List<Transaccion>> porMes(Mes mes);

  /// Inserta y devuelve el id asignado.
  ///
  /// El mes se deriva de la fecha, siempre (FR-008).
  Future<int> insertar(Transaccion transaccion);

  /// Actualiza una transacción guardada. Cambiar la fecha la reubica de mes.
  ///
  /// Lanza [ArgumentError] si no tiene id; un id inexistente es no-op.
  Future<void> actualizar(Transaccion transaccion);

  Future<void> eliminar(int id);
}
