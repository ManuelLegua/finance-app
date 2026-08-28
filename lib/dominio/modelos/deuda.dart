import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// Una compra financiada en cuotas (FR-015).
///
/// **No genera filas por cuota** (D3). Lo que aporta a cada mes se deriva de
/// `mesInicio` y `numCuotas`, así que corregir la deuda recalcula todos los
/// meses afectados con una sola escritura (FR-023).
final class Deuda {
  /// `null` mientras no esté guardada.
  final int? id;

  final String descripcion;
  final int tarjetaId;

  /// El monto que informa el banco. La app **no calcula intereses** ni
  /// amortización (FR-024): replicar el cálculo del banco produciría
  /// discrepancias de centavos contra el estado de cuenta real.
  final Dinero cuotaMensual;

  final int numCuotas;

  /// Primer mes que aporta cuota. Puede ser futuro (FR-020).
  final Mes mesInicio;

  /// `null` mientras siga vigente. Al fijarse, cesan las cuotas **de ese mes
  /// en adelante** y el saldo pasa a cero (FR-021).
  final Mes? mesSaldadaAnticipada;

  const Deuda({
    required this.id,
    required this.descripcion,
    required this.tarjetaId,
    required this.cuotaMensual,
    required this.numCuotas,
    required this.mesInicio,
    this.mesSaldadaAnticipada,
  }) : assert(numCuotas >= 1, 'Una deuda tiene al menos una cuota');

  bool get estaGuardada => id != null;

  /// Mes en que vence la última cuota (FR-018).
  Mes get mesUltimaCuota => mesInicio.mas(numCuotas - 1);

  /// Lo que costaría pagarla entera, sin importar cuánto se pagó ya.
  Dinero get montoTotal => cuotaMensual * numCuotas;

  Deuda copiarCon({
    int? id,
    String? descripcion,
    int? tarjetaId,
    Dinero? cuotaMensual,
    int? numCuotas,
    Mes? mesInicio,
    Mes? mesSaldadaAnticipada,
    bool reactivar = false,
  }) => Deuda(
    id: id ?? this.id,
    descripcion: descripcion ?? this.descripcion,
    tarjetaId: tarjetaId ?? this.tarjetaId,
    cuotaMensual: cuotaMensual ?? this.cuotaMensual,
    numCuotas: numCuotas ?? this.numCuotas,
    mesInicio: mesInicio ?? this.mesInicio,
    mesSaldadaAnticipada: reactivar
        ? null
        : (mesSaldadaAnticipada ?? this.mesSaldadaAnticipada),
  );

  @override
  bool operator ==(Object other) =>
      other is Deuda &&
      other.id == id &&
      other.descripcion == descripcion &&
      other.tarjetaId == tarjetaId &&
      other.cuotaMensual == cuotaMensual &&
      other.numCuotas == numCuotas &&
      other.mesInicio == mesInicio &&
      other.mesSaldadaAnticipada == mesSaldadaAnticipada;

  @override
  int get hashCode => Object.hash(
    id,
    descripcion,
    tarjetaId,
    cuotaMensual,
    numCuotas,
    mesInicio,
    mesSaldadaAnticipada,
  );

  @override
  String toString() =>
      'Deuda($descripcion, $numCuotas x ${cuotaMensual.centavos} c, '
      'desde $mesInicio)';
}
