// ignore_for_file: prefer_initializing_formals
// Dart no admite parametros nombrados que empiecen con guion bajo, asi que
// los campos privados no pueden recibirse como `this._repo`.

import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/interpretes/normalizador_comercio.dart';
import 'package:finanzas/dominio/modelos/consumo_pendiente.dart';
import 'package:finanzas/dominio/modelos/deuda.dart';
import 'package:finanzas/dominio/modelos/resumen_pendientes.dart';
import 'package:finanzas/dominio/modelos/transaccion.dart';
import 'package:finanzas/dominio/repositorios/repositorio_asociaciones.dart';
import 'package:finanzas/dominio/repositorios/repositorio_pendientes.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:flutter/foundation.dart';

export 'package:finanzas/dominio/modelos/consumo_pendiente.dart';
export 'package:finanzas/dominio/modelos/resumen_pendientes.dart';

/// La bandeja de pendientes: confirmar, corregir y descartar (spec 002,
/// FR-020 a FR-028).
///
/// **Nunca crea una transacción sin pasar por `confirmar()`**: es la pieza
/// que hace estructuralmente imposible saltarse FR-020 (nunca en silencio),
/// no una convención de la UI. `confirmar()` guarda la asociación
/// comercio-categoría aprendida (US3, FR-029, FR-031) y `cargar()` propone la
/// categoría de un comercio ya conocido (FR-030). Con `comoDeuda` (US4,
/// FR-035 a FR-037), `confirmar()` bifurca a una `Deuda` de 001 en vez de una
/// transacción, para las compras en cuotas.
///
/// La `Transaccion`/`Deuda` no se escribe con un repositorio propio: pasa por
/// `EstadoMes.agregarTransaccion()`/`agregarDeuda()`, que es donde vive la
/// regla de cierre de mes (`estado_mes.dart`, contracts/repositorios.md —
/// "la regla de cierre nunca vive en un repositorio"). Escribir directo al
/// repositorio se saltaría esa regla y además dejaría desactualizado el
/// `EstadoMes` que Presupuesto/Resumen tienen en pantalla, con su propia
/// caché de transacciones y deudas.
class EstadoPendientes extends ChangeNotifier {
  EstadoPendientes({
    required RepositorioPendientes repoPendientes,
    required RepositorioAsociaciones repoAsociaciones,
    required EstadoMes estadoMes,
  }) : _repoPendientes = repoPendientes,
       _repoAsociaciones = repoAsociaciones,
       _estadoMes = estadoMes;

  final RepositorioPendientes _repoPendientes;
  final RepositorioAsociaciones _repoAsociaciones;
  final EstadoMes _estadoMes;

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
      _pendientes = await _conCategoriaAprendida(await _repoPendientes.todos());
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
  /// antes de confirmar (FR-033), o cuando `EstadoMes` rechaza la escritura
  /// porque el mes de la fecha está cerrado (FR-055): confirmar un pendiente
  /// no es una vía para saltarse esa regla.
  ///
  /// Si [comoDeuda] no es `null`, el pendiente era una compra en cuotas
  /// (FR-035): se registra como esa `Deuda` en vez de como transacción
  /// (FR-036) y ni [categoria] ni la asociación aprendida entran en juego —
  /// una deuda no lleva categoría propia, la deriva `tarjetaCredito` (D14).
  /// Sin [comoDeuda], el comportamiento es exactamente el de US2/US3
  /// (FR-037).
  Future<bool> confirmar(
    ConsumoPendiente pendiente, {
    Dinero? monto,
    String? comercio,
    DateTime? fecha,
    Categoria? categoria,
    Deuda? comoDeuda,
  }) async {
    if (comoDeuda != null) {
      if (!await _estadoMes.agregarDeuda(comoDeuda)) {
        _error = _estadoMes.error ?? 'No se pudo registrar la deuda.';
        notifyListeners();
        return false;
      }
      return _eliminarPendienteConfirmado(pendiente);
    }

    final categoriaFinal = categoria ?? pendiente.categoriaPropuesta;
    if (categoriaFinal == null) {
      _error = 'Elegí una categoría antes de confirmar.';
      notifyListeners();
      return false;
    }

    final transaccion = Transaccion(
      id: null,
      fecha: fecha ?? pendiente.fecha,
      categoria: categoriaFinal,
      monto: monto ?? pendiente.monto,
      descripcion: comercio ?? pendiente.comercio,
    );
    if (!await _estadoMes.agregarTransaccion(transaccion)) {
      _error = _estadoMes.error ?? 'No se pudo registrar el gasto.';
      notifyListeners();
      return false;
    }

    try {
      await _repoAsociaciones.asociar(
        normalizarComercio(comercio ?? pendiente.comercio),
        categoriaFinal,
      );
    } on Object catch (error) {
      _error = _mensajeDe(error);
      notifyListeners();
      return false;
    }
    return _eliminarPendienteConfirmado(pendiente);
  }

  /// Último paso común de `confirmar()`: la `Transaccion`/`Deuda` ya está
  /// guardada, solo falta que el pendiente deje de aparecer en la bandeja.
  Future<bool> _eliminarPendienteConfirmado(ConsumoPendiente pendiente) async {
    try {
      await _repoPendientes.eliminar(pendiente.id!);
      await cargar();
      return true;
    } on Object catch (error) {
      _error = _mensajeDe(error);
      notifyListeners();
      return false;
    }
  }

  /// Rellena `categoriaPropuesta` en los pendientes sin categoría cuyo
  /// comercio ya tiene una asociación aprendida (FR-030).
  Future<List<ConsumoPendiente>> _conCategoriaAprendida(
    List<ConsumoPendiente> pendientes,
  ) async {
    final resultado = <ConsumoPendiente>[];
    for (final pendiente in pendientes) {
      if (pendiente.categoriaPropuesta != null) {
        resultado.add(pendiente);
        continue;
      }
      final categoriaAprendida = await _repoAsociaciones.categoriaDe(
        normalizarComercio(pendiente.comercio),
      );
      resultado.add(
        categoriaAprendida == null
            ? pendiente
            : pendiente.copiarCon(categoriaPropuesta: categoriaAprendida),
      );
    }
    return resultado;
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
