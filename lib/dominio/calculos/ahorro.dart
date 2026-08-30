import 'package:finanzas/dominio/modelos/progreso_ahorro.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';

export 'package:finanzas/dominio/modelos/progreso_ahorro.dart';

/// El objetivo declarado de la app: cuánto ahorrar y cuánto se lleva ahorrado
/// (FR-031 a FR-043, FR-053, FR-054).
///
/// Estas funciones no leen ni escriben nada: reciben los totales ya sumados
/// por el repositorio (`contracts/repositorios.md` prohíbe que un repositorio
/// calcule reglas financieras) y devuelven los derivados que muestra la
/// pantalla.

/// Cuánto conviene apartar este mes, según la regla elegida (FR-031, FR-037).
///
/// En déficit, o sin ingreso registrado, no hay nada que sugerir: no hay
/// contra qué medir un porcentaje ni qué "remanente" ofrecer.
SugerenciaAhorro calcularSugerencia({
  required ReglaAhorro regla,
  required int porcentajeBp,
  required Dinero? ingreso,
  required Dinero disponibleProyectado,
  required bool enDeficit,
}) {
  if (enDeficit || ingreso == null) {
    return const SugerenciaAhorro(
      montoSugerido: Dinero.cero,
      montoAlcanzable: Dinero.cero,
      excedeDisponible: false,
      noCorresponde: true,
    );
  }

  final montoSugerido = switch (regla) {
    ReglaAhorro.porcentajeIngreso => ingreso.porPuntosBase(porcentajeBp),
    ReglaAhorro.remanente => disponibleProyectado,
  };
  final excede = montoSugerido > disponibleProyectado;

  return SugerenciaAhorro(
    montoSugerido: montoSugerido,
    montoAlcanzable: excede ? disponibleProyectado : montoSugerido,
    excedeDisponible: excede,
    noCorresponde: false,
  );
}

/// Progreso del mes [mes] contra su propia meta, más el panorama histórico
/// completo (FR-035, FR-036, FR-039 a FR-043, FR-054).
///
/// [ahorradoMes] y [metaDelMes] son los del mes evaluado; [aportesPorMes] y
/// [metas] son los totales de **todos** los meses con datos, para construir
/// el historial completo. Un mes que aparece en uno de los dos pero no en el
/// otro igual sale en el historial: con `S/ 0.00` ahorrado si no tuvo
/// aportes, o sin meta si nunca la tuvo (FR-043, FR-054).
ProgresoAhorro calcularProgreso({
  required Mes mes,
  required Dinero disponibleProyectado,
  required Dinero ahorradoMes,
  required Dinero? metaDelMes,
  required Dinero acumuladoHistorico,
  required List<(Mes, Dinero)> aportesPorMes,
  required List<(Mes, Dinero)> metas,
}) {
  Dinero? pendiente;
  Dinero? excedente;
  bool? metaAlcanzable;
  Dinero? margenDisponible;
  Dinero? recorteNecesario;

  if (metaDelMes != null) {
    final diferencia = metaDelMes - ahorradoMes;
    pendiente = diferencia.esPositivo ? diferencia : Dinero.cero;
    excedente = diferencia.esNegativo ? -diferencia : Dinero.cero;

    final holgura = disponibleProyectado - metaDelMes;
    metaAlcanzable = !holgura.esNegativo;
    if (metaAlcanzable) {
      margenDisponible = holgura;
    } else {
      recorteNecesario = -holgura;
    }
  }

  final ahorradoPorMes = <Mes, Dinero>{
    for (final (unMes, total) in aportesPorMes) unMes: total,
  };
  final metaPorMes = <Mes, Dinero>{
    for (final (unMes, monto) in metas) unMes: monto,
  };
  final mesesConDatos = <Mes>{...ahorradoPorMes.keys, ...metaPorMes.keys}
      .toList()
    ..sort();

  return ProgresoAhorro(
    ahorradoMes: ahorradoMes,
    metaDelMes: metaDelMes,
    pendiente: pendiente,
    excedente: excedente,
    metaAlcanzable: metaAlcanzable,
    margenDisponible: margenDisponible,
    recorteNecesario: recorteNecesario,
    acumuladoHistorico: acumuladoHistorico,
    historialPorMes: [
      for (final unMes in mesesConDatos)
        RenglonHistorialAhorro(
          mes: unMes,
          meta: metaPorMes[unMes],
          ahorrado: ahorradoPorMes[unMes] ?? Dinero.cero,
        ),
    ],
  );
}

/// La meta del último mes anterior a [mes] que tuvo una, sin guardarla
/// (FR-053).
///
/// Es la misma idea que la precarga de obligaciones fijas: proponer, nunca
/// escribir en silencio.
PropuestaMeta proponerMetaDelMes(Mes mes, List<(Mes, Dinero)> metas) {
  (Mes, Dinero)? masReciente;
  for (final entrada in metas) {
    final (mesDeLaMeta, _) = entrada;
    if (mesDeLaMeta >= mes) continue;
    if (masReciente == null || mesDeLaMeta > masReciente.$1) {
      masReciente = entrada;
    }
  }
  return PropuestaMeta(montoPropuesto: masReciente?.$2);
}
