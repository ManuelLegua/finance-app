import 'package:finanzas/dominio/calculos/presupuesto.dart';
import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/dominio/modelos/resumen_mes.dart';
import 'package:finanzas/shared/tipos/dinero.dart';

export 'package:finanzas/dominio/modelos/resumen_mes.dart';

/// Calcula los totales del mes (FR-025 a FR-030).
///
/// **Por qué las cuotas y el gasto entran como totales y no como listas**: el
/// resumen solo necesita sus sumas. Recibir `List<Deuda>` y
/// `List<Transaccion>` lo acoplaría a modelos que no usa, y obligaría a
/// crearlos antes de tiempo. Quien sabe derivar las cuotas vigentes es
/// `deudas.dart` (D3) y quien suma el gasto es `desglose_categorias.dart`;
/// cada uno entrega su total ya calculado.
///
/// Ambos valen cero hasta que existan sus historias: US4 aporta las cuotas y
/// US3 el gasto real.
ResumenMes calcularResumenMes({
  required Dinero? ingreso,
  required List<Obligacion> obligaciones,
  Dinero cuotasVigentes = Dinero.cero,
  Dinero gastoRealTotal = Dinero.cero,
}) => ResumenMes(
  ingreso: ingreso,
  totalComprometido: totalObligaciones(obligaciones) + cuotasVigentes,
  gastoRealTotal: gastoRealTotal,
);
