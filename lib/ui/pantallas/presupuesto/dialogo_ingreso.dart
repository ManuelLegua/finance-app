import 'package:finanzas/shared/componentes/campo_monto.dart';
import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:flutter/material.dart';

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
