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
  TextStyle? get monto => titleMedium?.copyWith(
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Montos subordinados: totales de apoyo, restantes, diferencias.
  TextStyle? get montoSecundario => bodyMedium?.copyWith(
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
