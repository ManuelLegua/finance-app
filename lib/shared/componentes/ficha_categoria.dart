import 'package:finanzas/dominio/modelos/linea_categoria.dart';
import 'package:finanzas/shared/componentes/marca_estado.dart';
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
              // `Flexible` + `Wrap`, no un `Row` a secas: con los siete
              // dígitos que la app admite como máximo, gastado y
              // presupuestado juntos pueden no entrar en una sola línea. Que
              // se envuelvan a la siguiente, nunca que se corten.
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
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
              ),
            ],
          ),
          if (linea.sobregirada)
            MarcaEstado(
              icono: Icons.trending_up,
              texto: 'Te pasaste por ${FormatoSoles.formatear(linea.exceso)}',
              color: esquema.error,
            )
          else if (linea.noPresupuestada)
            MarcaEstado(
              icono: Icons.help_outline,
              texto: 'No estaba presupuestada',
              color: esquema.onSurfaceVariant,
            )
          else if (linea.presupuestado.esPositivo)
            MarcaEstado(
              icono: Icons.check_circle_outline,
              texto: 'Quedan ${FormatoSoles.formatear(linea.diferencia)}',
              color: esquema.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}
