import 'package:finanzas/dominio/modelos/aporte_ahorro.dart';
import 'package:finanzas/shared/tipos/dinero.dart';

/// Construye `AporteAhorro` de prueba con valores por defecto razonables.
///
/// Reemplaza los `aporte({...})` ad-hoc repetidos en
/// `test/datos/repositorio_ahorro_test.dart` y `test/ui/pantalla_ahorro_test.dart`.
class AporteAhorroBuilder {
  AporteAhorroBuilder({this.id, DateTime? fecha, this.centavos = 30000})
    : fecha = fecha ?? DateTime(2026, 8, 15);

  int? id;
  DateTime fecha;
  int centavos;

  AporteAhorro build() =>
      AporteAhorro(id: id, fecha: fecha, monto: Dinero.deCentavos(centavos));
}
