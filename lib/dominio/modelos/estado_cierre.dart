/// En qué situación está un mes respecto de la edición.
enum SituacionMes {
  /// El mes en curso (o uno futuro): se puede crear, editar y eliminar.
  abierto,

  /// El mes anterior, dentro de la ventana de gracia: se puede **registrar**
  /// un pago rezagado, pero lo que se registre queda inmutable (FR-055,
  /// FR-056).
  enGracia,

  /// Cualquier otro mes pasado: solo lectura (FR-052).
  cerrado,
}

/// Estado de cierre de un mes, derivado de la fecha de hoy y de los días de
/// gracia configurados. **No se persiste** (D13).
final class EstadoCierre {
  final SituacionMes situacion;

  /// Explicación en español de por qué el mes no admite cambios, lista para
  /// mostrarse. `null` cuando el mes está abierto y no hay nada que explicar.
  ///
  /// Existe para que la restricción se comunique con texto y no solo con un
  /// control deshabilitado o un color (FR-058).
  final String? motivo;

  const EstadoCierre({required this.situacion, this.motivo});

  bool get admiteRegistrar =>
      situacion == SituacionMes.abierto || situacion == SituacionMes.enGracia;

  bool get admiteEditar => situacion == SituacionMes.abierto;

  @override
  bool operator ==(Object other) =>
      other is EstadoCierre &&
      other.situacion == situacion &&
      other.motivo == motivo;

  @override
  int get hashCode => Object.hash(situacion, motivo);

  @override
  String toString() => 'EstadoCierre($situacion)';
}
