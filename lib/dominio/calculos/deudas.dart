import 'package:finanzas/dominio/modelos/deuda.dart';
import 'package:finanzas/dominio/modelos/estado_deuda.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';

export 'package:finanzas/dominio/modelos/estado_deuda.dart';

/// Cuotas, saldos y panorama de las deudas (FR-015 a FR-024).
///
/// **Las cuotas se derivan, no se almacenan** (D3). No existe tabla de
/// cuotas: lo que una deuda aporta a cada mes se calcula desde su mes de
/// inicio y su número de cuotas. Por eso corregir una deuda es una sola
/// escritura y todos los meses quedan correctos por construcción (FR-023).
///
/// **Estas funciones no consultan el cierre de meses** (FR-057). Editar una
/// deuda cambia lo que aporta a meses ya cerrados, y está bien: la cuota
/// nunca fue un dato de ese mes, siempre fue un derivado de la deuda. Es la
/// única corrección admitida sobre un mes cerrado.

/// Qué aporta una deuda al presupuesto de [mes]. `Dinero.cero` si no aporta.
Dinero cuotaVigenteEnMes(Deuda deuda, Mes mes) =>
    _aportaEn(deuda, mes) ? deuda.cuotaMensual : Dinero.cero;

/// Suma de las cuotas vigentes del mes (FR-016).
///
/// Es lo que entra al presupuesto en la categoría tarjeta de crédito. Para
/// mostrar de qué se compone, la UI pide `cuotaVigenteEnMes` deuda por deuda
/// (FR-017).
Dinero compromisoDeudasEnMes(List<Deuda> deudas, Mes mes) => deudas.fold(
  Dinero.cero,
  (acumulado, deuda) => acumulado + cuotaVigenteEnMes(deuda, mes),
);

/// Cuotas pagadas, restantes, saldo y mes de término (FR-018).
EstadoDeuda calcularEstadoDeuda(Deuda deuda, {required Mes mesRef}) {
  final saldada = _estaSaldadaEn(deuda, mesRef);

  // La cuota del mes en curso cuenta como pendiente hasta que el mes termina
  // (D4): una deuda de 12 cuotas que arranca este mes tiene doce por pagar.
  final transcurridas = mesRef.diferencia(deuda.mesInicio);
  final cuotasPagadas = transcurridas.clamp(0, deuda.numCuotas);
  final cuotasRestantes = saldada ? 0 : deuda.numCuotas - cuotasPagadas;

  return EstadoDeuda(
    situacion: _situacionEn(deuda, mesRef),
    cuotasPagadas: cuotasPagadas,
    cuotasRestantes: cuotasRestantes,
    saldoPendiente: deuda.cuotaMensual * cuotasRestantes,
    mesUltimaCuota: deuda.mesUltimaCuota,
  );
}

/// Total adeudado, compromiso del mes y mes en que quedará libre (FR-022).
PanoramaDeuda calcularPanorama(List<Deuda> deudas, {required Mes mesRef}) {
  var totalAdeudado = Dinero.cero;
  Mes? mesLibreDeDeudas;

  for (final deuda in deudas) {
    final estado = calcularEstadoDeuda(deuda, mesRef: mesRef);
    if (estado.estaSaldada) continue;

    // Incluye las de inicio futuro: todavía no aportan al mes, pero se deben
    // igual (FR-020).
    totalAdeudado += estado.saldoPendiente;

    final ultima = estado.mesUltimaCuota;
    if (mesLibreDeDeudas == null || ultima > mesLibreDeDeudas) {
      mesLibreDeDeudas = ultima;
    }
  }

  return PanoramaDeuda(
    totalAdeudado: totalAdeudado,
    compromisoMensual: compromisoDeudasEnMes(deudas, mesRef),
    mesLibreDeDeudas: mesLibreDeDeudas,
  );
}

/// Las deudas de una tarjeta que aportan cuota este mes, para desglosar el
/// compromiso consolidado (FR-017).
List<Deuda> deudasQueAportanEn(List<Deuda> deudas, Mes mes) =>
    deudas.where((deuda) => _aportaEn(deuda, mes)).toList(growable: false);

bool _aportaEn(Deuda deuda, Mes mes) {
  if (mes < deuda.mesInicio || mes > deuda.mesUltimaCuota) return false;
  return !_estaSaldadaEn(deuda, mes);
}

/// Saldada anticipadamente en [mes] o antes: desde ese mes **inclusive** deja
/// de aportar (FR-021).
bool _estaSaldadaEn(Deuda deuda, Mes mes) {
  final saldada = deuda.mesSaldadaAnticipada;
  return saldada != null && mes >= saldada;
}

SituacionDeuda _situacionEn(Deuda deuda, Mes mesRef) {
  if (_estaSaldadaEn(deuda, mesRef)) return SituacionDeuda.saldada;
  if (mesRef < deuda.mesInicio) return SituacionDeuda.futura;
  if (mesRef > deuda.mesUltimaCuota) return SituacionDeuda.saldada;
  return SituacionDeuda.vigente;
}
