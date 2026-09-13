import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/ui/estado/estado_propinas.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Dejar una propina, si se quiere (US2, spec 004 revisada).
///
/// Es la **única** pantalla de la app que menciona dinero para el
/// desarrollador, y se llega a ella solo desde Ajustes (FR-006). Nada de lo
/// que pase acá cambia el comportamiento de ninguna otra pantalla, y eso se
/// dice con todas las letras antes de mostrar un solo precio (FR-005): una
/// pantalla de pago que no aclara qué se lleva el que paga se lee como un
/// paywall.
///
/// Principio IV: todo se explica con texto. Si no se pudieron consultar los
/// montos, se dice — **nunca se inventa un precio** ni se muestra uno viejo.
class PantallaPropina extends StatelessWidget {
  const PantallaPropina({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Apoyar esta app')),
    body: const _Cuerpo(),
  );
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo();

  @override
  Widget build(BuildContext context) {
    final propinas = context.watch<EstadoPropinas>();
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(Espaciado.normal),
      children: [
        Icon(
          Icons.volunteer_activism_outlined,
          size: 40,
          color: esquema.primary,
        ),
        const SizedBox(height: Espaciado.chico),
        Text(
          'Finanzas es gratis y completa',
          style: textos.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Espaciado.chico),
        Text(
          'Todo lo que hace la app lo hace para cualquiera que la instale, sin '
          'pagar nada y sin límite de tiempo. Si te resultó útil y querés '
          'apoyar el proyecto, podés dejar una propina.',
          style: textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Espaciado.normal),
        const _AvisoNoDesbloqueaNada(),
        const SizedBox(height: Espaciado.grande),
        if (propinas.ultimoResultado != null)
          _ResultadoDeLaCompra(
            resultado: propinas.ultimoResultado!,
            onCerrar: propinas.limpiarResultado,
          ),
        if (propinas.cargando)
          const Padding(
            padding: EdgeInsets.all(Espaciado.grande),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (propinas.errorDeOfertas != null)
          _SinMontos(onReintentar: propinas.cargar)
        else
          for (final oferta in propinas.ofertas)
            _FichaMonto(
              oferta: oferta,
              apoyando: propinas.apoyando,
              onApoyar: () => propinas.apoyar(oferta),
            ),
        if (propinas.apoyando) const _CompraEnCurso(),
      ],
    );
  }
}

/// Lo que separa una propina de un paywall, dicho antes que cualquier precio
/// (FR-005).
class _AvisoNoDesbloqueaNada extends StatelessWidget {
  const _AvisoNoDesbloqueaNada();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Card(
      color: esquema.surfaceContainerHighest,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_open_outlined, color: esquema.onSurfaceVariant),
            const SizedBox(width: Espaciado.chico),
            const Expanded(
              child: Text(
                'Apoyar no desbloquea ninguna funcionalidad: ya las tenés '
                'todas. Es un gracias, no una compra.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un monto con su precio, tal como lo informa Google Play, y el botón que
/// arranca su compra.
///
/// El precio se muestra **antes** de tocar nada (FR-004): nadie debería tener
/// que abrir el diálogo de Google para enterarse de cuánto va a pagar.
class _FichaMonto extends StatelessWidget {
  const _FichaMonto({
    required this.oferta,
    required this.apoyando,
    required this.onApoyar,
  });

  final OfertaPropina oferta;

  /// Hay una compra esperando respuesta —de este monto o de otro—, así que
  /// ningún botón acepta un toque más.
  final bool apoyando;

  final VoidCallback onApoyar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(oferta.titulo, style: textos.titleMedium),
                  const SizedBox(height: Espaciado.minimo),
                  Text(oferta.precioFormateado, style: textos.montoSecundario),
                ],
              ),
            ),
            const SizedBox(width: Espaciado.chico),
            FilledButton(
              onPressed: apoyando ? null : onApoyar,
              child: const Text('Apoyar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cómo terminó la última compra.
///
/// El `switch` es exhaustivo a propósito: si mañana se suma un desenlace, esto
/// deja de compilar hasta que alguien decida qué decirle al usuario.
/// `cancelada` devuelve `null` y no muestra nada —cerrar el diálogo de Google
/// no merece ningún cartel (FR-008)— pero el caso se maneja igual, porque un
/// `switch` con un hueco es una forma de olvido.
class _ResultadoDeLaCompra extends StatelessWidget {
  const _ResultadoDeLaCompra({required this.resultado, required this.onCerrar});

  final ResultadoPropina resultado;
  final VoidCallback onCerrar;

  static ({IconData icono, String titulo, String detalle})? _mensajeDe(
    ResultadoPropina resultado,
  ) => switch (resultado) {
    ResultadoPropina.completada => (
      icono: Icons.favorite,
      titulo: '¡Gracias!',
      detalle: 'Tu apoyo llegó. La app sigue igual de completa que antes.',
    ),
    ResultadoPropina.pendiente => (
      icono: Icons.hourglass_empty,
      titulo: 'Google todavía está confirmando',
      detalle:
          'Cuando se confirme queda listo. No hace falta que hagas nada más '
          'ni que vuelvas a pagar.',
    ),
    ResultadoPropina.fallida => (
      icono: Icons.error_outline,
      titulo: 'No se pudo completar',
      detalle:
          'Google Play no pudo procesar el pago. Podés volver a intentarlo '
          'cuando quieras.',
    ),
    ResultadoPropina.cancelada => null,
  };

  @override
  Widget build(BuildContext context) {
    final mensaje = _mensajeDe(resultado);
    if (mensaje == null) return const SizedBox.shrink();

    final esquema = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Card(
      color: esquema.secondaryContainer,
      margin: const EdgeInsets.only(bottom: Espaciado.normal),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(mensaje.icono, color: esquema.onSecondaryContainer),
            const SizedBox(width: Espaciado.chico),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mensaje.titulo,
                    style: textos.titleSmall?.copyWith(
                      color: esquema.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: Espaciado.minimo),
                  Text(
                    mensaje.detalle,
                    style: textos.bodyMedium?.copyWith(
                      color: esquema.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onCerrar,
              icon: const Icon(Icons.close),
              tooltip: 'Cerrar',
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
/// tardar, y un botón apagado sin explicación se lee como que la app se colgó.
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
            'Confirmando con Google Play…',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

/// No se pudieron consultar los montos (sin conexión, sin Google Play, o la
/// tienda no respondió). Se dice con todas las letras y se ofrece reintentar:
/// mostrar un precio guardado de antes sería engañoso (FR-011).
class _SinMontos extends StatelessWidget {
  const _SinMontos({required this.onReintentar});

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
                    'No pudimos consultar los montos para apoyar. Revisá tu '
                    'conexión y volvé a intentarlo.',
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
