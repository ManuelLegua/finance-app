import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// Acceso al ingreso mensual (FR-001).
///
/// Es un **puerto**: declara qué necesita la app, sin decir cómo se guarda.
/// La implementación contra SQLite es `RepositorioIngresoSqlite`; las pruebas
/// de interfaz usan un doble en memoria.
///
/// Vive en `lib/dominio/` y no en `lib/shared/` por la dirección de las
/// dependencias: la firma habla de `Dinero` y `Mes`, y sus hermanas hablan de
/// `Obligacion` y `Configuracion`, que son modelos del dominio. Ponerlas en
/// `shared/` obligaría a que `shared/` importe de `dominio/`, invirtiendo la
/// regla `ui → datos → dominio → shared`.
abstract interface class RepositorioIngreso {
  /// El ingreso del mes, o `null` si no se registró.
  ///
  /// `null` y `Dinero.cero` son cosas distintas: el primero hace que la app
  /// pida registrar el ingreso, el segundo sería un sueldo de S/ 0.00.
  Future<Dinero?> obtener(Mes mes);

  /// Inserta o reemplaza el ingreso del mes.
  Future<void> guardar(Mes mes, Dinero monto);

  /// Quita el ingreso del mes. Si no había, no hace nada.
  Future<void> eliminar(Mes mes);

  /// Meses con ingreso registrado, en orden cronológico.
  Future<List<Mes>> mesesConIngreso();
}
