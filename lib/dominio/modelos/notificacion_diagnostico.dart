import 'package:finanzas/shared/constantes/enums.dart';

/// Una notificación de un origen reconocido que no se pudo interpretar
/// (spec 002, FR-017, FR-018).
///
/// El origen **es** reconocido — está en `origenesReconocidos` — solo falló
/// el texto puntual. Es el único lugar de la app donde se guarda texto de
/// notificación sin interpretar: consultable y borrable por el usuario
/// (FR-018), nunca transmitido (FR-019).
final class NotificacionDiagnostico {
  final int? id;
  final String origenPaquete;
  final MotivoDiagnostico motivo;
  final String textoCrudo;
  final DateTime fecha;

  const NotificacionDiagnostico({
    required this.id,
    required this.origenPaquete,
    required this.motivo,
    required this.textoCrudo,
    required this.fecha,
  });

  @override
  bool operator ==(Object other) =>
      other is NotificacionDiagnostico &&
      other.id == id &&
      other.origenPaquete == origenPaquete &&
      other.motivo == motivo &&
      other.textoCrudo == textoCrudo &&
      other.fecha == fecha;

  @override
  int get hashCode => Object.hash(id, origenPaquete, motivo, textoCrudo, fecha);

  @override
  String toString() =>
      'NotificacionDiagnostico($origenPaquete, ${motivo.slug})';
}
