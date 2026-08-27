import '../../core/dinero.dart';
import '../../core/mes.dart';
import '../modelos/enums.dart';
import '../modelos/obligacion.dart';

/// Reglas del presupuesto mensual: validación de montos (FR-005) y precarga
/// de obligaciones fijas (FR-006).

/// Resultado de validar lo que el usuario escribió en un campo de monto.
///
/// Nunca lanza: un monto mal escrito es un caso esperado, no un error de
/// programación. El motivo viene en español, listo para mostrar.
final class ResultadoValidacion {
  final Dinero? monto;
  final String? error;

  const ResultadoValidacion.valido(Dinero this.monto) : error = null;
  const ResultadoValidacion.invalido(String this.error) : monto = null;

  bool get esValido => monto != null;
}

/// Cuántas cifras enteras admite un monto. Siete, según el edge case de
/// "montos grandes": `S/ 9,999,999.99`.
const int _maxCifrasEnteras = 7;

/// Convierte lo escrito por el usuario en un [Dinero], o explica por qué no.
///
/// **El parseo nunca pasa por `double`** (Principio II): se separan las partes
/// entera y decimal como texto y se componen los centavos con aritmética
/// entera. Parsear `1234567.89` a `double` y multiplicar por 100 puede dar
/// `123456788.99999999`, y ahí ya se perdió un centavo antes de guardar nada.
ResultadoValidacion validarMonto(String entrada) {
  final texto = entrada.trim();
  if (texto.isEmpty) {
    return const ResultadoValidacion.invalido('Escribí un monto.');
  }

  if (texto.startsWith('-')) {
    return const ResultadoValidacion.invalido(
      'El monto no puede ser negativo.',
    );
  }

  // Se admite coma como separador decimal (el teclado numérico de Android la
  // ofrece en locales hispanos) y como separador de miles.
  final normalizado = _normalizarSeparadores(texto);
  if (normalizado == null) {
    return const ResultadoValidacion.invalido(
      'El monto solo puede tener números, un punto decimal y comas de miles.',
    );
  }

  final partes = normalizado.split('.');
  if (partes.length > 2) {
    return const ResultadoValidacion.invalido(
      'El monto tiene más de un punto decimal.',
    );
  }

  final entera = partes[0].isEmpty ? '0' : partes[0];
  final decimal = partes.length == 2 ? partes[1] : '';

  if (decimal.length > 2) {
    return const ResultadoValidacion.invalido(
      'El monto no puede tener más de dos decimales.',
    );
  }

  if (entera.length > _maxCifrasEnteras) {
    return const ResultadoValidacion.invalido(
      'El monto máximo es S/ 9,999,999.99.',
    );
  }

  final soles = int.tryParse(entera);
  if (soles == null) {
    return const ResultadoValidacion.invalido('Escribí un monto válido.');
  }

  final centimos = decimal.isEmpty ? 0 : int.parse(decimal.padRight(2, '0'));
  final monto = Dinero.deCentavos(soles * 100 + centimos);

  if (!monto.esPositivo) {
    return const ResultadoValidacion.invalido(
      'El monto tiene que ser mayor que S/ 0.00.',
    );
  }

  return ResultadoValidacion.valido(monto);
}

/// Deja un solo separador decimal `.` y quita los de miles, o devuelve `null`
/// si hay caracteres que no son dígitos ni separadores.
String? _normalizarSeparadores(String texto) {
  if (!RegExp(r'^[\d.,]+$').hasMatch(texto)) return null;

  final ultimaComa = texto.lastIndexOf(',');
  final ultimoPunto = texto.lastIndexOf('.');

  // El separador decimal es el último que aparece; el otro es de miles.
  if (ultimaComa > ultimoPunto) {
    return texto.replaceAll('.', '').replaceFirst(',', '.', ultimaComa);
  }
  return texto.replaceAll(',', '');
}

/// Propone las obligaciones fijas del mes anterior para el mes destino
/// (FR-006).
///
/// **No guarda nada.** Devuelve copias sin `id`, que la UI muestra para que el
/// usuario confirme o ajuste. Escribirlas sola dejaría al usuario con un
/// presupuesto que nunca revisó.
///
/// Las variables no se proponen: son estimaciones que cambian mes a mes, y
/// repetirlas daría una falsa sensación de presupuesto ya armado.
///
/// Las cuotas de deuda tampoco: se derivan solas (D3).
List<Obligacion> proponerFijasDelMesAnterior({
  required Mes mesDestino,
  required List<Obligacion> obligacionesMesAnterior,
}) =>
    obligacionesMesAnterior
        .where((o) => o.tipo == TipoObligacion.fija)
        .map((o) => o.copiarCon(mes: mesDestino, limpiarId: true))
        .toList(growable: false);

/// Suma de las obligaciones guardadas. **No incluye las cuotas de deuda**:
/// esas las agrega `calcularResumenMes` en US4, derivándolas (D3).
Dinero totalObligaciones(List<Obligacion> obligaciones) => obligaciones.fold(
      Dinero.cero,
      (acumulado, o) => acumulado + o.monto,
    );

/// Total por categoría, para las fichas del resumen.
Map<Categoria, Dinero> totalPorCategoria(List<Obligacion> obligaciones) {
  final totales = <Categoria, Dinero>{};
  for (final o in obligaciones) {
    totales[o.categoria] = (totales[o.categoria] ?? Dinero.cero) + o.monto;
  }
  return totales;
}
