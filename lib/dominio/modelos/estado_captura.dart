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

  /// Permiso concedido y captura encendida: la única situación en la que de
  /// verdad se procesan notificaciones.
  activa,
}

/// Estado de la captura, combinando el permiso real del sistema con el
/// interruptor de la app — **nunca** se confía en lo que el usuario aceptó
/// alguna vez (FR-003). No se persiste: se deriva en cada consulta.
final class EstadoCaptura {
  final bool permisoConcedido;
  final bool activaEnApp;

  const EstadoCaptura({
    required this.permisoConcedido,
    required this.activaEnApp,
  });

  /// Distinguir "nunca se activó" de "se activó y el permiso se revocó
  /// después" solo se puede saber comparando ambos valores: si la app
  /// recuerda haberla activado (`activaEnApp`) pero el sistema ya no
  /// concede el permiso, es que se lo revocaron — no que nunca se pidió.
  SituacionCaptura get situacion => switch ((permisoConcedido, activaEnApp)) {
    (true, true) => SituacionCaptura.activa,
    (true, false) => SituacionCaptura.inactivaEnApp,
    (false, true) => SituacionCaptura.permisoRevocado,
    (false, false) => SituacionCaptura.sinPermiso,
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
      other.activaEnApp == activaEnApp;

  @override
  int get hashCode => Object.hash(permisoConcedido, activaEnApp);

  @override
  String toString() => 'EstadoCaptura($situacion)';
}
