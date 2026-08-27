// ignore_for_file: prefer_initializing_formals
// Dart no admite parametros nombrados que empiecen con guion bajo, asi que
// los campos privados no pueden recibirse como `this._repo`. El lint sugiere
// algo que el lenguaje no permite en este caso.

import 'package:flutter/foundation.dart';

import '../../core/dinero.dart';
import '../../core/mes.dart';
import '../../datos/error_persistencia.dart';
import '../../datos/repositorios/repositorio_configuracion.dart';
import '../../datos/repositorios/repositorio_ingreso.dart';
import '../../datos/repositorios/repositorio_obligaciones.dart';
import '../../dominio/calculos/cierre_mes.dart';
import '../../dominio/calculos/presupuesto.dart';
import '../../dominio/modelos/estado_cierre.dart';
import '../../dominio/modelos/obligacion.dart';

/// Estado del mes que el usuario tiene abierto.
///
/// **Acá se aplica la regla de cierre**, no en los repositorios: duplicarla en
/// la capa de datos crearía dos verdades que se desincronizan
/// (contracts/repositorios.md). Toda escritura pasa primero por
/// `cierre_mes.dart`.
///
/// `_ahora` se inyecta para poder probar la ventana de gracia con fechas
/// fijas; en la app es `DateTime.now`.
class EstadoMes extends ChangeNotifier {
  EstadoMes({
    required RepositorioIngreso repoIngreso,
    required RepositorioObligaciones repoObligaciones,
    required RepositorioConfiguracion repoConfiguracion,
    DateTime Function()? ahora,
    Mes? mesInicial,
  })  : _repoIngreso = repoIngreso,
        _repoObligaciones = repoObligaciones,
        _repoConfiguracion = repoConfiguracion,
        _ahora = ahora ?? DateTime.now {
    _mes = mesInicial ?? Mes.deFecha(_ahora());
  }

  final RepositorioIngreso _repoIngreso;
  final RepositorioObligaciones _repoObligaciones;
  final RepositorioConfiguracion _repoConfiguracion;
  final DateTime Function() _ahora;

  late Mes _mes;
  Dinero? _ingreso;
  List<Obligacion> _obligaciones = const [];
  int _diasGraciaCierre = 5;
  bool _cargando = true;
  String? _error;

  Mes get mes => _mes;

  /// `null` significa "no registrado", que no es lo mismo que S/ 0.00.
  Dinero? get ingreso => _ingreso;

  bool get ingresoRegistrado => _ingreso != null;

  List<Obligacion> get obligaciones => List.unmodifiable(_obligaciones);

  bool get cargando => _cargando;

  /// Mensaje de error listo para mostrar, o `null`.
  String? get error => _error;

  /// Suma de las obligaciones guardadas. Las cuotas de deuda se suman en US4.
  Dinero get totalComprometido => totalObligaciones(_obligaciones);

  EstadoCierre get estadoCierre => estadoDe(
        _mes,
        hoy: _ahora(),
        diasGraciaCierre: _diasGraciaCierre,
      );

  bool get admiteEditar => estadoCierre.admiteEditar;

  bool get admiteRegistrar => estadoCierre.admiteRegistrar;

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _diasGraciaCierre = (await _repoConfiguracion.obtener()).diasGraciaCierre;
      _ingreso = await _repoIngreso.obtener(_mes);
      _obligaciones = await _repoObligaciones.porMes(_mes);
    } on Object catch (e) {
      _error = _mensajeDe(e);
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> irAMes(Mes destino) async {
    _mes = destino;
    await cargar();
  }

  Future<void> irAlMesAnterior() => irAMes(_mes.anterior);

  Future<void> irAlMesSiguiente() => irAMes(_mes.siguiente);

  Future<bool> guardarIngreso(Dinero monto) => _escribir(
        () => _repoIngreso.guardar(_mes, monto),
        requiereEdicion: ingresoRegistrado,
      );

  Future<bool> eliminarIngreso() => _escribir(
        () => _repoIngreso.eliminar(_mes),
        requiereEdicion: true,
      );

  Future<bool> agregarObligacion(Obligacion obligacion) => _escribir(
        () => _repoObligaciones.insertar(obligacion.copiarCon(mes: _mes)),
        requiereEdicion: false,
      );

  Future<bool> actualizarObligacion(Obligacion obligacion) => _escribir(
        () => _repoObligaciones.actualizar(obligacion),
        requiereEdicion: true,
      );

  Future<bool> eliminarObligacion(int id) => _escribir(
        () => _repoObligaciones.eliminar(id),
        requiereEdicion: true,
      );

  /// Las obligaciones fijas del mes anterior, para que el usuario confirme o
  /// ajuste (FR-006). No guarda nada.
  Future<List<Obligacion>> propuestaDePrecarga() async {
    if (_obligaciones.isNotEmpty || !admiteRegistrar) return const [];
    try {
      final fijas = await _repoObligaciones.fijasDeMes(_mes.anterior);
      return proponerFijasDelMesAnterior(
        mesDestino: _mes,
        obligacionesMesAnterior: fijas,
      );
    } on Object catch (e) {
      _error = _mensajeDe(e);
      notifyListeners();
      return const [];
    }
  }

  /// Confirma la precarga completa, en una sola transacción.
  Future<bool> confirmarPrecarga(List<Obligacion> propuestas) => _escribir(
        () => _repoObligaciones.insertarLote(propuestas),
        requiereEdicion: false,
      );

  /// Ejecuta una escritura si el cierre del mes lo permite, y recarga.
  ///
  /// [requiereEdicion] distingue crear (admitido en la ventana de gracia) de
  /// editar o eliminar (nunca admitido fuera del mes en curso, FR-056).
  Future<bool> _escribir(
    Future<void> Function() accion, {
    required bool requiereEdicion,
  }) async {
    final cierre = estadoCierre;
    final permitido =
        requiereEdicion ? cierre.admiteEditar : cierre.admiteRegistrar;
    if (!permitido) {
      _error = cierre.motivo;
      notifyListeners();
      return false;
    }

    try {
      await accion();
      await cargar();
      return true;
    } on Object catch (e) {
      _error = _mensajeDe(e);
      notifyListeners();
      return false;
    }
  }

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// La capa de datos ya tradujo el fallo a algo legible; lo demás es un
  /// defecto del software y no tiene sentido mostrárselo al usuario.
  static String _mensajeDe(Object e) => e is ErrorPersistencia
      ? e.mensaje
      : 'Ocurrió un problema inesperado. Volvé a intentarlo.';
}
