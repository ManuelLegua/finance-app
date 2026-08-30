import 'package:flutter_notification_listener/flutter_notification_listener.dart';

/// Punto de entrada del isolate en segundo plano (D-N1).
///
/// Android lo invoca directamente cuando llega una notificación, sin pasar
/// por la UI ni por el isolate principal — así es como la captura sigue
/// funcionando con la app cerrada (FR-011). Por eso este archivo no puede
/// depender de nada de `lib/ui/`, ni asumir que hay una pantalla escuchando
/// al otro lado: si algo de acá reenviara el evento al isolate principal en
/// vez de procesarlo acá mismo, se perdería cada vez que la app no está
/// abierta.
///
/// `@pragma('vm:entry-point')` evita que el compilador lo elimine en release
/// por parecer código muerto — nada en este isolate lo llama directamente,
/// lo invoca Android.
///
/// Todavía no interpreta ni persiste nada: T042 (US2) completa el cuerpo una
/// vez que existan el parser genérico (`dominio/interpretes/`) y los
/// repositorios de pendientes y diagnóstico. Registrarlo ya desde US1 es lo
/// que permite que `activar()` funcione de punta a punta sin esperar a US2.
@pragma('vm:entry-point')
void alRecibirNotificacion(NotificationEvent evento) {}
