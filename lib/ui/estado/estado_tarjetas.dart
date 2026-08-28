// ignore_for_file: prefer_initializing_formals
// Dart no admite parametros nombrados que empiecen con guion bajo.

import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/tarjeta.dart';
import 'package:finanzas/dominio/repositorios/repositorio_tarjetas.dart';
import 'package:flutter/foundation.dart';

/// Las tarjetas del usuario (FR-059).
///
/// Va separado de `EstadoMes` porque las tarjetas no dependen del mes: son
/// datos de configuración que sobreviven a la navegación entre meses.
class EstadoTarjetas extends ChangeNotifier {
  EstadoTarjetas({required RepositorioTarjetas repoTarjetas})
    : _repoTarjetas = repoTarjetas;

  final RepositorioTarjetas _repoTarjetas;

  List<Tarjeta> _tarjetas = const [];
  bool _cargando = true;
  String? _error;

  List<Tarjeta> get tarjetas => List.unmodifiable(_tarjetas);

  /// Las únicas que pueden respaldar una deuda en cuotas (FR-061).
  List<Tarjeta> get deCredito =>
      _tarjetas.where((tarjeta) => tarjeta.admiteCuotas).toList();

  bool get cargando => _cargando;

  String? get error => _error;

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _tarjetas = await _repoTarjetas.todas();
    } on Object catch (error) {
      _error = _mensajeDe(error);
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> agregar(Tarjeta tarjeta) =>
      _escribir(() => _repoTarjetas.insertar(tarjeta));

  Future<bool> actualizar(Tarjeta tarjeta) =>
      _escribir(() => _repoTarjetas.actualizar(tarjeta));

  /// Falla con un motivo legible si la tarjeta tiene deudas: no se borra en
  /// cascada lo que el usuario no pidió borrar.
  Future<bool> eliminar(int id) => _escribir(() => _repoTarjetas.eliminar(id));

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _escribir(Future<void> Function() accion) async {
    try {
      await accion();
      await cargar();
      return true;
    } on Object catch (error) {
      _error = _mensajeDe(error);
      notifyListeners();
      return false;
    }
  }

  static String _mensajeDe(Object error) => error is ErrorPersistencia
      ? error.mensaje
      : 'Ocurrió un problema inesperado. Volvé a intentarlo.';
}
