import 'package:finanzas/dominio/modelos/configuracion.dart';
import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/estado/estado_suscripcion.dart';
import 'package:finanzas/ui/pantallas/suscripcion/ficha_estado_suscripcion.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Ajustes transversales de la app.
///
/// Acá viven las preferencias que **no pertenecen a ninguna pantalla
/// temática**. Los días de gracia del cierre son el ejemplo: gobiernan el mes
/// entero, no el ahorro ni el presupuesto, y meterlos dentro de la
/// configuración de ahorro los dejaba donde nadie los buscaría.
///
/// La regla de ahorro y su porcentaje sí son del ahorro, y quedan en la
/// pantalla de esa historia (US5).
///
/// El estado de la suscripción también vive acá: FR-009 pide un lugar fijo
/// donde consultarlo, y Ajustes es el único que no depende de tener acceso a
/// lo que se compró.
class PantallaAjustes extends StatefulWidget {
  const PantallaAjustes({super.key});

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  Configuracion? _config;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    _refrescarSuscripcion();
  }

  Future<void> _cargar() async {
    final config = await context.read<RepositorioConfiguracion>().obtener();
    if (mounted) setState(() => _config = config);
  }

  /// Entrar a Ajustes es entrar a ver el estado de la suscripción, así que se
  /// vuelve a preguntar a Google Play (D4): el usuario pudo comprar, cancelar
  /// o dejar vencer fuera de la app, y una ficha desactualizada acá sería
  /// peor que no tenerla.
  ///
  /// Es de mejor esfuerzo: sin conexión se sigue mostrando lo último
  /// conocido, sin bloquear la pantalla ni avisar de nada.
  void _refrescarSuscripcion() {
    context.read<EstadoSuscripcionPremium>().refrescar();
  }

  Future<void> _cambiarDiasDeGracia(int dias) async {
    final actual = _config;
    if (actual == null || _guardando) return;

    setState(() => _guardando = true);
    final nueva = actual.copiarCon(diasGraciaCierre: dias);
    await context.read<RepositorioConfiguracion>().guardar(nueva);
    if (!mounted) return;

    setState(() {
      _config = nueva;
      _guardando = false;
    });
    // El cierre del mes depende de este valor: recargar deja la app coherente
    // sin que el usuario tenga que navegar a otra pantalla y volver.
    await context.read<EstadoMes>().cargar();
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (config == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Espaciado.chico),
      children: [
        const _Seccion(titulo: 'Cierre de meses'),
        _DiasDeGracia(
          dias: config.diasGraciaCierre,
          onCambiar: _cambiarDiasDeGracia,
        ),
        const _Seccion(titulo: 'Suscripción'),
        const FichaEstadoSuscripcion(),
      ],
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Espaciado.normal,
      Espaciado.normal,
      Espaciado.normal,
      Espaciado.chico,
    ),
    child: Text(
      titulo,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

/// Cuántos días del mes nuevo siguen admitiendo pagos con fecha del anterior
/// (FR-055).
class _DiasDeGracia extends StatelessWidget {
  const _DiasDeGracia({required this.dias, required this.onCambiar});

  /// Máximo admitido por el dominio. Más allá, la ventana se solaparía con
  /// buena parte del mes siguiente y el cierre dejaría de significar algo.
  static const int _maximo = 28;

  final int dias;
  final void Function(int) onCambiar;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Espaciado.normal),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plazo para pagos rezagados', style: tipografia.titleSmall),
            const SizedBox(height: Espaciado.minimo),
            Text(
              dias == 0
                  ? 'El mes anterior queda cerrado apenas empieza el nuevo.'
                  : 'Hasta el día $dias del mes podés registrar pagos con '
                        'fecha del mes anterior. Una vez guardados no se '
                        'pueden editar ni eliminar.',
              style: tipografia.bodyMedium?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Espaciado.chico),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: dias.toDouble(),
                    max: _maximo.toDouble(),
                    divisions: _maximo,
                    label: '$dias',
                    onChanged: (valor) => onCambiar(valor.round()),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    dias == 1 ? '1 día' : '$dias días',
                    textAlign: TextAlign.end,
                    style: tipografia.monto,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
