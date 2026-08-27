import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ui/cascaron.dart';
import 'ui/tema.dart';

void main() {
  runApp(const AppFinanzas());
}

/// Raíz de la app.
///
/// Locale fijo `es_PE`: la app es monolingüe por decisión (D7). No hay ARB ni
/// generación de traducciones porque ningún requisito lo pide, y montar esa
/// infraestructura sería trabajo sin respaldo (Principio V).
class AppFinanzas extends StatelessWidget {
  const AppFinanzas({super.key});

  static const Locale _peru = Locale('es', 'PE');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finanzas',
      debugShowCheckedModeBanner: false,
      theme: Tema.claro(),
      darkTheme: Tema.oscuro(),
      locale: _peru,
      supportedLocales: const <Locale>[_peru, Locale('es')],
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Cascaron(),
    );
  }
}
