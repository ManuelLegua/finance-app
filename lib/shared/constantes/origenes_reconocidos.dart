/// Un banco o billetera cuyas notificaciones la app sabe escuchar (spec 002,
/// FR-008, D-N10).
///
/// A diferencia de `Categoria` o `TipoTarjeta`, esto **no es un `enum`**: es
/// una lista de datos, a propósito. Agregar un origen nuevo es agregar un
/// elemento acá, no escribir ni desplegar código de interpretación nuevo
/// (FR-008a) — el parser genérico de `dominio/interpretes/` es el mismo para
/// todos.
final class OrigenReconocido {
  const OrigenReconocido({required this.nombre, required this.paquete});

  /// El que ve el usuario (p. ej. "BCP").
  final String nombre;

  /// El paquete Android de la app que manda la notificación (p. ej.
  /// `com.bcp.bank.android`). Cadena vacía significa "todavía sin verificar
  /// en un dispositivo real" (T041 de tasks.md): un origen así **no se
  /// escucha** — el servicio de escucha filtra por paquete exacto, y una
  /// cadena vacía nunca calza con el paquete real de una notificación.
  final String paquete;

  bool get paqueteVerificado => paquete.isNotEmpty;
}

/// Sembrada con los mismos emisores peruanos que `EntidadesPeru` (001,
/// `lib/dominio/modelos/entidades.dart`) — a propósito una lista propia y no
/// una derivada de esa: esta vive en `shared/` (Dart puro, sin conocer el
/// dominio — la dirección de dependencia es siempre hacia adentro) y además
/// lleva un dato que `EntidadesPeru` no necesita (`paquete`). Las dos listas
/// pueden divergir con el tiempo sin que eso sea un error: una es sugerencia
/// de texto libre para una tarjeta, la otra es una lista técnica de qué
/// notificaciones escuchar.
///
/// Los paquetes se completan observando cada app en un dispositivo real
/// (D-N10): no existe un padrón público de paquetes Android por banco, igual
/// que no existe documentación pública del formato de sus notificaciones.
final List<OrigenReconocido> origenesReconocidos = [
  for (final nombre in _nombresSembrados)
    OrigenReconocido(nombre: nombre, paquete: ''),
];

const List<String> _nombresSembrados = <String>[
  'BCP',
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
  'Oh!',
  'Yape',
  'Plin',
];
