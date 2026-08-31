import 'package:finanzas/datos/esquema.dart';
import 'package:sqflite/sqflite.dart';

/// Migraciones incrementales del esquema.
///
/// D10: cada paso lleva de una versión a la siguiente y **nunca borra ni
/// recrea tablas con datos**. La constitución exige que toda migración
/// preserve la información del usuario, y estos datos no tienen respaldo: la
/// spec descarta backup y exportación en esta versión, así que una migración
/// destructiva sería una pérdida irreversible.
///
/// Para agregar una migración: subir `Esquema.version`, añadir la entrada al
/// mapa con la versión de destino como clave, y cubrirla con una prueba en
/// `test/datos/base_datos_test.dart`.
abstract final class Migraciones {
  /// Clave: versión a la que se llega. Valor: los pasos para llegar.
  static const Map<int, List<String>> pasos = <int, List<String>>{
    // v1 → v2: spec 002, captura de notificaciones bancarias.
    2: <String>[
      Esquema.consumoPendiente,
      Esquema.indicePendienteNotificacion,
      Esquema.indicePendienteFecha,
      Esquema.comercioCategoria,
      Esquema.notificacionDiagnostico,
      Esquema.indiceDiagnosticoFecha,
      Esquema.alterConfiguracionCaptura,
    ],
    // v2 → v3: spec 003, cobros parciales de ingreso. `ingreso` no se borra
    // (D-C2): se lee una sola vez acá para copiar sus filas y queda intacta.
    3: <String>[
      Esquema.cobroIngreso,
      Esquema.indiceCobroIngresoMes,
      Esquema.migrarIngresoACobros,
    ],
    // v3 → v4: spec 004, suscripción premium. Solo agrega la tabla del estado
    // cacheado; ninguna tabla existente se toca. La fila `id = 1` no se
    // siembra acá: `RepositorioSuscripcionBilling.estadoCacheado()` devuelve
    // "nunca suscripto" mientras no exista, igual que hace `configuracion`
    // con sus valores por defecto.
    4: <String>[Esquema.suscripcionPremium],
  };

  /// Aplica los pasos necesarios para ir de [desde] a [hasta].
  static Future<void> aplicar(
    DatabaseExecutor conexion, {
    required int desde,
    required int hasta,
  }) async {
    for (var version = desde + 1; version <= hasta; version++) {
      final sentencias = pasos[version];
      if (sentencias == null) {
        throw StateError(
          'Falta la migración a la versión $version. La base quedó sin tocar '
          'a propósito: es preferible fallar al abrir que aplicar un cambio '
          'de esquema a medias.',
        );
      }
      for (final sentencia in sentencias) {
        await conexion.execute(sentencia);
      }
    }
  }
}
