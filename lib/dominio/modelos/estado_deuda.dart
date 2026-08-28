import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// En qué situación está una deuda respecto de un mes de referencia.
enum SituacionDeuda {
  /// Empieza después del mes de referencia: no aporta al presupuesto pero sí
  /// al total adeudado (FR-020).
  futura,

  /// Está aportando cuota.
  vigente,

  /// Terminó de pagarse, por vencimiento o anticipadamente (FR-019, FR-021).
  saldada,
}

/// Lo que se puede decir de una deuda en un mes dado (FR-018).
///
/// Todo derivado: no hay tabla de cuotas (D3).
final class EstadoDeuda {
  final SituacionDeuda situacion;

  /// Cuántas cuotas ya vencieron. **La del mes en curso no cuenta** (D4).
  final int cuotasPagadas;

  final int cuotasRestantes;

  /// Cuota por cuotas restantes. Cero si está saldada (FR-021).
  final Dinero saldoPendiente;

  final Mes mesUltimaCuota;

  const EstadoDeuda({
    required this.situacion,
    required this.cuotasPagadas,
    required this.cuotasRestantes,
    required this.saldoPendiente,
    required this.mesUltimaCuota,
  });

  bool get estaSaldada => situacion == SituacionDeuda.saldada;

  @override
  bool operator ==(Object other) =>
      other is EstadoDeuda &&
      other.situacion == situacion &&
      other.cuotasPagadas == cuotasPagadas &&
      other.cuotasRestantes == cuotasRestantes &&
      other.saldoPendiente == saldoPendiente &&
      other.mesUltimaCuota == mesUltimaCuota;

  @override
  int get hashCode => Object.hash(
    situacion,
    cuotasPagadas,
    cuotasRestantes,
    saldoPendiente,
    mesUltimaCuota,
  );

  @override
  String toString() =>
      'EstadoDeuda($situacion, $cuotasPagadas/$cuotasRestantes, '
      'saldo ${saldoPendiente.centavos} c)';
}

/// La foto completa de la deuda del usuario (FR-022).
final class PanoramaDeuda {
  /// Suma de los saldos pendientes, **incluidas las de inicio futuro**
  /// (FR-020).
  final Dinero totalAdeudado;

  /// Cuánto se paga de cuotas este mes.
  final Dinero compromisoMensual;

  /// Mes en que vence la última cuota de todas. `null` si no hay deudas
  /// activas: entonces la vista comunica el estado libre de deuda en vez de
  /// mostrarse vacía.
  final Mes? mesLibreDeDeudas;

  const PanoramaDeuda({
    required this.totalAdeudado,
    required this.compromisoMensual,
    required this.mesLibreDeDeudas,
  });

  bool get sinDeudas => mesLibreDeDeudas == null;

  @override
  bool operator ==(Object other) =>
      other is PanoramaDeuda &&
      other.totalAdeudado == totalAdeudado &&
      other.compromisoMensual == compromisoMensual &&
      other.mesLibreDeDeudas == mesLibreDeDeudas;

  @override
  int get hashCode =>
      Object.hash(totalAdeudado, compromisoMensual, mesLibreDeDeudas);

  @override
  String toString() =>
      'PanoramaDeuda(total ${totalAdeudado.centavos} c, '
      'mensual ${compromisoMensual.centavos} c, libre $mesLibreDeDeudas)';
}
