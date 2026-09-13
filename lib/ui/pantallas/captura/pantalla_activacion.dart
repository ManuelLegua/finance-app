import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/ui/estado/estado_captura.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Activar la captura de notificaciones bancarias y entender qué implica
/// (HU1, spec 002).
///
/// El estado real del permiso se relee cada vez que la app vuelve al primer
/// plano (`WidgetsBindingObserver`): el usuario puede haber ido a los
/// ajustes de Android y concedido o revocado el permiso ahí, y esta pantalla
/// nunca debe mostrar lo que asumía antes de que eso pasara (FR-003).
class PantallaActivacion extends StatefulWidget {
  const PantallaActivacion({super.key});

  @override
  State<PantallaActivacion> createState() => _PantallaActivacionState();
}

class _PantallaActivacionState extends State<PantallaActivacion>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      context.read<EstadoCapturaNotificaciones>().cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoCaptura = context.watch<EstadoCapturaNotificaciones>();

    if (estadoCaptura.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: estadoCaptura.cargar,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: Espaciado.chico),
        children: [
          if (estadoCaptura.error != null)
            _BannerError(
              mensaje: estadoCaptura.error!,
              onCerrar: estadoCaptura.cargar,
            ),
          _TarjetaSituacion(estadoCaptura: estadoCaptura),
        ],
      ),
    );
  }
}

class _TarjetaSituacion extends StatelessWidget {
  const _TarjetaSituacion({required this.estadoCaptura});

  final EstadoCapturaNotificaciones estadoCaptura;

  @override
  Widget build(BuildContext context) {
    final estado = estadoCaptura.estado;

    return switch (estado.situacion) {
      SituacionCaptura.activa => _CapturaActiva(
        estado: estado,
        onDesactivar: estadoCaptura.desactivar,
      ),
      SituacionCaptura.inactivaEnApp => _Explicacion(
        motivo: estado.motivo,
        etiquetaBoton: 'Activar captura',
        onTocar: estadoCaptura.activar,
      ),
      SituacionCaptura.permisoRevocado => _Explicacion(
        motivo: estado.motivo,
        etiquetaBoton: 'Ir a ajustes de Android',
        icono: Icons.warning_amber_rounded,
        onTocar: estadoCaptura.pedirPermiso,
      ),
      SituacionCaptura.sinPermiso => _Explicacion(
        motivo: null,
        etiquetaBoton: 'Ir a ajustes de Android',
        onTocar: estadoCaptura.pedirPermiso,
      ),
    };
  }
}

/// Lo que se explica **antes** de pedir el permiso (FR-001), y lo mismo que
/// se muestra si el permiso se revocó o si está concedido pero la captura
/// está apagada: en los tres casos hace falta la misma información para que
/// el usuario decida.
class _Explicacion extends StatelessWidget {
  const _Explicacion({
    required this.motivo,
    required this.etiquetaBoton,
    required this.onTocar,
    this.icono,
  });

  /// `null` cuando todavía no se pidió nunca: no hay nada que explicar sobre
  /// un estado previo, solo la explicación general de abajo.
  final String? motivo;
  final String etiquetaBoton;
  final IconData? icono;
  final VoidCallback onTocar;

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
            if (motivo != null) ...[
              Row(
                children: [
                  Icon(
                    icono ?? Icons.info_outline,
                    color: esquema.onSurfaceVariant,
                  ),
                  const SizedBox(width: Espaciado.chico),
                  Expanded(
                    child: Text(
                      motivo!,
                      style: tipografia.bodyMedium?.copyWith(
                        color: esquema.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: Espaciado.grande),
            ],
            Text('Qué va a leer la app', style: tipografia.titleSmall),
            const SizedBox(height: Espaciado.minimo),
            Text(
              'Solo las notificaciones de bancos y billeteras reconocidas '
              '(la lista completa aparece una vez que actives la captura). '
              'De cada una extrae el monto, el comercio y la fecha del '
              'consumo — nunca notificaciones de otras apps.',
              style: tipografia.bodyMedium,
            ),
            const SizedBox(height: Espaciado.normal),
            Text('Qué hace con eso', style: tipografia.titleSmall),
            const SizedBox(height: Espaciado.minimo),
            Text(
              'Nada sale de tu teléfono. Cada consumo detectado queda '
              'esperando en una bandeja hasta que vos lo confirmás; la app '
              'nunca registra un gasto sola.',
              style: tipografia.bodyMedium,
            ),
            const SizedBox(height: Espaciado.normal),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onTocar,
                child: Text(etiquetaBoton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapturaActiva extends StatelessWidget {
  const _CapturaActiva({required this.estado, required this.onDesactivar});

  final EstadoCaptura estado;
  final VoidCallback onDesactivar;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final origenes = estado.origenesQueCubre;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: Espaciado.normal,
        vertical: Espaciado.chico,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(Espaciado.normal),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: esquema.primary),
                const SizedBox(width: Espaciado.chico),
                Expanded(
                  child: Text('Captura activa', style: tipografia.titleSmall),
                ),
              ],
            ),
          ),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: Espaciado.normal,
            ),
            title: Text(
              '${origenes.length} bancos y billeteras',
              style: tipografia.bodyMedium,
            ),
            children: [
              for (final origen in origenes)
                ListTile(dense: true, title: Text(origen.nombre)),
            ],
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(Espaciado.normal),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDesactivar,
                child: const Text('Desactivar'),
              ),
            ),
          ),
        ],
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
            TextButton(onPressed: onCerrar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
