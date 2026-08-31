import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:finanzas/ui/estado/estado_pendientes.dart';
import 'package:finanzas/ui/estado/estado_tarjetas.dart';
import 'package:finanzas/ui/pantallas/captura/formulario_confirmar_pendiente.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Bandeja de consumos capturados, pendientes de confirmar (HU2, spec 002).
///
/// Ninguna acción de esta pantalla crea una transacción por sí sola: todas
/// pasan por `EstadoPendientes.confirmar()`, que es la única puerta hacia
/// 001 (FR-020).
class PantallaPendientes extends StatelessWidget {
  const PantallaPendientes({super.key});

  Future<void> _corregirYConfirmar(
    BuildContext context,
    EstadoPendientes estado,
    ConsumoPendiente pendiente,
  ) async {
    final tarjetasDeCredito = context.read<EstadoTarjetas>().deCredito;
    final datos = await showDialog<DatosConfirmacion>(
      context: context,
      builder: (_) => FormularioConfirmarPendiente(
        pendiente: pendiente,
        tarjetasDeCredito: tarjetasDeCredito,
      ),
    );
    if (datos == null) return;

    await estado.confirmar(
      pendiente,
      monto: datos.monto,
      comercio: datos.comercio,
      fecha: datos.fecha,
      categoria: datos.categoria,
      comoDeuda: datos.deuda,
    );
  }

  Future<void> _descartar(
    BuildContext context,
    EstadoPendientes estado,
    ConsumoPendiente pendiente,
  ) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Descartar este consumo?'),
        content: Text(
          'No se va a registrar como gasto. "${pendiente.comercio}" por '
          '${FormatoSoles.formatear(pendiente.monto)} desaparece de la '
          'bandeja.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmado ?? false) await estado.descartar(pendiente);
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoPendientes>();

    if (estado.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final pendientes = estado.pendientes;

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
            if (pendientes.isNotEmpty) _Resumen(estado: estado),
            if (pendientes.isEmpty)
              const _SinPendientes()
            else
              for (final pendiente in pendientes)
                _FilaPendiente(
                  pendiente: pendiente,
                  onConfirmarDirecto: pendiente.categoriaPropuesta == null
                      ? null
                      : () => estado.confirmar(pendiente),
                  onCorregir: () =>
                      _corregirYConfirmar(context, estado, pendiente),
                  onDescartar: () => _descartar(context, estado, pendiente),
                ),
          ],
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.estado});

  final EstadoPendientes estado;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final resumen = estado.resumen;

    return Card(
      margin: const EdgeInsets.all(Espaciado.normal),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resumen.cantidad == 1
                  ? '1 consumo por confirmar'
                  : '${resumen.cantidad} consumos por confirmar',
              style: tipografia.labelLarge,
            ),
            const SizedBox(height: Espaciado.minimo),
            Text(
              FormatoSoles.formatear(resumen.montoTotal),
              style: tipografia.montoDestacado,
            ),
            if (resumen.esCantidadInusual) ...[
              const SizedBox(height: Espaciado.chico),
              Row(
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 18,
                    color: esquema.error,
                  ),
                  const SizedBox(width: Espaciado.chico),
                  Expanded(
                    child: Text(
                      'Son bastantes sin revisar. Date una vuelta por acá '
                      'para que no se te acumulen.',
                      style: tipografia.bodySmall?.copyWith(
                        color: esquema.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SinPendientes extends StatelessWidget {
  const _SinPendientes();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Espaciado.amplio),
      child: Column(
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            size: 48,
            color: esquema.outline,
          ),
          const SizedBox(height: Espaciado.normal),
          Text(
            'Nada esperando confirmación',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Espaciado.chico),
          Text(
            'Cuando la app capture un consumo, va a aparecer acá para que lo '
            'confirmes o lo corrijas.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

enum _AccionSobrePendiente {
  confirmar('Confirmar'),
  editar('Corregir'),
  descartar('Descartar');

  const _AccionSobrePendiente(this.etiqueta);

  final String etiqueta;
}

class _FilaPendiente extends StatelessWidget {
  const _FilaPendiente({
    required this.pendiente,
    required this.onConfirmarDirecto,
    required this.onCorregir,
    required this.onDescartar,
  });

  final ConsumoPendiente pendiente;

  /// `null` cuando no hay categoría propuesta: confirmar exige abrir el
  /// formulario para elegirla (FR-033), no hay atajo de un toque.
  final VoidCallback? onConfirmarDirecto;
  final VoidCallback onCorregir;
  final VoidCallback onDescartar;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final categoria = pendiente.categoriaPropuesta;

    return ListTile(
      onTap: onCorregir,
      title: Text(pendiente.comercio),
      subtitle: Text(
        categoria == null
            ? '${FormatoFecha.corta(pendiente.fecha)} · sin categoría'
            : '${FormatoFecha.corta(pendiente.fecha)} · ${categoria.etiqueta}',
        style: categoria == null ? TextStyle(color: esquema.error) : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            FormatoSoles.formatear(pendiente.monto),
            style: tipografia.monto,
          ),
          PopupMenuButton<_AccionSobrePendiente>(
            onSelected: (accion) => switch (accion) {
              _AccionSobrePendiente.confirmar => onConfirmarDirecto?.call(),
              _AccionSobrePendiente.editar => onCorregir(),
              _AccionSobrePendiente.descartar => onDescartar(),
            },
            itemBuilder: (_) => [
              for (final accion in _AccionSobrePendiente.values)
                if (accion != _AccionSobrePendiente.confirmar ||
                    onConfirmarDirecto != null)
                  PopupMenuItem(value: accion, child: Text(accion.etiqueta)),
            ],
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
            TextButton(onPressed: onCerrar, child: const Text('Entendido')),
          ],
        ),
      ),
    );
  }
}
