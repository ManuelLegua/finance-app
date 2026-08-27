/// Error de la capa de datos, con contexto legible.
///
/// Envuelve las excepciones de `sqflite` para que ninguna pantalla muestre un
/// mensaje de SQL crudo. El [detalle] técnico se conserva para depurar, pero
/// lo que se muestra al usuario es [mensaje].
final class ErrorPersistencia implements Exception {
  /// Qué se estaba intentando hacer, en español y sin jerga.
  final String mensaje;

  /// La excepción original. Nunca se muestra al usuario.
  final Object? detalle;

  const ErrorPersistencia(this.mensaje, [this.detalle]);

  /// La base existe pero no se pudo abrir o está corrupta.
  ///
  /// Es el caso que más importa comunicar bien: si la app arrancara con datos
  /// vacíos, el usuario creería que perdió su historial cuando el archivo
  /// sigue ahí. Y como esta versión no tiene respaldo ni exportación, esa
  /// confusión no tiene vuelta atrás.
  factory ErrorPersistencia.alAbrir(Object causa) => ErrorPersistencia(
    'No se pudieron abrir tus datos. La información sigue guardada en el '
    'dispositivo, pero la app no puede leerla en este momento.',
    causa,
  );

  factory ErrorPersistencia.alGuardar(String que, Object causa) =>
      ErrorPersistencia('No se pudo guardar $que.', causa);

  factory ErrorPersistencia.alLeer(String que, Object causa) =>
      ErrorPersistencia('No se pudieron leer $que.', causa);

  /// La operación es válida pero contradice una regla de integridad, como
  /// borrar una tarjeta que todavía tiene deudas.
  factory ErrorPersistencia.integridad(String mensaje) =>
      ErrorPersistencia(mensaje);

  @override
  String toString() =>
      'ErrorPersistencia: $mensaje'
      '${detalle == null ? '' : ' (causa: $detalle)'}';
}
