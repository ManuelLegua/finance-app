import 'package:finanzas/dominio/modelos/notificacion_diagnostico.dart';

/// Registro local de notificaciones que no se pudieron interpretar
/// (spec 002, FR-018).
abstract interface class RepositorioDiagnostico {
  /// De la más reciente a la más antigua.
  Future<List<NotificacionDiagnostico>> todos();

  Future<int> insertar(NotificacionDiagnostico entrada);

  Future<void> eliminar(int id);

  /// Borra todo el registro de una vez (FR-018 "borrable").
  Future<void> vaciar();
}
