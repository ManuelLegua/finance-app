import 'package:finanzas/datos/esquema.dart';
import 'package:sqflite/sqflite.dart';

/// Migraciones incrementales del esquema.
///
/// D10: cada paso lleva de una versión a la siguiente y **nunca borra ni
/// recrea tablas con datos del usuario**. La constitución exige que toda
/// migración preserve su información. Desde la spec 005 existe respaldo y
/// restauración, pero eso no ablanda la regla: el respaldo es una acción
/// manual que el usuario pudo no haber hecho nunca, así que una migración
/// destructiva seguiría siendo una pérdida irreversible para él.
///
/// El paso v4 → v5 es el único que borra una tabla, y cabe dentro de la regla
/// en vez de ser una excepción a ella: `suscripcion_premium` no guardaba nada
/// que el usuario hubiera cargado, era la caché de lo que respondía Google
/// Play. Si algún paso futuro necesita borrar una tabla **con datos del
/// usuario**, la respuesta es que no se hace.
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
    // v3 → v4: spec 004, suscripción premium. Se conserva aunque el paso
    // siguiente borre lo que crea: una base que viene de la v3 tiene que
    // poder llegar a la v5, y el camino pasa por acá. Quitarlo dejaría un
    // hueco en la cadena y `aplicar()` fallaría al abrir.
    4: <String>[Esquema.suscripcionPremium],
    // v4 → v5: spec 004 revisada a propina voluntaria. Se va la tabla del
    // estado de la suscripción, que ya no significa nada. Es el único paso
    // destructivo del proyecto y está justificado en D9 de su research.md: no
    // guardaba información del usuario, solo la respuesta de Google Play.
    5: <String>[Esquema.borrarSuscripcionPremium],
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
