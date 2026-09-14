import 'package:finanzas/dominio/interpretes/interprete.dart';
import 'package:finanzas/dominio/modelos/consumo_pendiente.dart';
import 'package:finanzas/dominio/modelos/notificacion_diagnostico.dart';
import 'package:finanzas/shared/constantes/origenes_reconocidos.dart';

/// Qué hacer con una notificación recién llegada (spec 002, T042).
///
/// Es la decisión completa —filtrar, interpretar y armar lo que se guarda—
/// separada de quien la guarda. Vive acá y no en el callback headless por dos
/// razones: es Dart puro y por lo tanto se prueba sin base de datos ni
/// Android, y es donde están las reglas que importan. El callback queda como
/// lo que debe ser, un pegamento que persiste lo que esta función resolvió.
sealed class DecisionCaptura {
  const DecisionCaptura();
}

/// No se guarda nada. **Nada quiere decir nada**: ni pendiente, ni registro de
/// diagnóstico, ni rastro de ningún tipo (FR-008c, FR-012).
final class NoRegistrarNada extends DecisionCaptura {
  const NoRegistrarNada(this.motivo);

  final MotivoDeIgnorar motivo;
}

/// Un consumo que el usuario tiene que confirmar antes de que exista como
/// gasto (FR-020: nunca en silencio).
final class RegistrarPendiente extends DecisionCaptura {
  const RegistrarPendiente(this.pendiente);

  final ConsumoPendiente pendiente;
}

/// Un texto de un origen reconocido que no se pudo interpretar, guardado para
/// poder ajustar el reconocimiento después (FR-017, FR-018).
final class RegistrarDiagnostico extends DecisionCaptura {
  const RegistrarDiagnostico(this.diagnostico);

  final NotificacionDiagnostico diagnostico;
}

/// Por qué una notificación no dejó nada.
///
/// **No se persiste.** Existe para que las pruebas distingan un caso de otro y
/// para que leer el código sea posible; dejar constancia de las notificaciones
/// ignoradas sería exactamente lo que FR-008c prohíbe.
enum MotivoDeIgnorar {
  /// Ni el paquete ni el remitente calzan con un origen reconocido. Es el caso
  /// de todo correo personal, y por eso no puede generar diagnóstico.
  origenNoReconocido,

  /// El resumen que Gmail publica junto a cada correo (D-N12). Procesarlo
  /// duplicaría cada consumo, y con un identificador nativo distinto, así que
  /// la deduplicación de D-N5 tampoco lo atajaría.
  resumenDeGrupo,

  /// Dinero entrante, o un aviso que no es un movimiento (FR-012, FR-013).
  ///
  /// **No va a diagnóstico**: el diagnóstico es para lo que no se entendió, y
  /// esto se entendió perfectamente. Llenarlo de dinero recibido lo volvería
  /// inútil para lo que existe.
  noEsConsumo,
}

/// Decide qué hacer con una notificación.
///
/// [notificacionId] es el identificador nativo de Android, base de la
/// deduplicación (D-N5): una notificación reeditada llega con el mismo y no
/// genera un segundo pendiente (FR-015); dos consumos distintos llegan con
/// identificadores distintos y se conservan por separado aunque coincidan en
/// monto y comercio (FR-016).
///
/// [recibidaEn] entra como parámetro porque esta carpeta es Dart puro y no
/// puede leer el reloj. Es cuándo llegó el aviso, no cuándo ocurrió el gasto:
/// la fecha del consumo la extrae el parser del propio texto.
DecisionCaptura decidirCaptura({
  required String paquete,
  required String? titulo,
  required bool esResumenDeGrupo,
  required String cuerpo,
  required String notificacionId,
  required DateTime recibidaEn,
}) {
  // El filtro va primero y no recibe el cuerpo: para cuando se mira el texto,
  // ya está decidido que la notificación es de un origen reconocido.
  final filtro = filtrarNotificacion(
    paquete: paquete,
    titulo: titulo,
    esResumenDeGrupo: esResumenDeGrupo,
  );

  switch (filtro) {
    case Descartar(:final motivo):
      return NoRegistrarNada(_comoMotivoDeIgnorar(motivo));
    case ProcesarComo():
      break;
  }

  final resultado = interpretar(
    titulo: titulo ?? '',
    contenido: cuerpo,
    recibidaEn: recibidaEn,
  );

  switch (resultado) {
    case NoEsConsumo():
      return const NoRegistrarNada(MotivoDeIgnorar.noEsConsumo);

    case NoInterpretable(:final motivo):
      return RegistrarDiagnostico(
        NotificacionDiagnostico(
          id: null,
          origenPaquete: paquete,
          motivo: motivo,
          // El texto **entero**, no el que el parser recortó: lo que se guarda
          // sirve para entender por qué falló, y el tramo descartado puede ser
          // justamente el que lo causó.
          textoCrudo: cuerpo,
          fecha: recibidaEn,
        ),
      );

    case ConsumoExtraido(:final monto, :final comercio, :final fecha):
      return RegistrarPendiente(
        ConsumoPendiente(
          id: null,
          origenPaquete: paquete,
          notificacionId: notificacionId,
          monto: monto,
          comercio: comercio,
          fecha: fecha,
          // Sin proponer categoría a propósito: `EstadoPendientes.cargar()` le
          // busca la asociación aprendida a todo pendiente que llegue sin
          // ella. Consultarla acá duplicaría esa lógica en un isolate que no
          // la necesita.
          categoriaPropuesta: null,
          capturadoEn: recibidaEn,
        ),
      );
  }
}

MotivoDeIgnorar _comoMotivoDeIgnorar(MotivoDescarte motivo) => switch (motivo) {
  MotivoDescarte.origenNoReconocido => MotivoDeIgnorar.origenNoReconocido,
  MotivoDescarte.resumenDeGrupo => MotivoDeIgnorar.resumenDeGrupo,
};
