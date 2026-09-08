import 'package:finanzas/dominio/modelos/respaldo.dart';

/// Decide si un archivo candidato puede restaurarse, y si no, por qué.
///
/// Recibe **hechos ya averiguados** sobre el archivo: no lo abre, no lo copia
/// y no consulta la base. Quien los averigua es `RepositorioRespaldo`, que sí
/// puede tocar `dart:io` y `sqflite`; acá queda solo el criterio, que es lo
/// único de esta feature con una decisión propia que probar (D6).
///
/// El **orden** de las comprobaciones es parte del contrato, porque decide qué
/// motivo se reporta cuando falla más de una a la vez:
///
///  1. Un archivo sin integridad es `corrupto`, y nada más se puede afirmar de
///     él: si ni siquiera es SQLite, lo que se haya leído de sus tablas o de
///     su versión no significa nada.
///  2. Sin las tablas del esquema —o con `user_version` en 0— es un SQLite
///     ajeno: `noEsDeLaApp`. Que además diga tener una versión futura no lo
///     convierte en un respaldo de esta app.
///  3. Recién entonces una versión mayor que la soportada es
///     `deVersionMasNueva`: las migraciones solo van hacia adelante y no hay
///     forma de adivinar qué trae un esquema que todavía no se escribió.
ResultadoValidacionRespaldo validarRespaldo({
  required bool integridadOk,
  required bool tablasEsperadasPresentes,
  required int versionDelArchivo,
  required int versionSoportada,
}) {
  if (!integridadOk) return ResultadoValidacionRespaldo.corrupto;

  if (!tablasEsperadasPresentes || versionDelArchivo == 0) {
    return ResultadoValidacionRespaldo.noEsDeLaApp;
  }

  if (versionDelArchivo > versionSoportada) {
    return ResultadoValidacionRespaldo.deVersionMasNueva;
  }

  return ResultadoValidacionRespaldo.valido;
}
