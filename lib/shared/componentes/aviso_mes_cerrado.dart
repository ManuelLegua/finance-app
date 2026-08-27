import 'package:finanzas/dominio/modelos/estado_cierre.dart';
import 'package:flutter/material.dart';

/// Comunica que un mes está cerrado o en ventana de gracia (FR-058).
///
/// Lleva ícono **y** texto además del color: la constitución prohíbe que un
/// estado se transmita solo por color, y "no puedo editar esto" es
/// exactamente el tipo de restricción que, comunicada solo con controles
/// grises, deja al usuario pensando que la app está rota.
class AvisoMesCerrado extends StatelessWidget {
  const AvisoMesCerrado({required this.estado, super.key});

  final EstadoCierre estado;

  @override
  Widget build(BuildContext context) {
    final motivo = estado.motivo;
    if (estado.situacion == SituacionMes.abierto || motivo == null) {
      return const SizedBox.shrink();
    }

    final esGracia = estado.situacion == SituacionMes.enGracia;
    final esquema = Theme.of(context).colorScheme;
    final fondo = esGracia
        ? esquema.tertiaryContainer
        : esquema.surfaceContainerHighest;
    final texto = esGracia
        ? esquema.onTertiaryContainer
        : esquema.onSurfaceVariant;

    return Card(
      color: fondo,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              esGracia ? Icons.history_toggle_off : Icons.lock_outline,
              color: texto,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esGracia ? 'Plazo para pagos rezagados' : 'Mes cerrado',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(color: texto),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    motivo,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: texto),
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
