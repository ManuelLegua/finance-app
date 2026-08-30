import 'package:finanzas/dominio/modelos/consumo_pendiente.dart';
import 'package:finanzas/dominio/modelos/resumen_pendientes.dart';

/// Acceso a los consumos capturados y aún no confirmados (spec 002, FR-020 a
/// FR-028).
abstract interface class RepositorioPendientes {
  /// Todos los pendientes, del más reciente al más antiguo por fecha del
  /// consumo (FR-021).
  Future<List<ConsumoPendiente>> todos();

  /// Cantidad y monto total sin abrir cada fila (FR-022).
  Future<ResumenPendientes> resumen();

  /// Inserta un pendiente. Es un **upsert silencioso** sobre
  /// `(origenPaquete, notificacionId)` (D-N5): una notificación reeditada no
  /// produce una segunda fila ni un error (FR-015); dos notificaciones
  /// distintas siempre se conservan por separado, aunque monto y comercio
  /// coincidan (FR-016). Devuelve el id de la fila (nueva o ya existente).
  Future<int> insertar(ConsumoPendiente pendiente);

  /// Borra un pendiente — al confirmarlo (ya se creó la transacción o la
  /// deuda en 001) o al descartarlo (FR-020, FR-025). Un id inexistente es
  /// no-op silencioso.
  Future<void> eliminar(int id);
}
