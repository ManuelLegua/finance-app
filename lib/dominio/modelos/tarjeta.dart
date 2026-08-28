import 'package:finanzas/shared/constantes/enums.dart';

/// Un medio de pago (FR-059).
///
/// Las de crédito agrupan deudas en cuotas y permiten ver el compromiso
/// mensual consolidado (FR-017). Las de débito no admiten cuotas (FR-061).
final class Tarjeta {
  /// `null` mientras no esté guardada.
  final int? id;

  /// Cómo la reconoce el usuario. Ej. "BCP Visa Clásica".
  final String nombre;

  /// Entidad emisora. Se elige de `EntidadesPeru.sugeridas` o se escribe a
  /// mano (FR-060).
  final String entidad;

  final TipoTarjeta tipo;

  const Tarjeta({
    required this.id,
    required this.nombre,
    required this.entidad,
    required this.tipo,
  });

  bool get estaGuardada => id != null;

  /// Solo las de crédito pueden respaldar una deuda en cuotas (FR-061).
  bool get admiteCuotas => tipo.admiteCuotas;

  Tarjeta copiarCon({
    int? id,
    String? nombre,
    String? entidad,
    TipoTarjeta? tipo,
  }) => Tarjeta(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    entidad: entidad ?? this.entidad,
    tipo: tipo ?? this.tipo,
  );

  @override
  bool operator ==(Object other) =>
      other is Tarjeta &&
      other.id == id &&
      other.nombre == nombre &&
      other.entidad == entidad &&
      other.tipo == tipo;

  @override
  int get hashCode => Object.hash(id, nombre, entidad, tipo);

  @override
  String toString() => 'Tarjeta($nombre, $entidad, ${tipo.slug})';
}
