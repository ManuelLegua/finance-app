import 'dart:io';

import 'package:finanzas/dominio/interpretes/volcado_notificacion.dart';
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
/// ## Lo que hace hoy: observar, nada más
///
/// **No interpreta, no guarda y no registra nada.** Solo escribe al log del
/// dispositivo, como instrumento temporal para conseguir el insumo de T034 y
/// T041 (ver `dominio/interpretes/volcado_notificacion.dart`, que explica la
/// pregunta que se fue a responder y dónde está la raya de privacidad).
/// Mientras el cuerpo sea este, FR-020 —"nunca en silencio"— se cumple solo:
/// no hay ninguna ruta desde acá hasta una `Transaccion`.
///
/// El volcado se borra cuando deje de hacer falta. No es el principio de
/// T042: es lo que tiene que pasar **antes**, porque T042 no se puede escribir
/// sin saber qué texto llega realmente.
///
/// ## Lo que va a hacer: T042
///
/// Interpretar con el parser genérico y escribir el `ConsumoPendiente` crudo.
/// La propuesta de categoría de US3 (FR-030) no se resuelve acá:
/// `EstadoPendientes.cargar()` le busca la asociación aprendida a cualquier
/// pendiente que llegue sin `categoriaPropuesta`.
///
/// La guarda de suscripción que pedía T035 de la spec 004 **ya no va**: esa
/// spec se revisó el 2026-09-12 a propina voluntaria y no queda ningún acceso
/// que verificar. Nada de lo que llegue acá depende de que el usuario haya
/// pagado.
@pragma('vm:entry-point')
void alRecibirNotificacion(NotificationEvent evento) {
  final paquete = evento.packageName;
  if (paquete == null) return;

  // De toda notificación, solo de qué app vino (T041).
  _anotar(lineaDeOrigen(paquete));

  // El texto completo, solo de los paquetes bajo observación (T034).
  final volcado = volcadoDeTexto(paquete: paquete, crudo: evento.raw);
  if (volcado == null) return;
  _anotar(volcado);
}

/// Dónde queda el volcado dentro del teléfono.
///
/// **La ruta está escrita a mano y eso es deliberado.** Lo correcto sería
/// `path_provider`, pero este código corre en un isolate headless donde los
/// plugins no están registrados: pedir el directorio por canal de plataforma
/// fallaría justo cuando hace falta. Como el instrumento es temporal y el
/// `applicationId` es fijo, la ruta literal es la opción que no puede fallar.
///
/// Es el directorio **interno** de la app y no el externo. El externo parecía
/// mejor —`adb` lo lee sin más— pero desde Android 11 ese directorio lo crea
/// el sistema cuando la app lo pide por la vía oficial, no la app a mano: acá
/// la escritura fallaba en silencio. El interno siempre es escribible; a
/// cambio, sacarlo de ahí necesita que la propia app lo muestre.
const String _rutaDelVolcado =
    '/data/user/0/io.github.manuellegua.finanzas/files/'
    'volcado-notificaciones.txt';

/// Deja constancia de [texto] por las dos vías que pueden sobrevivir a un
/// fabricante hostil.
///
/// **Por `stderr` y no por `print`**: la salida estándar de Dart llega a
/// `logcat` con nivel INFO, y este teléfono —un Honor— descarta todo lo que
/// las apps escriban por debajo de ERROR. El volcado corría bien y no
/// aparecía. `stderr` sale como ERROR y atraviesa ese filtro.
///
/// **Y además a un archivo**, porque si el fabricante también filtrara los
/// errores, el archivo sigue ahí para leerlo después. Cada ciclo de
/// reinstalar cuesta volver a conceder el permiso de notificaciones a mano,
/// así que conviene que un intento traiga las dos respuestas.
///
/// Cualquier fallo se traga en silencio a propósito: es un instrumento de
/// diagnóstico, y hacer caer el callback por no poder escribir una nota sería
/// peor que no tener la nota.
void _anotar(String texto) {
  final fechado = '${DateTime.now().toIso8601String()} $texto';

  // Vía 1: la salida estándar. Llega a `logcat` como `I/flutter`.
  // ignore: avoid_print
  print(fechado);

  // Vía 2: una excepción asíncrona sin capturar. El motor de Flutter la
  // reporta como `E/flutter`, y **ese nivel sí atraviesa el filtro** de este
  // teléfono: las excepciones de otras apps se ven en el log y las líneas
  // INFO de las apps no.
  //
  // Va dentro de un `Future.microtask` a propósito: así queda sin capturar
  // —que es lo que la hace visible— sin cortar el flujo sincrónico de este
  // callback, que tiene que seguir para escribir el archivo.
  //
  // **Es un hack de diagnóstico y se va con el resto del instrumento.**
  Future<void>.microtask(() => throw StateError(fechado));

  // Vía 3: el archivo, que no depende de ninguna decisión del fabricante.
  try {
    File(_rutaDelVolcado).writeAsStringSync(
      '$fechado\n',
      mode: FileMode.append,
    );
  } on Object {
    return;
  }
}
