import 'package:finanzas/dominio/calculos/deudas.dart';
import 'package:finanzas/dominio/modelos/deuda.dart';
import 'package:finanzas/dominio/modelos/tarjeta.dart';
import 'package:finanzas/shared/componentes/fila_monto.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/estado/estado_tarjetas.dart';
import 'package:finanzas/ui/pantallas/deudas/formulario_deuda.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Deudas de tarjeta en cuotas (HU4).
///
/// Responde de un vistazo cuánto se debe, cuánto se paga este mes y en qué
/// mes se queda libre de deudas (FR-022, SC-006).
class PantallaDeudas extends StatelessWidget {
  const PantallaDeudas({super.key});

  Future<void> _abrirFormulario(
    BuildContext context,
    EstadoMes estado,
    List<Tarjeta> tarjetas, [
    Deuda? original,
  ]) async {
    if (tarjetas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registrá primero una tarjeta de crédito, desde el menú lateral.',
          ),
        ),
      );
      return;
    }

    final resultado = await showDialog<Deuda>(
      context: context,
      builder: (_) => FormularioDeuda(
        tarjetasDeCredito: tarjetas,
        mesActual: estado.mes,
        original: original,
      ),
    );
    if (resultado == null) return;

    if (resultado.estaGuardada) {
      await estado.actualizarDeuda(resultado);
    } else {
      await estado.agregarDeuda(resultado);
    }
  }

  Future<void> _saldar(
    BuildContext context,
    EstadoMes estado,
    Deuda deuda,
  ) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Saldar esta deuda?'),
        content: Text(
          'Desde ${FormatoFecha.mesLargo(estado.mes)} deja de sumar cuotas al '
          'presupuesto y su saldo pasa a S/ 0.00. Los gastos ya registrados no '
          'se tocan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Saldar'),
          ),
        ],
      ),
    );

    if (confirmado ?? false) {
      await estado.saldarDeuda(deuda.id!, estado.mes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoMes>();
    final tarjetas = context.watch<EstadoTarjetas>();

    if (estado.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final panorama = estado.panorama;
    final activas = estado.deudas
        .where(
          (deuda) =>
              !calcularEstadoDeuda(deuda, mesRef: estado.mes).estaSaldada,
        )
        .toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: estado.cargar,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Espaciado.bajoBotonFlotante),
          children: [
            if (estado.error != null) _BannerError(mensaje: estado.error!),
            if (panorama.sinDeudas)
              const _LibreDeDeudas()
            else ...[
              _Panorama(panorama: panorama),
              for (final deuda in activas)
                _FilaDeuda(
                  deuda: deuda,
                  estadoDeuda: calcularEstadoDeuda(deuda, mesRef: estado.mes),
                  tarjeta: _tarjetaDe(tarjetas.tarjetas, deuda.tarjetaId),
                  onEditar: () => _abrirFormulario(
                    context,
                    estado,
                    tarjetas.deCredito,
                    deuda,
                  ),
                  onSaldar: () => _saldar(context, estado, deuda),
                ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, estado, tarjetas.deCredito),
        icon: const Icon(Icons.add),
        label: const Text('Deuda'),
      ),
    );
  }

  static Tarjeta? _tarjetaDe(List<Tarjeta> tarjetas, int id) {
    for (final tarjeta in tarjetas) {
      if (tarjeta.id == id) return tarjeta;
    }
    return null;
  }
}

/// El estado que se comunica cuando no hay nada que deber.
///
/// Una lista vacía no dice nada; esto sí (edge case "sin deudas activas").
class _LibreDeDeudas extends StatelessWidget {
  const _LibreDeDeudas();

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
            'No debés nada en cuotas',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Espaciado.chico),
          Text(
            'Cuando compres algo en cuotas, registralo una sola vez: la app '
            'suma la cuota a cada mes que corresponda, sin que tengas que '
            'volver a anotarla.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Panorama extends StatelessWidget {
  const _Panorama({required this.panorama});

  final PanoramaDeuda panorama;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final mesLibre = panorama.mesLibreDeDeudas;

    return Card(
      margin: const EdgeInsets.all(Espaciado.normal),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Debés en total', style: tipografia.labelLarge),
            const SizedBox(height: Espaciado.minimo),
            Text(
              FormatoSoles.formatear(panorama.totalAdeudado),
              style: tipografia.montoDestacado,
            ),
            const Divider(height: Espaciado.grande),
            FilaMonto(
              etiqueta: 'Cuotas de este mes',
              valor: FormatoSoles.formatear(panorama.compromisoMensual),
              estiloEtiqueta: tipografia.bodyMedium,
              estiloValor: tipografia.monto,
            ),
            if (mesLibre != null) ...[
              const SizedBox(height: Espaciado.chico),
              Row(
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: 18,
                    color: esquema.onSurfaceVariant,
                  ),
                  const SizedBox(width: Espaciado.chico),
                  Expanded(
                    child: Text(
                      'Quedás libre de deudas en '
                      '${FormatoFecha.mesLargo(mesLibre)}',
                      style: tipografia.bodySmall?.copyWith(
                        color: esquema.onSurfaceVariant,
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

class _FilaDeuda extends StatelessWidget {
  const _FilaDeuda({
    required this.deuda,
    required this.estadoDeuda,
    required this.tarjeta,
    required this.onEditar,
    required this.onSaldar,
  });

  final Deuda deuda;
  final EstadoDeuda estadoDeuda;
  final Tarjeta? tarjeta;
  final VoidCallback onEditar;
  final VoidCallback onSaldar;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final esFutura = estadoDeuda.situacion == SituacionDeuda.futura;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(deuda.descripcion, style: tipografia.titleSmall),
                      Text(
                        tarjeta == null
                            ? 'Tarjeta eliminada'
                            : '${tarjeta!.nombre} · ${tarjeta!.entidad}',
                        style: tipografia.bodySmall?.copyWith(
                          color: esquema.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<AccionSobreDeuda>(
                  onSelected: (accion) => switch (accion) {
                    AccionSobreDeuda.editar => onEditar(),
                    AccionSobreDeuda.saldar => onSaldar(),
                  },
                  itemBuilder: (_) => [
                    for (final accion in AccionSobreDeuda.values)
                      PopupMenuItem(
                        value: accion,
                        child: Text(accion.etiqueta),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Espaciado.chico),
            FilaMonto(
              etiqueta: 'Saldo pendiente',
              valor: FormatoSoles.formatear(estadoDeuda.saldoPendiente),
              estiloEtiqueta: tipografia.bodyMedium,
              estiloValor: tipografia.monto,
            ),
            const SizedBox(height: Espaciado.minimo),
            Text(
              esFutura
                  ? 'Empieza en ${FormatoFecha.mesLargo(deuda.mesInicio)}: '
                        '${estadoDeuda.cuotasRestantes} cuotas de '
                        '${FormatoSoles.formatear(deuda.cuotaMensual)}'
                  : '${estadoDeuda.cuotasPagadas} de ${deuda.numCuotas} '
                        'pagadas · quedan ${estadoDeuda.cuotasRestantes} de '
                        '${FormatoSoles.formatear(deuda.cuotaMensual)}',
              style: tipografia.bodySmall?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Espaciado.minimo),
            Text(
              'Última cuota en '
              '${FormatoFecha.mesLargo(estadoDeuda.mesUltimaCuota)}',
              style: tipografia.bodySmall?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Qué se puede hacer con una deuda registrada.
enum AccionSobreDeuda {
  editar('Editar'),
  saldar('Saldar anticipadamente');

  const AccionSobreDeuda(this.etiqueta);

  final String etiqueta;
}

class _BannerError extends StatelessWidget {
  const _BannerError({required this.mensaje});

  final String mensaje;

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
            TextButton(
              onPressed: context.read<EstadoMes>().limpiarError,
              child: const Text('Entendido'),
            ),
          ],
        ),
      ),
    );
  }
}
