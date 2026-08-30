import 'package:finanzas/dominio/modelos/aporte_ahorro.dart';
import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/shared/componentes/aviso_mes_cerrado.dart';
import 'package:finanzas/shared/componentes/fila_monto.dart';
import 'package:finanzas/shared/componentes/tarjeta_sugerencia_ahorro.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/ui/estado/estado_ahorro.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/pantallas/ahorro/configuracion_ahorro.dart';
import 'package:finanzas/ui/pantallas/ahorro/formulario_aporte.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// El objetivo declarado de la app: sugerencia, meta y aportes de ahorro, en
/// una sola pantalla (HU5, SC-010).
class PantallaAhorro extends StatefulWidget {
  const PantallaAhorro({super.key});

  @override
  State<PantallaAhorro> createState() => _PantallaAhorroState();
}

class _PantallaAhorroState extends State<PantallaAhorro> {
  @override
  void initState() {
    super.initState();
    // El ahorro sigue el mismo mes que el resto de la app (el que tiene
    // abierto EstadoMes), pero esta pantalla no tiene su propio selector: se
    // carga una vez al entrar, no hace falta escuchar cambios mientras está
    // abierta.
    //
    // La carga se pospone al primer frame: `cargar()` llama a
    // `notifyListeners()` de inmediato para marcar "cargando", y hacerlo
    // durante el propio `initState` notifica al árbol mientras todavía se
    // está construyendo.
    final mes = context.read<EstadoMes>().mes;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EstadoAhorro>().cargar(mes);
    });
  }

  Future<void> _abrirFormulario(
    BuildContext context,
    EstadoAhorro estadoAhorro, [
    AporteAhorro? original,
  ]) async {
    final resultado = await showDialog<AporteAhorro>(
      context: context,
      builder: (_) => FormularioAporte(
        fechaPorDefecto: DateTime.now(),
        original: original,
        avisoDeCierre: (fecha) => estadoAhorro.admiteRegistrarEn(fecha)
            ? estadoAhorro.motivoDeCierreEn(fecha)
            : 'Ese mes ya está cerrado y no admite registrar aportes.',
      ),
    );
    if (resultado == null) return;

    final exito = resultado.estaGuardado
        ? await estadoAhorro.actualizarAporte(resultado)
        : await estadoAhorro.agregarAporte(resultado);
    if (!exito || !context.mounted) return;

    // FR-042: se admite igual, pero se informa.
    final disponible = context.read<EstadoMes>().resumen.disponibleProyectado;
    if (resultado.monto > disponible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este aporte supera tu disponible del mes.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoMes = context.watch<EstadoMes>();
    final estadoAhorro = context.watch<EstadoAhorro>();

    if (estadoAhorro.cargando || estadoMes.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final resumen = estadoMes.resumen;
    final sugerencia = estadoAhorro.sugerenciaPara(
      ingreso: resumen.ingreso,
      disponibleProyectado: resumen.disponibleProyectado,
      enDeficit: resumen.enDeficit,
    );
    final progreso = estadoAhorro.progresoCon(
      disponibleProyectado: resumen.disponibleProyectado,
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => estadoAhorro.cargar(estadoMes.mes),
        child: ListView(
          padding: const EdgeInsets.only(bottom: Espaciado.bajoBotonFlotante),
          children: [
            if (estadoAhorro.error != null)
              _BannerError(mensaje: estadoAhorro.error!),
            AvisoMesCerrado(estado: estadoAhorro.estadoCierre),
            TarjetaSugerenciaAhorro(sugerencia: sugerencia),
            _TarjetaMeta(
              progreso: progreso,
              // Una ruta empujada con Navigator.push no queda dentro del
              // MultiProvider de main.dart (es una rama nueva del árbol, no
              // un descendiente de Cascaron): hay que volver a proveer acá
              // lo que ConfiguracionAhorro necesita leer.
              onConfigurar: () {
                final repoConfiguracion = context
                    .read<RepositorioConfiguracion>();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MultiProvider(
                      providers: [
                        ChangeNotifierProvider<EstadoAhorro>.value(
                          value: estadoAhorro,
                        ),
                        ChangeNotifierProvider<EstadoMes>.value(
                          value: estadoMes,
                        ),
                        Provider<RepositorioConfiguracion>.value(
                          value: repoConfiguracion,
                        ),
                      ],
                      child: const ConfiguracionAhorro(),
                    ),
                  ),
                );
              },
            ),
            const _TituloSeccion(titulo: 'Aportes de este mes'),
            if (estadoAhorro.aportesDelMes.isEmpty)
              const _SinAportes()
            else
              for (final aporte in estadoAhorro.aportesDelMes)
                _FilaAporte(
                  aporte: aporte,
                  puedeEditar: estadoAhorro.puedeEditarAporte(aporte),
                  onAccion: (accion) => switch (accion) {
                    AccionSobreAporte.editar => _abrirFormulario(
                      context,
                      estadoAhorro,
                      aporte,
                    ),
                    AccionSobreAporte.eliminar => estadoAhorro.eliminarAporte(
                      aporte.id!,
                    ),
                  },
                ),
            if (progreso.historialPorMes.isNotEmpty) ...[
              const _TituloSeccion(titulo: 'Historial'),
              _TarjetaAcumulado(acumulado: progreso.acumuladoHistorico),
              for (final renglon in progreso.historialPorMes.reversed)
                _FilaHistorial(renglon: renglon),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, estadoAhorro),
        icon: const Icon(Icons.add),
        label: const Text('Aporte'),
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion({required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Espaciado.normal,
      Espaciado.grande,
      Espaciado.normal,
      Espaciado.chico,
    ),
    child: Text(titulo, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// Progreso del mes contra su propia meta (FR-035, FR-036, FR-040).
class _TarjetaMeta extends StatelessWidget {
  const _TarjetaMeta({required this.progreso, required this.onConfigurar});

  final ProgresoAhorro progreso;
  final VoidCallback onConfigurar;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final meta = progreso.metaDelMes;

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Meta del mes', style: tipografia.labelLarge),
                IconButton(
                  onPressed: onConfigurar,
                  icon: const Icon(Icons.tune),
                  tooltip: 'Configurar ahorro',
                ),
              ],
            ),
            if (meta == null)
              Text(
                'Todavía no fijaste una meta para este mes.',
                style: tipografia.bodyMedium?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              )
            else ...[
              Text(
                '${FormatoSoles.formatear(progreso.ahorradoMes)} de '
                '${FormatoSoles.formatear(meta)}',
                style: tipografia.montoDestacado,
              ),
              const SizedBox(height: Espaciado.minimo),
              Text(
                (progreso.excedente?.esPositivo ?? false)
                    ? 'Superaste la meta en '
                          '${FormatoSoles.formatear(progreso.excedente!)}'
                    : 'Te faltan '
                          '${FormatoSoles.formatear(progreso.pendiente ?? Dinero.cero)} '
                          'para la meta',
                style: tipografia.bodyMedium?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Espaciado.chico),
              Text(
                progreso.metaAlcanzable == true
                    ? 'Es alcanzable: sobran '
                          '${FormatoSoles.formatear(progreso.margenDisponible ?? Dinero.cero)} '
                          'del disponible.'
                    : 'No es alcanzable con el disponible actual: '
                          'tendrías que recortar '
                          '${FormatoSoles.formatear(progreso.recorteNecesario ?? Dinero.cero)} '
                          'en compromisos.',
                style: tipografia.bodySmall?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TarjetaAcumulado extends StatelessWidget {
  const _TarjetaAcumulado({required this.acumulado});

  final Dinero acumulado;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: Espaciado.normal,
        vertical: Espaciado.chico,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: FilaMonto(
          etiqueta: 'Ahorrado en total',
          valor: FormatoSoles.formatear(acumulado),
          estiloEtiqueta: tipografia.labelLarge,
          estiloValor: tipografia.monto,
        ),
      ),
    );
  }
}

class _FilaHistorial extends StatelessWidget {
  const _FilaHistorial({required this.renglon});

  final RenglonHistorialAhorro renglon;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final meta = renglon.meta;
    final cumplida = renglon.metaCumplida;

    return ListTile(
      title: Text(FormatoFecha.mesCorto(renglon.mes)),
      subtitle: meta == null
          ? const Text('Sin meta fijada')
          : Text(
              cumplida == true
                  ? 'Meta de ${FormatoSoles.formatear(meta)} cumplida'
                  : 'Meta de ${FormatoSoles.formatear(meta)} no alcanzada',
            ),
      trailing: Text(
        FormatoSoles.formatear(renglon.ahorrado),
        style: tipografia.monto,
      ),
      leading: Icon(
        meta == null
            ? Icons.remove_circle_outline
            : (cumplida == true
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked),
        color: esquema.onSurfaceVariant,
      ),
    );
  }
}

enum AccionSobreAporte {
  editar('Editar'),
  eliminar('Eliminar');

  const AccionSobreAporte(this.etiqueta);

  final String etiqueta;
}

class _FilaAporte extends StatelessWidget {
  const _FilaAporte({
    required this.aporte,
    required this.puedeEditar,
    required this.onAccion,
  });

  final AporteAhorro aporte;
  final bool puedeEditar;
  final void Function(AccionSobreAporte) onAccion;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        FormatoSoles.formatear(aporte.monto),
        style: Theme.of(context).textTheme.monto,
      ),
      subtitle: Text(FormatoFecha.corta(aporte.fecha)),
      trailing: puedeEditar
          ? PopupMenuButton<AccionSobreAporte>(
              onSelected: onAccion,
              itemBuilder: (_) => [
                for (final accion in AccionSobreAporte.values)
                  PopupMenuItem(value: accion, child: Text(accion.etiqueta)),
              ],
            )
          // Registrado en la ventana de gracia: quedó inmutable (FR-056).
          : const Tooltip(
              message: 'Registrado en un mes cerrado: no se puede editar',
              child: Icon(Icons.lock_outline, size: 18),
            ),
      onTap: puedeEditar ? () => onAccion(AccionSobreAporte.editar) : null,
    );
  }
}

class _SinAportes extends StatelessWidget {
  const _SinAportes();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: Espaciado.amplio,
      vertical: Espaciado.normal,
    ),
    child: Text(
      'Todavía no registraste ningún aporte este mes. Apenas apartes algo, '
      'anotalo acá para que quede en el acumulado.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _BannerError extends StatelessWidget {
  const _BannerError({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Card(
      color: esquema.errorContainer,
      margin: const EdgeInsets.symmetric(
        horizontal: Espaciado.normal,
        vertical: Espaciado.chico,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.interno),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: esquema.onErrorContainer),
            const SizedBox(width: Espaciado.interno),
            Expanded(
              child: Text(
                mensaje,
                style: TextStyle(color: esquema.onErrorContainer),
              ),
            ),
            TextButton(
              onPressed: context.read<EstadoAhorro>().limpiarError,
              child: const Text('Entendido'),
            ),
          ],
        ),
      ),
    );
  }
}
