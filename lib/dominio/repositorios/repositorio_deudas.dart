import 'package:finanzas/dominio/modelos/deuda.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// Deudas en cuotas (FR-015).
///
/// **No hay tabla de cuotas** (D3): actualizar una deuda es una sola
/// escritura y todos los meses quedan correctos al recalcularse (FR-023).
abstract interface class RepositorioDeudas {
  /// Todas, incluidas las de inicio futuro y las saldadas: el total adeudado
  /// las necesita (FR-020, FR-022).
  Future<List<Deuda>> todas();

  /// Las que no fueron saldadas anticipadamente.
  Future<List<Deuda>> activas();

  Future<List<Deuda>> porTarjeta(int tarjetaId);

  Future<int> insertar(Deuda deuda);

  Future<void> actualizar(Deuda deuda);

  /// Fija el mes desde el cual deja de aportar cuotas (FR-021). No toca las
  /// transacciones reales ya registradas.
  Future<void> marcarSaldada(int id, Mes mes);

  Future<void> eliminar(int id);
}
