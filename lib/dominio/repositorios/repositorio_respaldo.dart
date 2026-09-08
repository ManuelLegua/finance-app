import 'package:finanzas/dominio/modelos/respaldo.dart';

/// Sacar una copia de los datos a un archivo y volver a cargarla (spec 005).
///
/// Es el único repositorio del proyecto que opera sobre el **archivo** de la
/// base y no sobre sus filas: por eso es también el único que necesita cerrar
/// y reabrir la conexión viva, y el que carga con la garantía de todo-o-nada
/// de D3.
///
/// **No decide reglas de negocio**: si un archivo candidato es aceptable lo
/// decide `validarRespaldo(...)` en el dominio (D6), no la implementación de
/// esta interfaz. Acá se juntan los hechos y se ejecuta el intercambio.
///
/// **Privacidad (Principio I, enmienda v3.0.0)**: ningún método de acá sube,
/// envía ni transmite nada. [exportar] deja un archivo en el almacenamiento
/// privado de la app y devuelve su ruta; **quién lo recibe después lo decide
/// el usuario fuera de la app**, a través de la hoja de compartir del sistema
/// (D5). Este repositorio no conoce destinos.
///
/// Por eso mismo **no hay** un `exportarAutomatico` ni forma de programar
/// respaldos: la enmienda autoriza la salida de datos solo cuando el usuario
/// la pide en ese momento, así que una API que permitiera exportar sin
/// intervención suya contradiría el principio que habilita esta feature.
abstract interface class RepositorioRespaldo {
  /// Genera el archivo de respaldo y devuelve dónde quedó.
  ///
  /// Consolida el WAL, copia la base a una ruta temporal privada y vacía **en
  /// la copia** las tablas que no viajan (D4). No modifica la base viva de
  /// ninguna forma: las filas vaciadas siguen intactas en el original.
  ///
  /// Funciona con la base recién creada y sin ningún dato: genera igual un
  /// archivo válido (FR-012).
  Future<ArchivoRespaldo> exportar();

  /// Averigua si el archivo en [rutaCandidato] puede restaurarse, y devuelve
  /// el veredicto con la versión que trae.
  ///
  /// Copia el candidato a una ruta temporal y lo abre **sin `version:`**, para
  /// no dispararle migraciones a un archivo que quizá se rechace (D2).
  ///
  /// **No modifica ningún dato del usuario, pase lo que pase.**
  Future<InformeRespaldo> inspeccionar(String rutaCandidato);

  /// Reemplaza la base actual por la del archivo en [rutaCandidato].
  ///
  /// Al terminar, la base abierta es la del respaldo, ya migrada al esquema
  /// actual si venía de una versión anterior (FR-010), y sin ninguna fila de
  /// suscripción heredada del archivo (D4): el acceso premium nunca sale de
  /// un archivo local, se vuelve a consultar a Google Play.
  ///
  /// **Todo o nada (FR-008, FR-009)**: si falla en cualquier punto, deja la
  /// base tal como estaba antes de llamarlo y vuelve a dejarla abierta y
  /// usable. La red de seguridad es el rename a `finanzas.db.previo`, que
  /// solo se borra después de que la base nueva abrió bien.
  ///
  /// **Orden obligatorio**: solo se llama después de que [inspeccionar] haya
  /// devuelto `valido` para ese mismo archivo. Entre uno y otro va además la
  /// confirmación explícita del usuario que exige FR-007.
  Future<void> restaurar(String rutaCandidato);
}
