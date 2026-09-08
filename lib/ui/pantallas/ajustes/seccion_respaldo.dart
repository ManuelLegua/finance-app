import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:finanzas/shared/componentes/marca_estado.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/ui/estado/estado_respaldo.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

/// Exportar y restaurar los datos, dentro de Ajustes (spec 005).
///
/// Es una **sección** y no una pantalla propia (Principio IV): el usuario ya
/// viene a Ajustes a buscar este tipo de cosas, y un destino de navegación
/// nuevo solo agregaría un lugar donde perderse.
///
/// [elegirArchivo] y [compartirArchivo] entran por parámetro con su
/// implementación real por defecto. Son las dos únicas partes que dependen de
/// componentes del sistema operativo —la hoja de compartir y el selector de
/// documentos—, y una prueba de widget no puede abrirlos: inyectarlos deja el
/// resto del flujo verificable sin dispositivo.
class SeccionRespaldo extends StatelessWidget {
  const SeccionRespaldo({
    this.elegirArchivo = elegirConElSelectorDelSistema,
    this.compartirArchivo = compartirConLaHojaDelSistema,
    super.key,
  });

  /// Devuelve la ruta del archivo que el usuario señaló, o `null` si canceló.
  final Future<String?> Function() elegirArchivo;

  /// Entrega el archivo generado al sistema. **No elige destino**: eso lo
  /// decide el usuario en la hoja de compartir (FR-004).
  final Future<void> Function(ArchivoRespaldo archivo) compartirArchivo;

  Future<void> _exportar(BuildContext context) async {
    final estado = context.read<EstadoRespaldo>();
    await estado.exportar();

    final archivo = estado.archivoGenerado;
    // Si falló, el error ya está en pantalla y no hay nada que compartir.
    if (archivo == null) return;
    await compartirArchivo(archivo);
  }

  Future<void> _elegirParaRestaurar(BuildContext context) async {
    final estado = context.read<EstadoRespaldo>();
    final ruta = await elegirArchivo();
    // Cerrar el selector sin elegir nada no es un error ni cambia nada.
    if (ruta == null) return;
    await estado.inspeccionar(ruta);
  }

  @override
  Widget build(BuildContext context) => Consumer<EstadoRespaldo>(
    builder: (context, estado, _) => Column(
      children: [
        _TarjetaExportar(estado: estado, onExportar: () => _exportar(context)),
        const SizedBox(height: Espaciado.chico),
        _TarjetaRestaurar(
          estado: estado,
          onElegirArchivo: () => _elegirParaRestaurar(context),
        ),
      ],
    ),
  );
}

class _TarjetaExportar extends StatelessWidget {
  const _TarjetaExportar({required this.estado, required this.onExportar});

  final EstadoRespaldo estado;
  final VoidCallback onExportar;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final enCurso = estado.faseExportacion == FaseExportacion.enCurso;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Espaciado.normal),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Copia de tus datos', style: tipografia.titleSmall),
            const SizedBox(height: Espaciado.minimo),
            Text(
              'Guardá todo lo que tenés cargado en un archivo y elegí vos '
              'dónde dejarlo. Sirve para no perder nada si reinstalás la app '
              'o cambiás de teléfono.',
              style: tipografia.bodyMedium?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Espaciado.chico),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: enCurso ? null : onExportar,
                icon: const Icon(Icons.ios_share),
                label: Text(
                  enCurso ? 'Generando el archivo...' : 'Exportar respaldo',
                ),
              ),
            ),
            _ResultadoDeExportar(estado: estado),
          ],
        ),
      ),
    );
  }
}

/// Cómo terminó la exportación (FR-005).
///
/// Con ícono **y** texto: la constitución prohíbe comunicar un estado solo
/// por color, y "¿se generó o no?" es exactamente lo que el usuario no puede
/// quedarse dudando después de pedir un respaldo.
class _ResultadoDeExportar extends StatelessWidget {
  const _ResultadoDeExportar({required this.estado});

  final EstadoRespaldo estado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    switch (estado.faseExportacion) {
      case FaseExportacion.inactivo:
      case FaseExportacion.enCurso:
        return const SizedBox.shrink();
      case FaseExportacion.completado:
        final archivo = estado.archivoGenerado;
        return MarcaEstado(
          icono: Icons.check_circle_outline,
          texto: 'Respaldo generado: ${archivo?.nombrePropuesto ?? ''}',
          color: esquema.primary,
        );
      case FaseExportacion.fallido:
        return MarcaEstado(
          icono: Icons.error_outline,
          texto:
              estado.errorDeExportacion ??
              'No se pudo generar el respaldo. Volvé a intentarlo.',
          color: esquema.error,
        );
    }
  }
}

class _TarjetaRestaurar extends StatelessWidget {
  const _TarjetaRestaurar({
    required this.estado,
    required this.onElegirArchivo,
  });

  final EstadoRespaldo estado;
  final VoidCallback onElegirArchivo;

  @override
  Widget build(BuildContext context) {
    final tipografia = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final ocupado =
        estado.faseRestauracion == FaseRestauracion.validando ||
        estado.faseRestauracion == FaseRestauracion.reemplazando;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Espaciado.normal),
      child: Padding(
        padding: const EdgeInsets.all(Espaciado.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Restaurar un respaldo', style: tipografia.titleSmall),
            const SizedBox(height: Espaciado.minimo),
            Text(
              'Volvé a cargar tus datos desde un archivo que hayas exportado '
              'antes. Reemplaza todo lo que tengas ahora.',
              style: tipografia.bodyMedium?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Espaciado.chico),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: ocupado ? null : onElegirArchivo,
                icon: const Icon(Icons.restore_page_outlined),
                label: Text(
                  estado.faseRestauracion == FaseRestauracion.validando
                      ? 'Revisando el archivo...'
                      : 'Restaurar respaldo',
                ),
              ),
            ),
            _EstadoDeRestaurar(estado: estado),
          ],
        ),
      ),
    );
  }
}

class _EstadoDeRestaurar extends StatelessWidget {
  const _EstadoDeRestaurar({required this.estado});

  final EstadoRespaldo estado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    switch (estado.faseRestauracion) {
      case FaseRestauracion.inactivo:
      case FaseRestauracion.validando:
        return const SizedBox.shrink();
      case FaseRestauracion.esperandoConfirmacion:
        return _AvisoDeReemplazo(estado: estado);
      case FaseRestauracion.rechazado:
        return MarcaEstado(
          icono: Icons.block_outlined,
          texto: mensajeDeRechazo(estado.informe?.resultado),
          color: esquema.error,
        );
      case FaseRestauracion.reemplazando:
        return MarcaEstado(
          icono: Icons.hourglass_top_outlined,
          texto: 'Reemplazando tus datos...',
          color: esquema.onSurfaceVariant,
        );
      case FaseRestauracion.completado:
        return MarcaEstado(
          icono: Icons.check_circle_outline,
          texto: 'Datos restaurados desde el respaldo.',
          color: esquema.primary,
        );
      case FaseRestauracion.fallido:
        return MarcaEstado(
          icono: Icons.error_outline,
          texto:
              estado.errorDeRestauracion ??
              'No se pudo restaurar el respaldo. Tus datos quedaron como '
                  'estaban.',
          color: esquema.error,
        );
    }
  }
}

/// El aviso previo al reemplazo (FR-007).
///
/// Dice con todas las letras qué se va a perder y exige una confirmación
/// aparte: hasta que el usuario toque "Reemplazar todo" no se tocó un solo
/// dato suyo. Lleva ícono **y** texto, como `AvisoMesCerrado`: una operación
/// irreversible no puede distinguirse solo por el color del botón.
class _AvisoDeReemplazo extends StatelessWidget {
  const _AvisoDeReemplazo({required this.estado});

  final EstadoRespaldo estado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final tipografia = Theme.of(context).textTheme;
    final deVersionAnterior = estado.informe?.requiereMigracion ?? false;

    return Padding(
      padding: const EdgeInsets.only(top: Espaciado.interno),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: esquema.errorContainer,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(Espaciado.interno),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    color: esquema.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: Espaciado.interno),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Esto reemplaza todos tus datos',
                          style: tipografia.titleSmall?.copyWith(
                            color: esquema.onErrorContainer,
                          ),
                        ),
                        const SizedBox(height: Espaciado.minimo),
                        Text(
                          'Tu presupuesto, tus gastos, tus deudas y tu ahorro '
                          'de ahora se pierden y quedan los del archivo. No '
                          'se puede deshacer.',
                          style: tipografia.bodySmall?.copyWith(
                            color: esquema.onErrorContainer,
                          ),
                        ),
                        if (deVersionAnterior) ...[
                          const SizedBox(height: Espaciado.minimo),
                          Text(
                            'El respaldo es de una versión anterior de la '
                            'app: se actualiza solo al restaurarlo.',
                            style: tipografia.bodySmall?.copyWith(
                              color: esquema.onErrorContainer,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Espaciado.chico),
          Row(
            children: [
              FilledButton.icon(
                onPressed: estado.confirmarRestauracion,
                style: FilledButton.styleFrom(
                  backgroundColor: esquema.error,
                  foregroundColor: esquema.onError,
                ),
                icon: const Icon(Icons.warning_amber_outlined),
                label: const Text('Reemplazar todo'),
              ),
              const SizedBox(width: Espaciado.chico),
              TextButton(
                onPressed: estado.cancelarRestauracion,
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Por qué no se puede restaurar ese archivo (FR-009).
///
/// El `switch` es **exhaustivo a propósito**: si mañana aparece un quinto
/// motivo de rechazo, esto deja de compilar en vez de mostrarle al usuario un
/// "archivo inválido" que no le dice qué hacer.
String mensajeDeRechazo(ResultadoValidacionRespaldo? resultado) =>
    switch (resultado) {
      ResultadoValidacionRespaldo.corrupto =>
        'El archivo está dañado o no es un respaldo. Probá con otro.',
      ResultadoValidacionRespaldo.noEsDeLaApp =>
        'Ese archivo no es un respaldo de esta app.',
      ResultadoValidacionRespaldo.deVersionMasNueva =>
        'El respaldo es de una versión más nueva de la app. Actualizá la app '
            'para poder restaurarlo.',
      // Un respaldo válido no se rechaza: no hay motivo que explicar.
      ResultadoValidacionRespaldo.valido || null => '',
    };

/// El selector de documentos del sistema (Storage Access Framework en
/// Android). No pide ningún permiso de almacenamiento: el usuario señala un
/// archivo y solo ese archivo queda accesible (D5).
Future<String?> elegirConElSelectorDelSistema() async {
  final elegido = await FilePicker.pickFile();
  if (elegido == null) return null;

  final rutaLocal = elegido.path;
  if (rutaLocal != null) return rutaLocal;

  // En Android el selector devuelve un `content://` del SAF, que no es una
  // ruta de archivo: hay que materializarlo antes de poder abrirlo como base.
  final copia = File(p.join(Directory.systemTemp.path, 'candidato-elegido.db'));
  await copia.writeAsBytes(await elegido.readAsBytes());
  return copia.path;
}

/// La hoja de compartir del sistema. La app entrega el archivo y se
/// desentiende: guardarlo en el teléfono, mandarlo por correo o subirlo a
/// donde sea es decisión del usuario, fuera de la app (FR-004, Principio I).
Future<void> compartirConLaHojaDelSistema(ArchivoRespaldo archivo) async {
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(archivo.ruta)],
      fileNameOverrides: <String>[archivo.nombrePropuesto],
    ),
  );
}
