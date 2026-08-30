import 'dart:io' show Platform;

import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/estado/estado_pendientes.dart';
import 'package:finanzas/ui/pantallas/ahorro/pantalla_ahorro.dart';
import 'package:finanzas/ui/pantallas/ajustes/pantalla_ajustes.dart';
import 'package:finanzas/ui/pantallas/captura/pantalla_activacion.dart';
import 'package:finanzas/ui/pantallas/captura/pantalla_diagnostico.dart';
import 'package:finanzas/ui/pantallas/captura/pantalla_pendientes.dart';
import 'package:finanzas/ui/pantallas/categorias/pantalla_desglose.dart';
import 'package:finanzas/ui/pantallas/deudas/pantalla_deudas.dart';
import 'package:finanzas/ui/pantallas/deudas/pantalla_tarjetas.dart';
import 'package:finanzas/ui/pantallas/presupuesto/pantalla_presupuesto.dart';
import 'package:finanzas/ui/pantallas/resumen_mes/pantalla_resumen.dart';
import 'package:finanzas/ui/pantallas/transacciones/pantalla_transacciones.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Cascarón de navegación (D16).
///
/// **Barra inferior** para lo frecuente, **drawer** para lo ocasional. El
/// reparto sale de la frecuencia de uso, no de la importancia: Gastos se usa
/// varias veces al día y Resumen a diario, mientras que Tarjetas o Ajustes se
/// consultan de vez en cuando y aguantan el toque extra sin costo real.
///
/// Meter todo en el drawer cobraría ese toque también a registrar un gasto,
/// y hay dos criterios de éxito que lo penalizan: SC-002 pide menos de 15
/// segundos para anotar un gasto y SC-001 un máximo de dos interacciones para
/// conocer el saldo.
class Cascaron extends StatefulWidget {
  const Cascaron({super.key});

  @override
  State<Cascaron> createState() => _CascaronState();
}

class _CascaronState extends State<Cascaron> {
  /// Índice dentro de [_frecuentes], o `null` cuando se está viendo un
  /// destino del drawer.
  int _destinoFrecuente = 0;
  _Destino? _destinoDelDrawer;

  /// Uso diario o mensual: van en la barra inferior. Material 3 admite hasta
  /// cinco, y con seis la etiqueta "Presupuesto" se partía en dos líneas.
  static const List<_Destino> _frecuentes = <_Destino>[
    _Destino(
      etiqueta: 'Resumen',
      icono: Icons.donut_small_outlined,
      iconoActivo: Icons.donut_small,
      pantalla: PantallaResumen(),
    ),
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
      pantalla: PantallaTransacciones(),
    ),
    _Destino(
      etiqueta: 'Deudas',
      icono: Icons.credit_card_outlined,
      iconoActivo: Icons.credit_card,
      pantalla: PantallaDeudas(),
    ),
    _Destino(
      etiqueta: 'Ahorro',
      icono: Icons.savings_outlined,
      iconoActivo: Icons.savings,
      pantalla: PantallaAhorro(),
    ),
  ];

  /// Consultas ocasionales y ajustes. Acá crecen las features siguientes sin
  /// volver a romper la barra.
  ///
  /// No es `const`: "Captura" solo se agrega en Android (D-N8, FR-007), y esa
  /// condición no se puede evaluar en un literal constante.
  static final List<_Destino> _ocasionales = <_Destino>[
    const _Destino(
      // "Desglose por categoría" desbordaba los 280 px del drawer. Mismo tipo
      // de defecto que "Presupuesto" en la barra inferior: etiqueta más larga
      // que su contenedor.
      etiqueta: 'Categorías',
      icono: Icons.pie_chart_outline,
      iconoActivo: Icons.pie_chart,
      pantalla: PantallaDesglose(),
    ),
    const _Destino(
      etiqueta: 'Tarjetas',
      icono: Icons.credit_score_outlined,
      iconoActivo: Icons.credit_score,
      pantalla: PantallaTarjetas(),
    ),
    if (Platform.isAndroid) ...[
      const _Destino(
        etiqueta: 'Pendientes',
        icono: Icons.mark_email_unread_outlined,
        iconoActivo: Icons.mark_email_unread,
        pantalla: PantallaPendientes(),
      ),
      const _Destino(
        etiqueta: 'Captura',
        icono: Icons.settings_input_antenna_outlined,
        iconoActivo: Icons.settings_input_antenna,
        pantalla: PantallaActivacion(),
      ),
      const _Destino(
        etiqueta: 'Diagnóstico',
        icono: Icons.rule_outlined,
        iconoActivo: Icons.rule,
        pantalla: PantallaDiagnostico(),
      ),
    ],
    const _Destino(
      etiqueta: 'Ajustes',
      icono: Icons.settings_outlined,
      iconoActivo: Icons.settings,
      pantalla: PantallaAjustes(),
    ),
  ];

  _Destino get _actual => _destinoDelDrawer ?? _frecuentes[_destinoFrecuente];

  void _irAFrecuente(int indice) => setState(() {
    _destinoFrecuente = indice;
    _destinoDelDrawer = null;
  });

  void _irAOcasional(_Destino destino) => setState(() {
    _destinoDelDrawer = destino;
  });

  @override
  Widget build(BuildContext context) {
    final actual = _actual;

    return Scaffold(
      appBar: AppBar(title: Text(actual.etiqueta)),
      drawer: _MenuLateral(
        seleccionado: _destinoDelDrawer,
        ocasionales: _ocasionales,
        onElegir: _irAOcasional,
      ),
      body: actual.pantalla,
      bottomNavigationBar: NavigationBar(
        // Con un destino del drawer en pantalla ninguno de la barra está
        // activo, pero NavigationBar exige un índice: se conserva el último
        // para que volver de Ajustes devuelva a donde estabas.
        selectedIndex: _destinoFrecuente,
        onDestinationSelected: _irAFrecuente,
        destinations: [
          for (final destino in _frecuentes)
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

/// Drawer con los destinos ocasionales.
class _MenuLateral extends StatelessWidget {
  const _MenuLateral({
    required this.seleccionado,
    required this.ocasionales,
    required this.onElegir,
  });

  final _Destino? seleccionado;
  final List<_Destino> ocasionales;
  final void Function(_Destino) onElegir;

  @override
  Widget build(BuildContext context) {
    final mes = context.watch<EstadoMes>().mes;

    return NavigationDrawer(
      selectedIndex: seleccionado == null
          ? null
          : ocasionales.indexOf(seleccionado!),
      onDestinationSelected: (indice) {
        Navigator.of(context).pop();
        onElegir(ocasionales[indice]);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaciado.grande,
            Espaciado.grande,
            Espaciado.normal,
            Espaciado.interno,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Finanzas', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Espaciado.minimo),
              Text(
                FormatoFecha.mesTitulo(mes),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        for (final destino in ocasionales)
          NavigationDrawerDestination(
            icon: _IconoDeDestino(destino: destino, activo: false),
            selectedIcon: _IconoDeDestino(destino: destino, activo: true),
            label: Text(destino.etiqueta),
          ),
      ],
    );
  }
}

/// El ícono de un destino del drawer, con la cantidad de pendientes como
/// distintivo cuando el destino es "Pendientes" (spec 002, FR-022).
///
/// Es la única razón por la que `_ocasionales` no puede seguir siendo una
/// lista de datos puros consumida sin mirar: este destino en particular
/// necesita leer `EstadoPendientes`, que solo existe cuando la captura está
/// disponible (Android).
class _IconoDeDestino extends StatelessWidget {
  const _IconoDeDestino({required this.destino, required this.activo});

  final _Destino destino;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final icono = Icon(activo ? destino.iconoActivo : destino.icono);
    if (destino.etiqueta != 'Pendientes') return icono;

    final cantidad = context.watch<EstadoPendientes>().resumen.cantidad;
    if (cantidad == 0) return icono;

    return Badge(label: Text('$cantidad'), child: icono);
  }
}

class _Destino {
  const _Destino({
    required this.etiqueta,
    required this.icono,
    required this.iconoActivo,
    required this.pantalla,
  });

  final String etiqueta;
  final IconData icono;
  final IconData iconoActivo;
  final Widget pantalla;
}
