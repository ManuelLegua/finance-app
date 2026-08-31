import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/ui/estado/estado_suscripcion.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// En qué situación está la suscripción, en un solo lugar consultable
/// (FR-009, spec 004).
///
/// Se usa en Ajustes —donde siempre está a mano— y arriba del paywall cuando
/// hubo una suscripción antes, para que quien vuelve a ver el aviso entienda
/// por qué.
///
/// Principio IV: la situación se nombra con **texto**; el ícono y el color
/// acompañan. Un candado gris no distingue "vencida" de "cancelada", y la
/// diferencia le importa a quien la está mirando.
class FichaEstadoSuscripcion extends StatelessWidget {
  const FichaEstadoSuscripcion({super.key});

  /// Qué decir bajo el nombre de la situación.
  ///
  /// El `switch` es exhaustivo a propósito: si mañana se suma una situación
  /// al enum, esto deja de compilar hasta que alguien decida qué explicarle
  /// al usuario, en vez de mostrarle una ficha muda.
  static String _detalleDe(
    SituacionSuscripcion situacion,
    String nombrePlan,
    String? hasta,
  ) => switch (situacion) {
    SituacionSuscripcion.nunca =>
      'Deudas, Ahorro y la captura de notificaciones están bloqueados.',
    SituacionSuscripcion.enPrueba =>
      hasta == null
          ? 'Estás probando el $nombrePlan, todavía sin ningún cobro.'
          : 'Estás probando el $nombrePlan. El primer cobro es el $hasta.',
    SituacionSuscripcion.activa =>
      hasta == null
          ? 'Tenés el $nombrePlan.'
          : 'Tenés el $nombrePlan. Se renueva el $hasta.',
    SituacionSuscripcion.enGracia =>
      'Google Play no pudo cobrar el $nombrePlan. Conservás el acceso '
          'mientras dure el margen que da la tienda.',
    // Perder el acceso no es perder los datos, y hay que decirlo: es
    // justo lo que el usuario teme al ver que una pantalla se bloqueó
    // (FR-011).
    SituacionSuscripcion.vencida =>
      'El $nombrePlan ya no está vigente. Tus deudas, aportes y consumos '
          'siguen guardados: vuelven a verse al reactivar.',
    SituacionSuscripcion.cancelada =>
      'Cancelaste el $nombrePlan. Tus deudas, aportes y consumos siguen '
          'guardados: vuelven a verse al reactivar.',
  };

  static IconData _iconoDe(SituacionSuscripcion situacion) =>
      switch (situacion) {
        SituacionSuscripcion.nunca => Icons.lock_outline,
        SituacionSuscripcion.enPrueba => Icons.card_giftcard,
        SituacionSuscripcion.activa => Icons.verified_outlined,
        SituacionSuscripcion.enGracia => Icons.error_outline,
        SituacionSuscripcion.vencida => Icons.event_busy,
        SituacionSuscripcion.cancelada => Icons.cancel_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final suscripcion = context.watch<EstadoSuscripcionPremium>();
    final esquema = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    final situacion = suscripcion.situacion;
    final plan = suscripcion.plan;
    final vigenteHasta = suscripcion.estado?.vigenteHasta;

    // Sin plan conocido se habla del plan a secas: nunca se nombra uno que la
    // tienda no confirmó.
    final nombrePlan = plan == null
        ? 'plan'
        : 'plan ${plan.etiqueta.toLowerCase()}';
    final hasta = vigenteHasta == null
        ? null
        : FormatoFecha.corta(vigenteHasta);

    final color = suscripcion.premiumActivo
        ? esquema.primary
        : esquema.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Espaciado.normal),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_iconoDe(situacion), color: color),
            const SizedBox(width: Espaciado.chico),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    situacion.etiqueta,
                    style: textos.titleSmall?.copyWith(color: color),
                  ),
                  const SizedBox(height: Espaciado.minimo),
                  Text(
                    _detalleDe(situacion, nombrePlan, hasta),
                    style: textos.bodyMedium?.copyWith(
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
}
