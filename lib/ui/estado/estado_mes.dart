// ignore_for_file: prefer_initializing_formals
// Dart no admite parametros nombrados que empiecen con guion bajo, asi que
// los campos privados no pueden recibirse como `this._repo`. El lint sugiere
// algo que el lenguaje no permite en este caso.

import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/calculos/cierre_mes.dart';
import 'package:finanzas/dominio/calculos/desglose_categorias.dart';
import 'package:finanzas/dominio/calculos/deudas.dart';
import 'package:finanzas/dominio/calculos/ingreso.dart';
import 'package:finanzas/dominio/calculos/presupuesto.dart';
import 'package:finanzas/dominio/calculos/resumen_mes.dart';
import 'package:finanzas/dominio/modelos/cobro_ingreso.dart';
import 'package:finanzas/dominio/modelos/deuda.dart';
import 'package:finanzas/dominio/modelos/estado_cierre.dart';
import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/dominio/modelos/transaccion.dart';
import 'package:finanzas/dominio/repositorios/repositorio_cobros_ingreso.dart';
import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/dominio/repositorios/repositorio_deudas.dart';
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
    required RepositorioCobrosIngreso repoCobrosIngreso,
    required RepositorioObligaciones repoObligaciones,
    required RepositorioConfiguracion repoConfiguracion,
    required RepositorioTransacciones repoTransacciones,
    required RepositorioDeudas repoDeudas,
    RepositorioMeses? repoMeses,
    DateTime Function()? ahora,
    Mes? mesInicial,
  }) : _repoCobrosIngreso = repoCobrosIngreso,
       _repoObligaciones = repoObligaciones,
       _repoConfiguracion = repoConfiguracion,
       _repoTransacciones = repoTransacciones,
       _repoDeudas = repoDeudas,
       _repoMeses = repoMeses,
       _ahora = ahora ?? DateTime.now {
    _mes = mesInicial ?? Mes.deFecha(_ahora());
  }

  final RepositorioCobrosIngreso _repoCobrosIngreso;
  final RepositorioObligaciones _repoObligaciones;
  final RepositorioConfiguracion _repoConfiguracion;
  final RepositorioTransacciones _repoTransacciones;
  final RepositorioDeudas _repoDeudas;

  /// Opcional: sin él, el selector de mes no ofrece navegación por historial.
  final RepositorioMeses? _repoMeses;
  final DateTime Function() _ahora;

  late Mes _mes;
  List<CobroIngreso> _cobros = const [];
  List<Obligacion> _obligaciones = const [];
  List<Transaccion> _transacciones = const [];
  List<Deuda> _deudas = const [];
  List<Mes> _mesesRegistrados = const [];
  int _diasGraciaCierre = 5;
  bool _cargando = true;
  String? _error;

  Mes get mes => _mes;

  /// `null` significa "no registrado", que no es lo mismo que S/ 0.00.
  ///
  /// Se **deriva** de `_cobros` en cada lectura (FR-003), igual que
  /// `cuotasVigentes` se deriva de `_deudas` — nunca un dato guardado
  /// directamente (D-C3 de research.md 003).
  Dinero? get ingreso => totalIngreso(_cobros);

  bool get ingresoRegistrado => ingreso != null;

  /// Los cobros del mes, de fecha ascendente (FR-008).
  List<CobroIngreso> get cobros => List.unmodifiable(_cobros);

  List<Obligacion> get obligaciones => List.unmodifiable(_obligaciones);

  bool get cargando => _cargando;

  /// Mensaje de error listo para mostrar, o `null`.
  String? get error => _error;

  /// Todas las deudas, incluidas las futuras y las saldadas: el total
  /// adeudado las necesita (FR-020, FR-022).
  List<Deuda> get deudas => List.unmodifiable(_deudas);

  /// Lo que las deudas aportan al presupuesto de este mes (FR-016).
  ///
  /// Se **deriva** de las deudas, no se guarda (D3): por eso corregir una
  /// deuda arregla todos los meses sin reescribir nada.
  Dinero get cuotasVigentes => compromisoDeudasEnMes(_deudas, _mes);

  /// Las deudas que componen ese compromiso, para poder desglosarlo (FR-017).
  List<Deuda> get deudasDelMes => deudasQueAportanEn(_deudas, _mes);

  /// Total adeudado, compromiso mensual y mes libre de deudas (FR-022).
  PanoramaDeuda get panorama => calcularPanorama(_deudas, mesRef: _mes);

  /// Los gastos reales del mes, del más reciente al más antiguo (FR-013).
  List<Transaccion> get transacciones => List.unmodifiable(_transacciones);

  /// Presupuestado contra gastado, categoría por categoría (FR-010).
  List<LineaCategoria> get desglose => calcularDesglose(
    obligaciones: _obligaciones,
    transacciones: _transacciones,
    cuotasVigentes: cuotasVigentes,
    ingreso: ingreso,
  );

  /// Meses con datos, para el selector. Vacío si no se inyectó el repositorio.
  List<Mes> get mesesRegistrados => List.unmodifiable(_mesesRegistrados);

  /// Los totales del mes y su estado de déficit (FR-025 a FR-030).
  ///
  /// Se recalcula en cada lectura: es barato y evita que quede desfasado tras
  /// una escritura. Las cuotas de deuda entran en US4 y el gasto real en US3.
  ResumenMes get resumen => calcularResumenMes(
    ingreso: ingreso,
    obligaciones: _obligaciones,
    cuotasVigentes: cuotasVigentes,
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
      _cobros = await _repoCobrosIngreso.porMes(_mes);
      _obligaciones = await _repoObligaciones.porMes(_mes);
      _transacciones = await _repoTransacciones.porMes(_mes);
      _deudas = await _repoDeudas.todas();
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

  /// Registra un cobro de ingreso. El mes lo decide la fecha del cobro, no
  /// el mes abierto (FR-002), así que el cierre se consulta contra ese mes —
  /// mismo criterio que `agregarTransaccion` (FR-006).
  Future<bool> agregarCobro(CobroIngreso cobro) => _escribir(
    () => _repoCobrosIngreso.insertar(cobro),
    tipo: TipoEscritura.crear,
    mesAfectado: cobro.mes,
  );

  Future<bool> actualizarCobro(CobroIngreso cobro) => _escribir(
    () => _repoCobrosIngreso.actualizar(cobro),
    tipo: TipoEscritura.modificar,
    mesAfectado: cobro.mes,
  );

  Future<bool> eliminarCobro(int id) => _escribir(
    () => _repoCobrosIngreso.eliminar(id),
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

  /// Mismo criterio que [puedeEditarTransaccion], para un cobro (FR-006).
  bool puedeEditarCobro(CobroIngreso cobro) =>
      puedeEditarEn(cobro.mes, hoy: _ahora());

  /// Registra una deuda nueva.
  ///
  /// **No consulta el cierre de meses** (FR-057): la cuota de un mes nunca
  /// fue un dato de ese mes, siempre fue un derivado de la deuda (D3). Es la
  /// única corrección admitida sobre un mes cerrado.
  Future<bool> agregarDeuda(Deuda deuda) =>
      _escribirDeuda(() => _repoDeudas.insertar(deuda));

  Future<bool> actualizarDeuda(Deuda deuda) =>
      _escribirDeuda(() => _repoDeudas.actualizar(deuda));

  /// Cesan sus cuotas desde [mes] inclusive y su saldo pasa a cero (FR-021).
  Future<bool> saldarDeuda(int id, Mes mes) =>
      _escribirDeuda(() => _repoDeudas.marcarSaldada(id, mes));

  Future<bool> eliminarDeuda(int id) =>
      _escribirDeuda(() => _repoDeudas.eliminar(id));

  /// Escritura de deuda: sin verificación de cierre, por FR-057.
  Future<bool> _escribirDeuda(Future<void> Function() accion) async {
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
