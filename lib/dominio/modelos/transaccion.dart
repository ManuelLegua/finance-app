import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// Un gasto real ya ocurrido (FR-007).
///
/// Es el registro de **la realidad**, frente a la `Obligacion` que es la
/// previsión. La app muestra las dos en paralelo y no fuerza a elegir una.
final class Transaccion {
  /// `null` mientras no esté guardada.
  final int? id;

  /// Solo fecha, sin hora. **Determina a qué mes pertenece** el gasto
  /// (FR-008): uno con fecha del mes pasado se contabiliza allá, no en el mes
  /// que el usuario tenga abierto.
  final DateTime fecha;

  final Categoria categoria;
  final Dinero monto;

  /// Descripción corta. Puede quedar vacía: obligar a escribirla atentaría
  /// contra registrar un gasto en menos de quince segundos (SC-002).
  final String descripcion;

  const Transaccion({
    required this.id,
    required this.fecha,
    required this.categoria,
    required this.monto,
    required this.descripcion,
  });

  /// El mes al que pertenece, derivado siempre de la fecha.
  Mes get mes => Mes.deFecha(fecha);

  bool get estaGuardada => id != null;

  Transaccion copiarCon({
    int? id,
    DateTime? fecha,
    Categoria? categoria,
    Dinero? monto,
    String? descripcion,
    bool limpiarId = false,
  }) => Transaccion(
    id: limpiarId ? null : (id ?? this.id),
    fecha: fecha ?? this.fecha,
    categoria: categoria ?? this.categoria,
    monto: monto ?? this.monto,
    descripcion: descripcion ?? this.descripcion,
  );

  @override
  bool operator ==(Object other) =>
      other is Transaccion &&
      other.id == id &&
      other.fecha == fecha &&
      other.categoria == categoria &&
      other.monto == monto &&
      other.descripcion == descripcion;

  @override
  int get hashCode => Object.hash(id, fecha, categoria, monto, descripcion);

  @override
  String toString() =>
      'Transaccion($descripcion, ${categoria.slug}, ${monto.centavos} c, '
      '${fecha.toIso8601String().substring(0, 10)})';
}
