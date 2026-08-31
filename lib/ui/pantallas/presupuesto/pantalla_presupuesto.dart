import 'package:finanzas/dominio/modelos/cobro_ingreso.dart';
import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/shared/componentes/aviso_mes_cerrado.dart';
import 'package:finanzas/shared/componentes/encabezado_seccion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/formato/formato_fecha.dart';
import 'package:finanzas/shared/formato/formato_soles.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/pantallas/presupuesto/formulario_cobro.dart';
import 'package:finanzas/ui/pantallas/presupuesto/formulario_obligacion.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Lo que el menu contextual de una obligacion (o de un cobro) puede hacer.
///
/// Como enum en vez de cadenas sueltas: el `switch` es exhaustivo, asi que
/// agregar una accion sin manejarla no compila.
enum AccionSobreObligacion {
  editar('Editar'),
  eliminar('Eliminar');

  const AccionSobreObligacion(this.etiqueta);

  final String etiqueta;
}

/// Ingreso del mes y presupuesto de obligaciones (HU1).
class PantallaPresupuesto extends StatefulWidget {
  const PantallaPresupuesto({super.key});

  @override
  State<PantallaPresupuesto> createState() => _PantallaPresupuestoState();
}

class _PantallaPresupuestoState extends State<PantallaPresupuesto> {
  bool _precargaOfrecida = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ofrecerPrecarga());
  }

  /// Propone las fijas del mes anterior si el mes está vacío (FR-006).
  ///
  /// Nunca guarda sola: el usuario confirma o descarta.
  Future<void> _ofrecerPrecarga() async {
    if (_precargaOfrecida || !mounted) return;
    _precargaOfrecida = true;

    final estado = context.read<EstadoMes>();
    final propuestas = await estado.propuestaDePrecarga();
    if (propuestas.isEmpty || !mounted) return;

    final confirmadas = await showDialog<List<Obligacion>>(
      context: context,
      builder: (_) => _DialogoPrecarga(propuestas: propuestas),
    );
    if (confirmadas != null && confirmadas.isNotEmpty && mounted) {
      await estado.confirmarPrecarga(confirmadas);
    }
  }

  Future<void> _abrirFormularioCobro(
    EstadoMes estado, [
    CobroIngreso? original,
  ]) async {
    final resultado = await showDialog<CobroIngreso>(
      context: context,
      builder: (_) => FormularioCobro(
        fechaPorDefecto: DateTime.now(),
        original: original,
        avisoDeCierre: (fecha) => estado.admiteRegistrarEn(fecha)
            ? estado.motivoDeCierreEn(fecha)
            : 'Ese mes ya está cerrado y no admite registrar cobros.',
      ),
    );
    if (resultado == null) return;

    if (resultado.estaGuardado) {
      await estado.actualizarCobro(resultado);
    } else {
      await estado.agregarCobro(resultado);
    }
  }

  Future<void> _abrirFormulario(
    EstadoMes estado, [
    Obligacion? original,
  ]) async {
    final resultado = await showDialog<Obligacion>(
      context: context,
      builder: (_) => FormularioObligacion(mes: estado.mes, original: original),
    );
    if (resultado == null) return;

    if (resultado.estaGuardada) {
      await estado.actualizarObligacion(resultado);
    } else {
      await estado.agregarObligacion(resultado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoMes>();

    if (estado.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: estado.cargar,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Espaciado.bajoBotonFlotante),
          children: [
            if (estado.error != null) _BannerError(mensaje: estado.error!),
            AvisoMesCerrado(estado: estado.estadoCierre),
            _TarjetaIngreso(
              estado: estado,
              onAgregar: () => _abrirFormularioCobro(estado),
              onEditarCobro: (cobro) => _abrirFormularioCobro(estado, cobro),
              onEliminarCobro: (cobro) => estado.eliminarCobro(cobro.id!),
            ),
            _TarjetaObligaciones(
              estado: estado,
              onEditar: (obligacion) => _abrirFormulario(estado, obligacion),
              onEliminar: (obligacion) =>
                  estado.eliminarObligacion(obligacion.id!),
            ),
          ],
        ),
      ),
      floatingActionButton: estado.admiteRegistrar
          ? FloatingActionButton.extended(
              onPressed: () => _abrirFormulario(estado),
              icon: const Icon(Icons.add),
              label: const Text('Obligación'),
            )
          : null,
    );
  }
}

class _TarjetaIngreso extends StatelessWidget {
  const _TarjetaIngreso({
    required this.estado,
    required this.onAgregar,
    required this.onEditarCobro,
    required this.onEliminarCobro,
  });

  final EstadoMes estado;
  final VoidCallback onAgregar;
  final void Function(CobroIngreso) onEditarCobro;
  final void Function(CobroIngreso) onEliminarCobro;

  @override
  Widget build(BuildContext context) {
    final ingreso = estado.ingreso;
    final cobros = estado.cobros;
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(
        Espaciado.normal,
        Espaciado.normal,
        Espaciado.normal,
        Espaciado.chico,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 20,
                  color: esquema.primary,
                ),
                const SizedBox(width: Espaciado.chico),
                Expanded(
                  child: Text(
                    'Ingreso de ${FormatoFecha.mesLargo(estado.mes)}',
                    style: tipografia.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espaciado.chico),
            if (ingreso == null)
              Text(
                'Todavía no registraste tu sueldo de este mes.',
                style: tipografia.bodyMedium,
              )
            else
              Text(
                FormatoSoles.formatear(ingreso),
                style: tipografia.montoDestacado,
              ),
            // El detalle de cada cobro (FR-008): solo tiene sentido mostrarlo
            // cuando hay algo que listar.
            if (cobros.isNotEmpty) ...[
              const SizedBox(height: Espaciado.chico),
              for (final cobro in cobros)
                _FilaCobro(
                  cobro: cobro,
                  puedeEditar: estado.puedeEditarCobro(cobro),
                  onEditar: () => onEditarCobro(cobro),
                  onEliminar: () => onEliminarCobro(cobro),
                ),
            ],
            const SizedBox(height: Espaciado.interno),
            Row(
              children: [
                if (estado.admiteRegistrar)
                  FilledButton.tonalIcon(
                    onPressed: onAgregar,
                    icon: const Icon(Icons.add),
                    label: Text(cobros.isEmpty ? 'Registrar' : 'Agregar cobro'),
                  ),
                const Spacer(),
                // `Flexible`, no un tamaño fijo: con siete dígitos el botón
                // y este bloque juntos pueden no entrar en una sola fila.
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Comprometido', style: tipografia.labelSmall),
                      Text(
                        FormatoSoles.formatear(estado.totalComprometido),
                        style: tipografia.monto,
                      ),
                    ],
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

/// Un cobro dentro del detalle de ingreso (FR-008). Mismo patrón de
/// interacción que `_FilaObligacion`: tocable para corregir, con un menú para
/// eliminar — ambos deshabilitados si el mes de ese cobro ya no admite
/// edición (FR-006).
class _FilaCobro extends StatelessWidget {
  const _FilaCobro({
    required this.cobro,
    required this.puedeEditar,
    required this.onEditar,
    required this.onEliminar,
  });

  final CobroIngreso cobro;
  final bool puedeEditar;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        Icons.calendar_month_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(FormatoFecha.corta(cobro.fecha)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ver el comentario de `_FilaObligacion`: `ConstrainedBox` +
          // `FittedBox`, no `Flexible` — `trailing` mide a su hijo por
          // tamaño natural.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                FormatoSoles.formatear(cobro.monto),
                style: Theme.of(context).textTheme.monto,
              ),
            ),
          ),
          if (puedeEditar)
            PopupMenuButton<AccionSobreObligacion>(
              padding: EdgeInsets.zero,
              onSelected: (accion) => switch (accion) {
                AccionSobreObligacion.editar => onEditar(),
                AccionSobreObligacion.eliminar => onEliminar(),
              },
              itemBuilder: (_) => [
                for (final accion in AccionSobreObligacion.values)
                  PopupMenuItem(value: accion, child: Text(accion.etiqueta)),
              ],
            ),
        ],
      ),
      onTap: puedeEditar ? onEditar : null,
    );
  }
}

/// Las obligaciones del mes, agrupadas en una tarjeta — mismo tratamiento
/// visual que `_TarjetaIngreso`, para que las dos secciones se lean como
/// bloques equivalentes en vez de una tarjeta y una lista suelta.
class _TarjetaObligaciones extends StatelessWidget {
  const _TarjetaObligaciones({
    required this.estado,
    required this.onEditar,
    required this.onEliminar,
  });

  final EstadoMes estado;
  final void Function(Obligacion) onEditar;
  final void Function(Obligacion) onEliminar;

  @override
  Widget build(BuildContext context) {
    final obligaciones = estado.obligaciones;

    return Card(
      margin: const EdgeInsets.fromLTRB(
        Espaciado.normal,
        0,
        Espaciado.normal,
        Espaciado.chico,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EncabezadoSeccion(
            icono: Icons.receipt_long_outlined,
            titulo: 'Obligaciones',
            contador: obligaciones.length,
          ),
          if (obligaciones.isEmpty)
            const _SinObligaciones()
          else ...[
            for (final obligacion in obligaciones)
              _FilaObligacion(
                obligacion: obligacion,
                puedeEditar: estado.admiteEditar,
                onEditar: () => onEditar(obligacion),
                onEliminar: () => onEliminar(obligacion),
              ),
            const SizedBox(height: Espaciado.chico),
          ],
        ],
      ),
    );
  }
}

class _FilaObligacion extends StatelessWidget {
  const _FilaObligacion({
    required this.obligacion,
    required this.puedeEditar,
    required this.onEditar,
    required this.onEliminar,
  });

  final Obligacion obligacion;
  final bool puedeEditar;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final esFija = obligacion.tipo == TipoObligacion.fija;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Espaciado.chico),
      leading: Icon(
        esFija ? Icons.push_pin_outlined : Icons.trending_up,
        // El tipo se distingue por ícono y por texto, no solo por color.
        semanticLabel: obligacion.tipo.etiqueta,
      ),
      title: Text(obligacion.nombre),
      subtitle: Text(
        '${obligacion.categoria.etiqueta} · ${obligacion.tipo.etiqueta}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // `ConstrainedBox` + `FittedBox`, no `Flexible`: el slot `trailing`
          // de `ListTile` mide a su hijo por tamaño natural, no lo encoge
          // como haría un `Row` — `Flexible` ahí no tiene efecto. Con siete
          // dígitos y una tarjeta más angosta que la lista plana de antes,
          // el número puede no entrar a su tamaño natural — se achica en vez
          // de desbordar (nunca se trunca la cifra, que es lo único que no
          // puede pasar en una app de plata).
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                FormatoSoles.formatear(obligacion.monto),
                style: Theme.of(context).textTheme.monto,
              ),
            ),
          ),
          if (puedeEditar)
            PopupMenuButton<AccionSobreObligacion>(
              padding: EdgeInsets.zero,
              onSelected: (accion) => switch (accion) {
                AccionSobreObligacion.editar => onEditar(),
                AccionSobreObligacion.eliminar => onEliminar(),
              },
              itemBuilder: (_) => [
                for (final accion in AccionSobreObligacion.values)
                  PopupMenuItem(value: accion, child: Text(accion.etiqueta)),
              ],
            ),
        ],
      ),
      onTap: puedeEditar ? onEditar : null,
    );
  }
}

class _SinObligaciones extends StatelessWidget {
  const _SinObligaciones();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaciado.amplio,
        vertical: Espaciado.normal,
      ),
      child: Column(
        children: [
          Icon(Icons.playlist_add_outlined, size: 40, color: esquema.outline),
          const SizedBox(height: Espaciado.chico),
          Text(
            'Todavía no cargaste obligaciones. Agregá el alquiler, los '
            'servicios y lo que estimás gastar en el mes.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
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
              onPressed: context.read<EstadoMes>().limpiarError,
              child: const Text('Entendido'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ofrece precargar las obligaciones fijas del mes anterior (FR-006).
///
/// El usuario puede destildar las que no correspondan: la app propone, no
/// decide.
class _DialogoPrecarga extends StatefulWidget {
  const _DialogoPrecarga({required this.propuestas});

  final List<Obligacion> propuestas;

  @override
  State<_DialogoPrecarga> createState() => _DialogoPrecargaState();
}

class _DialogoPrecargaState extends State<_DialogoPrecarga> {
  late final Set<int> _elegidas = {
    for (var i = 0; i < widget.propuestas.length; i++) i,
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Precargar obligaciones fijas'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estas son las fijas del mes anterior. Confirmá las que sigan '
              'vigentes; podés ajustar los montos después.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Espaciado.chico),
            for (var i = 0; i < widget.propuestas.length; i++)
              CheckboxListTile(
                value: _elegidas.contains(i),
                onChanged: (marcada) => setState(() {
                  if (marcada ?? false) {
                    _elegidas.add(i);
                  } else {
                    _elegidas.remove(i);
                  }
                }),
                title: Text(widget.propuestas[i].nombre),
                subtitle: Text(
                  FormatoSoles.formatear(widget.propuestas[i].monto),
                  style: Theme.of(context).textTheme.montoSecundario,
                ),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop([
            for (var i = 0; i < widget.propuestas.length; i++)
              if (_elegidas.contains(i)) widget.propuestas[i],
          ]),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
