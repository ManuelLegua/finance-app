import 'package:finanzas/dominio/modelos/estado_suscripcion.dart';
import 'package:finanzas/shared/constantes/enums.dart';

/// Acceso al estado de la suscripción premium y al flujo de compra (spec 004).
///
/// Es el único repositorio del proyecto que habla con un servicio externo
/// (Google Play Billing), amparado por la enmienda al Principio I (v2.0.0).
/// El resto de sus garantías son las de cualquier repositorio de acá: la UI
/// no conoce el SDK de facturación, solo esta interfaz.
///
/// **Privacidad (FR-016)**: ningún método recibe ni devuelve `Dinero`,
/// `Deuda`, `Transaccion`, `AporteAhorro` ni ningún otro tipo del dominio
/// financiero. Lo único que cruza la red es el identificador del producto y
/// el token de compra que gestiona la propia Billing Library.
///
/// **Decidir si el acceso premium está concedido no es de este repositorio**:
/// eso es `EstadoSuscripcion.estaVigente`, en el dominio.
abstract interface class RepositorioSuscripcion {
  /// Lee el estado guardado en local, **sin tocar la red**. Nunca falla por
  /// falta de conexión: si nunca hubo una fila, devuelve un estado con
  /// `situacion = nunca`.
  Future<EstadoSuscripcion> estadoCacheado();

  /// Consulta Google Play y actualiza el estado local con lo que responda.
  ///
  /// Sin conexión **no lanza**: devuelve el [estadoCacheado] sin cambios, para
  /// que abrir una pantalla premium nunca dependa de la red.
  Future<EstadoSuscripcion> refrescar();

  /// Los planes y precios vigentes en Google Play, en vivo (FR-005).
  ///
  /// A diferencia de [estadoCacheado], sin conexión **sí lanza**
  /// `ErrorPersistencia.alLeer`: no hay nada útil que cachear acá, porque
  /// mostrar un precio viejo sería engañoso.
  Future<List<OfertaSuscripcion>> ofertasDisponibles();

  /// Lanza el flujo de compra de Google Play para [plan] y devuelve el estado
  /// resultante.
  ///
  /// Que el usuario cancele, o que Google rechace la compra, **no es un
  /// error**: es un flujo esperado (FR-008), así que devuelve el estado sin
  /// cambios en vez de lanzar.
  Future<EstadoSuscripcion> comprar(PlanSuscripcion plan);

  /// Recupera las compras ya asociadas a la cuenta de Google activa y
  /// actualiza el estado local (FR-014).
  ///
  /// Si no encuentra ninguna, devuelve un estado con `situacion = nunca`
  /// (FR-015): comunicar "no encontramos ninguna suscripción" es de la UI, no
  /// de acá.
  Future<EstadoSuscripcion> restaurar();
}
