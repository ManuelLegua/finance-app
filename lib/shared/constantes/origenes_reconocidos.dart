/// Un banco o billetera cuyas notificaciones la app sabe escuchar (spec 002,
/// FR-008, D-N10, D-N12).
///
/// A diferencia de `Categoria` o `TipoTarjeta`, esto **no es un `enum`**: es
/// una lista de datos, a propósito. Agregar un origen nuevo es agregar un
/// elemento acá, no escribir ni desplegar código de interpretación nuevo
/// (FR-008a) — el parser genérico de `dominio/interpretes/` es el mismo para
/// todos.
///
/// ## Dos modos de identificación, no uno (D-N12)
///
/// El diseño original identificaba un origen por el paquete de Android de su
/// app. Las capturas del 2026-09-13 mostraron que eso no alcanza: en el
/// teléfono de referencia las apps de banco solo notifican **dinero
/// entrante**, y los consumos —lo único que esta spec registra— llegan por
/// **correo**. Para un correo el paquete es siempre `com.google.android.gm`,
/// que no distingue al banco de ningún otro remitente.
///
/// Por eso un origen se identifica por [paquete] **o** por [remitente], y
/// alcanza con tener verificado cualquiera de los dos.
final class OrigenReconocido {
  const OrigenReconocido({
    required this.nombre,
    this.paquete = '',
    this.remitentes = const <String>{},
  });

  /// El que ve el usuario (p. ej. "BCP").
  final String nombre;

  /// El paquete Android de la app que manda la notificación por su cuenta
  /// (p. ej. `com.bcp.bank.android`). Cadena vacía significa "todavía sin
  /// verificar en un dispositivo real" (T041 de tasks.md).
  final String paquete;

  /// Los remitentes tal como aparecen en el `title` de la notificación cuando
  /// el aviso llega por correo (p. ej. `BCP Notificaciones`).
  ///
  /// **Es un conjunto y no una cadena porque un mismo emisor usa más de un
  /// nombre según el tipo de correo**: Sip firma `Operaciones Sip` un envío de
  /// dinero y `Sip` a secas un consumo con tarjeta. Con un único remitente por
  /// origen, la mitad de sus avisos se descarta por no reconocido — y se
  /// descartaba, hasta que las capturas G5 y G6 lo mostraron.
  ///
  /// Vacío significa "todavía sin verificar".
  final Set<String> remitentes;

  bool get paqueteVerificado => paquete.isNotEmpty;

  bool get remitenteVerificado => remitentes.isNotEmpty;

  /// Un origen se escucha si se lo puede identificar de alguna de las dos
  /// formas. Sin ninguna verificada no se escucha, y eso no rompe nada: una
  /// cadena vacía nunca calza con el paquete ni con el título real de una
  /// notificación.
  bool get utilizable => paqueteVerificado || remitenteVerificado;
}

/// Sembrada con los mismos emisores peruanos que `EntidadesPeru` (001,
/// `lib/dominio/modelos/entidades.dart`) — a propósito una lista propia y no
/// una derivada de esa: esta vive en `shared/` (Dart puro, sin conocer el
/// dominio — la dirección de dependencia es siempre hacia adentro) y además
/// lleva datos que `EntidadesPeru` no necesita (`paquete`, `remitente`). Las
/// dos listas pueden divergir con el tiempo sin que eso sea un error: una es
/// sugerencia de texto libre para una tarjeta, la otra es una lista técnica de
/// qué notificaciones escuchar.
///
/// Los paquetes y los remitentes se completan observando el teléfono (D-N10,
/// D-N12): no existe un padrón público de paquetes Android por banco, igual
/// que no existe documentación pública del formato de sus notificaciones.
final List<OrigenReconocido> origenesReconocidos = [
  const OrigenReconocido(
    nombre: 'BCP',
    remitentes: {'BCP Notificaciones'},
  ),
  // El único origen con los dos modos verificados: publica push por su cuenta
  // (el aviso de dinero recibido del 00:29) y además avisa por correo.
  const OrigenReconocido(
    nombre: 'Yape',
    paquete: 'com.bcp.innovacxion.yapeapp',
    remitentes: {'YAPE Notificaciones'},
  ),

  // El proyecto trata Oh! y Sip como un mismo origen desde D-N10 ("Oh!/SIP").
  //
  // Los dos remitentes están verificados y son del mismo emisor: firma
  // `Operaciones Sip` un envío de dinero (G2) y `Sip` un consumo con tarjeta
  // (G5, G6). Con solo el primero, los consumos con tarjeta —justo lo que esta
  // spec captura— se descartaban por origen no reconocido.
  const OrigenReconocido(
    nombre: 'Oh!',
    remitentes: {'Operaciones Sip', 'Sip'},
  ),

  for (final nombre in _nombresSinVerificar) OrigenReconocido(nombre: nombre),
];

/// Los que todavía no se observaron en un dispositivo: sin paquete ni
/// remitente, no se escuchan (T041).
const List<String> _nombresSinVerificar = <String>[
  'Interbank',
  'BBVA',
  'Scotiabank',
  'Banco Falabella',
  'Banco Ripley',
  'Banco Pichincha',
  'BanBif',
  'Mibanco',
  'Banco de la Nación',
  'Caja Arequipa',
  'Caja Huancayo',
  'Plin',
];

/// Qué hacer con una notificación recién llegada, **decidido sin mirar su
/// cuerpo** (FR-008c).
///
/// Que esta función no reciba el texto de la notificación es el punto de todo.
/// Reconocer el correo como vía implica que el servicio recibe el aviso de
/// **todo** correo que llegue al teléfono, no solo el del banco: Android
/// entrega primero y filtra después, no hay forma de suscribirse a un
/// remitente. La única garantía posible es estructural — quien decide si la
/// notificación se procesa no tiene acceso al cuerpo, así que no puede leer un
/// correo personal ni por error.
sealed class DecisionFiltro {
  const DecisionFiltro();
}

/// La notificación es de un origen reconocido y su cuerpo se puede leer.
final class ProcesarComo extends DecisionFiltro {
  const ProcesarComo(this.origen);

  final OrigenReconocido origen;
}

/// La notificación se descarta sin leerla, sin guardarla y sin dejar rastro —
/// ni pendiente, ni registro de diagnóstico, ni log (FR-008c).
final class Descartar extends DecisionFiltro {
  const Descartar(this.motivo);

  final MotivoDescarte motivo;
}

/// Por qué se descartó. **No se persiste**: existe para que las pruebas
/// distingan un descarte de otro y para que el diagnóstico de desarrollo sea
/// legible, no para dejar constancia de notificaciones ajenas.
enum MotivoDescarte {
  /// Ni el paquete ni el remitente calzan con ningún origen reconocido. Es el
  /// caso de todo correo personal.
  origenNoReconocido,

  /// El resumen de grupo que Gmail publica junto a cada correo (D-N12).
  ///
  /// Procesarlo contaría cada consumo dos veces. **La regla es `isGroup`, no
  /// la forma del texto**: cuando hay un solo correo sin leer el resumen copia
  /// el `bigText` entero y no trae `textLines`, así que la regla que parecía
  /// servir con varios correos —`bigText == null && textLines != null`— no los
  /// distingue.
  resumenDeGrupo,
}

/// Decide si una notificación se procesa, mirando solo sus metadatos.
///
/// [titulo] es el `title` del evento: para un correo, el remitente; para el
/// push de una app, lo que la app haya puesto ahí.
DecisionFiltro filtrarNotificacion({
  required String paquete,
  required String? titulo,
  required bool esResumenDeGrupo,
}) {
  // Primero el resumen de grupo: descartarlo no depende de reconocer el
  // origen, y saltearse este paso duplicaría todo consumo que sí calce.
  if (esResumenDeGrupo) return const Descartar(MotivoDescarte.resumenDeGrupo);

  final origen = _origenDe(paquete: paquete, titulo: titulo);
  if (origen == null) return const Descartar(MotivoDescarte.origenNoReconocido);

  return ProcesarComo(origen);
}

OrigenReconocido? _origenDe({required String paquete, required String? titulo}) {
  for (final origen in origenesReconocidos) {
    if (origen.paqueteVerificado && origen.paquete == paquete) return origen;
  }

  // El título se compara **exacto**, no por contenido. Un `contains` haría
  // que un correo de una persona cuyo nombre incluya "BCP" calce como banco, y
  // el costo de equivocarse acá es leer correo ajeno. Si un banco cambia su
  // nombre de remitente esto deja de capturar — que es la forma segura de
  // fallar: no captura de más, captura de menos, y se arregla agregando el
  // remitente nuevo a la lista.
  final remitente = titulo?.trim();
  if (remitente == null || remitente.isEmpty) return null;

  for (final origen in origenesReconocidos) {
    if (origen.remitentes.contains(remitente)) return origen;
  }

  return null;
}
