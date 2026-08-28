import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// Acceso a las obligaciones presupuestadas de cada mes (FR-002).
///
/// Devuelve **solo lo guardado**. Las cuotas de deuda no aparecen acá: se
/// derivan en la capa de cálculo (D3), y no existe tabla de cuotas.
abstract interface class RepositorioObligaciones {
  Future<List<Obligacion>> porMes(Mes mes);

  /// Solo las fijas: es el insumo de la precarga del mes siguiente (FR-006).
  Future<List<Obligacion>> fijasDeMes(Mes mes);

  /// Inserta y devuelve el id asignado.
  Future<int> insertar(Obligacion obligacion);

  /// Confirma la precarga completa de forma atómica.
  ///
  /// O entran todas o ninguna (FR-006): media precarga guardada dejaría al
  /// usuario con un presupuesto que nunca terminó de revisar.
  Future<void> insertarLote(List<Obligacion> obligaciones);

  /// Actualiza una obligación ya guardada.
  ///
  /// Lanza [ArgumentError] si la obligación no tiene id. Si el id no existe,
  /// es un no-op silencioso: el usuario ya no ve ese registro.
  Future<void> actualizar(Obligacion obligacion);

  Future<void> eliminar(int id);
}
