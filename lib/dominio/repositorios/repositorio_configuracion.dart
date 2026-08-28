import 'package:finanzas/dominio/modelos/configuracion.dart';

/// Acceso a los ajustes de la app: regla de ahorro, porcentaje y días de
/// gracia del cierre.
abstract interface class RepositorioConfiguracion {
  /// Los ajustes guardados. Si nunca se configuró nada, devuelve
  /// [Configuracion.porDefecto] y la deja persistida: el usuario no tiene que
  /// configurar antes de poder usar la app.
  Future<Configuracion> obtener();

  Future<void> guardar(Configuracion config);
}
