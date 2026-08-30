import 'package:finanzas/dominio/modelos/consumo_pendiente.dart';
import 'package:finanzas/shared/componentes/campo_monto.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:flutter/material.dart';

/// Lo que el usuario decidió al confirmar un pendiente (FR-024): los cuatro
/// campos, ya corregidos o tal como venían.
final class DatosConfirmacion {
  const DatosConfirmacion({
    required this.monto,
    required this.comercio,
    required this.fecha,
    required this.categoria,
  });

  final Dinero monto;
  final String comercio;
  final DateTime fecha;
  final Categoria categoria;
}

/// Corregir y confirmar un consumo capturado (FR-023, FR-024, FR-033).
///
/// Se abre siempre que el pendiente no trae categoría propuesta —no hay
/// forma de confirmar en un toque sin ella— y opcionalmente cuando el
/// usuario quiere corregir algo antes de confirmar uno que sí la trae.
class FormularioConfirmarPendiente extends StatefulWidget {
  const FormularioConfirmarPendiente({required this.pendiente, super.key});

  final ConsumoPendiente pendiente;

  @override
  State<FormularioConfirmarPendiente> createState() =>
      _FormularioConfirmarPendienteState();
}

class _FormularioConfirmarPendienteState
    extends State<FormularioConfirmarPendiente> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _monto;
  late final TextEditingController _comercio;
  late DateTime _fecha;
  Categoria? _categoria;

  @override
  void initState() {
    super.initState();
    final pendiente = widget.pendiente;
    _monto = TextEditingController(
      text: FormatoSoles.paraEditar(pendiente.monto),
    );
    _comercio = TextEditingController(text: pendiente.comercio);
    _fecha = pendiente.fecha;
    _categoria = pendiente.categoriaPropuesta;
  }

  @override
  void dispose() {
    _monto.dispose();
    _comercio.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(_fecha.year - 1),
      lastDate: hoy.isAfter(_fecha) ? hoy : _fecha,
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  void _confirmar() {
    if (!_formulario.currentState!.validate()) return;

    final monto = CampoMonto.montoDe(_monto.text);
    final categoria = _categoria;
    if (monto == null || categoria == null) return;

    Navigator.of(context).pop(
      DatosConfirmacion(
        monto: monto,
        comercio: _comercio.text.trim(),
        fecha: _fecha,
        categoria: categoria,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmar consumo'),
      content: SingleChildScrollView(
        child: Form(
          key: _formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoMonto(controlador: _monto),
              const SizedBox(height: Espaciado.entreCampos),
              TextFormField(
                controller: _comercio,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Comercio'),
                validator: (valor) => (valor == null || valor.trim().isEmpty)
                    ? 'Escribí a qué comercio corresponde.'
                    : null,
              ),
              const SizedBox(height: Espaciado.entreCampos),
              DropdownButtonFormField<Categoria>(
                initialValue: _categoria,
                decoration: InputDecoration(
                  labelText: 'Categoría',
                  hintText: _categoria == null ? 'Elegí una' : null,
                ),
                items: [
                  for (final categoria in Categoria.presupuestables)
                    DropdownMenuItem(
                      value: categoria,
                      child: Text(categoria.etiqueta),
                    ),
                ],
                validator: (valor) =>
                    valor == null ? 'Elegí una categoría.' : null,
                onChanged: (valor) => setState(() => _categoria = valor),
              ),
              const SizedBox(height: Espaciado.entreCampos),
              OutlinedButton.icon(
                onPressed: _elegirFecha,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(FormatoFecha.corta(_fecha)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirmar, child: const Text('Confirmar')),
      ],
    );
  }
}
