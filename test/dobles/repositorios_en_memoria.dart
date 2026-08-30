import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/aporte_ahorro.dart';
import 'package:finanzas/dominio/modelos/configuracion.dart';
import 'package:finanzas/dominio/modelos/deuda.dart';
import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/dominio/modelos/tarjeta.dart';
import 'package:finanzas/dominio/modelos/transaccion.dart';
import 'package:finanzas/dominio/repositorios/repositorio_ahorro.dart';
import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/dominio/repositorios/repositorio_deudas.dart';
import 'package:finanzas/dominio/repositorios/repositorio_ingreso.dart';
import 'package:finanzas/dominio/repositorios/repositorio_obligaciones.dart';
import 'package:finanzas/dominio/repositorios/repositorio_tarjetas.dart';
import 'package:finanzas/dominio/repositorios/repositorio_transacciones.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// Dobles en memoria de los repositorios.
///
/// **Para qué existen**: las pruebas de widget no pueden usar SQLite —
/// `sqflite_common_ffi` no completa dentro del reloj falso de `testWidgets` y
/// la prueba se cuelga en vez de fallar. También sirven para probar
/// `EstadoMes`, cuya decisión de si una escritura está permitida según el
/// cierre del mes merece pruebas propias.
///
/// **Para qué NO existen**: no reemplazan a `test/datos/`, que sigue corriendo
/// contra SQLite real. El contrato se verifica contra la base de verdad; si un
/// doble se desincroniza del adaptador, es esa suite la que tiene que
/// atraparlo. Acá se replica el comportamiento observable, no el SQL.

/// Ingreso en memoria. Igual que el real, distingue "no registrado" (`null`)
/// de un ingreso en cero.
final class RepositorioIngresoEnMemoria implements RepositorioIngreso {
  final Map<int, Dinero> _porMesOrdinal = <int, Dinero>{};

  /// Cuántas veces se pidió guardar. Deja verificar que una escritura
  /// bloqueada por el cierre del mes efectivamente no llegó al repositorio.
  int guardadosSolicitados = 0;

  @override
  Future<Dinero?> obtener(Mes mes) async => _porMesOrdinal[mes.ordinal];

  @override
  Future<void> guardar(Mes mes, Dinero monto) async {
    guardadosSolicitados++;
    _porMesOrdinal[mes.ordinal] = monto;
  }

  @override
  Future<void> eliminar(Mes mes) async {
    _porMesOrdinal.remove(mes.ordinal);
  }

  @override
  Future<List<Mes>> mesesConIngreso() async =>
      (_porMesOrdinal.keys.toList()..sort()).map(Mes.deOrdinal).toList();
}

/// Obligaciones en memoria.
///
/// Replica dos comportamientos que la pantalla sí observa: el orden estable
/// por id de inserción y la atomicidad de `insertarLote`.
final class RepositorioObligacionesEnMemoria
    implements RepositorioObligaciones {
  final List<Obligacion> _guardadas = <Obligacion>[];
  int _proximoId = 1;

  /// Si se fija, la próxima escritura falla con este error. Sirve para probar
  /// que la pantalla muestra el problema en vez de quedarse muda.
  Object? errorEnLaProximaEscritura;

  @override
  Future<List<Obligacion>> porMes(Mes mes) async =>
      _guardadas.where((obligacion) => obligacion.mes == mes).toList();

  @override
  Future<List<Obligacion>> fijasDeMes(Mes mes) async {
    final delMes = await porMes(mes);
    return delMes
        .where((obligacion) => obligacion.tipo.slug == 'fija')
        .toList();
  }

  @override
  Future<int> insertar(Obligacion obligacion) async {
    _fallarSiCorresponde();
    final id = _proximoId++;
    _guardadas.add(obligacion.copiarCon(id: id));
    return id;
  }

  @override
  Future<void> insertarLote(List<Obligacion> obligaciones) async {
    if (obligaciones.isEmpty) return;
    _fallarSiCorresponde();
    // Atómico como el real: se arma todo y recién ahí se publica.
    final nuevas = <Obligacion>[];
    var siguienteId = _proximoId;
    for (final obligacion in obligaciones) {
      nuevas.add(obligacion.copiarCon(id: siguienteId++));
    }
    _guardadas.addAll(nuevas);
    _proximoId = siguienteId;
  }

  @override
  Future<void> actualizar(Obligacion obligacion) async {
    final id = obligacion.id;
    if (id == null) {
      throw ArgumentError.value(
        obligacion,
        'obligacion',
        'No se puede actualizar una obligación sin id; usá insertar()',
      );
    }
    _fallarSiCorresponde();
    final indice = _guardadas.indexWhere((guardada) => guardada.id == id);
    // Un id inexistente es no-op silencioso, igual que en el adaptador real.
    if (indice != -1) _guardadas[indice] = obligacion;
  }

  @override
  Future<void> eliminar(int id) async {
    _fallarSiCorresponde();
    _guardadas.removeWhere((obligacion) => obligacion.id == id);
  }

  void _fallarSiCorresponde() {
    final error = errorEnLaProximaEscritura;
    if (error == null) return;
    errorEnLaProximaEscritura = null;
    throw error;
  }
}

/// Configuración en memoria. Arranca con los valores por defecto, como el real.
final class RepositorioConfiguracionEnMemoria
    implements RepositorioConfiguracion {
  Configuracion _actual = Configuracion.porDefecto;

  RepositorioConfiguracionEnMemoria([Configuracion? inicial]) {
    if (inicial != null) _actual = inicial;
  }

  @override
  Future<Configuracion> obtener() async => _actual;

  @override
  Future<void> guardar(Configuracion config) async => _actual = config;
}

/// Gastos reales en memoria.
///
/// Replica los dos comportamientos que la pantalla observa: el orden por
/// fecha descendente con desempate por id, y que el mes salga de la fecha.
final class RepositorioTransaccionesEnMemoria
    implements RepositorioTransacciones {
  final List<Transaccion> _guardadas = <Transaccion>[];
  int _proximoId = 1;

  /// Si se fija, la próxima escritura falla con este error.
  Object? errorEnLaProximaEscritura;

  @override
  Future<List<Transaccion>> porMes(Mes mes) async {
    final delMes = _guardadas
        .where((transaccion) => transaccion.mes == mes)
        .toList();
    delMes.sort((primera, segunda) {
      final porFecha = segunda.fecha.compareTo(primera.fecha);
      if (porFecha != 0) return porFecha;
      return (segunda.id ?? 0).compareTo(primera.id ?? 0);
    });
    return delMes;
  }

  @override
  Future<int> insertar(Transaccion transaccion) async {
    _fallarSiCorresponde();
    final id = _proximoId++;
    _guardadas.add(transaccion.copiarCon(id: id));
    return id;
  }

  @override
  Future<void> actualizar(Transaccion transaccion) async {
    final id = transaccion.id;
    if (id == null) {
      throw ArgumentError.value(
        transaccion,
        'transaccion',
        'No se puede actualizar una transacción sin id; usá insertar()',
      );
    }
    _fallarSiCorresponde();
    final indice = _guardadas.indexWhere((guardada) => guardada.id == id);
    if (indice != -1) _guardadas[indice] = transaccion;
  }

  @override
  Future<void> eliminar(int id) async {
    _fallarSiCorresponde();
    _guardadas.removeWhere((transaccion) => transaccion.id == id);
  }

  void _fallarSiCorresponde() {
    final error = errorEnLaProximaEscritura;
    if (error == null) return;
    errorEnLaProximaEscritura = null;
    throw error;
  }
}

/// Tarjetas en memoria.
final class RepositorioTarjetasEnMemoria implements RepositorioTarjetas {
  final List<Tarjeta> _guardadas = <Tarjeta>[];
  int _proximoId = 1;

  /// Ids de tarjetas que el doble considera con deudas asociadas, para poder
  /// probar el rechazo del borrado sin montar la base entera.
  final Set<int> conDeudas = <int>{};

  @override
  Future<List<Tarjeta>> todas() async => List.of(_guardadas);

  @override
  Future<List<Tarjeta>> deCredito() async =>
      _guardadas.where((tarjeta) => tarjeta.admiteCuotas).toList();

  @override
  Future<int> insertar(Tarjeta tarjeta) async {
    final id = _proximoId++;
    _guardadas.add(tarjeta.copiarCon(id: id));
    return id;
  }

  @override
  Future<void> actualizar(Tarjeta tarjeta) async {
    final indice = _guardadas.indexWhere(
      (guardada) => guardada.id == tarjeta.id,
    );
    if (indice != -1) _guardadas[indice] = tarjeta;
  }

  @override
  Future<void> eliminar(int id) async {
    if (conDeudas.contains(id)) {
      throw ErrorPersistencia.integridad(
        'Esa tarjeta tiene deudas registradas. Eliminá o reasigná las deudas '
        'antes de borrarla.',
      );
    }
    _guardadas.removeWhere((tarjeta) => tarjeta.id == id);
  }
}

/// Metas y aportes de ahorro en memoria.
final class RepositorioAhorroEnMemoria implements RepositorioAhorro {
  final Map<int, Dinero> _metasPorMesOrdinal = <int, Dinero>{};
  final List<AporteAhorro> _aportes = <AporteAhorro>[];
  int _proximoId = 1;

  Object? errorEnLaProximaEscritura;

  @override
  Future<Dinero?> metaDeMes(Mes mes) async => _metasPorMesOrdinal[mes.ordinal];

  @override
  Future<void> guardarMeta(Mes mes, Dinero monto) async {
    _metasPorMesOrdinal[mes.ordinal] = monto;
  }

  @override
  Future<void> eliminarMeta(Mes mes) async {
    _metasPorMesOrdinal.remove(mes.ordinal);
  }

  @override
  Future<List<(Mes, Dinero)>> metasHasta(Mes mes) async {
    final ordinales =
        _metasPorMesOrdinal.keys
            .where((ordinal) => ordinal <= mes.ordinal)
            .toList()
          ..sort();
    return [
      for (final ordinal in ordinales)
        (Mes.deOrdinal(ordinal), _metasPorMesOrdinal[ordinal]!),
    ];
  }

  @override
  Future<List<AporteAhorro>> aportesPorMes(Mes mes) async =>
      _aportes.where((aporte) => aporte.mes == mes).toList();

  @override
  Future<Dinero> acumuladoHistorico() async {
    return _aportes.fold<Dinero>(
      Dinero.cero,
      (acumulado, aporte) => acumulado + aporte.monto,
    );
  }

  @override
  Future<List<(Mes, Dinero)>> historialPorMes(Mes desde, Mes hasta) async {
    final porMes = <int, Dinero>{};
    for (final aporte in _aportes) {
      final ordinal = aporte.mes.ordinal;
      if (ordinal < desde.ordinal || ordinal > hasta.ordinal) continue;
      porMes[ordinal] = (porMes[ordinal] ?? Dinero.cero) + aporte.monto;
    }
    final ordinales = porMes.keys.toList()..sort();
    return [
      for (final ordinal in ordinales)
        (Mes.deOrdinal(ordinal), porMes[ordinal]!),
    ];
  }

  @override
  Future<int> insertarAporte(AporteAhorro aporte) async {
    _fallarSiCorresponde();
    final id = _proximoId++;
    _aportes.add(aporte.copiarCon(id: id));
    return id;
  }

  @override
  Future<void> actualizarAporte(AporteAhorro aporte) async {
    final id = aporte.id;
    if (id == null) {
      throw ArgumentError.value(
        aporte,
        'aporte',
        'No se puede actualizar un aporte sin id; usá insertarAporte()',
      );
    }
    _fallarSiCorresponde();
    final indice = _aportes.indexWhere((guardado) => guardado.id == id);
    if (indice != -1) _aportes[indice] = aporte;
  }

  @override
  Future<void> eliminarAporte(int id) async {
    _fallarSiCorresponde();
    _aportes.removeWhere((aporte) => aporte.id == id);
  }

  void _fallarSiCorresponde() {
    final error = errorEnLaProximaEscritura;
    if (error == null) return;
    errorEnLaProximaEscritura = null;
    throw error;
  }
}

/// Deudas en memoria.
final class RepositorioDeudasEnMemoria implements RepositorioDeudas {
  final List<Deuda> _guardadas = <Deuda>[];
  int _proximoId = 1;

  Object? errorEnLaProximaEscritura;

  @override
  Future<List<Deuda>> todas() async => List.of(_guardadas);

  @override
  Future<List<Deuda>> activas() async =>
      _guardadas.where((deuda) => deuda.mesSaldadaAnticipada == null).toList();

  @override
  Future<List<Deuda>> porTarjeta(int tarjetaId) async =>
      _guardadas.where((deuda) => deuda.tarjetaId == tarjetaId).toList();

  @override
  Future<int> insertar(Deuda deuda) async {
    _fallarSiCorresponde();
    final id = _proximoId++;
    _guardadas.add(deuda.copiarCon(id: id));
    return id;
  }

  @override
  Future<void> actualizar(Deuda deuda) async {
    _fallarSiCorresponde();
    final indice = _guardadas.indexWhere((guardada) => guardada.id == deuda.id);
    if (indice != -1) _guardadas[indice] = deuda;
  }

  @override
  Future<void> marcarSaldada(int id, Mes mes) async {
    _fallarSiCorresponde();
    final indice = _guardadas.indexWhere((deuda) => deuda.id == id);
    if (indice != -1) {
      _guardadas[indice] = _guardadas[indice].copiarCon(
        mesSaldadaAnticipada: mes,
      );
    }
  }

  @override
  Future<void> eliminar(int id) async {
    _fallarSiCorresponde();
    _guardadas.removeWhere((deuda) => deuda.id == id);
  }

  void _fallarSiCorresponde() {
    final error = errorEnLaProximaEscritura;
    if (error == null) return;
    errorEnLaProximaEscritura = null;
    throw error;
  }
}
