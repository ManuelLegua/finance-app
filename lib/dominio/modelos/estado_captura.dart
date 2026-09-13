import 'package:finanzas/shared/constantes/origenes_reconocidos.dart';

/// En qué situación está la captura de notificaciones bancarias (spec 002,
/// FR-003, FR-004).
enum SituacionCaptura {
  /// Nunca se concedió el permiso del sistema.
  sinPermiso,

  /// Se activó alguna vez (el interruptor de la app sigue en `true`), pero el
  /// permiso ya no está — el usuario lo revocó desde los ajustes de Android,
  /// o el sistema lo retiró.
  permisoRevocado,

  /// El permiso está concedido, pero el usuario apagó el interruptor de la
  /// app.
  inactivaEnApp,

  /// Permiso concedido y captura encendida, pero **el servicio no está
  /// corriendo**: Android lo detuvo, o quedó a medias tras reinstalar la app.
  ///
  /// Existe porque sin este valor la app informaba "activa" en una situación
  /// en la que no se capturaba nada (D-N13 de research.md). Es la diferencia
  /// entre "lo tenés encendido" y "está funcionando", y al usuario le importa
  /// la segunda.
  detenida,

  /// Permiso concedido, captura encendida y servicio corriendo: la única
  /// situación en la que de verdad se procesan notificaciones.
  activa,
}

/// Estado de la captura, combinando el permiso real del sistema con el
/// interruptor de la app — **nunca** se confía en lo que el usuario aceptó
/// alguna vez (FR-003). No se persiste: se deriva en cada consulta.
final class EstadoCaptura {
  final bool permisoConcedido;
  final bool activaEnApp;

  /// Si el servicio de escucha está efectivamente corriendo, preguntado al
  /// sistema en cada consulta.
  ///
  /// **No se deduce de los otros dos.** Tener el permiso y el interruptor
  /// encendido no implica que el servicio exista: Android lo mata, o queda a
  /// medias tras reinstalar la app, y hasta D-N13 eso se mostraba como
  /// "Captura activa".
  final bool servicioCorriendo;

  const EstadoCaptura({
    required this.permisoConcedido,
    required this.activaEnApp,
    required this.servicioCorriendo,
  });

  /// Distinguir "nunca se activó" de "se activó y el permiso se revocó
  /// después" solo se puede saber comparando ambos valores: si la app
  /// recuerda haberla activado (`activaEnApp`) pero el sistema ya no
  /// concede el permiso, es que se lo revocaron — no que nunca se pidió.
  /// El permiso manda sobre todo lo demás: sin él, que el servicio esté
  /// vinculado no sirve de nada, porque Android no le entrega notificaciones.
  SituacionCaptura get situacion =>
      switch ((permisoConcedido, activaEnApp, servicioCorriendo)) {
        (false, true, _) => SituacionCaptura.permisoRevocado,
        (false, false, _) => SituacionCaptura.sinPermiso,
        (true, false, _) => SituacionCaptura.inactivaEnApp,
        (true, true, false) => SituacionCaptura.detenida,
        (true, true, true) => SituacionCaptura.activa,
      };

  /// Explicación en español, lista para mostrar — igual que `EstadoCierre` de
  /// 001, ningún estado se comunica solo con un ícono (FR-029 por extensión).
  String get motivo => switch (situacion) {
    SituacionCaptura.sinPermiso =>
      'Todavía no activaste la captura de notificaciones.',
    SituacionCaptura.permisoRevocado =>
      'Le quitaste a la app el permiso de leer notificaciones desde los '
          'ajustes de Android. La captura dejó de funcionar hasta que lo '
          'concedas de nuevo.',
    SituacionCaptura.inactivaEnApp =>
      'La captura está apagada. El permiso sigue concedido, así que '
          'activarla de nuevo no te va a pedir nada.',
    // No se dice "está activa pero...": el usuario tiene que entender que
    // **no se está capturando**, no que hay un detalle menor pendiente.
    SituacionCaptura.detenida =>
      'La captura dejó de funcionar: el sistema detuvo el servicio. Tus '
          'consumos no se están registrando hasta que la vuelvas a activar.',
    SituacionCaptura.activa => 'Captura activa.',
  };

  /// Los bancos y billeteras que se escuchan mientras la captura está
  /// activa. Vacía en cualquier otra situación — no tiene sentido listar
  /// orígenes de algo que no está corriendo.
  List<OrigenReconocido> get origenesQueCubre =>
      situacion == SituacionCaptura.activa
      ? origenesReconocidos
      : const <OrigenReconocido>[];

  @override
  bool operator ==(Object other) =>
      other is EstadoCaptura &&
      other.permisoConcedido == permisoConcedido &&
      other.activaEnApp == activaEnApp &&
      other.servicioCorriendo == servicioCorriendo;

  @override
  int get hashCode =>
      Object.hash(permisoConcedido, activaEnApp, servicioCorriendo);

  @override
  String toString() => 'EstadoCaptura($situacion)';
}
