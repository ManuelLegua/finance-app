import 'package:finanzas/dominio/modelos/transaccion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';

/// Construye `Transaccion` de prueba con valores por defecto razonables.
///
/// Reemplaza los `gasto({...})` ad-hoc que había repetidos, con defaults
/// levemente distintos, en `test/dominio/desglose_test.dart`,
/// `test/datos/repositorio_transacciones_test.dart` y
/// `test/ui/pantalla_transacciones_test.dart`.
class TransaccionBuilder {
  TransaccionBuilder({
    this.id,
    DateTime? fecha,
    this.categoria = Categoria.comida,
    this.centavos = 4500,
    this.descripcion = 'Almuerzo',
  }) : fecha = fecha ?? DateTime(2026, 8, 15);

  int? id;
  DateTime fecha;
  Categoria categoria;
  int centavos;
  String descripcion;

  Transaccion build() => Transaccion(
    id: id,
    fecha: fecha,
    categoria: categoria,
    monto: Dinero.deCentavos(centavos),
    descripcion: descripcion,
  );
}
