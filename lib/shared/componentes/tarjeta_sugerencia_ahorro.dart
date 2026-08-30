import 'package:finanzas/dominio/calculos/ahorro.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:flutter/material.dart';

/// Cuánto conviene apartar este mes, según la regla elegida (FR-033, FR-037).
///
/// Se usa en `PantallaResumen` (con la sugerencia del mes que se está mirando)
/// y en `PantallaAhorro`: es el mismo dato, no dos redacciones distintas de la
/// misma tarjeta.
class TarjetaSugerenciaAhorro extends StatelessWidget {
  const TarjetaSugerenciaAhorro({required this.sugerencia, super.key});

  final SugerenciaAhorro sugerencia;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    if (sugerencia.noCorresponde) {
      return Card(
        color: esquema.surfaceContainerHighest,
        margin: const EdgeInsets.symmetric(
          horizontal: Espaciado.normal,
          vertical: Espaciado.chico,
        ),
        child: Padding(
          padding: const EdgeInsets.all(Espaciado.normal),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: esquema.onSurfaceVariant),
              const SizedBox(width: Espaciado.interno),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No corresponde ahorrar este mes',
                      style: tipografia.titleSmall,
                    ),
                    const SizedBox(height: Espaciado.minimo),
                    Text(
                      'Tus compromisos superan tu ingreso, o todavía no lo '
                      'registraste. Revisá el presupuesto antes de ahorrar.',
                      style: tipografia.bodyMedium?.copyWith(
                        color: esquema.onSurfaceVariant,
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

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: Espaciado.normal,
        vertical: Espaciado.chico,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sugerencia de ahorro', style: tipografia.labelLarge),
            const SizedBox(height: Espaciado.minimo),
            Text(
              FormatoSoles.formatear(sugerencia.montoAlcanzable),
              style: tipografia.montoDestacado,
            ),
            if (sugerencia.excedeDisponible) ...[
              const SizedBox(height: Espaciado.minimo),
              Text(
                'La regla sugería ${FormatoSoles.formatear(sugerencia.montoSugerido)}, '
                'pero no entra en tu disponible: te ofrecemos lo que sí '
                'alcanza.',
                style: tipografia.bodySmall?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
