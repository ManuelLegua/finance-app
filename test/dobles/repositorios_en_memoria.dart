import 'package:finanzas/dominio/modelos/configuracion.dart';
import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/dominio/modelos/transaccion.dart';
import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/dominio/repositorios/repositorio_ingreso.dart';
import 'package:finanzas/dominio/repositorios/repositorio_obligaciones.dart';
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
