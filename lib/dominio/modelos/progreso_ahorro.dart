import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// Cuánto conviene apartar este mes, según la regla elegida (FR-033, FR-034,
/// FR-037).
final class SugerenciaAhorro {
  final Dinero montoSugerido;

  /// `montoSugerido` acotado al disponible: nunca mayor a él (FR-034).
  final Dinero montoAlcanzable;

  final bool excedeDisponible;

  /// En déficit, o sin ingreso registrado: no hay nada que sugerir (FR-037).
  final bool noCorresponde;

  const SugerenciaAhorro({
    required this.montoSugerido,
    required this.montoAlcanzable,
    required this.excedeDisponible,
    required this.noCorresponde,
  });

  @override
  bool operator ==(Object other) =>
      other is SugerenciaAhorro &&
      other.montoSugerido == montoSugerido &&
      other.montoAlcanzable == montoAlcanzable &&
      other.excedeDisponible == excedeDisponible &&
      other.noCorresponde == noCorresponde;

  @override
  int get hashCode => Object.hash(
    montoSugerido,
    montoAlcanzable,
    excedeDisponible,
    noCorresponde,
  );

  @override
  String toString() =>
      'SugerenciaAhorro(sugerido: ${montoSugerido.centavos} c, '
      'alcanzable: ${montoAlcanzable.centavos} c, '
      'excede: $excedeDisponible, noCorresponde: $noCorresponde)';
}

/// Un mes del historial de ahorro, con la meta que regía **en ese mes**
/// (FR-054).
final class RenglonHistorialAhorro {
  final Mes mes;

  /// `null` = ese mes no tuvo meta fijada: figura sin veredicto (FR-054).
  final Dinero? meta;

  /// `S/ 0.00` si no hubo aportes ese mes, nunca un mes ausente (FR-043).
  final Dinero ahorrado;

  const RenglonHistorialAhorro({
    required this.mes,
    required this.meta,
    required this.ahorrado,
  });

  /// `null` cuando no hay meta contra la cual evaluar (FR-054).
  bool? get metaCumplida {
    final meta = this.meta;
    if (meta == null) return null;
    return ahorrado >= meta;
  }

  @override
  bool operator ==(Object other) =>
      other is RenglonHistorialAhorro &&
      other.mes == mes &&
      other.meta == meta &&
      other.ahorrado == ahorrado;

  @override
  int get hashCode => Object.hash(mes, meta, ahorrado);

  @override
  String toString() =>
      'RenglonHistorialAhorro($mes, meta: $meta, ahorrado: $ahorrado)';
}

/// El progreso del ahorro de un mes contra su propia meta, más el panorama
/// histórico completo (FR-035, FR-036, FR-039 a FR-043, FR-054).
///
/// Junta ambas cosas en un solo tipo porque la pantalla de ahorro las muestra
/// juntas, en una sola vista (SC-010).
final class ProgresoAhorro {
  /// Suma de los aportes del mes evaluado (FR-039).
  final Dinero ahorradoMes;

  /// `null` = el mes evaluado no tiene meta fijada: sin veredicto (FR-054).
  final Dinero? metaDelMes;

  /// Cuánto falta para la meta. `null` sin meta; `Dinero.cero` si ya se
  /// alcanzó o superó (FR-040).
  final Dinero? pendiente;

  /// Cuánto se superó la meta. `null` sin meta; `Dinero.cero` si no se llegó
  /// o se llegó justo (FR-040).
  final Dinero? excedente;

  /// `null` sin meta. La meta cabe en el disponible proyectado (FR-035).
  final bool? metaAlcanzable;

  /// Cuánto sobra del disponible después de la meta, cuando es alcanzable.
  final Dinero? margenDisponible;

  /// Cuánto habría que recortar en compromisos para que la meta entre,
  /// cuando no es alcanzable (FR-036).
  final Dinero? recorteNecesario;

  /// Suma de todos los aportes de todos los meses (FR-041).
  final Dinero acumuladoHistorico;

  /// Un renglón por mes con datos, con su propia meta y lo ahorrado
  /// (FR-041, FR-043, FR-054).
  final List<RenglonHistorialAhorro> historialPorMes;

  const ProgresoAhorro({
    required this.ahorradoMes,
    required this.metaDelMes,
    required this.pendiente,
    required this.excedente,
    required this.metaAlcanzable,
    required this.margenDisponible,
    required this.recorteNecesario,
    required this.acumuladoHistorico,
    required this.historialPorMes,
  });

  bool get tieneMeta => metaDelMes != null;

  @override
  bool operator ==(Object other) =>
      other is ProgresoAhorro &&
      other.ahorradoMes == ahorradoMes &&
      other.metaDelMes == metaDelMes &&
      other.pendiente == pendiente &&
      other.excedente == excedente &&
      other.metaAlcanzable == metaAlcanzable &&
      other.margenDisponible == margenDisponible &&
      other.recorteNecesario == recorteNecesario &&
      other.acumuladoHistorico == acumuladoHistorico &&
      _listasIguales(other.historialPorMes, historialPorMes);

  @override
  int get hashCode => Object.hash(
    ahorradoMes,
    metaDelMes,
    pendiente,
    excedente,
    metaAlcanzable,
    margenDisponible,
    recorteNecesario,
    acumuladoHistorico,
    Object.hashAll(historialPorMes),
  );

  static bool _listasIguales(
    List<RenglonHistorialAhorro> primera,
    List<RenglonHistorialAhorro> segunda,
  ) {
    if (primera.length != segunda.length) return false;
    for (var i = 0; i < primera.length; i++) {
      if (primera[i] != segunda[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'ProgresoAhorro(ahorrado: $ahorradoMes, meta: $metaDelMes, '
      'acumulado: $acumuladoHistorico)';
}

/// Propuesta de meta al abrir un mes sin una fijada (FR-053).
///
/// Nunca escribe nada: es un insumo para el formulario, que el usuario
/// confirma o ajusta.
final class PropuestaMeta {
  /// `null` si ningún mes anterior tuvo meta.
  final Dinero? montoPropuesto;

  const PropuestaMeta({required this.montoPropuesto});

  bool get hayPropuesta => montoPropuesto != null;

  @override
  bool operator ==(Object other) =>
      other is PropuestaMeta && other.montoPropuesto == montoPropuesto;

  @override
  int get hashCode => montoPropuesto.hashCode;

  @override
  String toString() => 'PropuestaMeta($montoPropuesto)';
}
