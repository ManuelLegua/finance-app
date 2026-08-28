import 'package:finanzas/dominio/modelos/estado_cierre.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter/material.dart';

/// Navega entre meses y deja claro si el que se está viendo admite cambios.
///
/// El estado de cierre se rotula con texto (FR-058): un mes cerrado que solo
/// se distinguiera por tener los botones grises se leería como una falla de
/// la app, no como una regla.
class SelectorMes extends StatelessWidget {
  const SelectorMes({
    required this.mes,
    required this.estadoCierre,
    required this.onAnterior,
    required this.onSiguiente,
    super.key,
  });

  final Mes mes;
  final EstadoCierre estadoCierre;
  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaciado.chico,
        vertical: Espaciado.chico,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onAnterior,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Mes anterior',
          ),
          Column(
            children: [
              Text(FormatoFecha.mesTitulo(mes), style: tipografia.titleMedium),
              if (estadoCierre.situacion != SituacionMes.abierto)
                Text(
                  estadoCierre.situacion == SituacionMes.enGracia
                      ? 'Solo se pueden registrar pagos rezagados'
                      : 'Mes cerrado · solo lectura',
                  style: tipografia.labelSmall?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: onSiguiente,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Mes siguiente',
          ),
        ],
      ),
    );
  }
}
