import 'package:finanzas/dominio/modelos/entidades.dart';
import 'package:finanzas/dominio/modelos/tarjeta.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/ui/estado/estado_tarjetas.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Gestión de tarjetas (FR-059, FR-060).
class PantallaTarjetas extends StatelessWidget {
  const PantallaTarjetas({super.key});

  Future<void> _abrirFormulario(
    BuildContext context,
    EstadoTarjetas estado, [
    Tarjeta? original,
  ]) async {
    final resultado = await showDialog<Tarjeta>(
      context: context,
      builder: (_) => _FormularioTarjeta(original: original),
    );
    if (resultado == null) return;

    if (resultado.estaGuardada) {
      await estado.actualizar(resultado);
    } else {
      await estado.agregar(resultado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoTarjetas>();

    if (estado.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: Espaciado.bajoBotonFlotante),
        children: [
          if (estado.error != null) _BannerError(mensaje: estado.error!),
          if (estado.tarjetas.isEmpty)
            const _SinTarjetas()
          else
            for (final tarjeta in estado.tarjetas)
              ListTile(
                leading: Icon(
                  tarjeta.admiteCuotas
                      ? Icons.credit_card
                      : Icons.payment_outlined,
                  // El tipo se distingue por ícono y por texto, no por color.
                  semanticLabel: tarjeta.tipo.etiqueta,
                ),
                title: Text(tarjeta.nombre),
                subtitle: Text('${tarjeta.entidad} · ${tarjeta.tipo.etiqueta}'),
                trailing: PopupMenuButton<AccionSobreTarjeta>(
                  onSelected: (accion) => switch (accion) {
                    AccionSobreTarjeta.editar => _abrirFormulario(
                      context,
                      estado,
                      tarjeta,
                    ),
                    AccionSobreTarjeta.eliminar => estado.eliminar(tarjeta.id!),
                  },
                  itemBuilder: (_) => [
                    for (final accion in AccionSobreTarjeta.values)
                      PopupMenuItem(
                        value: accion,
                        child: Text(accion.etiqueta),
                      ),
                  ],
                ),
                onTap: () => _abrirFormulario(context, estado, tarjeta),
              ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, estado),
        icon: const Icon(Icons.add),
        label: const Text('Tarjeta'),
      ),
    );
  }
}

enum AccionSobreTarjeta {
  editar('Editar'),
  eliminar('Eliminar');

  const AccionSobreTarjeta(this.etiqueta);

  final String etiqueta;
}

class _SinTarjetas extends StatelessWidget {
  const _SinTarjetas();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Espaciado.amplio),
    child: Text(
      'Todavía no registraste tarjetas. Agregá las que usás para poder '
      'cargar deudas en cuotas: solo las de crédito las admiten.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _FormularioTarjeta extends StatefulWidget {
  const _FormularioTarjeta({this.original});

  final Tarjeta? original;

  @override
  State<_FormularioTarjeta> createState() => _FormularioTarjetaState();
}

class _FormularioTarjetaState extends State<_FormularioTarjeta> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _entidad;
  late TipoTarjeta _tipo;

  bool get _esEdicion => widget.original != null;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.original?.nombre ?? '');
    _entidad = TextEditingController(text: widget.original?.entidad ?? '');
    _tipo = widget.original?.tipo ?? TipoTarjeta.credito;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _entidad.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formulario.currentState!.validate()) return;
    Navigator.of(context).pop(
      Tarjeta(
        id: widget.original?.id,
        nombre: _nombre.text.trim(),
        entidad: _entidad.text.trim(),
        tipo: _tipo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_esEdicion ? 'Editar tarjeta' : 'Nueva tarjeta'),
      content: SingleChildScrollView(
        child: Form(
          key: _formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nombre,
                autofocus: !_esEdicion,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'BCP Visa Clásica',
                ),
                validator: (texto) => (texto ?? '').trim().isEmpty
                    ? 'Ponele un nombre para reconocerla.'
                    : null,
              ),
              const SizedBox(height: Espaciado.entreCampos),
              // La lista sugiere, no restringe: se admite escribir una que no
              // esté (FR-060). Es local, sin consultar ninguna API (D14).
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _entidad.text),
                optionsBuilder: (valor) {
                  final escrito = valor.text.toLowerCase();
                  if (escrito.isEmpty) return EntidadesPeru.sugeridas;
                  return EntidadesPeru.sugeridas.where(
                    (entidad) => entidad.toLowerCase().contains(escrito),
                  );
                },
                onSelected: (entidad) => _entidad.text = entidad,
                fieldViewBuilder:
                    (context, controlador, foco, onFieldSubmitted) {
                      controlador.addListener(
                        () => _entidad.text = controlador.text,
                      );
                      return TextFormField(
                        controller: controlador,
                        focusNode: foco,
                        decoration: const InputDecoration(
                          labelText: 'Entidad',
                          hintText: 'BCP, Interbank, Oh!…',
                        ),
                        validator: (texto) => (texto ?? '').trim().isEmpty
                            ? 'Decí de qué banco o entidad es.'
                            : null,
                      );
                    },
              ),
              const SizedBox(height: Espaciado.entreCampos),
              SegmentedButton<TipoTarjeta>(
                segments: const [
                  ButtonSegment(
                    value: TipoTarjeta.credito,
                    label: Text('Crédito'),
                    icon: Icon(Icons.credit_card),
                  ),
                  ButtonSegment(
                    value: TipoTarjeta.debito,
                    label: Text('Débito'),
                    icon: Icon(Icons.payment_outlined),
                  ),
                ],
                selected: {_tipo},
                onSelectionChanged: (seleccion) =>
                    setState(() => _tipo = seleccion.first),
              ),
              const SizedBox(height: Espaciado.chico),
              Text(
                _tipo == TipoTarjeta.credito
                    ? 'Puede respaldar deudas en cuotas.'
                    : 'Las de débito no admiten deudas en cuotas.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardar,
          child: Text(_esEdicion ? 'Guardar' : 'Agregar'),
        ),
      ],
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
              onPressed: context.read<EstadoTarjetas>().limpiarError,
              child: const Text('Entendido'),
            ),
          ],
        ),
      ),
    );
  }
}
