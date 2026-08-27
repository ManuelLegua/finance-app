import 'package:finanzas/dominio/calculos/presupuesto.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de monto en soles, con validación y cifras tabulares.
///
/// La validación es la misma función pura que prueban las suites del dominio
/// (`validarMonto`), no una copia: si la regla cambia, cambia en un solo sitio.
class CampoMonto extends StatelessWidget {
  const CampoMonto({
    required this.controlador,
    this.etiqueta = 'Monto',
    this.autofocus = false,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  /// Valida el texto actual. `null` si es válido.
  static String? validar(String? texto) => validarMonto(texto ?? '').error;

  /// El monto escrito, o `null` si no es válido.
  static Dinero? montoDe(String texto) => validarMonto(texto).monto;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controlador,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => onSubmitted?.call(),
      style: Theme.of(context).textTheme.monto,
      decoration: InputDecoration(
        labelText: etiqueta,
        prefixText: 'S/ ',
        hintText: '0.00',
      ),
      validator: validar,
    );
  }
}
