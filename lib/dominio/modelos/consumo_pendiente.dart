import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';

/// Un consumo detectado y aún no confirmado (spec 002, FR-020 a FR-028).
///
/// Al confirmarse se convierte en una `Transaccion` de 001 (o una `Deuda`,
/// HU4) y la fila se borra; al descartarse, se borra sin dejar ningún
/// rastro. Nunca existe sin haber pasado por el parser genérico y sin que
/// su dirección se haya clasificado como saliente (D-N2, D-N11) — no hay
/// ruta de escritura que cree un pendiente con datos parciales (FR-017) ni
/// con dinero entrante (FR-008b).
final class ConsumoPendiente {
  /// `null` mientras no esté guardado.
  final int? id;

  /// Paquete Android de la app de origen (FR-010) — no un enum cerrado,
  /// clave hacia `OrigenReconocido.paquete` (D-N10).
  final String origenPaquete;

  /// Identificador nativo de la notificación que lo originó. Base de la
  /// deduplicación (D-N5, FR-015/FR-016) — no es una clave de negocio.
  final String notificacionId;

  final Dinero monto;

  /// Tal como lo informa el banco; el usuario puede corregirlo al confirmar.
  final String comercio;

  /// Fecha del consumo — la que lleva la `Transaccion` resultante (FR-026),
  /// no la de captura.
  final DateTime fecha;

  /// `null` si el comercio no tiene asociación aprendida (FR-033: confirmar
  /// exige elegir categoría en ese caso).
  final Categoria? categoriaPropuesta;

  /// Cuándo llegó la notificación. Solo para ordenar y para "cantidad
  /// inusualmente alta" (FR-028); no se muestra como si fuera la fecha del
  /// gasto.
  final DateTime capturadoEn;

  const ConsumoPendiente({
    required this.id,
    required this.origenPaquete,
    required this.notificacionId,
    required this.monto,
    required this.comercio,
    required this.fecha,
    required this.categoriaPropuesta,
    required this.capturadoEn,
  });

  bool get estaGuardado => id != null;

  ConsumoPendiente copiarCon({
    int? id,
    String? origenPaquete,
    String? notificacionId,
    Dinero? monto,
    String? comercio,
    DateTime? fecha,
    Categoria? categoriaPropuesta,
    bool limpiarCategoriaPropuesta = false,
    DateTime? capturadoEn,
    bool limpiarId = false,
  }) => ConsumoPendiente(
    id: limpiarId ? null : (id ?? this.id),
    origenPaquete: origenPaquete ?? this.origenPaquete,
    notificacionId: notificacionId ?? this.notificacionId,
    monto: monto ?? this.monto,
    comercio: comercio ?? this.comercio,
    fecha: fecha ?? this.fecha,
    categoriaPropuesta: limpiarCategoriaPropuesta
        ? null
        : (categoriaPropuesta ?? this.categoriaPropuesta),
    capturadoEn: capturadoEn ?? this.capturadoEn,
  );

  @override
  bool operator ==(Object other) =>
      other is ConsumoPendiente &&
      other.id == id &&
      other.origenPaquete == origenPaquete &&
      other.notificacionId == notificacionId &&
      other.monto == monto &&
      other.comercio == comercio &&
      other.fecha == fecha &&
      other.categoriaPropuesta == categoriaPropuesta &&
      other.capturadoEn == capturadoEn;

  @override
  int get hashCode => Object.hash(
    id,
    origenPaquete,
    notificacionId,
    monto,
    comercio,
    fecha,
    categoriaPropuesta,
    capturadoEn,
  );

  @override
  String toString() =>
      'ConsumoPendiente($comercio, ${monto.centavos} c, $origenPaquete)';
}
