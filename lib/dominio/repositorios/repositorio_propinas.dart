import 'package:finanzas/dominio/modelos/propina.dart';

/// Los montos de apoyo y el flujo de compra (spec 004 revisada).
///
/// Es el único repositorio del proyecto que habla con un servicio externo
/// (Google Play Billing), amparado por la enmienda al Principio I (v2.0.0), y
/// el único que **no persiste nada**: no hay tabla detrás (research.md D8).
///
/// **Privacidad (FR-009)**: ningún método recibe ni devuelve `Dinero`,
/// `Deuda`, `Transaccion`, `AporteAhorro` ni ningún otro tipo del dominio
/// financiero. Lo único que cruza la red es el identificador del producto y el
/// token de compra que gestiona la propia Billing Library.
///
/// **Lo que esta interfaz deliberadamente no tiene**: ningún método que diga
/// si el usuario apoyó. Nada en la app puede depender de eso, y no exponerlo
/// es la forma estructural de garantizar FR-002 — no una convención que
/// alguien pueda saltarse más adelante.
abstract interface class RepositorioPropinas {
  /// Los montos vigentes en Google Play, en el orden de `idsDePropina`
  /// (FR-004).
  ///
  /// A diferencia de casi todo el resto del proyecto, sin conexión **sí
  /// lanza** `ErrorPersistencia.alLeer`: no hay nada útil que cachear acá,
  /// porque mostrar un precio viejo sería engañoso (FR-011).
  ///
  /// Antes de consultar, acusa recibo de cualquier compra que haya quedado
  /// pendiente de una sesión anterior (FR-010).
  Future<List<OfertaPropina>> ofertasDisponibles();

  /// Lanza el flujo de compra de Google Play para [oferta] y devuelve cómo
  /// terminó.
  ///
  /// Que el usuario cancele **no es un error**: devuelve
  /// `ResultadoPropina.cancelada` sin lanzar (FR-008).
  Future<ResultadoPropina> apoyar(OfertaPropina oferta);
}
