import 'package:finanzas/shared/tipos/mes.dart';
import 'package:intl/intl.dart';

/// Fechas en convención peruana.
///
/// D7: se usa `intl` solo para fechas; el dinero nunca pasa por acá.
///
/// Los patrones son **numéricos** (`dd/MM/yyyy`), que es la convención
/// peruana y además no requiere cargar los datos de locale de `intl` —
/// `initializeDateFormatting` es asíncrono y haría falta esperarlo antes de
/// pintar la primera pantalla. Los nombres de mes, que sí serían específicos
/// del idioma, son una constante local: son doce cadenas, más barato y más
/// predecible que arrastrar la tabla de símbolos completa.
abstract final class FormatoFecha {
  static final DateFormat _corta = DateFormat('dd/MM/yyyy');
  static final DateFormat _diaYMes = DateFormat('dd/MM');

  static const List<String> _nombresDeMes = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'setiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  /// `27/08/2026`. Para listados de transacciones y aportes.
  static String corta(DateTime fecha) => _corta.format(fecha);

  /// `27/08`. Para listas donde el año ya está implícito en el mes abierto.
  static String diaYMes(DateTime fecha) => _diaYMes.format(fecha);

  /// `agosto 2026`. Para encabezados y el selector de mes.
  static String mesLargo(Mes mes) =>
      '${_nombresDeMes[mes.mes - 1]} ${mes.anio}';

  /// `Agosto 2026`, con inicial mayúscula, para títulos.
  static String mesTitulo(Mes mes) {
    final nombre = _nombresDeMes[mes.mes - 1];
    return '${nombre[0].toUpperCase()}${nombre.substring(1)} ${mes.anio}';
  }

  /// `ago 2026`. Para etiquetas estrechas, como el historial de ahorro.
  static String mesCorto(Mes mes) =>
      '${_nombresDeMes[mes.mes - 1].substring(0, 3)} ${mes.anio}';

  /// `2026-08-27`, el formato en que se persisten las fechas.
  static String iso(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';

  /// Lee una fecha persistida en `YYYY-MM-DD`.
  static DateTime desdeIso(String texto) => DateTime.parse(texto);
}
