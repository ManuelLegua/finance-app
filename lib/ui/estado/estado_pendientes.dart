// ignore_for_file: prefer_initializing_formals
// Dart no admite parametros nombrados que empiecen con guion bajo, asi que
// los campos privados no pueden recibirse como `this._repo`.

import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/consumo_pendiente.dart';
import 'package:finanzas/dominio/modelos/resumen_pendientes.dart';
import 'package:finanzas/dominio/modelos/transaccion.dart';
import 'package:finanzas/dominio/repositorios/repositorio_pendientes.dart';
import 'package:finanzas/dominio/repositorios/repositorio_transacciones.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:flutter/foundation.dart';

export 'package:finanzas/dominio/modelos/consumo_pendiente.dart';
export 'package:finanzas/dominio/modelos/resumen_pendientes.dart';

/// La bandeja de pendientes: confirmar, corregir y descartar (spec 002,
/// FR-020 a FR-028).
///
/// **Nunca crea una transacción sin pasar por `confirmar()`**: es la pieza
/// que hace estructuralmente imposible saltarse FR-020 (nunca en silencio),
/// no una convención de la UI. US4 (T054) amplía `confirmar()` para
/// bifurcar a una `Deuda` cuando el pendiente se marca en cuotas; US3
/// (T049) lo amplía para consultar y guardar la asociación aprendida.
class EstadoPendientes extends ChangeNotifier {
  EstadoPendientes({
    required RepositorioPendientes repoPendientes,
    required RepositorioTransacciones repoTransacciones,
  }) : _repoPendientes = repoPendientes,
       _repoTransacciones = repoTransacciones;

  final RepositorioPendientes _repoPendientes;
  final RepositorioTransacciones _repoTransacciones;

  List<ConsumoPendiente> _pendientes = const [];
  ResumenPendientes _resumen = ResumenPendientes.vacio;
  bool _cargando = true;
  String? _error;

  List<ConsumoPendiente> get pendientes => List.unmodifiable(_pendientes);

  ResumenPendientes get resumen => _resumen;

  bool get cargando => _cargando;

  String? get error => _error;

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _pendientes = await _repoPendientes.todos();
      _resumen = await _repoPendientes.resumen();
    } on Object catch (error) {
      _error = _mensajeDe(error);
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Confirma [pendiente], creando la transacción del mes de su fecha
  /// (FR-026) — no la de hoy. Los parámetros opcionales son la corrección
  /// que el usuario haya hecho antes de confirmar (FR-024); si se omiten, se
  /// usa lo que trajo el pendiente.
  ///
  /// Devuelve `false` sin crear ni borrar nada cuando no hay categoría —ni
  /// propuesta ni corregida— porque un comercio desconocido exige elegirla
  /// antes de confirmar (FR-033).
  Future<bool> confirmar(
    ConsumoPendiente pendiente, {
    Dinero? monto,
    String? comercio,
    DateTime? fecha,
    Categoria? categoria,
  }) async {
    final categoriaFinal = categoria ?? pendiente.categoriaPropuesta;
    if (categoriaFinal == null) {
      _error = 'Elegí una categoría antes de confirmar.';
      notifyListeners();
      return false;
    }

    try {
      await _repoTransacciones.insertar(
        Transaccion(
          id: null,
          fecha: fecha ?? pendiente.fecha,
          categoria: categoriaFinal,
          monto: monto ?? pendiente.monto,
          descripcion: comercio ?? pendiente.comercio,
        ),
      );
      await _repoPendientes.eliminar(pendiente.id!);
      await cargar();
      return true;
    } on Object catch (error) {
      _error = _mensajeDe(error);
      notifyListeners();
      return false;
    }
  }

  /// Descarta [pendiente] sin crear ninguna transacción (FR-025).
  Future<void> descartar(ConsumoPendiente pendiente) async {
    try {
      await _repoPendientes.eliminar(pendiente.id!);
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
