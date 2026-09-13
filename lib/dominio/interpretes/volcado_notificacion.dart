/// Instrumento temporal para conseguir el insumo de T034 y T041 (spec 002).
///
/// **Esto no es parte de la funcionalidad y se borra cuando deje de hacer
/// falta.** Existe para responder una sola pregunta, la más barata de las que
/// dejó pendientes el hallazgo del 2026-09-12: cuando el correo del banco
/// llega como notificación de Gmail, ¿el evento trae el cuerpo completo o solo
/// el preview truncado que corta justo sobre el comercio?
///
/// `NotificationEvent.text` expone únicamente `EXTRA_TEXT` —el preview—, pero
/// el lado Android del plugin reenvía además `EXTRA_BIG_TEXT` y
/// `EXTRA_TEXT_LINES`, que llegan a Dart dentro de `evento.raw` con las claves
/// `bigText` y `textLines`. Nadie las miró nunca porque el callback headless
/// está vacío desde que se registró.
///
/// Si `bigText` trae el correo entero, la spec 002 revive con un filtro por
/// remitente de Gmail y sin que un dato salga del teléfono. Si viene igual de
/// truncado, esa vía queda descartada por escrito y la decisión pasa a la spec
/// 006.
///
/// **Dónde está la raya de privacidad.** De *toda* notificación se registra
/// solo el nombre del paquete, que es lo que T041 necesita y no revela ningún
/// contenido. El texto completo se vuelca **solo** para los paquetes de
/// [paquetesBajoObservacion]: volcar el cuerpo de cada notificación del
/// teléfono a un log sería una fuga hacia adentro, y el Principio I no deja de
/// aplicar porque el destino sea local.
library;

/// Prefijo de toda línea que escriba este instrumento.
///
/// Sirve para filtrar en `adb logcat` sin depender de la etiqueta que el
/// motor de Flutter le ponga al `print` del isolate headless.
const String marcaDeVolcado = 'FINANZAS-VOLCADO';

/// Los paquetes cuyo **texto completo** se vuelca.
///
/// Arranca solo con Gmail porque es de donde llegan los consumos en el
/// dispositivo de referencia (hallazgo del 2026-09-12): las apps de BCP, Yape
/// y Sip solo mandan push del dinero entrante. Agregar un paquete acá es
/// decidir a conciencia volcar el contenido de sus notificaciones.
const Set<String> paquetesBajoObservacion = <String>{'com.google.android.gm'};

/// Las claves de `raw` que pueden traer texto, en el orden en que se muestran.
///
/// Se recorre esta lista y no las claves del mapa recibido: así el volcado
/// **nunca** puede incluir `largeIcon` ni ningún otro binario, aunque el
/// plugin agregue claves nuevas más adelante.
const List<String> _clavesDeTexto = <String>[
  'title',
  'text',
  'bigText',
  'textLines',
  'subText',
  'summaryText',
  'infoText',
];

/// La única línea que se registra de una notificación cualquiera (T041).
///
/// Sin contenido: solo de qué app vino, que es lo que hace falta para
/// completar el `paquete` de cada `OrigenReconocido`.
String lineaDeOrigen(String paquete) => '$marcaDeVolcado origen: $paquete';

/// El volcado de texto de una notificación bajo observación (T034), o `null`
/// si su paquete no lo está.
///
/// Devolver `null` en vez de un volcado vacío es lo que hace que quien llama
/// no tenga que conocer la lista: si no hay nada que volcar, no hay nada que
/// escribir.
String? volcadoDeTexto({
  required String paquete,
  required Map<Object?, Object?>? crudo,
}) {
  if (!paquetesBajoObservacion.contains(paquete)) return null;

  final lineas = <String>['$marcaDeVolcado === $paquete ==='];
  for (final clave in _clavesDeTexto) {
    lineas.add('$marcaDeVolcado $clave: ${_describir(crudo?[clave])}');
  }
  lineas.add('$marcaDeVolcado ${_veredicto(crudo)}');
  return lineas.join('\n');
}

/// La respuesta a la pregunta, dicha de una: si `bigText` aporta algo que
/// `text` no tenga.
///
/// Se calcula acá y no se deja para el ojo humano porque comparar dos bloques
/// de texto largos en una salida de `logcat` es justamente donde se cuelan los
/// errores de lectura.
String _veredicto(Map<Object?, Object?>? crudo) {
  final preview = _comoTexto(crudo?['text']);
  final completo = _comoTexto(crudo?['bigText']);

  if (completo == null) {
    return 'VEREDICTO: no hay bigText. El preview es todo lo que llega.';
  }
  if (preview == null) {
    return 'VEREDICTO: hay bigText (${completo.length} caracteres) y no hay '
        'text.';
  }
  if (completo.length > preview.length) {
    return 'VEREDICTO: bigText tiene ${completo.length} caracteres contra los '
        '${preview.length} de text — trae más que el preview.';
  }
  return 'VEREDICTO: bigText no agrega nada sobre text '
      '(${completo.length} contra ${preview.length} caracteres).';
}

/// Cómo se muestra un valor del mapa crudo.
///
/// Una lista se numera línea por línea: `textLines` es donde Android pone los
/// mensajes agrupados, y verlos pegados con comas escondería exactamente la
/// estructura que se está tratando de entender.
String _describir(Object? valor) {
  if (valor == null) return '(ausente)';
  if (valor is List) {
    if (valor.isEmpty) return '(lista vacía)';
    final numeradas = <String>[];
    for (var indice = 0; indice < valor.length; indice++) {
      numeradas.add('\n$marcaDeVolcado   [$indice] ${valor[indice]}');
    }
    return '${valor.length} líneas${numeradas.join()}';
  }
  final texto = valor.toString();
  return '${texto.length} caracteres | $texto';
}

/// El valor como texto, o `null` si no hay nada útil.
///
/// Una cadena vacía cuenta como ausente: Android completa algunos extras con
/// `""` y tratarlos como presentes daría un veredicto falso.
String? _comoTexto(Object? valor) {
  if (valor == null) return null;
  final texto = valor.toString();
  return texto.isEmpty ? null : texto;
}
