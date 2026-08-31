import 'package:finanzas/dominio/modelos/cobro_ingreso.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// Acceso a los cobros de ingreso (FR-001). Reemplaza a `RepositorioIngreso`
/// de la spec 001, que trabajaba con un único monto por mes.
///
/// Es un **puerto**: declara qué necesita la app, sin decir cómo se guarda.
/// **Ningún método calcula el total del mes**: eso lo deriva `totalIngreso`
/// en `lib/dominio/calculos/ingreso.dart`, ni aplica la regla de cierre —
/// eso vive en `EstadoMes` (contracts/repositorios.md).
abstract interface class RepositorioCobrosIngreso {
  /// Los cobros de [mes], de fecha ascendente (FR-008).
  Future<List<CobroIngreso>> porMes(Mes mes);

  /// Inserta y devuelve el id asignado.
  Future<int> insertar(CobroIngreso cobro);

  /// Lanza [ArgumentError] si no tiene id; un id inexistente es no-op.
  Future<void> actualizar(CobroIngreso cobro);

  Future<void> eliminar(int id);
}
