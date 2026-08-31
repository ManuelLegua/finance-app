import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/ui/estado/estado_asociaciones.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Comercios que la app aprendió a categorizar solo con confirmar consumos
/// (HU3, spec 002, FR-034).
///
/// Existe para que "la app aprende sola" no sea una caja negra: el usuario
/// puede ver qué asoció, corregirlo si se equivocó una vez, o borrarlo si ya
/// no aplica (comercio que cambió de rubro, error de tipeo que quedó fijado).
class PantallaAsociaciones extends StatelessWidget {
  const PantallaAsociaciones({super.key});

  Future<void> _corregir(
    BuildContext context,
    EstadoAsociaciones estado,
    AsociacionComercio asociacion,
  ) async {
    final categoria = await showDialog<Categoria>(
      context: context,
      builder: (_) => _DialogoElegirCategoria(actual: asociacion.categoria),
    );
    if (categoria == null || categoria == asociacion.categoria) return;
    await estado.corregir(asociacion.comercioNormalizado, categoria);
  }

  Future<void> _eliminar(
    BuildContext context,
    EstadoAsociaciones estado,
    AsociacionComercio asociacion,
  ) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Olvidar esta asociación?'),
        content: Text(
          'La próxima vez que llegue un consumo de '
          '"${asociacion.comercioNormalizado}" va a pedir la categoría de '
          'nuevo. No afecta a ningún gasto ya registrado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Olvidar'),
          ),
        ],
      ),
    );
    if (confirmado ?? false) {
      await estado.eliminar(asociacion.comercioNormalizado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoAsociaciones>();

    if (estado.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final asociaciones = estado.asociaciones;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: estado.cargar,
        child: ListView(
          children: [
            if (estado.error != null)
              _BannerError(
                mensaje: estado.error!,
                onCerrar: estado.limpiarError,
              ),
            const _Explicacion(),
            if (asociaciones.isEmpty)
              const _SinAsociaciones()
            else
              for (final asociacion in asociaciones)
                _FilaAsociacion(
                  asociacion: asociacion,
                  onCorregir: () => _corregir(context, estado, asociacion),
                  onEliminar: () => _eliminar(context, estado, asociacion),
                ),
          ],
        ),
      ),
    );
  }
}

class _Explicacion extends StatelessWidget {
  const _Explicacion();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Espaciado.normal),
      child: Text(
        'Cada vez que confirmás un consumo, la app recuerda la categoría '
        'para ese comercio y te la propone la próxima vez.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: esquema.onSurfaceVariant),
      ),
    );
  }
}

class _SinAsociaciones extends StatelessWidget {
  const _SinAsociaciones();

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Espaciado.amplio),
      child: Column(
        children: [
          Icon(Icons.school_outlined, size: 48, color: esquema.outline),
          const SizedBox(height: Espaciado.normal),
          Text(
            'Todavía no aprendió ningún comercio',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Espaciado.chico),
          Text(
            'Confirmá un consumo con su categoría y va a aparecer acá.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _FilaAsociacion extends StatelessWidget {
  const _FilaAsociacion({
    required this.asociacion,
    required this.onCorregir,
    required this.onEliminar,
  });

  final AsociacionComercio asociacion;
  final VoidCallback onCorregir;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onCorregir,
      title: Text(asociacion.comercioNormalizado),
      subtitle: Text(asociacion.categoria.etiqueta),
      trailing: IconButton(
        onPressed: onEliminar,
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Olvidar asociación',
      ),
    );
  }
}

class _DialogoElegirCategoria extends StatefulWidget {
  const _DialogoElegirCategoria({required this.actual});

  final Categoria actual;

  @override
  State<_DialogoElegirCategoria> createState() =>
      _DialogoElegirCategoriaState();
}

class _DialogoElegirCategoriaState extends State<_DialogoElegirCategoria> {
  late Categoria _elegida = widget.actual;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Corregir categoría'),
      content: DropdownButtonFormField<Categoria>(
        initialValue: _elegida,
        decoration: const InputDecoration(labelText: 'Categoría'),
        items: [
          for (final categoria in Categoria.presupuestables)
            DropdownMenuItem(value: categoria, child: Text(categoria.etiqueta)),
        ],
        onChanged: (valor) {
          if (valor != null) setState(() => _elegida = valor);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_elegida),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _BannerError extends StatelessWidget {
  const _BannerError({required this.mensaje, required this.onCerrar});

  final String mensaje;
  final VoidCallback onCerrar;

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
            TextButton(onPressed: onCerrar, child: const Text('Entendido')),
          ],
        ),
      ),
    );
  }
}
