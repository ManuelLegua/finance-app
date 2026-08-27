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

  const Configuracion({
    required this.regla,
    required this.porcentajeBp,
    required this.diasGraciaCierre,
  });

  /// Lo que ve un usuario que abre la app por primera vez: sin obligarlo a
  /// configurar nada antes de poder usarla.
  static const Configuracion porDefecto = Configuracion(
    regla: ReglaAhorro.porcentajeIngreso,
    porcentajeBp: 2000,
    diasGraciaCierre: 5,
  );

  Configuracion copiarCon({
    ReglaAhorro? regla,
    int? porcentajeBp,
    int? diasGraciaCierre,
  }) =>
      Configuracion(
        regla: regla ?? this.regla,
        porcentajeBp: porcentajeBp ?? this.porcentajeBp,
        diasGraciaCierre: diasGraciaCierre ?? this.diasGraciaCierre,
      );

  @override
  bool operator ==(Object other) =>
      other is Configuracion &&
      other.regla == regla &&
      other.porcentajeBp == porcentajeBp &&
      other.diasGraciaCierre == diasGraciaCierre;

  @override
  int get hashCode => Object.hash(regla, porcentajeBp, diasGraciaCierre);

  @override
  String toString() =>
      'Configuracion(${regla.slug}, ${porcentajeBp}bp, '
      '$diasGraciaCierre días de gracia)';
}
