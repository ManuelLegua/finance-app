// ignore_for_file: prefer_initializing_formals
// Dart no admite parametros nombrados que empiecen con guion bajo, asi que
// los campos privados no pueden recibirse como `this._repo`.

import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/calculos/ahorro.dart';
import 'package:finanzas/dominio/calculos/cierre_mes.dart';
import 'package:finanzas/dominio/modelos/aporte_ahorro.dart';
import 'package:finanzas/dominio/modelos/configuracion.dart';
import 'package:finanzas/dominio/modelos/estado_cierre.dart';
import 'package:finanzas/dominio/repositorios/repositorio_ahorro.dart';
import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/estado/estado_mes.dart' show TipoEscritura;
import 'package:flutter/foundation.dart';

export 'package:finanzas/dominio/calculos/ahorro.dart';

/// El objetivo declarado de la app: sugerencia, progreso y aportes de ahorro
/// (HU5).
///
/// Sigue el mismo mes que `EstadoMes`: el mes es un concepto único y
/// compartido en toda la app (D16 en la práctica), así que quien la usa le
/// pasa `estado.mes` al entrar a la pantalla. No se sincroniza solo con
/// `EstadoMes` porque la pantalla de ahorro no tiene su propio selector de
/// mes: al no navegar mientras está abierta, cargar una vez al entrar alcanza.
///
/// **Acá se aplica la regla de cierre a los aportes**, igual que a las
/// transacciones en `EstadoMes`: duplicarla en la capa de datos crearía dos
/// verdades que se desincronizan (contracts/repositorios.md).
class EstadoAhorro extends ChangeNotifier {
  EstadoAhorro({
    required RepositorioAhorro repoAhorro,
    required RepositorioConfiguracion repoConfiguracion,
    DateTime Function()? ahora,
  }) : _repoAhorro = repoAhorro,
       _repoConfiguracion = repoConfiguracion,
       _ahora = ahora ?? DateTime.now;

  /// Desde cuándo se arma el historial completo. No hay forma de que un
  /// aporte real sea anterior a esto, así que equivale a "desde siempre" sin
  /// tener que consultarle a la base cuál fue el primer mes con datos.
  static const Mes _origenDelHistorial = Mes(2000, 1);

  final RepositorioAhorro _repoAhorro;
  final RepositorioConfiguracion _repoConfiguracion;
  final DateTime Function() _ahora;

  late Mes _mes;
  Configuracion _configuracion = Configuracion.porDefecto;
  List<AporteAhorro> _aportesDelMes = const [];
  Dinero? _metaDelMes;
  Dinero _acumuladoHistorico = Dinero.cero;
  List<(Mes, Dinero)> _historialConAportes = const [];
  List<(Mes, Dinero)> _metasHastaElMes = const [];
  bool _cargando = true;
  String? _error;

  Mes get mes => _mes;

  ReglaAhorro get regla => _configuracion.regla;

  int get porcentajeBp => _configuracion.porcentajeBp;

  bool get cargando => _cargando;

  String? get error => _error;

  List<AporteAhorro> get aportesDelMes => List.unmodifiable(_aportesDelMes);

  /// Cuánto conviene apartar este mes, según la regla elegida (FR-033,
  /// FR-034, FR-037). El [resumen] puede ser el de cualquier mes: no hace
  /// falta que coincida con el que tiene cargado este estado.
  SugerenciaAhorro sugerenciaPara({
    required Dinero? ingreso,
    required Dinero disponibleProyectado,
    required bool enDeficit,
  }) => calcularSugerencia(
    regla: regla,
    porcentajeBp: porcentajeBp,
    ingreso: ingreso,
    disponibleProyectado: disponibleProyectado,
    enDeficit: enDeficit,
  );

  /// El progreso del mes cargado contra su propia meta, más el historial
  /// completo (FR-035, FR-036, FR-039 a FR-043, FR-054).
  ProgresoAhorro progresoCon({required Dinero disponibleProyectado}) =>
      calcularProgreso(
        mes: _mes,
        disponibleProyectado: disponibleProyectado,
        ahorradoMes: _sumaDe(_aportesDelMes),
        metaDelMes: _metaDelMes,
        acumuladoHistorico: _acumuladoHistorico,
        aportesPorMes: _historialConAportes,
        metas: _metasHastaElMes,
      );

  /// La meta que se propone al abrir el mes cargado, si no tiene una propia
  /// todavía (FR-053).
  PropuestaMeta get propuesta => proponerMetaDelMes(_mes, _metasHastaElMes);

  EstadoCierre get estadoCierre =>
      estadoDe(_mes, hoy: _ahora(), diasGraciaCierre: _configuracion.diasGraciaCierre);

  bool get admiteRegistrar => estadoCierre.admiteRegistrar;

  /// Un aporte guardado en un mes que no es el actual quedó inmutable
  /// (FR-056): se registró en la ventana de gracia.
  bool puedeEditarAporte(AporteAhorro aporte) =>
      puedeEditarEn(aporte.mes, hoy: _ahora());

  /// Si se puede **registrar** un aporte con esa fecha (FR-055).
  bool admiteRegistrarEn(DateTime fecha) => puedeRegistrarEn(
    Mes.deFecha(fecha),
    hoy: _ahora(),
    diasGraciaCierre: _configuracion.diasGraciaCierre,
  );

  String? motivoDeCierreEn(DateTime fecha) => estadoDe(
    Mes.deFecha(fecha),
    hoy: _ahora(),
    diasGraciaCierre: _configuracion.diasGraciaCierre,
  ).motivo;

  Future<void> cargar(Mes mes) async {
    _mes = mes;
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _configuracion = await _repoConfiguracion.obtener();
      _aportesDelMes = await _repoAhorro.aportesPorMes(mes);
      _metaDelMes = await _repoAhorro.metaDeMes(mes);
      _acumuladoHistorico = await _repoAhorro.acumuladoHistorico();
      _historialConAportes = await _repoAhorro.historialPorMes(
        _origenDelHistorial,
        mes,
      );
      _metasHastaElMes = await _repoAhorro.metasHasta(mes);
    } on Object catch (error) {
      _error = _mensajeDe(error);
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Fija o reemplaza la meta del mes cargado (FR-035). Nunca pasa por el
  /// cierre: fijar una meta es una decisión sobre el futuro del mes, no un
  /// registro retroactivo, y sigue habilitada aunque el mes ya haya pasado.
  Future<bool> fijarMeta(Dinero monto) =>
      _escribir(() => _repoAhorro.guardarMeta(_mes, monto));

  Future<bool> agregarAporte(AporteAhorro aporte) => _escribirAporte(
    () => _repoAhorro.insertarAporte(aporte),
    tipo: TipoEscritura.crear,
    mesAfectado: aporte.mes,
  );

  Future<bool> actualizarAporte(AporteAhorro aporte) => _escribirAporte(
    () => _repoAhorro.actualizarAporte(aporte),
    tipo: TipoEscritura.modificar,
    mesAfectado: aporte.mes,
  );

  Future<bool> eliminarAporte(int id) => _escribirAporte(
    () => _repoAhorro.eliminarAporte(id),
    tipo: TipoEscritura.modificar,
  );

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _escribirAporte(
    Future<void> Function() accion, {
    required TipoEscritura tipo,
    Mes? mesAfectado,
  }) async {
    final cierre = mesAfectado == null
        ? estadoCierre
        : estadoDe(
            mesAfectado,
            hoy: _ahora(),
            diasGraciaCierre: _configuracion.diasGraciaCierre,
          );
    if (!tipo.permitidaPor(cierre)) {
      _error = cierre.motivo;
      notifyListeners();
      return false;
    }
    return _escribir(accion);
  }

  Future<bool> _escribir(Future<void> Function() accion) async {
    try {
      await accion();
      await cargar(_mes);
      return true;
    } on Object catch (error) {
      _error = _mensajeDe(error);
      notifyListeners();
      return false;
    }
  }

  static Dinero _sumaDe(List<AporteAhorro> aportes) =>
      aportes.fold(Dinero.cero, (acumulado, aporte) => acumulado + aporte.monto);

  static String _mensajeDe(Object error) => error is ErrorPersistencia
      ? error.mensaje
      : 'Ocurrió un problema inesperado. Volvé a intentarlo.';
}
