/// Un monto de dinero, siempre en soles peruanos.
///
/// Principio II de la constitución, no negociable: el dinero se representa y
/// se almacena como un entero de centavos. **No existe constructor desde
/// `double`** y ninguna operación devuelve punto flotante, porque un error de
/// centavos destruye la confianza en una app cuyo único propósito es decir
/// cuánto dinero queda.
///
/// Los montos que el usuario guarda son siempre `>= 0`; los derivados
/// (disponible, diferencia por categoría) pueden ser negativos y eso es un
/// estado legítimo, no un error: es el déficit.
final class Dinero implements Comparable<Dinero> {
  /// Único estado. Con signo.
  final int centavos;

  const Dinero.deCentavos(this.centavos);

  static const Dinero cero = Dinero.deCentavos(0);

  /// Compone un monto desde soles y céntimos, como los lee el usuario.
  ///
  /// Lanza [ArgumentError] si los céntimos caen fuera de `0..99`: eso indica
  /// que quien llama está haciendo aritmética decimal a mano.
  factory Dinero.deSoles(int soles, [int centimos = 0]) {
    if (centimos < 0 || centimos > 99) {
      throw ArgumentError.value(
        centimos,
        'centimos',
        'Debe estar entre 0 y 99',
      );
    }
    final signo = soles.isNegative ? -1 : 1;
    return Dinero.deCentavos(soles * 100 + signo * centimos);
  }

  /// Compone un monto desde texto decimal ya normalizado (p. ej. `"57.70"`
  /// o, con coma de miles, `"1,234.56"`), sin pasar nunca por `double`
  /// (Principio II): separa la parte entera de la decimal como texto y
  /// arma los centavos con aritmética entera. Es el mismo partido que ya
  /// hacía `validarMonto` a mano; existe para que el parser de
  /// notificaciones (spec 002, D-N3) lo reutilice en vez de duplicarlo.
  ///
  /// El separador decimal tiene que ser un punto, con uno o dos dígitos.
  /// Lanza [FormatException] si el texto no tiene esa forma — quien llama
  /// ya debe haber validado el formato (p. ej. con una expresión regular)
  /// antes de llegar acá.
  factory Dinero.deTextoDecimal(String texto) {
    final sinMiles = texto.replaceAll(',', '');
    final coincidencia = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$')
        .firstMatch(sinMiles);
    if (coincidencia == null) {
      throw FormatException('No es un monto decimal válido: "$texto"');
    }
    final entera = coincidencia.group(1)!;
    final decimal = (coincidencia.group(2) ?? '').padRight(2, '0');
    return Dinero.deCentavos(int.parse(entera) * 100 + int.parse(decimal));
  }

  Dinero operator +(Dinero otro) => Dinero.deCentavos(centavos + otro.centavos);

  Dinero operator -(Dinero otro) => Dinero.deCentavos(centavos - otro.centavos);

  Dinero operator -() => Dinero.deCentavos(-centavos);

  /// Repite el monto [veces]. Es cómo se obtiene el saldo pendiente de una
  /// deuda: la cuota por las cuotas que faltan.
  Dinero operator *(int veces) => Dinero.deCentavos(centavos * veces);

  /// Aplica un porcentaje expresado en puntos base (20% = 2000).
  ///
  /// Toda la operación es entera y el redondeo es al centavo más cercano,
  /// medio alejándose de cero. Los porcentajes se guardan en puntos base
  /// precisamente para no tener que almacenar decimales en ningún lado.
  Dinero porPuntosBase(int puntosBase) {
    if (puntosBase < 0 || puntosBase > 10000) {
      throw ArgumentError.value(
        puntosBase,
        'puntosBase',
        'Debe estar entre 0 y 10000',
      );
    }
    final producto = centavos * puntosBase;
    final signo = producto.isNegative ? -1 : 1;
    final redondeado = (producto.abs() + 5000) ~/ 10000;
    return Dinero.deCentavos(signo * redondeado);
  }

  /// Magnitud sin signo, para expresar faltantes y excesos en positivo.
  Dinero abs() => Dinero.deCentavos(centavos.abs());

  bool get esCero => centavos == 0;

  bool get esPositivo => centavos > 0;

  bool get esNegativo => centavos < 0;

  bool operator <(Dinero otro) => centavos < otro.centavos;

  bool operator <=(Dinero otro) => centavos <= otro.centavos;

  bool operator >(Dinero otro) => centavos > otro.centavos;

  bool operator >=(Dinero otro) => centavos >= otro.centavos;

  @override
  int compareTo(Dinero otro) => centavos.compareTo(otro.centavos);

  @override
  bool operator ==(Object other) =>
      other is Dinero && other.centavos == centavos;

  @override
  int get hashCode => centavos.hashCode;

  /// Representación de depuración. Para mostrar al usuario se usa
  /// `FormatoSoles`, que es lo único que produce `S/ 1,234.56`.
  @override
  String toString() => 'Dinero($centavos c)';
}
