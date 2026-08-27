import 'dinero.dart';

/// Presenta montos como `S/ 1,234.56` (FR-048).
///
/// D2: el formato se construye a mano desde el entero de centavos.
/// **No se usa `intl.NumberFormat`**: recibe `num`, así que habría que
/// convertir los centavos a `double` justo antes de mostrar la cifra, que es
/// exactamente el lugar donde el punto flotante haría más daño — el usuario
/// vería el error y no habría forma de explicárselo.
abstract final class FormatoSoles {
  static const String simbolo = 'S/';

  /// `S/ 1,234.56`. Los negativos llevan el signo antes del símbolo:
  /// `-S/ 350.00`.
  static String formatear(Dinero monto) {
    final signo = monto.centavos.isNegative ? '-' : '';
    return '$signo$simbolo ${_cifra(monto.centavos.abs())}';
  }

  /// `1,234.56`, sin símbolo, para columnas donde la moneda ya está rotulada.
  static String formatearSinSimbolo(Dinero monto) {
    final signo = monto.centavos.isNegative ? '-' : '';
    return '$signo${_cifra(monto.centavos.abs())}';
  }

  /// Parte entera agrupada de a tres, más dos decimales siempre presentes.
  static String _cifra(int centavosAbsolutos) {
    final soles = centavosAbsolutos ~/ 100;
    final centimos = centavosAbsolutos % 100;
    return '${_agruparMiles(soles)}.${centimos.toString().padLeft(2, '0')}';
  }

  static String _agruparMiles(int entero) {
    final digitos = entero.toString();
    final salida = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      if (i > 0 && (digitos.length - i) % 3 == 0) {
        salida.write(',');
      }
      salida.write(digitos[i]);
    }
    return salida.toString();
  }
}
