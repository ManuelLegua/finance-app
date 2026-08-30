import 'package:finanzas/shared/tipos/dinero.dart';

/// Lo que la bandeja de pendientes muestra sin abrir cada fila (spec 002,
/// FR-022, FR-028). Derivado, nunca se guarda.
final class ResumenPendientes {
  /// A partir de cuántos pendientes sin confirmar se señala la cantidad como
  /// inusual (FR-028). Constante de dominio, no configurable: no hay
  /// requisito que pida ajustarla.
  static const int umbralCantidadInusual = 20;

  final int cantidad;
  final Dinero montoTotal;

  const ResumenPendientes({required this.cantidad, required this.montoTotal});

  static const ResumenPendientes vacio = ResumenPendientes(
    cantidad: 0,
    montoTotal: Dinero.cero,
  );

  bool get esCantidadInusual => cantidad > umbralCantidadInusual;

  @override
  bool operator ==(Object other) =>
      other is ResumenPendientes &&
      other.cantidad == cantidad &&
      other.montoTotal == montoTotal;

  @override
  int get hashCode => Object.hash(cantidad, montoTotal);

  @override
  String toString() => 'ResumenPendientes($cantidad, ${montoTotal.centavos} c)';
}
