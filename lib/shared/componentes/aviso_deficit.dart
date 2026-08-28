import 'package:finanzas/dominio/modelos/resumen_mes.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:flutter/material.dart';

/// Comunica que los compromisos superan al ingreso (FR-028, FR-029).
///
/// Lleva **ícono, título y monto del faltante**, no solo un color rojo. La
/// constitución lo exige para no depender de la percepción cromática, y en
/// una app de plata es además lo que hace que el usuario entienda el problema
/// sin tener que interpretarlo.
class AvisoDeficit extends StatelessWidget {
  const AvisoDeficit({required this.resumen, super.key});

  final ResumenMes resumen;

  @override
  Widget build(BuildContext context) {
    if (!resumen.enDeficit) return const SizedBox.shrink();

    final esquema = Theme.of(context).colorScheme;
    final tipografia = Theme.of(context).textTheme;

    return Card(
      color: esquema.errorContainer,
      margin: const EdgeInsets.symmetric(
        horizontal: Espaciado.normal,
        vertical: Espaciado.chico,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: esquema.onErrorContainer),
            const SizedBox(width: Espaciado.interno),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tus compromisos superan tu ingreso',
                    style: tipografia.titleSmall?.copyWith(
                      color: esquema.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: Espaciado.minimo),
                  Text(
                    'Te faltan ${FormatoSoles.formatear(resumen.faltante)} '
                    'para cubrirlos. Revisá el presupuesto antes de ahorrar '
                    'este mes.',
                    style: tipografia.bodyMedium?.copyWith(
                      color: esquema.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
