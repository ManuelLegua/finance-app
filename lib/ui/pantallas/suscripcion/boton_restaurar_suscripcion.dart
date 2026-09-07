import 'package:finanzas/ui/estado/estado_suscripcion.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// La acción explícita para restaurar una suscripción ya comprada con la
/// cuenta de Google actual (FR-014).
///
/// Vive en el paywall y en Ajustes (T039) y no dentro de
/// `FichaEstadoSuscripcion`: esa ficha se oculta con `situacion = nunca`, que
/// es exactamente el estado de quien instala la app en un dispositivo nuevo
/// y necesita restaurar (Acceptance Scenario 1).
class BotonRestaurarSuscripcion extends StatelessWidget {
  const BotonRestaurarSuscripcion({super.key});

  Future<void> _restaurar(
    BuildContext context,
    EstadoSuscripcionPremium suscripcion,
  ) async {
    await suscripcion.restaurar();
    if (!context.mounted) return;

    // Un error de verdad (sin conexión, Google Play no respondió) se explica
    // con su propio mensaje; recién si no hubo error se interpreta el
    // resultado como "esta cuenta no tiene suscripción" (FR-015).
    final mensaje =
        suscripcion.error ??
        (suscripcion.premiumActivo
            ? null
            : 'No encontramos ninguna suscripción para esta cuenta.');
    if (mensaje == null) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final suscripcion = context.watch<EstadoSuscripcionPremium>();

    return TextButton(
      onPressed: suscripcion.restaurando
          ? null
          : () => _restaurar(context, suscripcion),
      child: Text(
        suscripcion.restaurando ? 'Restaurando…' : 'Restaurar suscripción',
      ),
    );
  }
}
