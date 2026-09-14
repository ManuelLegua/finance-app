import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';

/// Resultado de interpretar el texto de una notificación bancaria.
///
/// Contrato del parser genérico (spec 002, D-N2): un único parser interpreta
/// el texto de cualquier origen reconocido — no hay un intérprete por banco.
/// Ver contracts/interpretes.md de la spec.
sealed class ResultadoInterpretacion {
  const ResultadoInterpretacion();
}

/// La notificación es un consumo (dinero saliente) y se extrajeron sus
/// datos completos. **Nunca parcial ni inventado** (FR-017): si algún campo
/// no se puede extraer con confianza, el resultado es [NoInterpretable], no
/// un [ConsumoExtraido] con huecos.
final class ConsumoExtraido extends ResultadoInterpretacion {
  final Dinero monto;
  final String comercio;

  /// Fecha del consumo, no de recepción de la notificación.
  final DateTime fecha;

  const ConsumoExtraido({
    required this.monto,
    required this.comercio,
    required this.fecha,
  });
}

/// La notificación se interpretó, pero no es un consumo que registrar:
/// dinero entrante, un consumo rechazado o extornado, una promoción, etc.
/// (FR-012, FR-013).
final class NoEsConsumo extends ResultadoInterpretacion {
  const NoEsConsumo();
}

/// El texto no se pudo interpretar con confianza: formato desconocido,
/// monto ilegible o moneda distinta al sol (FR-014, FR-017).
final class NoInterpretable extends ResultadoInterpretacion {
  final MotivoDiagnostico motivo;

  const NoInterpretable(this.motivo);
}

/// Interpreta el texto de una notificación de un origen ya reconocido.
///
/// **Único parser, compartido por todos los orígenes** (D-N2): no recibe el
/// origen como parámetro porque no lo necesita — el texto es lo único de lo
/// que depende, y es justamente eso lo que permite que un banco nuevo no
/// exija código nuevo (FR-008a).
///
/// Quién puede llamarla ya está filtrado: `filtrarNotificacion` decide, **sin
/// ver el cuerpo**, si la notificación es de un origen reconocido (FR-008c).
/// Para cuando el texto llega acá, mirarlo ya es legítimo.
///
/// [contenido] es el cuerpo completo — `raw['bigText']`, no `text`, que Gmail
/// trunca justo sobre el comercio.
///
/// [recibidaEn] entra como parámetro y no se lee del reloj: esta carpeta es
/// Dart puro y `test/pureza_test.dart` falla si alguien llama a
/// `DateTime.now()` acá adentro.
ResultadoInterpretacion interpretar({
  required String titulo,
  required String contenido,
  required DateTime recibidaEn,
}) {
  final zona = _zonaDeLaOperacion(contenido);

  switch (_direccionDe(zona)) {
    case _Direccion.entrante:
      return const NoEsConsumo();
    case _Direccion.ninguna:
    case _Direccion.ambas:
      return const NoInterpretable(MotivoDiagnostico.formatoNoReconocido);
    case _Direccion.saliente:
      break;
  }

  if (_tieneMontoExtranjero(zona)) {
    return const NoInterpretable(MotivoDiagnostico.monedaExtranjera);
  }

  final monto = _montoEnSolesDe(zona);
  if (monto == null) {
    return const NoInterpretable(MotivoDiagnostico.montoIlegible);
  }

  final comercio = _comercioDe(zona);
  if (comercio == null) {
    return const NoInterpretable(MotivoDiagnostico.formatoNoReconocido);
  }

  return ConsumoExtraido(
    monto: monto,
    comercio: comercio,
    fecha: _fechaDe(zona) ?? _soloElDia(recibidaEn),
  );
}

// ---------------------------------------------------------------------------
// Acotar lo que se lee
// ---------------------------------------------------------------------------

/// El tramo del correo que describe la operación, sin el pie.
///
/// **Acotar es obligatorio, no una optimización.** El pie fijo del BCP dice
/// "¿Problemas con tus **compras**? Si tu compra fue **rechazada**…" y
/// "…tu **tarjeta de débito o crédito**…": leído entero, un consumo
/// inequívoco muestra señales de las dos direcciones y termina en diagnóstico.
///
/// **Y la marca no puede ser el `¿`**, aunque sirva para los dos correos del
/// BCP. El de Sip no tiene un solo signo de apertura en todo el cuerpo: su pie
/// arranca con "Si no reconoces la operación". Una regla deducida de un solo
/// emisor se lee como general y no lo es — es lo que D-N9 venía advirtiendo.
String _zonaDeLaOperacion(String contenido) {
  final lineas = contenido.split('\n');
  for (var indice = 0; indice < lineas.length; indice++) {
    if (_abreElPie(lineas[indice])) return lineas.take(indice).join('\n');
  }
  return contenido;
}

/// Los arranques de pie observados en los correos reales.
///
/// Cada uno viene de un texto capturado, no de imaginar cómo escribiría un
/// banco: los dos primeros son del BCP, los tres últimos de Sip.
const List<String> _aperturasDePie = <String>[
  'no reconoces',
  'problemas con tus',
  'para tu seguridad',
  'jamás solicitará',
  'nunca te solicitará',
  'este correo electrónico fue enviado',
];

bool _abreElPie(String linea) {
  final limpia = linea.trim().toLowerCase();
  if (limpia.startsWith('¿')) return true;
  return _aperturasDePie.any(limpia.contains);
}

// ---------------------------------------------------------------------------
// Dirección del dinero (D-N11, D-N15)
// ---------------------------------------------------------------------------

enum _Direccion { saliente, entrante, ambas, ninguna }

/// Palabras que indican que el dinero **salió**.
///
/// Incluye las formas de envío desde D-N15: un yapeo enviado o una
/// transferencia bajan el saldo igual que una compra con tarjeta, así que son
/// consumos (FR-008d).
const List<String> _palabrasDeSalida = <String>[
  'realizaste un consumo',
  'realizaste una operación',
  'realizado una transacción',
  'consumo',
  'compra',
  'cargo',
  'pagaste',
  'pago realizado',
  'pago de servicios',
  'enviar a celular',
  'enviaste',
  'yapeaste',
  'acabas de yapear',
  'transferencia realizada',
];

const List<String> _palabrasDeEntrada = <String>[
  'recepción',
  'recibiste',
  'te yapeó',
  'te envió',
  'te enviaron',
  'monto recibido',
  'abono',
  'depósito',
  'transferencia recibida',
];

/// Clasifica leyendo **primero el asunto**, y solo si no alcanza, el cuerpo.
///
/// El asunto —la primera línea del correo— dice la operación en pocas palabras
/// y sin nada alrededor que la contradiga. El cuerpo, en cambio, está lleno de
/// etiquetas que parecen señales y no lo son: "Operación realizada" encabeza
/// tanto un yapeo recibido como uno enviado, y "Enviado por" (me lo mandaron)
/// se parece demasiado a "Enviado a" (lo mandé yo). Preguntarle al asunto
/// primero esquiva todas esas trampas de una vez.
_Direccion _direccionDe(String zona) {
  final porAsunto = _direccionEn(_asuntoDe(zona));
  if (porAsunto == _Direccion.saliente || porAsunto == _Direccion.entrante) {
    return porAsunto;
  }
  return _direccionEn(zona);
}

String _asuntoDe(String zona) {
  for (final linea in zona.split('\n')) {
    if (linea.trim().isNotEmpty) return linea;
  }
  return '';
}

_Direccion _direccionEn(String texto) {
  final minuscula = texto.toLowerCase();
  final sale = _palabrasDeSalida.any(minuscula.contains);
  final entra = _palabrasDeEntrada.any(minuscula.contains);

  if (sale && entra) return _Direccion.ambas;
  if (sale) return _Direccion.saliente;
  if (entra) return _Direccion.entrante;
  return _Direccion.ninguna;
}

// ---------------------------------------------------------------------------
// Monto
// ---------------------------------------------------------------------------

/// El sol, con el punto opcional después de la barra.
///
/// **Ese punto no es un capricho de formato**: el BCP escribe `S/ 23.60` y Sip
/// escribe `S/. 37.70`. Una expresión sin el `\.?` reconoce el monto de un
/// emisor y no el del otro — y el ejemplo que propone D-N3 no lo tiene.
final RegExp _montoEnSoles = RegExp(r'S/\.?\s*(\d[\d,]*(?:\.\d{1,2})?)');

/// Cualquier monto que no esté en soles (FR-014).
///
/// No se convierte ni se aproxima: la regla del proyecto no admite
/// multimoneda y D14 de la 001 rechazó traer tipos de cambio de ninguna parte.
final RegExp _montoExtranjero = RegExp(
  r'(?:US\$|USD|\$)\s*\d[\d,]*(?:\.\d{1,2})?',
);

bool _tieneMontoExtranjero(String zona) => _montoExtranjero.hasMatch(zona);

Dinero? _montoEnSolesDe(String zona) {
  final coincidencia = _montoEnSoles.firstMatch(zona);
  if (coincidencia == null) return null;
  try {
    return Dinero.deTextoDecimal(coincidencia.group(1)!);
  } on FormatException {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Comercio
// ---------------------------------------------------------------------------

/// Las etiquetas bajo las que cada emisor pone con quién fue la operación.
///
/// `Enviado a` es la del destinatario de un envío: desde D-N15 ocupa el lugar
/// del comercio cuando no hay comercio (un yapeo a una persona).
///
/// **Cuidado con `Enviado por`**, que es lo contrario y encabeza los avisos de
/// dinero recibido. No está en esta lista y no puede estarlo: por eso la
/// etiqueta se compara entera, nunca por prefijo.
const List<String> _etiquetasDeComercio = <String>[
  'establecimiento',
  'empresa',
  'comercio',
  'enviado a',
];

/// El valor que sigue a una etiqueta conocida.
///
/// **El valor va en el renglón siguiente, no al lado de su etiqueta.** Es lo
/// único que se mantiene entre emisores: lo demás cambia — Sip escribe
/// `Establecimiento:` con dos puntos y el BCP `Empresa` sin ellos. Se admiten
/// las dos formas, y también que el valor venga en la misma línea tras el `:`.
String? _comercioDe(String zona) {
  final lineas = zona.split('\n');
  for (var indice = 0; indice < lineas.length; indice++) {
    final linea = lineas[indice].trim();
    final corte = linea.indexOf(':');
    final etiqueta = (corte == -1 ? linea : linea.substring(0, corte))
        .trim()
        .toLowerCase();

    if (!_etiquetasDeComercio.contains(etiqueta)) continue;

    if (corte != -1) {
      final mismaLinea = linea.substring(corte + 1).trim();
      if (mismaLinea.isNotEmpty) return mismaLinea;
    }
    final siguiente = _primeraLineaConTexto(lineas, desde: indice + 1);
    if (siguiente != null) return siguiente;
  }
  return null;
}

String? _primeraLineaConTexto(List<String> lineas, {required int desde}) {
  for (var indice = desde; indice < lineas.length; indice++) {
    final texto = lineas[indice].trim();
    if (texto.isNotEmpty) return texto;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Fecha
// ---------------------------------------------------------------------------

final RegExp _fechaNumerica = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})');

final RegExp _fechaEnLetras = RegExp(
  r'(\d{1,2})\s+de\s+([a-záéíóúA-ZÁÉÍÓÚ]+)\s+de\s+(\d{4})',
);

/// Los doce meses, con las **dos grafías de setiembre**.
///
/// El BCP escribe `setiembre` y `septiembre` indistintamente, el mismo día y
/// desde el mismo remitente. Las dos son correctas en español y aceptar una
/// sola haría fallar la mitad de sus correos.
const Map<String, int> _meses = <String, int>{
  'enero': 1,
  'febrero': 2,
  'marzo': 3,
  'abril': 4,
  'mayo': 5,
  'junio': 6,
  'julio': 7,
  'agosto': 8,
  'setiembre': 9,
  'septiembre': 9,
  'octubre': 10,
  'noviembre': 11,
  'diciembre': 12,
};

/// La fecha del consumo, o `null` si el texto no la trae de forma reconocible.
///
/// Devolver `null` en vez de adivinar es lo que pide FR-017; quien llama
/// decide con qué reemplazarla, y lo hace con un dato real —el momento en que
/// llegó la notificación, que para un consumo es cuestión de segundos— y no
/// con uno inventado.
DateTime? _fechaDe(String zona) {
  final numerica = _fechaNumerica.firstMatch(zona);
  if (numerica != null) {
    return DateTime(
      int.parse(numerica.group(3)!),
      int.parse(numerica.group(2)!),
      int.parse(numerica.group(1)!),
    );
  }

  final enLetras = _fechaEnLetras.firstMatch(zona);
  if (enLetras != null) {
    final mes = _meses[enLetras.group(2)!.toLowerCase()];
    if (mes != null) {
      return DateTime(
        int.parse(enLetras.group(3)!),
        mes,
        int.parse(enLetras.group(1)!),
      );
    }
  }

  return null;
}

DateTime _soloElDia(DateTime momento) =>
    DateTime(momento.year, momento.month, momento.day);
