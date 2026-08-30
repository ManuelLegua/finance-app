import 'package:flutter/material.dart';

/// Una fila "etiqueta … monto" que nunca se corta.
///
/// `Row` sin `Expanded` desborda cuando el monto llega a los siete dígitos
/// que la app admite como máximo (FR-048): la etiqueta acá cede el espacio
/// que le sobra y, si aun así no alcanza, se envuelve en una segunda línea
/// antes que recortar el número.
class FilaMonto extends StatelessWidget {
  const FilaMonto({
    required this.etiqueta,
    required this.valor,
    required this.estiloValor,
    this.estiloEtiqueta,
    super.key,
  });

  final String etiqueta;
  final String valor;
  final TextStyle? estiloEtiqueta;
  final TextStyle? estiloValor;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(child: Text(etiqueta, style: estiloEtiqueta)),
      Text(valor, style: estiloValor),
    ],
  );
}
