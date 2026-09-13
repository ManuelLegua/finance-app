// ignore_for_file: prefer_initializing_formals
// Dart no admite parametros nombrados que empiecen con guion bajo, asi que
// los campos privados no pueden recibirse como `this._repo`.

import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/propina.dart';
import 'package:finanzas/dominio/repositorios/repositorio_propinas.dart';
import 'package:flutter/foundation.dart';

export 'package:finanzas/dominio/modelos/propina.dart';

/// Estado de la pantalla de apoyo (spec 004 revisada).
///
/// **Vive solo mientras la pantalla está abierta**, y a propósito no se
/// provee en el árbol de `main.dart`: la pantalla de apoyo lo crea al
/// empujarse desde Ajustes y se va con ella. Así ninguna otra parte de la app
/// puede leer nada sobre el apoyo, que es la garantía estructural de FR-002 y
/// FR-006 — no una convención que alguien pueda saltarse más adelante.
class EstadoPropinas extends ChangeNotifier {
  EstadoPropinas({required RepositorioPropinas repoPropinas})
    : _repoPropinas = repoPropinas;

  final RepositorioPropinas _repoPropinas;

  List<OfertaPropina> _ofertas = const [];
  bool _cargando = true;
  bool _apoyando = false;
  String? _errorDeOfertas;
  ResultadoPropina? _ultimoResultado;

  List<OfertaPropina> get ofertas => List.unmodifiable(_ofertas);

  bool get cargando => _cargando;

  /// Hay una compra esperando la respuesta de Google Play. La pantalla lo
  /// dice con texto y deshabilita los botones mientras dure, para que un
  /// doble toque no abra dos flujos de compra.
  bool get apoyando => _apoyando;

  /// Por qué no se pudieron traer los montos. La pantalla lo muestra con la
  /// opción de reintentar, en vez de inventar precios (FR-011).
  String? get errorDeOfertas => _errorDeOfertas;

  /// Cómo terminó el último intento de apoyar, o `null` si todavía no hubo
  /// ninguno. La pantalla lo traduce a un mensaje con un `switch` exhaustivo.
  ResultadoPropina? get ultimoResultado => _ultimoResultado;

  /// Los montos vigentes. A diferencia de casi todo el resto de la app, acá
  /// **sí** importa fallar: mostrar un precio viejo o inventado sería
  /// engañoso (FR-004).
  Future<void> cargar() async {
    _cargando = true;
    _errorDeOfertas = null;
    notifyListeners();

    try {
      _ofertas = await _repoPropinas.ofertasDisponibles();
    } on Object catch (error) {
      _ofertas = const [];
      _errorDeOfertas = _mensajeDe(error);
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Lanza el flujo de compra de Google Play.
  ///
  /// **Cancelar no es un error** (FR-008): el resultado queda en `cancelada`
  /// y la pantalla no muestra nada. Quien cerró el diálogo de Google no hizo
  /// nada malo y no tiene por qué ver un cartel.
  ///
  /// Mientras una compra está en curso, otra no arranca.
  Future<void> apoyar(OfertaPropina oferta) async {
    if (_apoyando) return;

    _apoyando = true;
    _ultimoResultado = null;
    notifyListeners();

    try {
      _ultimoResultado = await _repoPropinas.apoyar(oferta);
    } on Object {
      _ultimoResultado = ResultadoPropina.fallida;
    } finally {
      _apoyando = false;
      notifyListeners();
    }
  }

  /// Olvida el resultado de la última compra, para que el agradecimiento no
  /// quede fijo en pantalla después de que el usuario lo leyó.
  void limpiarResultado() {
    _ultimoResultado = null;
    notifyListeners();
  }

  static String _mensajeDe(Object error) => error is ErrorPersistencia
      ? error.mensaje
      : 'Ocurrió un problema inesperado. Volvé a intentarlo.';
}
