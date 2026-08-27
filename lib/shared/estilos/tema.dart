import 'package:flutter/material.dart';

/// Tema de la app según D11: Material 3 del SDK, sin kit de componentes.
///
/// Tres reglas que atraviesan toda la interfaz:
///  1. Cifras tabulares en todo monto, para que las columnas no bailen al
///     cambiar de mes.
///  2. Jerarquía por tamaño, no por color.
///  3. Contraste AA, y ningún estado comunicado solo por color.
abstract final class Tema {
  /// Verde sobrio: la app habla de sueldo y ahorro, no de alertas.
  static const Color _semilla = Color(0xFF2E7D5B);

  static ThemeData claro() => _construir(Brightness.light);

  static ThemeData oscuro() => _construir(Brightness.dark);

  static ThemeData _construir(Brightness brillo) {
    final esquema = ColorScheme.fromSeed(
      seedColor: _semilla,
      brightness: brillo,
    );

    return ThemeData(
      colorScheme: esquema,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: esquema.surface,
        foregroundColor: esquema.onSurface,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: esquema.outlineVariant),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}

/// Espaciado de la interfaz.
///
/// Nombrarlos evita que aparezcan 8, 12, 16 y 32 sueltos por las pantallas:
/// leyendo `Espaciado.entreCampos` se entiende la intencion, leyendo `16` hay
/// que deducirla. Y cambiar el ritmo visual pasa a ser un solo lugar.
abstract final class Espaciado {
  /// Separacion minima, entre un rotulo y su valor.
  static const double minimo = 4;

  /// Entre elementos de un mismo bloque.
  static const double chico = 8;

  /// Dentro de una tarjeta, entre sus partes.
  static const double interno = 12;

  /// Margen estandar de pantalla y separacion entre campos de un formulario.
  static const double normal = 16;
  static const double entreCampos = 16;

  /// Alrededor de un estado vacio o un mensaje centrado.
  static const double amplio = 32;

  /// Espacio al final de una lista para que el ultimo elemento no quede
  /// tapado por el boton flotante.
  static const double bajoBotonFlotante = 96;
}

/// Estilos para montos. **Todo monto de la app usa uno de estos.**
///
/// `FontFeature.tabularFigures()` da a cada dígito el mismo ancho. Sin eso,
/// `S/ 1,111.00` y `S/ 9,999.00` ocupan anchos distintos y las cifras se
/// desalinean entre filas, que es exactamente lo que hace que una app de
/// plata se vea poco confiable.
extension EstilosDeMonto on TextTheme {
  /// El dato que responde la pregunta de la pantalla: el disponible del mes.
  TextStyle? get montoDestacado => displaySmall?.copyWith(
    fontFeatures: const [FontFeature.tabularFigures()],
    fontWeight: FontWeight.w600,
  );

  /// Montos de una fila o ficha: obligaciones, gastos, cuotas.
  TextStyle? get monto =>
      titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Montos subordinados: totales de apoyo, restantes, diferencias.
  TextStyle? get montoSecundario =>
      bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
