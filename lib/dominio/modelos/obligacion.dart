import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// Una partida planificada del mes (FR-002).
///
/// Es la **previsión**, frente a la `Transaccion` que es la realidad.
///
/// Nunca lleva categoría `tarjetaCredito`: ese compromiso lo derivan las
/// deudas en cuotas (D3), y registrarlo a mano duplicaría el monto en el
/// presupuesto. La UI lo impide ofreciendo solo `Categoria.presupuestables`.
final class Obligacion {
  /// `null` mientras no esté guardada. Es lo que distingue una propuesta de
  /// precarga de una obligación real: la app propone, el usuario confirma
  /// (FR-006).
  final int? id;

  final Mes mes;
  final String nombre;
  final Categoria categoria;
  final Dinero monto;

  /// Solo las fijas se proponen al abrir el mes siguiente (FR-006).
  final TipoObligacion tipo;

  const Obligacion({
    required this.id,
    required this.mes,
    required this.nombre,
    required this.categoria,
    required this.monto,
    required this.tipo,
  });

  bool get estaGuardada => id != null;

  Obligacion copiarCon({
    int? id,
    Mes? mes,
    String? nombre,
    Categoria? categoria,
    Dinero? monto,
    TipoObligacion? tipo,
    bool limpiarId = false,
  }) =>
      Obligacion(
        id: limpiarId ? null : (id ?? this.id),
        mes: mes ?? this.mes,
        nombre: nombre ?? this.nombre,
        categoria: categoria ?? this.categoria,
        monto: monto ?? this.monto,
        tipo: tipo ?? this.tipo,
      );

  @override
  bool operator ==(Object other) =>
      other is Obligacion &&
      other.id == id &&
      other.mes == mes &&
      other.nombre == nombre &&
      other.categoria == categoria &&
      other.monto == monto &&
      other.tipo == tipo;

  @override
  int get hashCode => Object.hash(id, mes, nombre, categoria, monto, tipo);

  @override
  String toString() =>
      'Obligacion($nombre, ${categoria.slug}, ${monto.centavos} c, '
      '${tipo.slug}, $mes)';
}
