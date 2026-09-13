/// Un monto que se puede dejar como propina, tal como lo informa Google Play
/// (spec 004 revisada, FR-003).
///
/// **No se persiste**: se consulta en vivo cada vez que se abre la pantalla de
/// apoyo. Una propina no concede nada, así que no hay estado que cachear
/// (research.md D8).
final class OfertaPropina {
  /// Identificador del producto en Google Play Console — uno de
  /// `idsDePropina`. Es lo único que la app conoce de antemano.
  final String id;

  /// Nombre que la tienda le da al producto, ya localizado.
  final String titulo;

  /// Precio ya formateado y localizado por Google Play (p. ej. `S/ 5.00`).
  ///
  /// Es un texto, no un [Dinero], a propósito: no es dinero que la app
  /// calcule, sume ni guarde, sino un precio que la tienda informa para
  /// mostrar tal cual. Sobre este valor no se hace aritmética ni se parsea
  /// nada, así que el Principio II no le aplica.
  final String precioFormateado;

  const OfertaPropina({
    required this.id,
    required this.titulo,
    required this.precioFormateado,
  });

  @override
  bool operator ==(Object other) =>
      other is OfertaPropina &&
      other.id == id &&
      other.titulo == titulo &&
      other.precioFormateado == precioFormateado;

  @override
  int get hashCode => Object.hash(id, titulo, precioFormateado);

  @override
  String toString() => 'OfertaPropina($id, $precioFormateado)';
}

/// Cómo terminó un intento de apoyar.
///
/// Es un enum y no un `bool` porque son cuatro desenlaces con tratamientos
/// distintos, y el `switch` exhaustivo obliga a manejarlos todos: tratar
/// [cancelada] como un fallo sería reprocharle al usuario haber cerrado un
/// diálogo (FR-008).
enum ResultadoPropina {
  /// Google confirmó el pago. La app agradece (FR-012).
  completada,

  /// El usuario cerró el diálogo de Google. **No es un error** (FR-008).
  cancelada,

  /// Google aceptó la compra pero todavía no la confirma. Se acusará recibo
  /// la próxima vez que se abran los montos (FR-010).
  pendiente,

  /// La tienda rechazó la compra. Se muestra el motivo y se deja reintentar.
  fallida,
}
