import 'package:finanzas/shared/constantes/enums.dart';

/// Ajustes de la app. Fila única en la base de datos.
///
/// La **regla** de ahorro es global; la **meta** no: cada mes tiene la suya
/// (D12), porque con una meta única el historial evaluaría los meses pasados
/// contra la meta de hoy y meses ya cumplidos aparecerían como incumplidos.
final class Configuracion {
  /// Cómo se calcula el ahorro sugerido (FR-031).
  final ReglaAhorro regla;

  /// Porcentaje en puntos base: 20% = 2000 (FR-032).
  ///
  /// Se guarda en puntos base para no tener que almacenar decimales en
  /// ningún lado (D2).
  final int porcentajeBp;

  /// Días desde el inicio del mes durante los que todavía se puede registrar
  /// un pago con fecha del mes anterior (FR-055).
  final int diasGraciaCierre;

  /// Interruptor de la captura de notificaciones bancarias (spec 002,
  /// FR-005), independiente del permiso del sistema: apagarlo no revoca el
  /// permiso de Android, solo hace que la app descarte lo que reciba.
  final bool capturaNotificacionesActiva;

  const Configuracion({
    required this.regla,
    required this.porcentajeBp,
    required this.diasGraciaCierre,
    this.capturaNotificacionesActiva = false,
  });

  /// Lo que ve un usuario que abre la app por primera vez: sin obligarlo a
  /// configurar nada antes de poder usarla. La captura empieza inactiva
  /// hasta que el usuario la active a propósito (HU1 de la spec 002).
  static const Configuracion porDefecto = Configuracion(
    regla: ReglaAhorro.porcentajeIngreso,
    porcentajeBp: 2000,
    diasGraciaCierre: 5,
    capturaNotificacionesActiva: false,
  );

  Configuracion copiarCon({
    ReglaAhorro? regla,
    int? porcentajeBp,
    int? diasGraciaCierre,
    bool? capturaNotificacionesActiva,
  }) => Configuracion(
    regla: regla ?? this.regla,
    porcentajeBp: porcentajeBp ?? this.porcentajeBp,
    diasGraciaCierre: diasGraciaCierre ?? this.diasGraciaCierre,
    capturaNotificacionesActiva:
        capturaNotificacionesActiva ?? this.capturaNotificacionesActiva,
  );

  @override
  bool operator ==(Object other) =>
      other is Configuracion &&
      other.regla == regla &&
      other.porcentajeBp == porcentajeBp &&
      other.diasGraciaCierre == diasGraciaCierre &&
      other.capturaNotificacionesActiva == capturaNotificacionesActiva;

  @override
  int get hashCode => Object.hash(
    regla,
    porcentajeBp,
    diasGraciaCierre,
    capturaNotificacionesActiva,
  );

  @override
  String toString() =>
      'Configuracion(${regla.slug}, ${porcentajeBp}bp, '
      '$diasGraciaCierre días de gracia, '
      'captura: $capturaNotificacionesActiva)';
}
