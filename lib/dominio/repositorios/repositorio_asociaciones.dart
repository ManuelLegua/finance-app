import 'package:finanzas/dominio/modelos/asociacion_comercio.dart';
import 'package:finanzas/shared/constantes/enums.dart';

/// Asociaciones aprendidas comercio → categoría (spec 002, FR-029 a FR-034).
abstract interface class RepositorioAsociaciones {
  /// `null` si el comercio nunca fue asociado — nunca una categoría por
  /// defecto inventada (FR-033).
  Future<Categoria?> categoriaDe(String comercioNormalizado);

  /// Upsert: sobre un comercio ya asociado reemplaza la categoría, no la
  /// duplica (FR-029, FR-031).
  Future<void> asociar(String comercioNormalizado, Categoria categoria);

  /// Para consultarlas y corregirlas (FR-034).
  Future<List<AsociacionComercio>> todas();

  Future<void> eliminar(String comercioNormalizado);
}
