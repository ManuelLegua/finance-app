import 'package:finanzas/shared/constantes/enums.dart';

/// Estado de la suscripción premium, tal como lo informó Google Play la
/// última vez que se pudo consultar (spec 004).
///
/// Es una fila única cacheada en local, análoga a `Configuracion`: existe
/// para que abrir una pantalla premium no exija conexión (edge case "sin
/// conexión" de la spec). Lo que decide el acceso es [estaVigente].
final class EstadoSuscripcion {
  final SituacionSuscripcion situacion;

  /// `null` solo cuando nunca hubo una suscripción.
  final PlanSuscripcion? plan;

  /// Hasta cuándo cubre el período vigente. **Informativo**: no participa de
  /// [estaVigente] (ver D2 de research.md).
  final DateTime? vigenteHasta;

  /// Cuándo se confirmó este estado contra Google Play por última vez. Sirve
  /// para que la UI pueda decir hace cuánto no se verifica, no para invalidar
  /// el caché sola.
  final DateTime ultimaVerificacion;

  const EstadoSuscripcion({
    required this.situacion,
    required this.plan,
    required this.vigenteHasta,
    required this.ultimaVerificacion,
  });

  /// El punto de partida: nadie se suscribió todavía.
  const EstadoSuscripcion.nunca({required this.ultimaVerificacion})
    : situacion = SituacionSuscripcion.nunca,
      plan = null,
      vigenteHasta = null;

  /// Si el acceso premium (Deudas, Ahorro y captura de notificaciones) está
  /// concedido ahora mismo.
  ///
  /// **Sale solo de [situacion]**, que es la que Google Play ya evaluó. No se
  /// recalcula comparando [vigenteHasta] contra la fecha del dispositivo a
  /// propósito: dos relojes potencialmente desincronizados no deben decidir
  /// algo tan sensible como un acceso pago (D2 de research.md).
  ///
  /// `enGracia` concede acceso porque el margen tras un cobro fallido lo fija
  /// Google, no la app (FR-013).
  bool get estaVigente => switch (situacion) {
    SituacionSuscripcion.enPrueba ||
    SituacionSuscripcion.activa ||
    SituacionSuscripcion.enGracia => true,
    SituacionSuscripcion.nunca ||
    SituacionSuscripcion.vencida ||
    SituacionSuscripcion.cancelada => false,
  };

  EstadoSuscripcion copiaCon({
    SituacionSuscripcion? situacion,
    PlanSuscripcion? plan,
    DateTime? vigenteHasta,
    DateTime? ultimaVerificacion,
  }) => EstadoSuscripcion(
    situacion: situacion ?? this.situacion,
    plan: plan ?? this.plan,
    vigenteHasta: vigenteHasta ?? this.vigenteHasta,
    ultimaVerificacion: ultimaVerificacion ?? this.ultimaVerificacion,
  );

  @override
  bool operator ==(Object other) =>
      other is EstadoSuscripcion &&
      other.situacion == situacion &&
      other.plan == plan &&
      other.vigenteHasta == vigenteHasta &&
      other.ultimaVerificacion == ultimaVerificacion;

  @override
  int get hashCode =>
      Object.hash(situacion, plan, vigenteHasta, ultimaVerificacion);

  @override
  String toString() =>
      'EstadoSuscripcion(${situacion.slug}, plan: ${plan?.slug})';
}

/// Un plan disponible para comprar, tal como lo ofrece Google Play (FR-005).
///
/// No se persiste: se consulta en vivo para armar el paywall. Sin conexión el
/// paywall lo dice y ofrece reintentar — nunca se inventa un precio.
final class OfertaSuscripcion {
  final PlanSuscripcion plan;

  /// Ya viene localizado y formateado por Google Play (ej. `"S/ 19.90 al
  /// mes"`).
  ///
  /// Es un texto, no un [Dinero] a propósito: no es un monto que la app
  /// calcule ni guarde, así que el Principio II no le aplica. Sobre este
  /// valor no se hace aritmética ni se parsea nada.
  final String precioFormateado;

  /// Días de prueba gratis de esta oferta (FR-006a).
  final int duracionPruebaDias;

  const OfertaSuscripcion({
    required this.plan,
    required this.precioFormateado,
    required this.duracionPruebaDias,
  });

  @override
  bool operator ==(Object other) =>
      other is OfertaSuscripcion &&
      other.plan == plan &&
      other.precioFormateado == precioFormateado &&
      other.duracionPruebaDias == duracionPruebaDias;

  @override
  int get hashCode => Object.hash(plan, precioFormateado, duracionPruebaDias);
}
