import 'package:finanzas/datos/notificaciones/callback_headless.dart';
import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/dominio/repositorios/servicio_escucha_notificaciones.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:permission_handler/permission_handler.dart';

/// Envoltorio de `flutter_notification_listener` (D-N1).
///
/// Nunca se instancia fuera de Android (D-N8, FR-007) — el paquete que
/// envuelve ni siquiera declara soporte para otra plataforma. La guarda de
/// `Platform.isAndroid` vive en el punto donde se arma esta dependencia
/// (`main.dart`/cascarón), no acá adentro.
final class ServicioEscuchaNotificacionesAndroid
    implements ServicioEscuchaNotificaciones {
  ServicioEscuchaNotificacionesAndroid(this._repoConfiguracion);

  final RepositorioConfiguracion _repoConfiguracion;

  @override
  Future<bool> permisoConcedido() async =>
      await NotificationsListener.hasPermission ?? false;

  /// En Android 12 y anteriores no hay diálogo que mostrar, pero **eso no
  /// significa que siempre devuelva `true`**: si el usuario apagó las
  /// notificaciones de la app desde los ajustes del sistema, devuelve
  /// denegado igual. Y desde Android 13, un segundo rechazo deja el permiso
  /// denegado de forma permanente: el diálogo ya no vuelve a aparecer y la
  /// única salida es habilitarlo a mano en los ajustes de la app.
  @override
  Future<bool> pedirPermisoDelAvisoPersistente() async {
    final estado = await Permission.notification.request();
    return estado.isGranted;
  }

  @override
  Future<bool> estaCorriendo() async =>
      await NotificationsListener.isRunning ?? false;

  /// Abre la pantalla de Android donde se concede el permiso, **después de
  /// asegurarse de que la app aparezca en ella** (D-N13).
  ///
  /// El arranque del servicio va primero a propósito, y no es una repetición
  /// de [activar]: al arrancar, el plugin deshabilita y vuelve a habilitar el
  /// componente del servicio para forzar que Android lo revincule. Ese
  /// segundo paso es el que repara el caso en que desactivar la captura dejó
  /// el componente deshabilitado — y un componente deshabilitado **no figura
  /// en la lista de acceso a notificaciones**, así que sin esto se mandaba al
  /// usuario a conceder un permiso en una pantalla donde la app no estaba.
  ///
  /// No toca el interruptor de la app: pedir el permiso no es activar la
  /// captura.
  ///
  /// Si arrancar falla, se abre igual la pantalla: es preferible que el
  /// usuario llegue y no encuentre la app —el estado de hoy— a que no llegue.
  @override
  Future<void> abrirAjustesDePermiso() async {
    try {
      await NotificationsListener.initialize(
        callbackHandle: alRecibirNotificacion,
      );
      await NotificationsListener.startService(
        foreground: true,
        title: 'Captura de consumos activa',
        description: 'Finanzas está leyendo tus notificaciones bancarias.',
      );
    } on Object {
      // Se sigue: abrir la pantalla es lo que el usuario pidió.
    }
    await NotificationsListener.openPermissionSettings();
  }

  @override
  Future<void> activar() async {
    await NotificationsListener.initialize(
      callbackHandle: alRecibirNotificacion,
    );
    // Modo foreground (D-N4): sin esto, el paquete documenta que el
    // servicio puede no reiniciar solo tras un reboot del dispositivo.
    await NotificationsListener.startService(
      foreground: true,
      title: 'Captura de consumos activa',
      description: 'Finanzas está leyendo tus notificaciones bancarias.',
    );
    await _guardarInterruptor(activa: true);
  }

  @override
  Future<void> desactivar() async {
    await NotificationsListener.stopService();
    await _guardarInterruptor(activa: false);
  }

  Future<void> _guardarInterruptor({required bool activa}) async {
    final config = await _repoConfiguracion.obtener();
    await _repoConfiguracion.guardar(
      config.copiarCon(capturaNotificacionesActiva: activa),
    );
  }
}
