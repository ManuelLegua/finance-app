import 'package:flutter/material.dart';

import '../../../core/dinero.dart';
import '../../../core/formato_soles.dart';
import '../../../core/mes.dart';
import '../../../dominio/modelos/enums.dart';
import '../../../dominio/modelos/obligacion.dart';
import '../../widgets/campo_monto.dart';

/// Alta y edición de una obligación (FR-002).
///
/// El selector de categorías usa `Categoria.presupuestables`, que **excluye
/// `tarjetaCredito`**: ese compromiso lo derivan las deudas en cuotas (D3), y
/// registrarlo a mano duplicaría el monto en el presupuesto del mes.
class FormularioObligacion extends StatefulWidget {
  const FormularioObligacion({required this.mes, this.original, super.key});

  final Mes mes;

  /// `null` para un alta; la obligación a editar en otro caso.
  final Obligacion? original;

  @override
  State<FormularioObligacion> createState() => _FormularioObligacionState();
}

class _FormularioObligacionState extends State<FormularioObligacion> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _monto;
  late Categoria _categoria;
  late TipoObligacion _tipo;

  bool get _esEdicion => widget.original != null;

  @override
  void initState() {
    super.initState();
    final original = widget.original;
    _nombre = TextEditingController(text: original?.nombre ?? '');
    _monto = TextEditingController(
      text: original == null ? '' : FormatoSoles.paraEditar(original.monto),
    );
    _categoria = original?.categoria ?? Categoria.servicios;
    _tipo = original?.tipo ?? TipoObligacion.fija;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _monto.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formulario.currentState!.validate()) return;

    final monto = CampoMonto.montoDe(_monto.text);
    if (monto == null) return;

    Navigator.of(context).pop(
      Obligacion(
        id: widget.original?.id,
        mes: widget.mes,
        nombre: _nombre.text.trim(),
        categoria: _categoria,
        monto: monto,
        tipo: _tipo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_esEdicion ? 'Editar obligación' : 'Nueva obligación'),
      content: SingleChildScrollView(
        child: Form(
          key: _formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombre,
                autofocus: !_esEdicion,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Alquiler, luz, internet…',
                ),
                validator: (texto) => (texto ?? '').trim().isEmpty
                    ? 'Ponele un nombre para reconocerla.'
                    : null,
              ),
              const SizedBox(height: 16),
              CampoMonto(controlador: _monto, onSubmitted: _guardar),
              const SizedBox(height: 16),
              DropdownButtonFormField<Categoria>(
                initialValue: _categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  for (final categoria in Categoria.presupuestables)
                    DropdownMenuItem(
                      value: categoria,
                      child: Text(categoria.etiqueta),
                    ),
                ],
                onChanged: (valor) => setState(() => _categoria = valor!),
              ),
              const SizedBox(height: 16),
              SegmentedButton<TipoObligacion>(
                segments: const [
                  ButtonSegment(
                    value: TipoObligacion.fija,
                    label: Text('Fija'),
                    icon: Icon(Icons.push_pin_outlined),
                  ),
                  ButtonSegment(
                    value: TipoObligacion.variable,
                    label: Text('Variable'),
                    icon: Icon(Icons.trending_up),
                  ),
                ],
                selected: {_tipo},
                onSelectionChanged: (seleccion) =>
                    setState(() => _tipo = seleccion.first),
              ),
              const SizedBox(height: 8),
              Text(
                _tipo == TipoObligacion.fija
                    ? 'Las fijas se proponen precargadas el mes que viene.'
                    : 'Las variables son estimaciones: no se precargan.',
                style: Theme.of(context).textTheme.bodySmall,
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
        FilledButton(
          onPressed: _guardar,
          child: Text(_esEdicion ? 'Guardar' : 'Agregar'),
        ),
      ],
    );
  }
}

/// Diálogo para registrar o corregir el ingreso del mes (FR-001).
class DialogoIngreso extends StatefulWidget {
  const DialogoIngreso({this.actual, super.key});

  final Dinero? actual;

  @override
  State<DialogoIngreso> createState() => _DialogoIngresoState();
}

class _DialogoIngresoState extends State<DialogoIngreso> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _monto;

  @override
  void initState() {
    super.initState();
    final actual = widget.actual;
    _monto = TextEditingController(
      text: actual == null ? '' : FormatoSoles.paraEditar(actual),
    );
  }

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formulario.currentState!.validate()) return;
    final monto = CampoMonto.montoDe(_monto.text);
    if (monto != null) Navigator.of(context).pop(monto);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ingreso del mes'),
      content: Form(
        key: _formulario,
        child: CampoMonto(
          controlador: _monto,
          etiqueta: 'Sueldo',
          autofocus: true,
          onSubmitted: _guardar,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
