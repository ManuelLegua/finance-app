// ignore_for_file: prefer_initializing_formals
// Dart no admite parametros nombrados que empiecen con guion bajo, asi que
// los campos privados no pueden recibirse como `this._repo`.

import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/respaldo.dart';
import 'package:finanzas/dominio/repositorios/repositorio_respaldo.dart';
import 'package:flutter/foundation.dart';

export 'package:finanzas/dominio/modelos/respaldo.dart';

/// En qué punto va la exportación (data-model.md §4).
///
/// Es un enum y no un par de `bool` sueltos: "en curso" y "fallido" son
/// estados excluyentes, y el `switch` que arma la pantalla deja de compilar si
/// mañana aparece uno nuevo.
enum FaseExportacion { inactivo, enCurso, completado, fallido }

/// En qué punto va la restauración (data-model.md §4).
///
/// Los tres primeros valores **no tocan ningún dato**: se puede abandonar en
/// cualquiera de ellos sin dejar nada a medias. `esperandoConfirmacion` es
/// donde vive FR-007 — el archivo ya se validó, pero hace falta que el
/// usuario confirme aparte que acepta reemplazar todo lo que tiene.
enum FaseRestauracion {
  inactivo,
  validando,
  rechazado,
  esperandoConfirmacion,
  reemplazando,
  completado,
  fallido,
}

/// Exportar los datos a un archivo y volver a cargarlos (spec 005).
///
/// **Este notificador no conoce destinos**: pide el archivo al repositorio y
/// avisa que está listo. Entregárselo a la hoja de compartir del sistema es
/// cosa de la pantalla, y elegir adónde va, del usuario (FR-004, D5).
class EstadoRespaldo extends ChangeNotifier {
  EstadoRespaldo({required RepositorioRespaldo repoRespaldo})
    : _repoRespaldo = repoRespaldo;

  final RepositorioRespaldo _repoRespaldo;

  FaseExportacion _faseExportacion = FaseExportacion.inactivo;
  ArchivoRespaldo? _archivoGenerado;
  String? _errorDeExportacion;

  FaseRestauracion _faseRestauracion = FaseRestauracion.inactivo;
  InformeRespaldo? _informe;
  String? _errorDeRestauracion;

  /// El archivo que el usuario eligió, mientras espera su confirmación. Se
  /// suelta apenas la restauración termina o se cancela.
  String? _rutaCandidata;

  FaseExportacion get faseExportacion => _faseExportacion;

  /// El archivo recién generado, listo para entregar. Queda disponible
  /// después de exportar para que la pantalla pueda ofrecer compartirlo otra
  /// vez sin volver a copiar la base.
  ArchivoRespaldo? get archivoGenerado => _archivoGenerado;

  String? get errorDeExportacion => _errorDeExportacion;

  FaseRestauracion get faseRestauracion => _faseRestauracion;

  /// Lo que se averiguó del archivo elegido: el veredicto y qué versión trae.
  /// Es de donde sale el motivo del rechazo y el aviso de que el respaldo es
  /// de una versión anterior.
  InformeRespaldo? get informe => _informe;

  String? get errorDeRestauracion => _errorDeRestauracion;

  /// Genera el archivo de respaldo.
  ///
  /// Mientras una exportación está en curso, otra no arranca: sin esta guarda
  /// un doble toque copiaría la base dos veces.
  Future<void> exportar() async {
    if (_faseExportacion == FaseExportacion.enCurso) return;

    _faseExportacion = FaseExportacion.enCurso;
    _errorDeExportacion = null;
    _archivoGenerado = null;
    notifyListeners();

    try {
      _archivoGenerado = await _repoRespaldo.exportar();
      _faseExportacion = FaseExportacion.completado;
    } on Object catch (error) {
      _errorDeExportacion = _mensajeDe(error);
      _faseExportacion = FaseExportacion.fallido;
    } finally {
      notifyListeners();
    }
  }

  /// Mira el archivo que el usuario eligió y decide si se puede restaurar.
  ///
  /// **No toca ningún dato**: al terminar queda esperando la confirmación
  /// (FR-007) o con el motivo del rechazo (FR-009), y en los dos casos lo que
  /// el usuario tiene cargado sigue intacto.
  Future<void> inspeccionar(String rutaCandidata) async {
    if (_faseRestauracion == FaseRestauracion.validando ||
        _faseRestauracion == FaseRestauracion.reemplazando) {
      return;
    }

    _faseRestauracion = FaseRestauracion.validando;
    _errorDeRestauracion = null;
    _informe = null;
    _rutaCandidata = rutaCandidata;
    notifyListeners();

    try {
      final informe = await _repoRespaldo.inspeccionar(rutaCandidata);
      _informe = informe;
      _faseRestauracion = informe.esValido
          ? FaseRestauracion.esperandoConfirmacion
          : FaseRestauracion.rechazado;
    } on Object catch (error) {
      _errorDeRestauracion = _mensajeDe(error);
      _faseRestauracion = FaseRestauracion.fallido;
    } finally {
      notifyListeners();
    }
  }

  /// Reemplaza los datos actuales por los del archivo ya validado (FR-008).
  ///
  /// Solo hace algo desde [FaseRestauracion.esperandoConfirmacion]: el orden
  /// que fija el contrato es inspeccionar, confirmar y recién ahí reemplazar,
  /// y saltearse un paso es justo lo que FR-007 prohíbe.
  Future<void> confirmarRestauracion() async {
    final ruta = _rutaCandidata;
    if (_faseRestauracion != FaseRestauracion.esperandoConfirmacion ||
        ruta == null) {
      return;
    }

    _faseRestauracion = FaseRestauracion.reemplazando;
    _errorDeRestauracion = null;
    notifyListeners();

    try {
      await _repoRespaldo.restaurar(ruta);
      _faseRestauracion = FaseRestauracion.completado;
    } on Object catch (error) {
      _errorDeRestauracion = _mensajeDe(error);
      _faseRestauracion = FaseRestauracion.fallido;
    } finally {
      _rutaCandidata = null;
      notifyListeners();
    }
  }

  /// Abandona la restauración antes de tocar nada.
  ///
  /// Nunca deja nada a medias: hasta la confirmación no se escribió un solo
  /// byte sobre los datos del usuario.
  void cancelarRestauracion() {
    _faseRestauracion = FaseRestauracion.inactivo;
    _informe = null;
    _errorDeRestauracion = null;
    _rutaCandidata = null;
    notifyListeners();
  }

  /// Vuelve al punto de partida, para que el resultado de una exportación no
  /// quede en pantalla para siempre.
  void limpiarExportacion() {
    _faseExportacion = FaseExportacion.inactivo;
    _archivoGenerado = null;
    _errorDeExportacion = null;
    notifyListeners();
  }

  static String _mensajeDe(Object error) => error is ErrorPersistencia
      ? error.mensaje
      : 'Ocurrió un problema inesperado. Volvé a intentarlo.';
}
