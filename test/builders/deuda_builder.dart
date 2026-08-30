import 'package:finanzas/dominio/modelos/deuda.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// Construye `Deuda` de prueba con valores por defecto razonables.
///
/// Reemplaza los `deuda({...})` ad-hoc que había repetidos, con defaults
/// levemente distintos, en `test/dominio/deudas_test.dart`,
/// `test/datos/repositorio_deudas_test.dart` y `test/ui/pantalla_deudas_test.dart`.
class DeudaBuilder {
  DeudaBuilder({
    this.id,
    this.descripcion = 'Celular',
    this.tarjetaId = 1,
    this.cuotaCentavos = 15000,
    this.numCuotas = 12,
    this.mesInicio = const Mes(2026, 8),
    this.mesSaldadaAnticipada,
  });

  int? id;
  String descripcion;
  int tarjetaId;
  int cuotaCentavos;
  int numCuotas;
  Mes mesInicio;
  Mes? mesSaldadaAnticipada;

  Deuda build() => Deuda(
    id: id,
    descripcion: descripcion,
    tarjetaId: tarjetaId,
    cuotaMensual: Dinero.deCentavos(cuotaCentavos),
    numCuotas: numCuotas,
    mesInicio: mesInicio,
    mesSaldadaAnticipada: mesSaldadaAnticipada,
  );
}
