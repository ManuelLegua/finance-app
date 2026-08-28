import 'package:finanzas/dominio/modelos/tarjeta.dart';

/// Gestión de tarjetas (FR-059).
abstract interface class RepositorioTarjetas {
  Future<List<Tarjeta>> todas();

  /// Las únicas que admiten deudas en cuotas (FR-061). Alimenta el selector
  /// del formulario de deuda.
  Future<List<Tarjeta>> deCredito();

  Future<int> insertar(Tarjeta tarjeta);

  Future<void> actualizar(Tarjeta tarjeta);

  /// Borra la tarjeta. **Falla si tiene deudas asociadas**: la integridad
  /// referencial no se resuelve borrando en cascada datos financieros del
  /// usuario.
  Future<void> eliminar(int id);
}
