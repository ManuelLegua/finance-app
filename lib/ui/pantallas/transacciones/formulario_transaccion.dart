import 'package:finanzas/dominio/modelos/transaccion.dart';
import 'package:finanzas/shared/componentes/campo_monto.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:flutter/material.dart';

/// Alta y edición de un gasto real (FR-007).
///
/// Está armado para **registrar en menos de quince segundos** (SC-002): el
/// monto arranca enfocado con teclado numérico, la fecha viene puesta en hoy
/// y la descripción es opcional. Lo único que el usuario tiene que decidir es
/// el monto y la categoría.
class FormularioTransaccion extends StatefulWidget {
  const FormularioTransaccion({
    required this.fechaPorDefecto,
    this.original,
    this.avisoDeCierre,
    super.key,
  });

  /// Normalmente hoy. La fecha decide a qué mes va el gasto (FR-008).
  final DateTime fechaPorDefecto;

  /// `null` para un alta; el gasto a editar en otro caso.
  final Transaccion? original;

  /// Advertencia a mostrar cuando la fecha elegida cae en un mes que ya cerró
  /// pero sigue dentro de la ventana de gracia (FR-055, FR-056).
  final String? Function(DateTime)? avisoDeCierre;

  @override
  State<FormularioTransaccion> createState() => _FormularioTransaccionState();
}

class _FormularioTransaccionState extends State<FormularioTransaccion> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _monto;
  late final TextEditingController _descripcion;
  late DateTime _fecha;
  late Categoria _categoria;

  bool get _esEdicion => widget.original != null;

  @override
  void initState() {
    super.initState();
    final original = widget.original;
    _monto = TextEditingController(
      text: original == null ? '' : FormatoSoles.paraEditar(original.monto),
    );
    _descripcion = TextEditingController(text: original?.descripcion ?? '');
    _fecha = original?.fecha ?? widget.fechaPorDefecto;
    _categoria = original?.categoria ?? Categoria.comida;
  }

  @override
  void dispose() {
    _monto.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      // Un año hacia atrás alcanza para cualquier gasto rezagado real, y
      // evita fechas absurdas por un error de tipeo.
      firstDate: DateTime(_fecha.year - 1),
      lastDate: widget.fechaPorDefecto,
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  void _guardar() {
    if (!_formulario.currentState!.validate()) return;

    final monto = CampoMonto.montoDe(_monto.text);
    if (monto == null) return;

    Navigator.of(context).pop(
      Transaccion(
        id: widget.original?.id,
        fecha: _fecha,
        categoria: _categoria,
        monto: monto,
        descripcion: _descripcion.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aviso = widget.avisoDeCierre?.call(_fecha);

    return AlertDialog(
      title: Text(_esEdicion ? 'Editar gasto' : 'Nuevo gasto'),
      content: SingleChildScrollView(
        child: Form(
          key: _formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoMonto(
                controlador: _monto,
                autofocus: !_esEdicion,
                onSubmitted: _guardar,
              ),
              const SizedBox(height: Espaciado.entreCampos),
              DropdownButtonFormField<Categoria>(
                initialValue: _categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  for (final categoria in Categoria.values)
                    DropdownMenuItem(
                      value: categoria,
                      child: Text(categoria.etiqueta),
                    ),
                ],
                onChanged: (valor) => setState(() => _categoria = valor!),
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
              const SizedBox(height: Espaciado.entreCampos),
              TextFormField(
                controller: _descripcion,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  hintText: 'Almuerzo, pasaje, recibo de luz…',
                ),
                onFieldSubmitted: (_) => _guardar(),
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
          child: Text(_esEdicion ? 'Guardar' : 'Registrar'),
        ),
      ],
    );
  }
}

/// Advierte que la fecha elegida cae en un mes ya cerrado.
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
