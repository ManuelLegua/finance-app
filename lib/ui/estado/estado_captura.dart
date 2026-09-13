// ignore_for_file: prefer_initializing_formals
// Dart no admite parametros nombrados que empiecen con guion bajo, asi que
// los campos privados no pueden recibirse como `this._repo`.

import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/estado_captura.dart' as dominio;
import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/dominio/repositorios/servicio_escucha_notificaciones.dart';
import 'package:flutter/foundation.dart';

export 'package:finanzas/dominio/modelos/estado_captura.dart';

/// Activación de la captura de notificaciones bancarias (spec 002, HU1).
///
/// Combina [RepositorioConfiguracion] (el interruptor de la app) con
/// [ServicioEscuchaNotificaciones] (el permiso real del sistema) en el
/// derivado puro `dominio.EstadoCaptura` — nunca se confía en lo que el
/// usuario aceptó alguna vez (FR-003).
class EstadoCapturaNotificaciones extends ChangeNotifier {
  EstadoCapturaNotificaciones({
    required RepositorioConfiguracion repoConfiguracion,
    required ServicioEscuchaNotificaciones servicio,
  }) : _repoConfiguracion = repoConfiguracion,
       _servicio = servicio;

  final RepositorioConfiguracion _repoConfiguracion;
  final ServicioEscuchaNotificaciones _servicio;

  bool _permisoConcedido = false;
  bool _activaEnApp = false;
  bool _servicioCorriendo = false;
  bool _cargando = true;
  String? _error;

  bool get cargando => _cargando;

  String? get error => _error;

  dominio.EstadoCaptura get estado => dominio.EstadoCaptura(
    permisoConcedido: _permisoConcedido,
    activaEnApp: _activaEnApp,
    servicioCorriendo: _servicioCorriendo,
  );

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _permisoConcedido = await _servicio.permisoConcedido();
      _activaEnApp =
          (await _repoConfiguracion.obtener()).capturaNotificacionesActiva;
      // Se pregunta siempre, aunque el interruptor esté apagado: es lo que
      // distingue "encendido" de "funcionando" (D-N13).
      _servicioCorriendo = await _servicio.estaCorriendo();
    } on Object catch (error) {
      _error = _mensajeDe(error);
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Dirige a los ajustes de Android donde se concede el permiso (FR-002).
  /// No recarga sola: quien la llama sabe que el usuario va a volver a la
  /// app después, momento en el que corresponde `cargar()` de nuevo.
  Future<void> pedirPermiso() => _servicio.abrirAjustesDePermiso();

  /// Enciende la captura (FR-001 a FR-003 ya cumplidos por la UI antes de
  /// llamar esto). Si el permiso de lectura todavía no está concedido,
  /// arranca igual — no va a recibir nada hasta que el usuario lo conceda —
  /// para no duplicar la decisión de cuándo mostrar el botón en dos lugares.
  ///
  /// **Antes de arrancar pide el permiso del aviso persistente** (D-N13). Es
  /// el único permiso que esta feature pide desde la app, y sin él Android
  /// mata el servicio apenas nace: arrancar igual dejaría al usuario con una
  /// pantalla que dice "activa" y una captura que nunca corrió. Si lo
  /// rechaza, no se enciende nada y se explica por qué.
  Future<void> activar() async {
    final puedeAvisar = await _servicio.pedirPermisoDelAvisoPersistente();
    if (!puedeAvisar) {
      _error =
          'Android necesita que la app pueda mostrar una notificación para '
          'dejar la captura corriendo en segundo plano. Sin ese permiso la '
          'captura se apagaría sola.';
      notifyListeners();
      return;
    }
    await _cambiar(_servicio.activar);
  }

  /// Apaga la captura, conservando transacciones confirmadas y asociaciones
  /// aprendidas (FR-005).
  Future<void> desactivar() => _cambiar(_servicio.desactivar);

  Future<void> _cambiar(Future<void> Function() accion) async {
    try {
      await accion();
      await cargar();
    } on Object catch (error) {
      _error = _mensajeDe(error);
      notifyListeners();
    }
  }

  static String _mensajeDe(Object error) => error is ErrorPersistencia
      ? error.mensaje
      : 'Ocurrió un problema inesperado. Volvé a intentarlo.';
}
