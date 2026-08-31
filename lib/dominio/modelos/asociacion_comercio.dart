import 'package:finanzas/shared/constantes/enums.dart';

/// Vínculo aprendido entre un comercio y la categoría con la que el usuario
/// suele confirmarlo (spec 002, FR-029 a FR-034).
final class AsociacionComercio {
  /// Salida de `normalizarComercio()` (D-N7), no el texto crudo — es la
  /// clave primaria en la base.
  final String comercioNormalizado;

  final Categoria categoria;

  /// Se reescribe cada vez que el usuario confirma ese comercio con una
  /// categoría distinta (FR-031).
  final DateTime actualizadoEn;

  const AsociacionComercio({
    required this.comercioNormalizado,
    required this.categoria,
    required this.actualizadoEn,
  });

  @override
  bool operator ==(Object other) =>
      other is AsociacionComercio &&
      other.comercioNormalizado == comercioNormalizado &&
      other.categoria == categoria &&
      other.actualizadoEn == actualizadoEn;

  @override
  int get hashCode =>
      Object.hash(comercioNormalizado, categoria, actualizadoEn);

  @override
  String toString() =>
      'AsociacionComercio($comercioNormalizado -> ${categoria.slug})';
}
