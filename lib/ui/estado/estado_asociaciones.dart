// ignore_for_file: prefer_initializing_formals
// Dart no admite parametros nombrados que empiecen con guion bajo, asi que
// los campos privados no pueden recibirse como `this._repo`.

import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/asociacion_comercio.dart';
import 'package:finanzas/dominio/repositorios/repositorio_asociaciones.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:flutter/foundation.dart';

export 'package:finanzas/dominio/modelos/asociacion_comercio.dart';

/// Consultar, corregir y eliminar las asociaciones comercio-categoría que
/// `EstadoPendientes` aprendió al confirmar consumos (spec 002, FR-034).
class EstadoAsociaciones extends ChangeNotifier {
  EstadoAsociaciones({required RepositorioAsociaciones repoAsociaciones})
    : _repoAsociaciones = repoAsociaciones;

  final RepositorioAsociaciones _repoAsociaciones;

  List<AsociacionComercio> _asociaciones = const [];
  bool _cargando = true;
  String? _error;

  List<AsociacionComercio> get asociaciones => List.unmodifiable(_asociaciones);

  bool get cargando => _cargando;

  String? get error => _error;

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _asociaciones = await _repoAsociaciones.todas();
    } on Object catch (error) {
      _error = _mensajeDe(error);
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Corrige la categoría de [comercioNormalizado] (FR-034); es el mismo
  /// upsert que usa la confirmación de un pendiente (FR-031).
  Future<void> corregir(String comercioNormalizado, Categoria categoria) =>
      _escribir(
        () => _repoAsociaciones.asociar(comercioNormalizado, categoria),
      );

  Future<void> eliminar(String comercioNormalizado) =>
      _escribir(() => _repoAsociaciones.eliminar(comercioNormalizado));

  Future<void> _escribir(Future<void> Function() accion) async {
    try {
      await accion();
      await cargar();
    } on Object catch (error) {
      _error = _mensajeDe(error);
      notifyListeners();
    }
  }

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  static String _mensajeDe(Object error) => error is ErrorPersistencia
      ? error.mensaje
      : 'Ocurrió un problema inesperado. Volvé a intentarlo.';
}
