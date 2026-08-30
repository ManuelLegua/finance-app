import 'package:finanzas/dominio/modelos/aporte_ahorro.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// Metas y aportes de ahorro (FR-031 a FR-043, FR-053, FR-054).
///
/// **Ningún método calcula reglas financieras** (contracts/repositorios.md):
/// suma en SQL solo lo que es un total plano de filas guardadas. Todo lo que
/// combina esos totales con el disponible o con la regla elegida vive en
/// `lib/dominio/calculos/ahorro.dart`.
abstract interface class RepositorioAhorro {
  /// La meta de [mes], o `null` si ese mes no tiene una fijada.
  ///
  /// `null` y una meta en un valor bajo son cosas distintas: cada mes
  /// conserva la suya, nunca la de hoy (FR-035, FR-054, D12).
  Future<Dinero?> metaDeMes(Mes mes);

  /// Fija o reemplaza la meta de [mes].
  Future<void> guardarMeta(Mes mes, Dinero monto);

  Future<void> eliminarMeta(Mes mes);

  /// Las metas hasta [mes] inclusive, en orden cronológico.
  ///
  /// Insumo de `proponerMetaDelMes` (FR-053): de ahí sale la meta del último
  /// mes anterior que tuvo una.
  Future<List<(Mes, Dinero)>> metasHasta(Mes mes);

  Future<List<AporteAhorro>> aportesPorMes(Mes mes);

  /// Suma de todos los aportes de todos los meses, con `SUM()` sobre enteros
  /// (FR-041, Principio II).
  Future<Dinero> acumuladoHistorico();

  /// Los meses entre [desde] y [hasta] que tienen aportes, con su total.
  ///
  /// Los meses del rango sin aportes **no aparecen acá**: los completa la
  /// capa de dominio con `S/ 0.00`, no se inventan filas (FR-043).
  Future<List<(Mes, Dinero)>> historialPorMes(Mes desde, Mes hasta);

  /// Inserta y devuelve el id asignado.
  Future<int> insertarAporte(AporteAhorro aporte);

  /// Lanza [ArgumentError] si no tiene id; un id inexistente es no-op.
  Future<void> actualizarAporte(AporteAhorro aporte);

  Future<void> eliminarAporte(int id);
}
