import 'package:finanzas/shared/estilos/tema.dart';
import 'package:flutter/material.dart';

/// Ícono más texto para comunicar un estado (sobregiro, sin presupuesto,
/// mes cerrado...) sin depender solo del color (FR-029).
///
/// Se usa en cualquier fila o ficha que necesite esa marca: la constitución
/// prohíbe que un estado se distinga únicamente por el color, así que el
/// texto siempre acompaña al ícono.
class MarcaEstado extends StatelessWidget {
  const MarcaEstado({
    required this.icono,
    required this.texto,
    required this.color,
    super.key,
  });

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Espaciado.minimo),
    child: Row(
      children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(width: Espaciado.chico),
        Expanded(
          child: Text(
            texto,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}
