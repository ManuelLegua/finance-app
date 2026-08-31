import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';

/// Resultado de interpretar el texto de una notificación bancaria.
///
/// Contrato del parser genérico (spec 002, D-N2): un único parser interpreta
/// el texto de cualquier origen reconocido — no hay un intérprete por banco.
/// Ver contracts/interpretes.md de la spec.
sealed class ResultadoInterpretacion {
  const ResultadoInterpretacion();
}

/// La notificación es un consumo (dinero saliente) y se extrajeron sus
/// datos completos. **Nunca parcial ni inventado** (FR-017): si algún campo
/// no se puede extraer con confianza, el resultado es [NoInterpretable], no
/// un [ConsumoExtraido] con huecos.
final class ConsumoExtraido extends ResultadoInterpretacion {
  final Dinero monto;
  final String comercio;

  /// Fecha del consumo, no de recepción de la notificación.
  final DateTime fecha;

  const ConsumoExtraido({
    required this.monto,
    required this.comercio,
    required this.fecha,
  });
}

/// La notificación se interpretó, pero no es un consumo que registrar:
/// dinero entrante, un consumo rechazado o extornado, una promoción, etc.
/// (FR-012, FR-013).
final class NoEsConsumo extends ResultadoInterpretacion {
  const NoEsConsumo();
}

/// El texto no se pudo interpretar con confianza: formato desconocido,
/// monto ilegible o moneda distinta al sol (FR-014, FR-017).
final class NoInterpretable extends ResultadoInterpretacion {
  final MotivoDiagnostico motivo;

  const NoInterpretable(this.motivo);
}
