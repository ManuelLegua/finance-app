import 'package:finanzas/dominio/modelos/transaccion.dart';
import 'package:finanzas/shared/componentes/aviso_mes_cerrado.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/pantallas/transacciones/formulario_transaccion.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Lo que el usuario efectivamente gastó (HU3).
///
/// Es la pantalla de uso diario: SC-002 pide que anotar un gasto lleve menos
/// de quince segundos, así que el botón de registrar está siempre a la vista
/// y el formulario abre con el monto enfocado.
class PantallaTransacciones extends StatelessWidget {
  const PantallaTransacciones({super.key});

  Future<void> _abrirFormulario(
    BuildContext context,
    EstadoMes estado, [
    Transaccion? original,
  ]) async {
    final resultado = await showDialog<Transaccion>(
      context: context,
      builder: (_) => FormularioTransaccion(
        fechaPorDefecto: DateTime.now(),
        original: original,
        avisoDeCierre: (fecha) => estado.admiteRegistrarEn(fecha)
            ? estado.motivoDeCierreEn(fecha)
            : 'Ese mes ya está cerrado y no admite registrar gastos.',
      ),
    );
    if (resultado == null) return;

    if (resultado.estaGuardada) {
      await estado.actualizarTransaccion(resultado);
    } else {
      await estado.agregarTransaccion(resultado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoMes>();

    if (estado.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final transacciones = estado.transacciones;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: estado.cargar,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Espaciado.bajoBotonFlotante),
          children: [
            if (estado.error != null) _BannerError(mensaje: estado.error!),
            AvisoMesCerrado(estado: estado.estadoCierre),
            _TotalDelMes(estado: estado),
            if (transacciones.isEmpty)
              const _SinGastos()
            else
              for (final transaccion in transacciones)
                _FilaGasto(
                  transaccion: transaccion,
                  puedeEditar: estado.puedeEditarTransaccion(transaccion),
                  onAccion: (accion) => switch (accion) {
                    AccionSobreGasto.editar => _abrirFormulario(
                      context,
                      estado,
                      transaccion,
                    ),
                    AccionSobreGasto.eliminar => estado.eliminarTransaccion(
                      transaccion.id!,
                    ),
                  },
                ),
          ],
        ),
      ),
      // Siempre disponible: aunque el mes abierto esté cerrado, el gasto puede
      // ir a otra fecha, y es el propio dominio el que decide si entra.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, estado),
        icon: const Icon(Icons.add),
        label: const Text('Gasto'),
      ),
    );
  }
}

/// Qué se puede hacer con un gasto ya registrado.
enum AccionSobreGasto {
  editar('Editar'),
  eliminar('Eliminar');

  const AccionSobreGasto(this.etiqueta);

  final String etiqueta;
}

class _TotalDelMes extends StatelessWidget {
  const _TotalDelMes({required this.estado});

  final EstadoMes estado;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final resumen = estado.resumen;

    return Card(
      margin: const EdgeInsets.all(Espaciado.normal),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gastado en ${FormatoFecha.mesLargo(estado.mes)}',
              style: tipografia.labelLarge,
            ),
            const SizedBox(height: Espaciado.minimo),
            Text(
              FormatoSoles.formatear(resumen.gastoRealTotal),
              style: tipografia.montoDestacado,
            ),
            if (resumen.ingresoRegistrado) ...[
              const SizedBox(height: Espaciado.minimo),
              Text(
                'Te quedan ${FormatoSoles.formatear(resumen.disponibleReal)} '
                'de lo que entró este mes.',
                style: tipografia.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilaGasto extends StatelessWidget {
  const _FilaGasto({
    required this.transaccion,
    required this.puedeEditar,
    required this.onAccion,
  });

  final Transaccion transaccion;
  final bool puedeEditar;
  final void Function(AccionSobreGasto) onAccion;

  @override
  Widget build(BuildContext context) {
    final tieneDescripcion = transaccion.descripcion.isNotEmpty;

    return ListTile(
      title: Text(
        tieneDescripcion
            ? transaccion.descripcion
            : transaccion.categoria.etiqueta,
      ),
      subtitle: Text(
        tieneDescripcion
            ? '${transaccion.categoria.etiqueta} · '
                  '${FormatoFecha.corta(transaccion.fecha)}'
            : FormatoFecha.corta(transaccion.fecha),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            FormatoSoles.formatear(transaccion.monto),
            style: Theme.of(context).textTheme.monto,
          ),
          if (puedeEditar)
            PopupMenuButton<AccionSobreGasto>(
              onSelected: onAccion,
              itemBuilder: (_) => [
                for (final accion in AccionSobreGasto.values)
                  PopupMenuItem(value: accion, child: Text(accion.etiqueta)),
              ],
            )
          else
            // Registrado en la ventana de gracia: quedó inmutable (FR-056).
            // Se dice con ícono y tooltip, no dejando un hueco.
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Espaciado.interno),
              child: Tooltip(
                message: 'Registrado en un mes cerrado: no se puede editar',
                child: Icon(Icons.lock_outline, size: 18),
              ),
            ),
        ],
      ),
      onTap: puedeEditar ? () => onAccion(AccionSobreGasto.editar) : null,
    );
  }
}

class _SinGastos extends StatelessWidget {
  const _SinGastos();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: Espaciado.amplio,
      vertical: Espaciado.grande,
    ),
    child: Text(
      'Todavía no anotaste gastos este mes. Registrá el almuerzo, el pasaje '
      'o el recibo apenas los pagues: es lo que hace que los números digan '
      'la verdad.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
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
