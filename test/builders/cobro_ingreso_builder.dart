import 'package:finanzas/dominio/modelos/cobro_ingreso.dart';
import 'package:finanzas/shared/tipos/dinero.dart';

/// Construye `CobroIngreso` de prueba con valores por defecto razonables.
///
/// Mismo patrón que `AporteAhorroBuilder`/`DeudaBuilder`.
class CobroIngresoBuilder {
  CobroIngresoBuilder({this.id, DateTime? fecha, this.centavos = 200000})
    : fecha = fecha ?? DateTime(2026, 8, 15);

  int? id;
  DateTime fecha;
  int centavos;

  CobroIngreso build() =>
      CobroIngreso(id: id, fecha: fecha, monto: Dinero.deCentavos(centavos));
}
