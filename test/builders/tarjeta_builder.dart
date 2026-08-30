import 'package:finanzas/dominio/modelos/tarjeta.dart';
import 'package:finanzas/shared/constantes/enums.dart';

/// Construye `Tarjeta` de prueba con valores por defecto razonables.
///
/// Reemplaza los `const Tarjeta(...)` repetidos en
/// `test/datos/repositorio_deudas_test.dart` y `test/ui/pantalla_deudas_test.dart`.
class TarjetaBuilder {
  TarjetaBuilder({
    this.id,
    this.nombre = 'BCP Visa',
    this.entidad = 'BCP',
    this.tipo = TipoTarjeta.credito,
  });

  int? id;
  String nombre;
  String entidad;
  TipoTarjeta tipo;

  Tarjeta build() =>
      Tarjeta(id: id, nombre: nombre, entidad: entidad, tipo: tipo);
}
