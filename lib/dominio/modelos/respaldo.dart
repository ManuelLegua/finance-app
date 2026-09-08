/// Modelos del respaldo y su validación (spec 005).
///
/// Dart puro: acá no se abre ningún archivo ni se consulta ninguna base. Un
/// respaldo **es** un archivo SQLite (D1 de research.md), pero desde el
/// dominio solo se lo conoce por su ruta y por los hechos que alguien más ya
/// averiguó sobre él.
library;

/// El veredicto sobre un archivo candidato a restaurarse (FR-009).
///
/// Es un enum y no un `bool` con un mensaje al lado porque el usuario tiene
/// que poder distinguir los motivos: "está dañado", "no es de esta app" y "es
/// de una versión más nueva" llevan a acciones distintas. Además el `switch`
/// exhaustivo que produce el mensaje deja de compilar si mañana aparece un
/// quinto motivo, en vez de mostrar un "error" genérico.
enum ResultadoValidacionRespaldo {
  /// Pasa las tres comprobaciones de D2: se puede seguir al aviso de
  /// reemplazo.
  valido,

  /// `integrity_check` no devolvió `ok`, o el archivo ni siquiera es SQLite.
  corrupto,

  /// Es SQLite válido, pero le faltan tablas del esquema o su
  /// `user_version` es 0: no lo escribió esta app.
  noEsDeLaApp,

  /// Su `user_version` es mayor que la que esta versión de la app sabe leer.
  /// Las migraciones solo van hacia adelante, así que no hay forma de
  /// interpretarlo.
  deVersionMasNueva,
}

/// Lo que la app sabe decir de un archivo candidato **antes** de tocar nada.
///
/// Se arma en `inspeccionar()` y se muestra en la UI: por eso lleva las dos
/// versiones y no solo el veredicto — con un respaldo válido pero anterior,
/// la pantalla puede avisar que se va a actualizar al restaurarlo.
final class InformeRespaldo {
  const InformeRespaldo({
    required this.resultado,
    required this.versionDelArchivo,
    required this.versionSoportada,
  });

  final ResultadoValidacionRespaldo resultado;

  /// El `PRAGMA user_version` que traía el archivo. Es 0 cuando no se pudo
  /// leer, que es también el valor de un SQLite sin esquema versionado.
  final int versionDelArchivo;

  /// La versión de esquema que esta instalación de la app sabe leer.
  final int versionSoportada;

  bool get esValido => resultado == ResultadoValidacionRespaldo.valido;

  /// Si al restaurarlo van a correr migraciones (FR-010). Solo tiene sentido
  /// preguntarlo de un archivo ya aceptado.
  bool get requiereMigracion =>
      esValido && versionDelArchivo < versionSoportada;
}

/// El archivo de respaldo recién generado, listo para entregar al usuario.
///
/// No es una entidad persistida: es lo que sale de `exportar()`. La app deja
/// el archivo en su almacenamiento privado y propone un nombre; **adónde va
/// después lo decide el usuario** fuera de la app (FR-004, D5).
final class ArchivoRespaldo {
  const ArchivoRespaldo({required this.ruta, required this.nombrePropuesto});

  /// Dónde quedó el archivo generado, en el directorio temporal privado.
  final String ruta;

  /// Cómo se llama de cara al usuario: `finanzas-respaldo-AAAA-MM-DD.db`.
  /// Renombrarlo no rompe nada: la restauración no depende del nombre.
  final String nombrePropuesto;
}
