import 'package:finanzas/dominio/modelos/deuda.dart';
import 'package:finanzas/dominio/modelos/linea_categoria.dart';
import 'package:finanzas/dominio/modelos/resumen_mes.dart';
import 'package:finanzas/shared/componentes/aviso_deficit.dart';
import 'package:finanzas/shared/componentes/aviso_mes_cerrado.dart';
import 'package:finanzas/shared/componentes/ficha_categoria.dart';
import 'package:finanzas/shared/componentes/selector_mes.dart';
import 'package:finanzas/shared/constantes/enums.dart';
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
          if (estado.desglose.isNotEmpty) ...[
            const _TituloCategorias(),
            for (final linea in estado.desglose)
              if (linea.categoria == Categoria.tarjetaCredito &&
                  estado.deudasDelMes.isNotEmpty)
                _TarjetaDesplegable(
                  linea: linea,
                  deudas: estado.deudasDelMes,
                )
              else
                FichaCategoria(linea: linea),
          ],
        ],
      ),
    );
  }
}

/// El compromiso de tarjeta de crédito, desglosado en las deudas que lo
/// componen (FR-017).
///
/// Ese monto no se escribe a mano: lo derivan las cuotas vigentes (D3). Poder
/// abrirlo es lo que evita que el usuario lo vea como un número mágico.
class _TarjetaDesplegable extends StatelessWidget {
  const _TarjetaDesplegable({required this.linea, required this.deudas});

  final LineaCategoria linea;
  final List<Deuda> deudas;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: Espaciado.normal),
      title: Text(linea.categoria.etiqueta, style: tipografia.bodyLarge),
      subtitle: Text(
        deudas.length == 1
            ? 'Una deuda en cuotas'
            : '${deudas.length} deudas en cuotas',
        style: tipografia.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
      ),
      trailing: Text(
        FormatoSoles.formatear(linea.presupuestado),
        style: tipografia.monto,
      ),
      children: [
        for (final deuda in deudas)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(
              left: Espaciado.amplio,
              right: Espaciado.normal,
            ),
            title: Text(deuda.descripcion, style: tipografia.bodyMedium),
            trailing: Text(
              FormatoSoles.formatear(deuda.cuotaMensual),
              style: tipografia.montoSecundario,
            ),
          ),
      ],
    );
  }
}

class _TituloCategorias extends StatelessWidget {
  const _TituloCategorias();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Espaciado.normal,
      Espaciado.grande,
      Espaciado.normal,
      Espaciado.chico,
    ),
    child: Text(
      'Por categoría',
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );
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
