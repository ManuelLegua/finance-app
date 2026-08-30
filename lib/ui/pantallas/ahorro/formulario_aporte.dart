import 'package:finanzas/dominio/modelos/aporte_ahorro.dart';
import 'package:finanzas/shared/componentes/campo_monto.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:flutter/material.dart';

/// Alta y edición de un aporte de ahorro (FR-038).
class FormularioAporte extends StatefulWidget {
  const FormularioAporte({
    required this.fechaPorDefecto,
    this.original,
    this.avisoDeCierre,
    super.key,
  });

  /// Normalmente hoy. La fecha decide a qué mes va el aporte.
  final DateTime fechaPorDefecto;

  /// `null` para un alta; el aporte a editar en otro caso.
  final AporteAhorro? original;

  /// Advertencia cuando la fecha elegida cae en un mes cerrado pero sigue
  /// dentro de la ventana de gracia (FR-055, FR-056).
  final String? Function(DateTime)? avisoDeCierre;

  @override
  State<FormularioAporte> createState() => _FormularioAporteState();
}

class _FormularioAporteState extends State<FormularioAporte> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _monto;
  late DateTime _fecha;

  bool get _esEdicion => widget.original != null;

  @override
  void initState() {
    super.initState();
    final original = widget.original;
    _monto = TextEditingController(
      text: original == null ? '' : FormatoSoles.paraEditar(original.monto),
    );
    _fecha = original?.fecha ?? widget.fechaPorDefecto;
  }

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(_fecha.year - 1),
      lastDate: widget.fechaPorDefecto,
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  void _guardar() {
    if (!_formulario.currentState!.validate()) return;

    final monto = CampoMonto.montoDe(_monto.text);
    if (monto == null) return;

    Navigator.of(
      context,
    ).pop(AporteAhorro(id: widget.original?.id, fecha: _fecha, monto: monto));
  }

  @override
  Widget build(BuildContext context) {
    final aviso = widget.avisoDeCierre?.call(_fecha);

    return AlertDialog(
      title: Text(_esEdicion ? 'Editar aporte' : 'Nuevo aporte'),
      content: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CampoMonto(
              controlador: _monto,
              etiqueta: 'Monto ahorrado',
              autofocus: !_esEdicion,
              onSubmitted: _guardar,
            ),
            const SizedBox(height: Espaciado.entreCampos),
            OutlinedButton.icon(
              onPressed: _elegirFecha,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(FormatoFecha.corta(_fecha)),
            ),
            if (aviso != null) ...[
              const SizedBox(height: Espaciado.chico),
              _AvisoDeFecha(mensaje: aviso),
            ],
          ],
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

class _AvisoDeFecha extends StatelessWidget {
  const _AvisoDeFecha({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Espaciado.interno),
      decoration: BoxDecoration(
        color: esquema.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.history_toggle_off,
            size: 18,
            color: esquema.onTertiaryContainer,
          ),
          const SizedBox(width: Espaciado.chico),
          Expanded(
            child: Text(
              mensaje,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: esquema.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
