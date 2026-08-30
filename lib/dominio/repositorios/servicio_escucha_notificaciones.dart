/// Puerto hacia la escucha de notificaciones bancarias (spec 002, D-N1).
///
/// Es la única pieza de esta feature atada a una plataforma concreta — la
/// interfaz vive en `dominio/` (igual que los repositorios de 001) para que
/// la UI y el estado dependan de esta abstracción, nunca del plugin. Fuera
/// de Android no se instancia ninguna implementación (D-N8, FR-007).
abstract interface class ServicioEscuchaNotificaciones {
  /// El permiso real del sistema, leído en cada llamada — nunca cacheado
  /// (FR-003).
  Future<bool> permisoConcedido();

  /// Dirige al usuario a la pantalla de Android donde se concede o revoca el
  /// permiso de acceso a notificaciones (FR-002).
  Future<void> abrirAjustesDePermiso();

  /// Enciende el interruptor de la app y arranca el servicio de escucha en
  /// modo *foreground* (D-N4). No pide el permiso — eso ya pasó por
  /// [abrirAjustesDePermiso]; si el permiso no está concedido, el servicio
  /// arranca pero no va a recibir notificaciones hasta que lo esté.
  Future<void> activar();

  /// Apaga el interruptor de la app y detiene el servicio. Las
  /// transacciones ya confirmadas y las asociaciones aprendidas no se tocan
  /// (FR-005).
  Future<void> desactivar();
}
