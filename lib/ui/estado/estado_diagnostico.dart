// ignore_for_file: prefer_initializing_formals
// Dart no admite parametros nombrados que empiecen con guion bajo, asi que
// los campos privados no pueden recibirse como `this._repo`.

import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/notificacion_diagnostico.dart';
import 'package:finanzas/dominio/repositorios/repositorio_diagnostico.dart';
import 'package:flutter/foundation.dart';

export 'package:finanzas/dominio/modelos/notificacion_diagnostico.dart';

/// Notificaciones que la app reconoció como de un banco pero no pudo
/// interpretar (spec 002, FR-018).
class EstadoDiagnostico extends ChangeNotifier {
  EstadoDiagnostico({required RepositorioDiagnostico repoDiagnostico})
    : _repoDiagnostico = repoDiagnostico;

  final RepositorioDiagnostico _repoDiagnostico;

  List<NotificacionDiagnostico> _entradas = const [];
  bool _cargando = true;
  String? _error;

  List<NotificacionDiagnostico> get entradas => List.unmodifiable(_entradas);

  bool get cargando => _cargando;

  String? get error => _error;

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _entradas = await _repoDiagnostico.todos();
    } on Object catch (error) {
      _error = _mensajeDe(error);
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> vaciar() => _escribir(_repoDiagnostico.vaciar);

  Future<void> eliminar(int id) =>
      _escribir(() => _repoDiagnostico.eliminar(id));

  Future<void> _escribir(Future<void> Function() accion) async {
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
