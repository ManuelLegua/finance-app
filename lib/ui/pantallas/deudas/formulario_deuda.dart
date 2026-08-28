import 'package:finanzas/dominio/modelos/deuda.dart';
import 'package:finanzas/dominio/modelos/tarjeta.dart';
import 'package:finanzas/shared/componentes/campo_monto.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter/material.dart';

/// Alta y edición de una deuda en cuotas (FR-015).
///
/// El selector de tarjeta ofrece **solo las de crédito** (FR-061): una de
/// débito no financia en cuotas.
///
/// La cuota se registra tal como la informa el banco. La app no calcula
/// intereses ni amortización (FR-024): replicar el cálculo del banco daría
/// discrepancias de centavos contra el estado de cuenta real.
class FormularioDeuda extends StatefulWidget {
  const FormularioDeuda({
    required this.tarjetasDeCredito,
    required this.mesActual,
    this.original,
    super.key,
  });

  final List<Tarjeta> tarjetasDeCredito;
  final Mes mesActual;
  final Deuda? original;

  @override
  State<FormularioDeuda> createState() => _FormularioDeudaState();
}

class _FormularioDeudaState extends State<FormularioDeuda> {
  /// Plazos habituales en el mercado peruano. El usuario puede escribir otro.
  static const List<int> _plazosHabituales = <int>[3, 6, 9, 12, 18, 24, 36];

  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _descripcion;
  late final TextEditingController _cuota;
  late final TextEditingController _numCuotas;
  late Mes _mesInicio;
  int? _tarjetaId;

  bool get _esEdicion => widget.original != null;

  @override
  void initState() {
    super.initState();
    final original = widget.original;
    _descripcion = TextEditingController(text: original?.descripcion ?? '');
    _cuota = TextEditingController(
      text: original == null
          ? ''
          : FormatoSoles.paraEditar(original.cuotaMensual),
    );
    _numCuotas = TextEditingController(
      text: (original?.numCuotas ?? 12).toString(),
    );
    _mesInicio = original?.mesInicio ?? widget.mesActual;
    _tarjetaId =
        original?.tarjetaId ??
        (widget.tarjetasDeCredito.isEmpty
            ? null
            : widget.tarjetasDeCredito.first.id);
  }

  @override
  void dispose() {
    _descripcion.dispose();
    _cuota.dispose();
    _numCuotas.dispose();
    super.dispose();
  }

  String? _validarCuotas(String? texto) {
    final cuotas = int.tryParse((texto ?? '').trim());
    if (cuotas == null) return 'Escribí en cuántas cuotas se paga.';
    if (cuotas < 1) return 'Tiene que ser al menos una cuota.';
    if (cuotas > 120) return 'El máximo son 120 cuotas (diez años).';
    return null;
  }

  void _guardar() {
    if (!_formulario.currentState!.validate()) return;

    final cuota = CampoMonto.montoDe(_cuota.text);
    final tarjetaId = _tarjetaId;
    if (cuota == null || tarjetaId == null) return;

    Navigator.of(context).pop(
      Deuda(
        id: widget.original?.id,
        descripcion: _descripcion.text.trim(),
        tarjetaId: tarjetaId,
        cuotaMensual: cuota,
        numCuotas: int.parse(_numCuotas.text.trim()),
        mesInicio: _mesInicio,
        mesSaldadaAnticipada: widget.original?.mesSaldadaAnticipada,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cuotas = int.tryParse(_numCuotas.text.trim()) ?? 0;
    final cuota = CampoMonto.montoDe(_cuota.text);

    return AlertDialog(
      title: Text(_esEdicion ? 'Editar deuda' : 'Nueva deuda'),
      content: SingleChildScrollView(
        child: Form(
          key: _formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _descripcion,
                autofocus: !_esEdicion,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Qué compraste',
                  hintText: 'Celular, refrigeradora…',
                ),
                validator: (texto) => (texto ?? '').trim().isEmpty
                    ? 'Ponele un nombre para reconocerla.'
                    : null,
              ),
              const SizedBox(height: Espaciado.entreCampos),
              DropdownButtonFormField<int>(
                initialValue: _tarjetaId,
                decoration: const InputDecoration(labelText: 'Tarjeta'),
                items: [
                  for (final tarjeta in widget.tarjetasDeCredito)
                    DropdownMenuItem(
                      value: tarjeta.id,
                      child: Text('${tarjeta.nombre} · ${tarjeta.entidad}'),
                    ),
                ],
                onChanged: (valor) => setState(() => _tarjetaId = valor),
                validator: (valor) =>
                    valor == null ? 'Elegí una tarjeta de crédito.' : null,
              ),
              const SizedBox(height: Espaciado.entreCampos),
              CampoMonto(
                controlador: _cuota,
                etiqueta: 'Cuota mensual',
                onSubmitted: _guardar,
              ),
              const SizedBox(height: Espaciado.minimo),
              Text(
                'El monto que te cobra el banco cada mes. La app no calcula '
                'intereses: usa la cuota tal como viene en tu estado de '
                'cuenta.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Espaciado.entreCampos),
              TextFormField(
                controller: _numCuotas,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Número de cuotas',
                ),
                validator: _validarCuotas,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Espaciado.chico),
              Wrap(
                spacing: Espaciado.chico,
                children: [
                  for (final plazo in _plazosHabituales)
                    ActionChip(
                      label: Text('$plazo'),
                      onPressed: () =>
                          setState(() => _numCuotas.text = plazo.toString()),
                    ),
                ],
              ),
              const SizedBox(height: Espaciado.entreCampos),
              _SelectorMesInicio(
                mes: _mesInicio,
                onCambiar: (mes) => setState(() => _mesInicio = mes),
              ),
              if (cuota != null && cuotas >= 1) ...[
                const SizedBox(height: Espaciado.entreCampos),
                _Resumen(
                  total: cuota * cuotas,
                  mesUltimaCuota: _mesInicio.mas(cuotas - 1),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardar,
          child: Text(_esEdicion ? 'Guardar' : 'Registrar'),
        ),
      ],
    );
  }
}

/// Elige el mes en que arranca la deuda. Puede ser futuro (FR-020).
class _SelectorMesInicio extends StatelessWidget {
  const _SelectorMesInicio({required this.mes, required this.onCambiar});

  final Mes mes;
  final void Function(Mes) onCambiar;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: const InputDecoration(labelText: 'Primera cuota'),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => onCambiar(mes.anterior),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Mes anterior',
        ),
        Text(
          FormatoFecha.mesTitulo(mes),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        IconButton(
          onPressed: () => onCambiar(mes.siguiente),
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Mes siguiente',
        ),
      ],
    ),
  );
}

/// Lo que el usuario va a terminar pagando, calculado en vivo.
class _Resumen extends StatelessWidget {
  const _Resumen({required this.total, required this.mesUltimaCuota});

  final Dinero total;
  final Mes mesUltimaCuota;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Espaciado.interno),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vas a pagar ${FormatoSoles.formatear(total)} en total',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Espaciado.minimo),
          Text(
            'Última cuota en ${FormatoFecha.mesLargo(mesUltimaCuota)}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
