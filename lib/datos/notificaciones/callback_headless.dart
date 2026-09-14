import 'dart:ui';

import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/repositorios/repositorio_diagnostico_sqlite.dart';
import 'package:finanzas/datos/repositorios/repositorio_pendientes_sqlite.dart';
import 'package:finanzas/dominio/interpretes/decision_captura.dart';
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
/// **Acá no hay reglas, solo persistencia.** Qué hacer con cada notificación
/// lo decide `decidirCaptura`, que es Dart puro y está probada sin base de
/// datos ni Android de por medio. Este archivo se limita a darle los datos del
/// evento y a guardar lo que resuelva. Si alguna vez aparece un `if` con una
/// regla de negocio acá adentro, está en el lugar equivocado.
@pragma('vm:entry-point')
Future<void> alRecibirNotificacion(NotificationEvent evento) async {
  // Sin esto, los plugins no están registrados en este isolate y `sqflite` no
  // tiene canal contra el que hablar: abrir la base falla. El isolate lo crea
  // el plugin de notificaciones, no el arranque normal de la app, así que
  // nadie más lo hace por nosotros.
  DartPluginRegistrant.ensureInitialized();

  final paquete = evento.packageName;
  if (paquete == null) return;

  final decision = decidirCaptura(
    paquete: paquete,
    titulo: evento.title,
    esResumenDeGrupo: evento.isGroup ?? false,
    cuerpo: _cuerpoDe(evento),
    notificacionId: _identidadDe(evento),
    recibidaEn: evento.createAt ?? DateTime.now(),
  );

  if (decision is NoRegistrarNada) return;

  await _guardar(decision);
}

/// El cuerpo del aviso: `bigText` si está, y solo si no, el preview.
///
/// **El orden importa y no es una preferencia.** `NotificationEvent.text`
/// expone `EXTRA_TEXT`, que para un correo es el preview y Gmail lo trunca
/// justo sobre el comercio — 24 caracteres contra 301 en la primera captura
/// que lo midió. `EXTRA_BIG_TEXT` trae el correo entero y llega a Dart dentro
/// de `raw` (D-N12).
String _cuerpoDe(NotificationEvent evento) {
  final completo = evento.raw?['bigText']?.toString();
  if (completo != null && completo.isNotEmpty) return completo;
  return evento.text ?? '';
}

/// El identificador nativo que sostiene la deduplicación (D-N5).
///
/// Se prefiere `key`, que es el de Android y no cambia cuando una app reedita
/// su notificación — que es justamente el caso que FR-015 pide no duplicar.
/// `uniqueId` lo genera el plugin y sirve de respaldo.
String _identidadDe(NotificationEvent evento) =>
    evento.key ?? evento.uniqueId ?? '${evento.packageName}:${evento.id}';

/// Abre la base y guarda. **No cierra, y eso es el arreglo, no un olvido.**
///
/// La versión original de esta función cerraba la conexión al terminar,
/// razonando que sostenerla abierta en segundo plano contra la misma base que
/// usa la app era pedir un bloqueo. **Ese razonamiento estaba al revés.**
/// `sqflite` comparte el handle nativo por ruta entre isolates del mismo
/// proceso: cerrar desde acá **le cierra la conexión a la interfaz**, que
/// queda inutilizable hasta que el usuario reinicia la app.
///
/// El síntoma era feo y difícil de atribuir: capturar un consumo con la app
/// abierta dejaba la bandeja diciendo "Nada esperando confirmación" con las
/// filas presentes en el archivo (T061a). Perder un consumo capturado en
/// silencio es justo lo que FR-020 y esta feature entera existen para evitar.
///
/// Dejarla abierta no filtra nada: es la misma conexión que la app ya usa, y
/// el proceso la cierra cuando Android lo termina.
///
/// Un fallo al guardar se traga en silencio a propósito: una excepción sin
/// capturar en un isolate headless puede tumbarlo, y con él la captura de
/// todas las notificaciones siguientes. Perder una es mejor que perderlas
/// todas — y el usuario nunca vio ese consumo como registrado, porque nada se
/// registra sin que él lo confirme (FR-020).
Future<void> _guardar(DecisionCaptura decision) async {
  final baseDatos = BaseDatos();
  try {
    final conexion = await baseDatos.abrir();

    switch (decision) {
      case RegistrarPendiente(:final pendiente):
        await RepositorioPendientesSqlite(conexion).insertar(pendiente);
      case RegistrarDiagnostico(:final diagnostico):
        await RepositorioDiagnosticoSqlite(conexion).insertar(diagnostico);
      case NoRegistrarNada():
        break;
    }
  } on Object {
    return;
  }
}
