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
///
/// **Guarda de suscripción (spec 004, T035, FR-011)**: cuando T042 llene este
/// cuerpo, lo primero —antes de interpretar nada y antes de escribir una sola
/// fila— tiene que ser consultar `RepositorioSuscripcion.estadoCacheado()` y
/// descartar la notificación si el acceso no está vigente. Va `estadoCacheado`
/// y **no** `refrescar`: esto corre en un isolate headless, sin UI y sin
/// garantía de red, y una consulta a Google Play acá dejaría la captura a
/// merced de la conexión.
///
/// Lo que se corta es que lleguen consumos **nuevos**. Los pendientes que ya
/// estaban no se tocan: la bandeja los sigue mostrando y se pueden descartar
/// aunque la suscripción haya vencido (Acceptance Scenario 4 de US4), que es
/// lo que fija `test/ui/captura/pantalla_pendientes_test.dart`.
@pragma('vm:entry-point')
void alRecibirNotificacion(NotificationEvent evento) {
  // Vacío a propósito hasta T042 de la spec 002. La guarda de suscripción que
  // describe la documentación de arriba va acá, como primera línea.
}
