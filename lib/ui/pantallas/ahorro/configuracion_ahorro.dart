import 'package:finanzas/dominio/modelos/configuracion.dart';
import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/shared/componentes/campo_monto.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/ui/estado/estado_ahorro.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Regla de ahorro, porcentaje y meta del mes en curso (FR-031, FR-032,
/// FR-035, FR-053).
///
/// La regla y el porcentaje son globales; la meta es del mes que
/// `EstadoAhorro` tiene cargado. Ver la nota en `pantalla_ajustes.dart`: acá
/// viven porque son del ahorro, no ajustes transversales.
class ConfiguracionAhorro extends StatefulWidget {
  const ConfiguracionAhorro({super.key});

  @override
  State<ConfiguracionAhorro> createState() => _ConfiguracionAhorroState();
}

class _ConfiguracionAhorroState extends State<ConfiguracionAhorro> {
  final _formularioMeta = GlobalKey<FormState>();
  late final TextEditingController _meta;
  Configuracion? _config;
  bool _guardandoConfig = false;

  @override
  void initState() {
    super.initState();
    final estadoAhorro = context.read<EstadoAhorro>();
    final metaActual = estadoAhorro.progresoCon(
      disponibleProyectado: Dinero.cero,
    ).metaDelMes;
    final propuesta = estadoAhorro.propuesta.montoPropuesto;
    _meta = TextEditingController(
      text: FormatoSoles.paraEditar(metaActual ?? propuesta ?? Dinero.cero),
    );
    _cargarConfig();
  }

  Future<void> _cargarConfig() async {
    final config = await context.read<RepositorioConfiguracion>().obtener();
    if (mounted) setState(() => _config = config);
  }

  @override
  void dispose() {
    _meta.dispose();
    super.dispose();
  }

  Future<void> _cambiarConfig(Configuracion nueva) async {
    if (_guardandoConfig) return;
    setState(() => _guardandoConfig = true);
    await context.read<RepositorioConfiguracion>().guardar(nueva);
    if (!mounted) return;

    setState(() {
      _config = nueva;
      _guardandoConfig = false;
    });
    await _recargarAhorro();
  }

  Future<void> _recargarAhorro() async {
    if (!mounted) return;
    final mes = context.read<EstadoMes>().mes;
    await context.read<EstadoAhorro>().cargar(mes);
  }

  Future<void> _confirmarMeta() async {
    if (!_formularioMeta.currentState!.validate()) return;
    final monto = CampoMonto.montoDe(_meta.text);
    if (monto == null) return;

    final guardo = await context.read<EstadoAhorro>().fijarMeta(monto);
    if (guardo && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Meta del mes guardada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final propuesta = context.watch<EstadoAhorro>().propuesta;
    final mesActual = context.watch<EstadoMes>().mes;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar ahorro')),
      body: config == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: Espaciado.chico),
              children: [
                const _Seccion(titulo: 'Cómo se calcula la sugerencia'),
                _CardRegla(
                  config: config,
                  onCambiar: (regla) => _cambiarConfig(
                    config.copiarCon(regla: regla),
                  ),
                ),
                if (config.regla == ReglaAhorro.porcentajeIngreso)
                  _CardPorcentaje(
                    porcentajeBp: config.porcentajeBp,
                    onCambiar: (bp) => _cambiarConfig(
                      config.copiarCon(porcentajeBp: bp),
                    ),
                  ),
                const _Seccion(titulo: 'Meta de este mes'),
                _CardMeta(
                  formulario: _formularioMeta,
                  controlador: _meta,
                  propuesta: propuesta.hayPropuesta
                      ? 'Sugerida a partir del último mes con meta: '
                            '${FormatoSoles.formatear(propuesta.montoPropuesto!)}'
                      : null,
                  mesTitulo: FormatoFecha.mesLargo(mesActual),
                  onConfirmar: _confirmarMeta,
                ),
              ],
            ),
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

class _CardRegla extends StatelessWidget {
  const _CardRegla({required this.config, required this.onCambiar});

  final Configuracion config;
  final void Function(ReglaAhorro) onCambiar;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Espaciado.normal),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Regla de ahorro',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: Espaciado.chico),
            SegmentedButton<ReglaAhorro>(
              segments: [
                for (final regla in ReglaAhorro.values)
                  ButtonSegment(value: regla, label: Text(regla.etiqueta)),
              ],
              selected: {config.regla},
              onSelectionChanged: (seleccion) => onCambiar(seleccion.first),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardPorcentaje extends StatelessWidget {
  const _CardPorcentaje({required this.porcentajeBp, required this.onCambiar});

  final int porcentajeBp;
  final void Function(int) onCambiar;

  @override
  Widget build(BuildContext context) {
    final porcentaje = porcentajeBp ~/ 100;
    final tipografia = Theme.of(context).textTheme;

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
            Text('Porcentaje del ingreso', style: tipografia.titleSmall),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: porcentaje.toDouble(),
                    max: 100,
                    divisions: 100,
                    label: '$porcentaje%',
                    onChanged: (valor) => onCambiar(valor.round() * 100),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '$porcentaje%',
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

class _CardMeta extends StatelessWidget {
  const _CardMeta({
    required this.formulario,
    required this.controlador,
    required this.propuesta,
    required this.mesTitulo,
    required this.onConfirmar,
  });

  final GlobalKey<FormState> formulario;
  final TextEditingController controlador;
  final String? propuesta;
  final String mesTitulo;
  final VoidCallback onConfirmar;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Espaciado.normal),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Form(
          key: formulario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cuánto querés apartar en $mesTitulo',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (propuesta != null) ...[
                const SizedBox(height: Espaciado.minimo),
                Text(
                  propuesta!,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: Espaciado.chico),
              CampoMonto(controlador: controlador, etiqueta: 'Meta del mes'),
              const SizedBox(height: Espaciado.chico),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: onConfirmar,
                  child: const Text('Confirmar meta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
