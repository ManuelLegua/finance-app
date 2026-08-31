import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/ui/estado/estado_suscripcion.dart';
import 'package:finanzas/ui/pantallas/suscripcion/ficha_estado_suscripcion.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Aviso de suscripción: qué desbloquea y a qué precio (US1, spec 004).
///
/// Se muestra **en lugar** de una pantalla premium, no encima: el usuario
/// nunca ve datos parciales de algo a lo que no tiene acceso (SC-001).
///
/// Principio IV: todo se explica con texto. El candado acompaña, no comunica
/// solo. Y si no se pudieron consultar los precios, se dice — **nunca se
/// inventa un precio** ni se muestra uno viejo.
class PantallaPaywall extends StatelessWidget {
  const PantallaPaywall({required this.funcionalidad, super.key});

  /// Cómo se llama lo que el usuario quiso abrir ("Deudas", "Ahorro"). Se usa
  /// para que el aviso hable de lo que efectivamente tocó, no en abstracto.
  final String funcionalidad;

  /// Lo que desbloquea la suscripción, en el orden en que se explica.
  static const List<({IconData icono, String titulo, String detalle})>
  _incluye = [
    (
      icono: Icons.credit_card,
      titulo: 'Deudas en cuotas',
      detalle:
          'Registrá lo que debés en cuotas y mirá cuánto compromete cada mes.',
    ),
    (
      icono: Icons.savings,
      titulo: 'Ahorro',
      detalle: 'Ponete una meta mensual y seguí tus aportes.',
    ),
    (
      icono: Icons.notifications_active,
      titulo: 'Captura de notificaciones',
      detalle:
          'Los consumos de tus tarjetas llegan solos, sin anotarlos a mano.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final suscripcion = context.watch<EstadoSuscripcionPremium>();
    final esquema = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(Espaciado.normal),
      children: [
        // Quien ya tuvo suscripción merece saber por qué volvió a ver esto;
        // a quien nunca la tuvo, "Nunca suscripto" no le dice nada que el
        // aviso no explique mejor abajo.
        if (suscripcion.situacion != SituacionSuscripcion.nunca) ...[
          const FichaEstadoSuscripcion(),
          const SizedBox(height: Espaciado.normal),
        ],
        Icon(Icons.lock_outline, size: 40, color: esquema.primary),
        const SizedBox(height: Espaciado.chico),
        Text(
          '$funcionalidad es parte de Finanzas Premium',
          style: textos.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Espaciado.chico),
        Text(
          'Con la suscripción se desbloquean estas tres cosas. Todo lo demás '
          '—presupuesto, resumen del mes y gastos— es y sigue siendo gratis.',
          style: textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Espaciado.grande),
        for (final incluido in _incluye)
          _FilaIncluida(
            icono: incluido.icono,
            titulo: incluido.titulo,
            detalle: incluido.detalle,
          ),
        const SizedBox(height: Espaciado.grande),
        if (suscripcion.errorDeOfertas != null)
          _SinPrecios(
            mensaje: suscripcion.errorDeOfertas!,
            onReintentar: suscripcion.cargarOfertas,
          )
        else ...[
          Text(
            'El primer mes es gratis en cualquiera de los dos planes.',
            style: textos.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Espaciado.chico),
          for (final oferta in suscripcion.ofertas)
            _FichaPlan(
              oferta: oferta,
              comprando: suscripcion.comprando,
              onComprar: () => suscripcion.comprar(oferta.plan),
            ),
          if (suscripcion.comprando) const _CompraEnCurso(),
        ],
      ],
    );
  }
}

class _FilaIncluida extends StatelessWidget {
  const _FilaIncluida({
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  final IconData icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Espaciado.normal),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: esquema.primary),
          const SizedBox(width: Espaciado.chico),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: textos.titleMedium),
                Text(
                  detalle,
                  style: textos.bodyMedium?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un plan con su precio, tal como lo informa Google Play, y el botón que
/// arranca su compra.
///
/// El precio se muestra **antes** de tocar nada (FR-005, Acceptance Scenario
/// 1): nadie debería tener que abrir el diálogo de Google para enterarse de
/// cuánto le van a cobrar.
class _FichaPlan extends StatelessWidget {
  const _FichaPlan({
    required this.oferta,
    required this.comprando,
    required this.onComprar,
  });

  final OfertaSuscripcion oferta;

  /// Hay una compra esperando confirmación —de este plan o del otro—, así que
  /// ningún botón acepta un toque más.
  final bool comprando;

  final VoidCallback onComprar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final hayPrueba = oferta.duracionPruebaDias > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan ${oferta.plan.etiqueta.toLowerCase()}',
              style: textos.titleMedium,
            ),
            const SizedBox(height: Espaciado.minimo),
            Text(
              hayPrueba
                  ? '${oferta.precioFormateado} · '
                        '${oferta.duracionPruebaDias} días de prueba'
                  : oferta.precioFormateado,
              style: textos.bodyMedium,
            ),
            const SizedBox(height: Espaciado.chico),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: comprando ? null : onComprar,
                child: Text(hayPrueba ? 'Empezar gratis' : 'Suscribirme'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La compra ya se disparó y Google todavía no respondió.
///
/// Se dice con texto, no solo grisando los botones: la confirmación puede
/// tardar, y un botón apagado sin explicación se lee como que la app se
/// colgó.
class _CompraEnCurso extends StatelessWidget {
  const _CompraEnCurso();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Espaciado.chico),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: Espaciado.chico),
        Flexible(
          child: Text(
            'Confirmando la compra con Google Play…',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

/// No se pudieron consultar los planes (sin conexión, o Google Play no
/// respondió). Se dice con todas las letras y se ofrece reintentar: mostrar
/// un precio guardado de antes sería engañoso.
class _SinPrecios extends StatelessWidget {
  const _SinPrecios({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Card(
      color: esquema.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.wifi_off, color: esquema.onSurfaceVariant),
                const SizedBox(width: Espaciado.chico),
                const Expanded(
                  child: Text(
                    'No pudimos consultar los planes ni sus precios. Revisá '
                    'tu conexión y volvé a intentarlo.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espaciado.chico),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onReintentar,
                child: const Text('Reintentar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
