import 'package:finanzas/dominio/modelos/linea_categoria.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:flutter/material.dart';

/// Una categoría con lo presupuestado, lo gastado y lo que queda (FR-010).
///
/// El sobregiro y el gasto no presupuestado se marcan con **ícono y texto**,
/// no solo con color (FR-029): quien no distingue el rojo tiene que poder
/// entender igual que se pasó del presupuesto.
class FichaCategoria extends StatelessWidget {
  const FichaCategoria({required this.linea, super.key});

  final LineaCategoria linea;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaciado.normal,
        vertical: Espaciado.chico,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  linea.categoria.etiqueta,
                  style: tipografia.bodyLarge,
                ),
              ),
              Text(
                FormatoSoles.formatear(linea.gastado),
                style: tipografia.monto,
              ),
              if (linea.presupuestado.esPositivo)
                Text(
                  ' de ${FormatoSoles.formatear(linea.presupuestado)}',
                  style: tipografia.montoSecundario?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (linea.sobregirada)
            _Marca(
              icono: Icons.trending_up,
              texto: 'Te pasaste por ${FormatoSoles.formatear(linea.exceso)}',
              color: esquema.error,
            )
          else if (linea.noPresupuestada)
            _Marca(
              icono: Icons.help_outline,
              texto: 'No estaba presupuestada',
              color: esquema.onSurfaceVariant,
            )
          else if (linea.presupuestado.esPositivo)
            _Marca(
              icono: Icons.check_circle_outline,
              texto: 'Quedan ${FormatoSoles.formatear(linea.diferencia)}',
              color: esquema.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca({required this.icono, required this.texto, required this.color});

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
        Text(
          texto,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    ),
  );
}
