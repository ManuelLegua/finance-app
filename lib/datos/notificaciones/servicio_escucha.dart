import 'package:finanzas/datos/notificaciones/callback_headless.dart';
import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/dominio/repositorios/servicio_escucha_notificaciones.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';

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

  @override
  Future<void> abrirAjustesDePermiso() =>
      NotificationsListener.openPermissionSettings();

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
