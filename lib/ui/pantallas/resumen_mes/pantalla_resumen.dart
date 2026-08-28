import 'package:finanzas/dominio/modelos/resumen_mes.dart';
import 'package:finanzas/shared/componentes/aviso_deficit.dart';
import 'package:finanzas/shared/componentes/aviso_mes_cerrado.dart';
import 'package:finanzas/shared/componentes/selector_mes.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Pantalla principal: responde "¿cuánto me queda este mes?" (HU2).
///
/// El disponible proyectado va en la jerarquía tipográfica mayor (D11): es la
/// pregunta que motiva la app, y tiene que leerse de un vistazo sin que el
/// usuario haga cuentas.
class PantallaResumen extends StatelessWidget {
  const PantallaResumen({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoMes>();

    if (estado.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final resumen = estado.resumen;

    return RefreshIndicator(
      onRefresh: estado.cargar,
      child: ListView(
        padding: const EdgeInsets.only(bottom: Espaciado.amplio),
        children: [
          SelectorMes(
            mes: estado.mes,
            estadoCierre: estado.estadoCierre,
            onAnterior: estado.irAlMesAnterior,
            onSiguiente: estado.irAlMesSiguiente,
          ),
          AvisoMesCerrado(estado: estado.estadoCierre),
          if (!resumen.ingresoRegistrado)
            const _FaltaRegistrarIngreso()
          else ...[
            AvisoDeficit(resumen: resumen),
            _Disponible(resumen: resumen),
          ],
          _DesgloseDeTotales(resumen: resumen),
        ],
      ),
    );
  }
}

/// Mes sin ingreso: se pide registrarlo en vez de mostrar totales en cero
/// como si fueran válidos (HU2 escenario 4).
class _FaltaRegistrarIngreso extends StatelessWidget {
  const _FaltaRegistrarIngreso();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Card(
      color: esquema.secondaryContainer,
      margin: const EdgeInsets.symmetric(
        horizontal: Espaciado.normal,
        vertical: Espaciado.chico,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: esquema.onSecondaryContainer),
            const SizedBox(width: Espaciado.interno),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Falta registrar tu ingreso',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(color: esquema.onSecondaryContainer),
                  ),
                  const SizedBox(height: Espaciado.minimo),
                  Text(
                    'Sin el sueldo del mes no se puede calcular cuánto te '
                    'queda. Registralo en Presupuesto.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: esquema.onSecondaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El dato que responde la pregunta de la pantalla.
class _Disponible extends StatelessWidget {
  const _Disponible({required this.resumen});

  final ResumenMes resumen;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final disponible = resumen.disponibleProyectado;

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
            Text(
              resumen.enDeficit ? 'Te falta' : 'Disponible este mes',
              style: tipografia.labelLarge,
            ),
            const SizedBox(height: Espaciado.minimo),
            Text(
              FormatoSoles.formatear(
                resumen.enDeficit ? resumen.faltante : disponible,
              ),
              style: tipografia.montoDestacado,
            ),
            const SizedBox(height: Espaciado.minimo),
            Text(
              resumen.enDeficit
                  ? 'Tus compromisos superan lo que ganás este mes.'
                  : 'Después de cubrir todos tus compromisos.',
              style: tipografia.bodySmall?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ingreso, comprometido y los dos disponibles, en columna alineada.
class _DesgloseDeTotales extends StatelessWidget {
  const _DesgloseDeTotales({required this.resumen});

  final ResumenMes resumen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: Espaciado.normal,
        vertical: Espaciado.chico,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Column(
          children: [
            _FilaDeTotal(
              etiqueta: 'Ingreso',
              monto: resumen.ingreso,
              ausente: 'sin registrar',
            ),
            const Divider(height: Espaciado.grande),
            _FilaDeTotal(
              etiqueta: 'Comprometido',
              monto: resumen.totalComprometido,
            ),
            _FilaDeTotal(
              etiqueta: 'Disponible proyectado',
              monto: resumen.ingresoRegistrado
                  ? resumen.disponibleProyectado
                  : null,
              ausente: '—',
            ),
            const Divider(height: Espaciado.grande),
            _FilaDeTotal(etiqueta: 'Gasto real', monto: resumen.gastoRealTotal),
            _FilaDeTotal(
              etiqueta: 'Disponible real',
              monto: resumen.ingresoRegistrado ? resumen.disponibleReal : null,
              ausente: '—',
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaDeTotal extends StatelessWidget {
  const _FilaDeTotal({
    required this.etiqueta,
    required this.monto,
    this.ausente = '—',
  });

  final String etiqueta;

  /// `null` cuando el dato todavía no existe; se muestra [ausente] en su
  /// lugar, nunca un `S/ 0.00` que se confundiría con un valor real.
  final Dinero? monto;

  final String ausente;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final valor = monto;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espaciado.minimo),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: tipografia.bodyMedium),
          Text(
            valor == null ? ausente : FormatoSoles.formatear(valor),
            style: tipografia.monto,
          ),
        ],
      ),
    );
  }
}
