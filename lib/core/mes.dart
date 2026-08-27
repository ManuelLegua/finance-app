/// Un mes calendario: la unidad de gestión de toda la app.
///
/// D5: internamente se identifica por un ordinal entero
/// `anio * 12 + (mes - 1)`. El dominio hace aritmética de meses todo el
/// tiempo — vigencia de cuotas, mes de la última cuota, precarga del mes
/// anterior, historial — y con un ordinal todo eso es suma y resta de
/// enteros, con el orden cronológico igual al orden numérico, sin acarreo
/// de año ni comparaciones de texto.
final class Mes implements Comparable<Mes> {
  final int anio;

  /// 1 = enero … 12 = diciembre.
  final int mes;

  const Mes(this.anio, this.mes)
    : assert(mes >= 1 && mes <= 12, 'El mes debe estar entre 1 y 12');

  /// Reconstruye un mes desde su ordinal persistido.
  factory Mes.deOrdinal(int ordinal) =>
      Mes(ordinal ~/ 12, ordinal % 12 + 1);

  /// El mes al que pertenece una fecha. El día se descarta.
  ///
  /// FR-008: una transacción se asigna al mes de su fecha, no al mes que el
  /// usuario tenga abierto.
  factory Mes.deFecha(DateTime fecha) => Mes(fecha.year, fecha.month);

  int get ordinal => anio * 12 + (mes - 1);

  Mes get siguiente => mas(1);

  Mes get anterior => mas(-1);

  /// Avanza [meses] posiciones. Acepta negativos para retroceder.
  Mes mas(int meses) => Mes.deOrdinal(ordinal + meses);

  /// Cuántos meses hay entre este mes y [otro]. Positivo si este es posterior.
  int diferencia(Mes otro) => ordinal - otro.ordinal;

  bool operator <(Mes otro) => ordinal < otro.ordinal;

  bool operator <=(Mes otro) => ordinal <= otro.ordinal;

  bool operator >(Mes otro) => ordinal > otro.ordinal;

  bool operator >=(Mes otro) => ordinal >= otro.ordinal;

  @override
  int compareTo(Mes otro) => ordinal.compareTo(otro.ordinal);

  @override
  bool operator ==(Object other) =>
      other is Mes && other.anio == anio && other.mes == mes;

  @override
  int get hashCode => ordinal.hashCode;

  @override
  String toString() => '$anio-${mes.toString().padLeft(2, '0')}';
}
