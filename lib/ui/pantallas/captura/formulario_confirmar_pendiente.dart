import 'package:finanzas/dominio/modelos/consumo_pendiente.dart';
import 'package:finanzas/dominio/modelos/deuda.dart';
import 'package:finanzas/dominio/modelos/tarjeta.dart';
import 'package:finanzas/shared/componentes/campo_monto.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter/material.dart';

/// Lo que el usuario decidió al confirmar un pendiente: los campos, ya
/// corregidos o tal como venían (FR-024), y cómo registrarlo.
///
/// Es exactamente una de las dos cosas: [categoria] llena confirma como
/// transacción (US2/US3); [deuda] llena confirma como compra en cuotas
/// (US4, FR-035, FR-036) — nunca las dos, nunca ninguna.
final class DatosConfirmacion {
  const DatosConfirmacion({
    required this.monto,
    required this.comercio,
    required this.fecha,
    this.categoria,
    this.deuda,
  }) : assert(
         (categoria == null) != (deuda == null),
         'Un pendiente se confirma como transacción (con categoría) o como '
         'deuda en cuotas, no las dos cosas ni ninguna.',
       );

  final Dinero monto;
  final String comercio;
  final DateTime fecha;
  final Categoria? categoria;
  final Deuda? deuda;
}

/// Corregir y confirmar un consumo capturado (FR-023, FR-024, FR-033), o
/// marcarlo como una compra en cuotas (FR-035, FR-036).
///
/// Se abre siempre que el pendiente no trae categoría propuesta —no hay
/// forma de confirmar en un toque sin ella— y opcionalmente cuando el
/// usuario quiere corregir algo antes de confirmar uno que sí la trae.
class FormularioConfirmarPendiente extends StatefulWidget {
  const FormularioConfirmarPendiente({
    required this.pendiente,
    required this.tarjetasDeCredito,
    super.key,
  });

  final ConsumoPendiente pendiente;

  /// Para marcarlo en cuotas hace falta una tarjeta de crédito a la que
  /// cargarlo (FR-061): si está vacía, la opción ni se ofrece — no hay forma
  /// de completarla.
  final List<Tarjeta> tarjetasDeCredito;

  @override
  State<FormularioConfirmarPendiente> createState() =>
      _FormularioConfirmarPendienteState();
}

class _FormularioConfirmarPendienteState
    extends State<FormularioConfirmarPendiente> {
  /// Plazos habituales en el mercado peruano, igual que `FormularioDeuda` de
  /// 001. El usuario puede escribir otro.
  static const List<int> _plazosHabituales = <int>[3, 6, 9, 12, 18, 24, 36];

  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _monto;
  late final TextEditingController _comercio;
  late final TextEditingController _numCuotas;
  late DateTime _fecha;
  Categoria? _categoria;
  bool _enCuotas = false;
  int? _tarjetaId;

  @override
  void initState() {
    super.initState();
    final pendiente = widget.pendiente;
    _monto = TextEditingController(
      text: FormatoSoles.paraEditar(pendiente.monto),
    );
    _comercio = TextEditingController(text: pendiente.comercio);
    _numCuotas = TextEditingController(text: '12');
    _fecha = pendiente.fecha;
    _categoria = pendiente.categoriaPropuesta;
    _tarjetaId = widget.tarjetasDeCredito.isEmpty
        ? null
        : widget.tarjetasDeCredito.first.id;
  }

  @override
  void dispose() {
    _monto.dispose();
    _comercio.dispose();
    _numCuotas.dispose();
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

  String? _validarCuotas(String? texto) {
    if (!_enCuotas) return null;
    final cuotas = int.tryParse((texto ?? '').trim());
    if (cuotas == null) return 'Escribí en cuántas cuotas se paga.';
    if (cuotas < 1) return 'Tiene que ser al menos una cuota.';
    if (cuotas > 120) return 'El máximo son 120 cuotas (diez años).';
    return null;
  }

  void _confirmar() {
    if (!_formulario.currentState!.validate()) return;

    final monto = CampoMonto.montoDe(_monto.text);
    if (monto == null) return;
    final comercio = _comercio.text.trim();

    if (_enCuotas) {
      final tarjetaId = _tarjetaId;
      final numCuotas = int.tryParse(_numCuotas.text.trim());
      if (tarjetaId == null || numCuotas == null) return;

      Navigator.of(context).pop(
        DatosConfirmacion(
          monto: monto,
          comercio: comercio,
          fecha: _fecha,
          deuda: Deuda(
            id: null,
            descripcion: comercio,
            tarjetaId: tarjetaId,
            cuotaMensual: monto,
            numCuotas: numCuotas,
            mesInicio: Mes.deFecha(_fecha),
          ),
        ),
      );
      return;
    }

    final categoria = _categoria;
    if (categoria == null) return;

    Navigator.of(context).pop(
      DatosConfirmacion(
        monto: monto,
        comercio: comercio,
        fecha: _fecha,
        categoria: categoria,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cuotas = int.tryParse(_numCuotas.text.trim()) ?? 0;
    final monto = CampoMonto.montoDe(_monto.text);

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
              OutlinedButton.icon(
                onPressed: _elegirFecha,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(FormatoFecha.corta(_fecha)),
              ),
              if (widget.tarjetasDeCredito.isNotEmpty) ...[
                const SizedBox(height: Espaciado.chico),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fue una compra en cuotas'),
                  value: _enCuotas,
                  onChanged: (valor) => setState(() => _enCuotas = valor),
                ),
              ],
              const SizedBox(height: Espaciado.entreCampos),
              if (_enCuotas) ...[
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
                if (monto != null && cuotas >= 1) ...[
                  const SizedBox(height: Espaciado.entreCampos),
                  Text(
                    'Vas a pagar ${FormatoSoles.formatear(monto * cuotas)} en '
                    'total, última cuota en '
                    '${FormatoFecha.mesLargo(Mes.deFecha(_fecha).mas(cuotas - 1))}.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ] else
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
