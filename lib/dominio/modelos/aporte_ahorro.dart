import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// Dinero efectivamente apartado (FR-038).
///
/// Es el registro de lo que **ya ocurrió**, igual que `Transaccion` para los
/// gastos: la app no fuerza a elegir entre la sugerencia y lo real, muestra
/// las dos.
final class AporteAhorro {
  /// `null` mientras no esté guardado.
  final int? id;

  /// Solo fecha, sin hora. Determina a qué mes pertenece el aporte.
  final DateTime fecha;

  /// Puede exceder el disponible del mes (FR-042).
  final Dinero monto;

  const AporteAhorro({
    required this.id,
    required this.fecha,
    required this.monto,
  });

  /// El mes al que pertenece, derivado siempre de la fecha.
  Mes get mes => Mes.deFecha(fecha);

  bool get estaGuardado => id != null;

  AporteAhorro copiarCon({
    int? id,
    DateTime? fecha,
    Dinero? monto,
    bool limpiarId = false,
  }) => AporteAhorro(
    id: limpiarId ? null : (id ?? this.id),
    fecha: fecha ?? this.fecha,
    monto: monto ?? this.monto,
  );

  @override
  bool operator ==(Object other) =>
      other is AporteAhorro &&
      other.id == id &&
      other.fecha == fecha &&
      other.monto == monto;

  @override
  int get hashCode => Object.hash(id, fecha, monto);

  @override
  String toString() =>
      'AporteAhorro(${monto.centavos} c, '
      '${fecha.toIso8601String().substring(0, 10)})';
}
