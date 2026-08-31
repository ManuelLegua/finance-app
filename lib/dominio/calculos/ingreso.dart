import 'package:finanzas/dominio/modelos/cobro_ingreso.dart';
import 'package:finanzas/shared/tipos/dinero.dart';

/// El ingreso total del mes: la suma de sus cobros (FR-003).
///
/// `null` si [cobros] está vacía — un mes sin ningún cobro es "ingreso sin
/// registrar", nunca un sueldo de S/ 0.00 (FR-005). Asume que quien llama
/// (`EstadoMes`) ya filtró la lista al mes que corresponde.
Dinero? totalIngreso(List<CobroIngreso> cobros) => cobros.isEmpty
    ? null
    : cobros.fold<Dinero>(
        Dinero.cero,
        (acumulado, cobro) => acumulado + cobro.monto,
      );
