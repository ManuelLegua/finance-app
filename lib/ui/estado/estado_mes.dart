// ignore_for_file: prefer_initializing_formals
// Dart no admite parametros nombrados que empiecen con guion bajo, asi que
// los campos privados no pueden recibirse como `this._repo`. El lint sugiere
// algo que el lenguaje no permite en este caso.

import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/calculos/cierre_mes.dart';
import 'package:finanzas/dominio/calculos/desglose_categorias.dart';
import 'package:finanzas/dominio/calculos/presupuesto.dart';
import 'package:finanzas/dominio/calculos/resumen_mes.dart';
import 'package:finanzas/dominio/modelos/estado_cierre.dart';
import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/dominio/modelos/transaccion.dart';
import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/dominio/repositorios/repositorio_ingreso.dart';
import 'package:finanzas/dominio/repositorios/repositorio_meses.dart';
import 'package:finanzas/dominio/repositorios/repositorio_obligaciones.dart';
import 'package:finanzas/dominio/repositorios/repositorio_transacciones.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter/foundation.dart';

/// Que se intenta hacer sobre el mes.
///
/// Existe porque el cierre trata distinto crear y modificar: la ventana de
/// gracia admite registrar un pago rezagado, pero nunca editarlo ni borrarlo
/// (FR-055, FR-056). Como enum, cada llamada dice cual de las dos es; con un
/// `bool` habria que ir a la firma para saber que significa `true`.
enum TipoEscritura {
  crear,
  modificar;

  bool permitidaPor(EstadoCierre cierre) => switch (this) {
    TipoEscritura.crear => cierre.admiteRegistrar,
    TipoEscritura.modificar => cierre.admiteEditar,
  };
}

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
    required RepositorioTransacciones repoTransacciones,
    RepositorioMeses? repoMeses,
    DateTime Function()? ahora,
    Mes? mesInicial,
  }) : _repoIngreso = repoIngreso,
       _repoObligaciones = repoObligaciones,
       _repoConfiguracion = repoConfiguracion,
       _repoTransacciones = repoTransacciones,
       _repoMeses = repoMeses,
       _ahora = ahora ?? DateTime.now {
    _mes = mesInicial ?? Mes.deFecha(_ahora());
  }

  final RepositorioIngreso _repoIngreso;
  final RepositorioObligaciones _repoObligaciones;
  final RepositorioConfiguracion _repoConfiguracion;
  final RepositorioTransacciones _repoTransacciones;

  /// Opcional: sin él, el selector de mes no ofrece navegación por historial.
  final RepositorioMeses? _repoMeses;
  final DateTime Function() _ahora;

  late Mes _mes;
  Dinero? _ingreso;
  List<Obligacion> _obligaciones = const [];
  List<Transaccion> _transacciones = const [];
  List<Mes> _mesesRegistrados = const [];
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

  /// Los gastos reales del mes, del más reciente al más antiguo (FR-013).
  List<Transaccion> get transacciones => List.unmodifiable(_transacciones);

  /// Presupuestado contra gastado, categoría por categoría (FR-010).
  List<LineaCategoria> get desglose => calcularDesglose(
    obligaciones: _obligaciones,
    transacciones: _transacciones,
  );

  /// Meses con datos, para el selector. Vacío si no se inyectó el repositorio.
  List<Mes> get mesesRegistrados => List.unmodifiable(_mesesRegistrados);

  /// Los totales del mes y su estado de déficit (FR-025 a FR-030).
  ///
  /// Se recalcula en cada lectura: es barato y evita que quede desfasado tras
  /// una escritura. Las cuotas de deuda entran en US4 y el gasto real en US3.
  ResumenMes get resumen => calcularResumenMes(
    ingreso: _ingreso,
    obligaciones: _obligaciones,
    gastoRealTotal: totalGastado(_transacciones),
  );

  /// Suma de las obligaciones guardadas. Las cuotas de deuda se suman en US4.
  Dinero get totalComprometido => resumen.totalComprometido;

  EstadoCierre get estadoCierre =>
      estadoDe(_mes, hoy: _ahora(), diasGraciaCierre: _diasGraciaCierre);

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
      _transacciones = await _repoTransacciones.porMes(_mes);
      _mesesRegistrados = await _repoMeses?.mesesRegistrados() ?? const [];
    } on Object catch (error) {
      _error = _mensajeDe(error);
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
    tipo: ingresoRegistrado ? TipoEscritura.modificar : TipoEscritura.crear,
  );

  Future<bool> eliminarIngreso() => _escribir(
    () => _repoIngreso.eliminar(_mes),
    tipo: TipoEscritura.modificar,
  );

  Future<bool> agregarObligacion(Obligacion obligacion) => _escribir(
    () => _repoObligaciones.insertar(obligacion.copiarCon(mes: _mes)),
    tipo: TipoEscritura.crear,
  );

  Future<bool> actualizarObligacion(Obligacion obligacion) => _escribir(
    () => _repoObligaciones.actualizar(obligacion),
    tipo: TipoEscritura.modificar,
  );

  Future<bool> eliminarObligacion(int id) => _escribir(
    () => _repoObligaciones.eliminar(id),
    tipo: TipoEscritura.modificar,
  );

  /// Registra un gasto. El mes lo decide la fecha de la transacción, no el
  /// mes abierto (FR-008), así que el cierre se consulta contra ese mes: es
  /// lo que habilita el pago rezagado dentro de la ventana de gracia.
  Future<bool> agregarTransaccion(Transaccion transaccion) => _escribir(
    () => _repoTransacciones.insertar(transaccion),
    tipo: TipoEscritura.crear,
    mesAfectado: transaccion.mes,
  );

  Future<bool> actualizarTransaccion(Transaccion transaccion) => _escribir(
    () => _repoTransacciones.actualizar(transaccion),
    tipo: TipoEscritura.modificar,
    mesAfectado: transaccion.mes,
  );

  Future<bool> eliminarTransaccion(int id) => _escribir(
    () => _repoTransacciones.eliminar(id),
    tipo: TipoEscritura.modificar,
  );

  /// Si se puede registrar un gasto con esa fecha (FR-055).
  ///
  /// Distinto de [admiteRegistrar], que mira el mes abierto: acá interesa el
  /// mes de la fecha elegida, que puede ser el anterior.
  bool admiteRegistrarEn(DateTime fecha) => puedeRegistrarEn(
    Mes.deFecha(fecha),
    hoy: _ahora(),
    diasGraciaCierre: _diasGraciaCierre,
  );

  /// El motivo por el que una fecha no admite registro, listo para mostrar.
  String? motivoDeCierreEn(DateTime fecha) => estadoDe(
    Mes.deFecha(fecha),
    hoy: _ahora(),
    diasGraciaCierre: _diasGraciaCierre,
  ).motivo;

  /// Un gasto ya guardado en un mes que no es el actual quedó inmutable
  /// (FR-056): se registró en la ventana de gracia y no se puede editar.
  bool puedeEditarTransaccion(Transaccion transaccion) =>
      puedeEditarEn(transaccion.mes, hoy: _ahora());

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
    } on Object catch (error) {
      _error = _mensajeDe(error);
      notifyListeners();
      return const [];
    }
  }

  /// Confirma la precarga completa, en una sola transacción.
  Future<bool> confirmarPrecarga(List<Obligacion> propuestas) => _escribir(
    () => _repoObligaciones.insertarLote(propuestas),
    tipo: TipoEscritura.crear,
  );

  /// Ejecuta una escritura si el cierre del mes lo permite, y recarga.
  ///
  /// El [tipo] decide si el cierre del mes la permite.
  Future<bool> _escribir(
    Future<void> Function() accion, {
    required TipoEscritura tipo,
    Mes? mesAfectado,
  }) async {
    final cierre = mesAfectado == null
        ? estadoCierre
        : estadoDe(
            mesAfectado,
            hoy: _ahora(),
            diasGraciaCierre: _diasGraciaCierre,
          );
    if (!tipo.permitidaPor(cierre)) {
      _error = cierre.motivo;
      notifyListeners();
      return false;
    }

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

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// La capa de datos ya tradujo el fallo a algo legible; lo demás es un
  /// defecto del software y no tiene sentido mostrárselo al usuario.
  static String _mensajeDe(Object error) => error is ErrorPersistencia
      ? error.mensaje
      : 'Ocurrió un problema inesperado. Volvé a intentarlo.';
}
