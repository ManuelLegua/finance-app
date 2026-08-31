import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/ui/estado/estado_diagnostico.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Notificaciones que la app no pudo interpretar (spec 002, FR-018).
///
/// Existe para que un formato que el parser genérico no reconoce sea
/// **visible** en vez de desaparecer en silencio: es la señal de que hay que
/// ajustar el reconocimiento, y el usuario puede borrarla cuando quiera —
/// nada de esto sale del dispositivo (FR-019).
class PantallaDiagnostico extends StatelessWidget {
  const PantallaDiagnostico({super.key});

  Future<void> _vaciar(BuildContext context, EstadoDiagnostico estado) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Borrar el registro?'),
        content: const Text(
          'Se borran las notificaciones que no se pudieron interpretar. No '
          'afecta a ningún gasto ya registrado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmado ?? false) await estado.vaciar();
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoDiagnostico>();

    if (estado.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final entradas = estado.entradas;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: estado.cargar,
        child: ListView(
          children: [
            if (estado.error != null)
              _BannerError(
                mensaje: estado.error!,
                onCerrar: estado.limpiarError,
              ),
            const _Explicacion(),
            if (entradas.isEmpty)
              const _SinEntradas()
            else ...[
              for (final entrada in entradas)
                _FilaDiagnostico(
                  entrada: entrada,
                  onEliminar: () => estado.eliminar(entrada.id!),
                ),
              Padding(
                padding: const EdgeInsets.all(Espaciado.normal),
                child: OutlinedButton.icon(
                  onPressed: () => _vaciar(context, estado),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Borrar todo el registro'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Explicacion extends StatelessWidget {
  const _Explicacion();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Espaciado.normal),
      child: Text(
        'Acá quedan las notificaciones de bancos que la app reconoció como '
        'tuyas pero no pudo leer bien. No se registró ningún gasto a partir '
        'de ellas. Nada de esto sale de tu teléfono.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: esquema.onSurfaceVariant),
      ),
    );
  }
}

class _SinEntradas extends StatelessWidget {
  const _SinEntradas();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Espaciado.amplio),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 48, color: esquema.primary),
          const SizedBox(height: Espaciado.normal),
          Text(
            'Nada sin interpretar',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FilaDiagnostico extends StatelessWidget {
  const _FilaDiagnostico({required this.entrada, required this.onEliminar});

  final NotificacionDiagnostico entrada;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    entrada.motivo.etiqueta,
                    style: tipografia.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: onEliminar,
                  icon: const Icon(Icons.close),
                  tooltip: 'Quitar del registro',
                ),
              ],
            ),
            Text(
              FormatoFecha.corta(entrada.fecha),
              style: tipografia.bodySmall?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Espaciado.chico),
            Text(entrada.textoCrudo, style: tipografia.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _BannerError extends StatelessWidget {
  const _BannerError({required this.mensaje, required this.onCerrar});

  final String mensaje;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Card(
      color: esquema.errorContainer,
      margin: const EdgeInsets.symmetric(
        horizontal: Espaciado.normal,
        vertical: Espaciado.chico,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.interno),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: esquema.onErrorContainer),
            const SizedBox(width: Espaciado.interno),
            Expanded(
              child: Text(
                mensaje,
                style: TextStyle(color: esquema.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onCerrar, child: const Text('Entendido')),
          ],
        ),
      ),
    );
  }
}
