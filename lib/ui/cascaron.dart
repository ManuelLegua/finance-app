import 'package:finanzas/ui/pantallas/presupuesto/pantalla_presupuesto.dart';
import 'package:flutter/material.dart';

/// Cascarón de navegación: el `Scaffold` raíz con los cinco destinos.
///
/// Se construye en la fase Foundational, antes que las pantallas, para que
/// cada historia de usuario solo tenga que enchufar la suya. Sin esto, al
/// terminar las 105 tareas habría pantallas construidas a las que no se
/// podría llegar.
///
/// Los destinos sin pantalla todavía muestran un marcador que dice a qué
/// tarea corresponden, en vez de una pantalla en blanco.
class Cascaron extends StatefulWidget {
  const Cascaron({super.key});

  @override
  State<Cascaron> createState() => _CascaronState();
}

class _CascaronState extends State<Cascaron> {
  int _destino = 0;

  static const List<_Destino> _destinos = <_Destino>[
    _Destino(
      etiqueta: 'Presupuesto',
      icono: Icons.account_balance_wallet_outlined,
      iconoActivo: Icons.account_balance_wallet,
      pantalla: PantallaPresupuesto(),
    ),
    _Destino(
      etiqueta: 'Gastos',
      icono: Icons.receipt_long_outlined,
      iconoActivo: Icons.receipt_long,
      pendiente: 'US3 · registro de gastos reales',
    ),
    _Destino(
      etiqueta: 'Deudas',
      icono: Icons.credit_card_outlined,
      iconoActivo: Icons.credit_card,
      pendiente: 'US4 · deudas de tarjeta en cuotas',
    ),
    _Destino(
      etiqueta: 'Ahorro',
      icono: Icons.savings_outlined,
      iconoActivo: Icons.savings,
      pendiente: 'US5 · meta de ahorro y aportes',
    ),
    _Destino(
      etiqueta: 'Categorías',
      icono: Icons.pie_chart_outline,
      iconoActivo: Icons.pie_chart,
      pendiente: 'US6 · desglose por categoría',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final actual = _destinos[_destino];

    return Scaffold(
      appBar: AppBar(title: Text(actual.etiqueta)),
      body: actual.pantalla ??
          _EnConstruccion(pendiente: actual.pendiente ?? ''),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _destino,
        onDestinationSelected: (indice) => setState(() => _destino = indice),
        destinations: [
          for (final destino in _destinos)
            NavigationDestination(
              icon: Icon(destino.icono),
              selectedIcon: Icon(destino.iconoActivo),
              label: destino.etiqueta,
            ),
        ],
      ),
    );
  }
}

class _Destino {
  const _Destino({
    required this.etiqueta,
    required this.icono,
    required this.iconoActivo,
    this.pantalla,
    this.pendiente,
  });

  final String etiqueta;
  final IconData icono;
  final IconData iconoActivo;

  /// La pantalla del destino, o `null` si su historia todavía no se construyó.
  final Widget? pantalla;

  /// Qué historia la construirá, para el marcador temporal.
  final String? pendiente;
}

/// Marcador temporal. Cada historia lo reemplaza por su pantalla.
class _EnConstruccion extends StatelessWidget {
  const _EnConstruccion({required this.pendiente});

  final String pendiente;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_outlined,
                size: 48, color: esquema.outline),
            const SizedBox(height: 16),
            Text(
              'Todavía no construido',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              pendiente,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
