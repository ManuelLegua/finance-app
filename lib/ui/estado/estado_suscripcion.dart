// ignore_for_file: prefer_initializing_formals
// Dart no admite parametros nombrados que empiecen con guion bajo, asi que
// los campos privados no pueden recibirse como `this._repo`.

import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/estado_suscripcion.dart' as dominio;
import 'package:finanzas/dominio/repositorios/repositorio_suscripcion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:flutter/foundation.dart';

export 'package:finanzas/dominio/modelos/estado_suscripcion.dart';

/// Estado de la suscripción premium para la UI (spec 004).
///
/// Se llama `EstadoSuscripcionPremium` y no `EstadoSuscripcion` para no
/// chocar con el modelo de dominio homónimo que este archivo reexporta —
/// mismo criterio que `EstadoCapturaNotificaciones` en la spec 002.
///
/// **Quién decide el acceso**: `dominio.EstadoSuscripcion.estaVigente`, no
/// esta clase. Acá solo se orquesta cuándo consultar y qué mostrar.
class EstadoSuscripcionPremium extends ChangeNotifier {
  EstadoSuscripcionPremium({required RepositorioSuscripcion repoSuscripcion})
    : _repoSuscripcion = repoSuscripcion;

  final RepositorioSuscripcion _repoSuscripcion;

  dominio.EstadoSuscripcion? _estado;
  List<dominio.OfertaSuscripcion> _ofertas = const [];
  bool _cargando = true;
  bool _comprando = false;
  bool _restaurando = false;
  String? _error;
  String? _errorDeOfertas;

  /// Si las pantallas premium (Deudas, Ahorro, captura) están accesibles.
  ///
  /// Mientras no se haya cargado nada todavía es `false`: nunca se concede
  /// acceso por omisión.
  bool get premiumActivo => _estado?.estaVigente ?? false;

  dominio.EstadoSuscripcion? get estado => _estado;

  SituacionSuscripcion get situacion =>
      _estado?.situacion ?? SituacionSuscripcion.nunca;

  PlanSuscripcion? get plan => _estado?.plan;

  List<dominio.OfertaSuscripcion> get ofertas => _ofertas;

  bool get cargando => _cargando;

  /// Si hay una compra esperando la confirmación de Google Play. El paywall
  /// lo dice con texto y deshabilita los botones mientras dure.
  bool get comprando => _comprando;

  /// Si hay una restauración en curso. Mismo criterio que [comprando]: la
  /// acción se deshabilita mientras dure, para que un doble toque no dispare
  /// dos consultas a Google Play.
  bool get restaurando => _restaurando;

  String? get error => _error;

  /// Por qué no se pudieron traer los planes. El paywall lo muestra con la
  /// opción de reintentar, en vez de inventar precios.
  String? get errorDeOfertas => _errorDeOfertas;

  /// Estado cacheado + refresco de mejor esfuerzo, más los planes de la
  /// tienda (D4 de research.md).
  ///
  /// Sin conexión el refresco no falla: se sigue con lo último conocido, para
  /// que abrir una pantalla premium nunca dependa de la red.
  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _estado = await _repoSuscripcion.estadoCacheado();
      _estado = await _repoSuscripcion.refrescar();
    } on Object catch (error) {
      _error = _mensajeDe(error);
    } finally {
      _cargando = false;
      notifyListeners();
    }

    await cargarOfertas();
  }

  /// Los planes y precios vigentes. A diferencia del estado, acá **sí**
  /// importa fallar: mostrar un precio viejo o inventado sería engañoso.
  Future<void> cargarOfertas() async {
    _errorDeOfertas = null;
    notifyListeners();

    try {
      _ofertas = await _repoSuscripcion.ofertasDisponibles();
    } on Object catch (error) {
      _ofertas = const [];
      _errorDeOfertas = _mensajeDe(error);
    }
    notifyListeners();
  }

  /// Lanza el flujo de compra de Google Play y deja el estado que resulte.
  ///
  /// Al terminar, quien escuche este notificador ve el acceso concedido sin
  /// reiniciar nada (FR-007): la guarda del cascarón se reconstruye sola.
  ///
  /// **Cancelar no es un error** (FR-008). El repositorio devuelve el estado
  /// sin cambios y acá no se marca ningún fallo: el usuario que cerró el
  /// diálogo de Google no hizo nada malo y no tiene por qué ver un cartel.
  ///
  /// Mientras una compra está en curso, otra no arranca: sin esta guarda un
  /// doble toque abriría dos flujos de compra.
  Future<void> comprar(PlanSuscripcion plan) async {
    if (_comprando) return;

    _comprando = true;
    _error = null;
    notifyListeners();

    try {
      _estado = await _repoSuscripcion.comprar(plan);
    } on Object catch (error) {
      _error = _mensajeDe(error);
    } finally {
      _comprando = false;
      notifyListeners();
    }
  }

  /// Le pide a Google Play las compras ya asociadas a la cuenta actual
  /// (FR-014). Si no encuentra ninguna, el estado que resulta queda en
  /// `situacion = nunca` (FR-015): a quien llama le toca decidir cómo
  /// comunicar "esta cuenta no tiene suscripción", por ejemplo mirando
  /// [premiumActivo] después de esperar esta llamada.
  Future<void> restaurar() async {
    if (_restaurando) return;

    _restaurando = true;
    _error = null;
    notifyListeners();

    try {
      _estado = await _repoSuscripcion.restaurar();
    } on Object catch (error) {
      _error = _mensajeDe(error);
    } finally {
      _restaurando = false;
      notifyListeners();
    }
  }

  /// Vuelve a preguntarle a Google Play por el estado. Se llama al abrir una
  /// pantalla premium y al volver de comprar (D4).
  Future<void> refrescar() async {
    try {
      _estado = await _repoSuscripcion.refrescar();
      _error = null;
    } on Object catch (error) {
      _error = _mensajeDe(error);
    }
    notifyListeners();
  }

  void limpiarError() {
    _error = null;
    notifyListeners();
  }

  static String _mensajeDe(Object error) => error is ErrorPersistencia
      ? error.mensaje
      : 'Ocurrió un problema inesperado. Volvé a intentarlo.';
}
