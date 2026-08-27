import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/dinero.dart';
import '../../../core/formato_fecha.dart';
import '../../../core/formato_soles.dart';
import '../../../dominio/modelos/enums.dart';
import '../../../dominio/modelos/obligacion.dart';
import '../../estado/estado_mes.dart';
import '../../tema.dart';
import '../../widgets/aviso_mes_cerrado.dart';
import 'formulario_obligacion.dart';

/// Ingreso del mes y presupuesto de obligaciones (HU1).
class PantallaPresupuesto extends StatefulWidget {
  const PantallaPresupuesto({super.key});

  @override
  State<PantallaPresupuesto> createState() => _PantallaPresupuestoState();
}

class _PantallaPresupuestoState extends State<PantallaPresupuesto> {
  bool _precargaOfrecida = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ofrecerPrecarga());
  }

  /// Propone las fijas del mes anterior si el mes está vacío (FR-006).
  ///
  /// Nunca guarda sola: el usuario confirma o descarta.
  Future<void> _ofrecerPrecarga() async {
    if (_precargaOfrecida || !mounted) return;
    _precargaOfrecida = true;

    final estado = context.read<EstadoMes>();
    final propuestas = await estado.propuestaDePrecarga();
    if (propuestas.isEmpty || !mounted) return;

    final confirmadas = await showDialog<List<Obligacion>>(
      context: context,
      builder: (_) => _DialogoPrecarga(propuestas: propuestas),
    );
    if (confirmadas != null && confirmadas.isNotEmpty && mounted) {
      await estado.confirmarPrecarga(confirmadas);
    }
  }

  Future<void> _editarIngreso(EstadoMes estado) async {
    final monto = await showDialog<Dinero>(
      context: context,
      builder: (_) => DialogoIngreso(actual: estado.ingreso),
    );
    if (monto != null) await estado.guardarIngreso(monto);
  }

  Future<void> _abrirFormulario(EstadoMes estado, [Obligacion? original]) async {
    final resultado = await showDialog<Obligacion>(
      context: context,
      builder: (_) => FormularioObligacion(
        mes: estado.mes,
        original: original,
      ),
    );
    if (resultado == null) return;

    if (resultado.estaGuardada) {
      await estado.actualizarObligacion(resultado);
    } else {
      await estado.agregarObligacion(resultado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoMes>();

    if (estado.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: estado.cargar,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (estado.error != null) _BannerError(mensaje: estado.error!),
            AvisoMesCerrado(estado: estado.estadoCierre),
            _TarjetaIngreso(
              estado: estado,
              onEditar: () => _editarIngreso(estado),
            ),
            _EncabezadoObligaciones(total: estado.obligaciones.length),
            if (estado.obligaciones.isEmpty)
              const _SinObligaciones()
            else
              for (final obligacion in estado.obligaciones)
                _FilaObligacion(
                  obligacion: obligacion,
                  puedeEditar: estado.admiteEditar,
                  onEditar: () => _abrirFormulario(estado, obligacion),
                  onEliminar: () =>
                      estado.eliminarObligacion(obligacion.id!),
                ),
          ],
        ),
      ),
      floatingActionButton: estado.admiteRegistrar
          ? FloatingActionButton.extended(
              onPressed: () => _abrirFormulario(estado),
              icon: const Icon(Icons.add),
              label: const Text('Obligación'),
            )
          : null,
    );
  }
}

class _TarjetaIngreso extends StatelessWidget {
  const _TarjetaIngreso({required this.estado, required this.onEditar});

  final EstadoMes estado;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final ingreso = estado.ingreso;
    final tipografia = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingreso de ${FormatoFecha.mesLargo(estado.mes)}',
              style: tipografia.labelLarge,
            ),
            const SizedBox(height: 8),
            if (ingreso == null)
              Text(
                'Todavía no registraste tu sueldo de este mes.',
                style: tipografia.bodyMedium,
              )
            else
              Text(
                FormatoSoles.formatear(ingreso),
                style: tipografia.montoDestacado,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (estado.admiteRegistrar)
                  FilledButton.tonalIcon(
                    onPressed: onEditar,
                    icon: Icon(ingreso == null ? Icons.add : Icons.edit),
                    label: Text(ingreso == null ? 'Registrar' : 'Corregir'),
                  ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Comprometido', style: tipografia.labelSmall),
                    Text(
                      FormatoSoles.formatear(estado.totalComprometido),
                      style: tipografia.monto,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EncabezadoObligaciones extends StatelessWidget {
  const _EncabezadoObligaciones({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          total == 0 ? 'Obligaciones' : 'Obligaciones ($total)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
}

class _FilaObligacion extends StatelessWidget {
  const _FilaObligacion({
    required this.obligacion,
    required this.puedeEditar,
    required this.onEditar,
    required this.onEliminar,
  });

  final Obligacion obligacion;
  final bool puedeEditar;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final esFija = obligacion.tipo == TipoObligacion.fija;

    return ListTile(
      leading: Icon(
        esFija ? Icons.push_pin_outlined : Icons.trending_up,
        // El tipo se distingue por ícono y por texto, no solo por color.
        semanticLabel: obligacion.tipo.etiqueta,
      ),
      title: Text(obligacion.nombre),
      subtitle: Text(
        '${obligacion.categoria.etiqueta} · ${obligacion.tipo.etiqueta}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            FormatoSoles.formatear(obligacion.monto),
            style: Theme.of(context).textTheme.monto,
          ),
          if (puedeEditar)
            PopupMenuButton<String>(
              onSelected: (opcion) =>
                  opcion == 'editar' ? onEditar() : onEliminar(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
              ],
            ),
        ],
      ),
      onTap: puedeEditar ? onEditar : null,
    );
  }
}

class _SinObligaciones extends StatelessWidget {
  const _SinObligaciones();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Text(
          'Todavía no cargaste obligaciones. Agregá el alquiler, los '
          'servicios y lo que estimás gastar en el mes.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: esquema.onErrorContainer),
            const SizedBox(width: 12),
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

/// Ofrece precargar las obligaciones fijas del mes anterior (FR-006).
///
/// El usuario puede destildar las que no correspondan: la app propone, no
/// decide.
class _DialogoPrecarga extends StatefulWidget {
  const _DialogoPrecarga({required this.propuestas});

  final List<Obligacion> propuestas;

  @override
  State<_DialogoPrecarga> createState() => _DialogoPrecargaState();
}

class _DialogoPrecargaState extends State<_DialogoPrecarga> {
  late final Set<int> _elegidas =
      {for (var i = 0; i < widget.propuestas.length; i++) i};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Precargar obligaciones fijas'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estas son las fijas del mes anterior. Confirmá las que sigan '
              'vigentes; podés ajustar los montos después.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < widget.propuestas.length; i++)
              CheckboxListTile(
                value: _elegidas.contains(i),
                onChanged: (marcada) => setState(() {
                  if (marcada ?? false) {
                    _elegidas.add(i);
                  } else {
                    _elegidas.remove(i);
                  }
                }),
                title: Text(widget.propuestas[i].nombre),
                subtitle: Text(
                  FormatoSoles.formatear(widget.propuestas[i].monto),
                ),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            [
              for (var i = 0; i < widget.propuestas.length; i++)
                if (_elegidas.contains(i)) widget.propuestas[i],
            ],
          ),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
