/// Puerto hacia la escucha de notificaciones bancarias (spec 002, D-N1).
///
/// Es la única pieza de esta feature atada a una plataforma concreta — la
/// interfaz vive en `dominio/` (igual que los repositorios de 001) para que
/// la UI y el estado dependan de esta abstracción, nunca del plugin. Fuera
/// de Android no se instancia ninguna implementación (D-N8, FR-007).
abstract interface class ServicioEscuchaNotificaciones {
  /// El permiso de **leer** las notificaciones de otras apps, leído en cada
  /// llamada — nunca cacheado (FR-003). Es el permiso central de esta
  /// feature, el que se concede desde los ajustes de Android.
  Future<bool> permisoConcedido();

  /// Pide el permiso de **mostrar** notificaciones propias, y devuelve si
  /// quedó concedido.
  ///
  /// No confundir con [permisoConcedido]: aquel es para leer las de los
  /// bancos, este es para que la app pueda mostrar **una sola**, el aviso
  /// persistente que todo servicio en primer plano está obligado a publicar.
  ///
  /// Sin él, desde Android 13 el sistema mata el servicio apenas arranca
  /// (`Context.startForegroundService() did not then call
  /// Service.startForeground()`) y la captura no corre nunca — que es
  /// exactamente lo que pasaba antes de D-N13. En versiones anteriores de
  /// Android no hay nada que pedir y devuelve `true`.
  Future<bool> pedirPermisoDelAvisoPersistente();

  /// Si el servicio de escucha está corriendo ahora mismo, preguntado al
  /// sistema.
  ///
  /// **No se deduce del permiso ni del interruptor de la app**: Android mata
  /// el servicio por su cuenta, y tras reinstalar queda registrado contra el
  /// build anterior. Sin esta consulta la app informaba "Captura activa" sin
  /// capturar nada (D-N13 de research.md).
  Future<bool> estaCorriendo();

  /// Dirige al usuario a la pantalla de Android donde se concede o revoca el
  /// permiso de acceso a notificaciones (FR-002).
  ///
  /// La implementación **debe dejar la app visible en esa lista antes de
  /// abrirla**: desactivar la captura puede deshabilitar el componente del
  /// servicio, y un componente deshabilitado no aparece ahí — mandando al
  /// usuario a conceder un permiso en una pantalla donde la app no figura
  /// (D-N13).
  Future<void> abrirAjustesDePermiso();

  /// Enciende el interruptor de la app y arranca el servicio de escucha en
  /// modo *foreground* (D-N4). No pide el permiso — eso ya pasó por
  /// [abrirAjustesDePermiso]; si el permiso no está concedido, el servicio
  /// arranca pero no va a recibir notificaciones hasta que lo esté.
  Future<void> activar();

  /// Si Android tiene a la app exenta de la optimización de batería (D-N4).
  ///
  /// **No es condición para que la captura funcione**, y por eso no entra en
  /// `EstadoCaptura`: sin la exención se capturan consumos igual, solo que el
  /// sistema puede matar el servicio cuando el teléfono está quieto — y
  /// algunos fabricantes lo hacen con ganas. Decir "no funciona" cuando sí
  /// funciona sería peor que no avisar nada.
  Future<bool> exentaDeOptimizacionDeBateria();

  /// Lleva al usuario a la lista del sistema donde se concede esa exención.
  ///
  /// Va a los **ajustes** y no al diálogo directo a propósito: el diálogo
  /// exige `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, que Google Play limita a
  /// casos de uso acotados y obliga a justificar. La lista no exige ningún
  /// permiso y llega al mismo lado con un toque más — el mismo trato que ya
  /// se le da al permiso de lectura en [abrirAjustesDePermiso].
  Future<void> abrirAjustesDeOptimizacionDeBateria();

  /// Apaga el interruptor de la app y detiene el servicio. Las
  /// transacciones ya confirmadas y las asociaciones aprendidas no se tocan
  /// (FR-005).
  Future<void> desactivar();
}
