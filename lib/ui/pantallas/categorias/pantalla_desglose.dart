import 'package:finanzas/dominio/modelos/linea_categoria.dart';
import 'package:finanzas/shared/componentes/marca_estado.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// En qué se va el dinero, categoría por categoría (HU6).
///
/// Una fila por categoría con presupuestado, gastado, diferencia y peso
/// sobre el ingreso, ordenadas de mayor a menor gasto (FR-044, FR-045). Las
/// categorías sobregiradas o sin presupuesto se señalan con ícono y texto,
/// nunca solo con color (FR-029).
class PantallaDesglose extends StatelessWidget {
  const PantallaDesglose({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoMes>();

    if (estado.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final lineas = estado.desglose;

    return RefreshIndicator(
      onRefresh: estado.cargar,
      child: lineas.isEmpty
          ? const _SinActividad()
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: Espaciado.chico),
              children: [
                for (final linea in lineas) _FilaDesglose(linea: linea),
              ],
            ),
    );
  }
}

class _SinActividad extends StatelessWidget {
  const _SinActividad();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(Espaciado.amplio),
          child: Column(
            children: [
              Icon(Icons.pie_chart_outline, size: 48, color: esquema.outline),
              const SizedBox(height: Espaciado.normal),
              Text(
                'Nada que desglosar todavía',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Espaciado.chico),
              Text(
                'Cuando registres un presupuesto o un gasto en el mes, '
                'aparece acá agrupado por categoría.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilaDesglose extends StatelessWidget {
  const _FilaDesglose({required this.linea});

  final LineaCategoria linea;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: Espaciado.normal,
        vertical: Espaciado.chico,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    linea.categoria.etiqueta,
                    style: tipografia.titleSmall,
                  ),
                ),
                Text(
                  '${_formatearPeso(linea.pesoIngresoBp)} del ingreso',
                  style: tipografia.bodySmall?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espaciado.interno),
            Row(
              children: [
                _Valor(etiqueta: 'Presupuestado', monto: linea.presupuestado),
                _Valor(etiqueta: 'Gastado', monto: linea.gastado),
                _Valor(etiqueta: 'Diferencia', monto: linea.diferencia),
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
              ),
          ],
        ),
      ),
    );
  }

  /// `12.50%` desde puntos base, sin pasar por `double` (D2).
  static String _formatearPeso(int puntosBase) {
    final enteros = puntosBase ~/ 100;
    final decimales = (puntosBase % 100).toString().padLeft(2, '0');
    return '$enteros.$decimales%';
  }
}

class _Valor extends StatelessWidget {
  const _Valor({required this.etiqueta, required this.monto});

  final String etiqueta;
  final Dinero monto;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: tipografia.bodySmall?.copyWith(
              color: esquema.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Espaciado.minimo),
          Text(FormatoSoles.formatear(monto), style: tipografia.monto),
        ],
      ),
    );
  }
}
