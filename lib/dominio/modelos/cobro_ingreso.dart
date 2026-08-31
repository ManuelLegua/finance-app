import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// Un cobro de sueldo (FR-001).
///
/// El sueldo del mes puede llegar en más de un cobro (quincena, fin de mes,
/// etc.); el total del mes es la suma de sus `CobroIngreso` (`totalIngreso`
/// en `lib/dominio/calculos/ingreso.dart`), no un dato guardado directamente.
/// Reemplaza a `Ingreso` (un monto único por mes) de la spec 001.
final class CobroIngreso {
  /// `null` mientras no esté guardado.
  final int? id;

  /// Solo fecha, sin hora. Determina a qué mes pertenece el cobro (FR-002),
  /// igual que `Transaccion` y `AporteAhorro`.
  final DateTime fecha;

  final Dinero monto;

  const CobroIngreso({
    required this.id,
    required this.fecha,
    required this.monto,
  });

  /// El mes al que pertenece, derivado siempre de la fecha.
  Mes get mes => Mes.deFecha(fecha);

  bool get estaGuardado => id != null;

  CobroIngreso copiarCon({
    int? id,
    DateTime? fecha,
    Dinero? monto,
    bool limpiarId = false,
  }) => CobroIngreso(
    id: limpiarId ? null : (id ?? this.id),
    fecha: fecha ?? this.fecha,
    monto: monto ?? this.monto,
  );

  @override
  bool operator ==(Object other) =>
      other is CobroIngreso &&
      other.id == id &&
      other.fecha == fecha &&
      other.monto == monto;

  @override
  int get hashCode => Object.hash(id, fecha, monto);

  @override
  String toString() =>
      'CobroIngreso(${monto.centavos} c, '
      '${fecha.toIso8601String().substring(0, 10)})';
}
