import 'package:finanzas/shared/estilos/tema.dart';
import 'package:flutter/material.dart';

/// Encabezado de una sección de pantalla, con un ícono que la identifica de
/// un vistazo.
///
/// Reemplaza a los títulos de texto suelto que tenía cada pantalla: el
/// ícono es la ayuda visual para reconocer la sección sin leer la palabra
/// entera, sobre todo quien escanea la pantalla rápido — nunca reemplaza al
/// texto, solo lo acompaña (Principio IV: nada se comunica solo por un
/// símbolo).
class EncabezadoSeccion extends StatelessWidget {
  const EncabezadoSeccion({
    required this.icono,
    required this.titulo,
    this.contador,
    super.key,
  });

  final IconData icono;
  final String titulo;

  /// Si no es `null` ni cero, se agrega entre paréntesis junto al título.
  final int? contador;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final mostrarContador = contador != null && contador! > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Espaciado.normal,
        Espaciado.normal,
        Espaciado.normal,
        Espaciado.chico,
      ),
      child: Row(
        children: [
          Icon(icono, size: 20, color: esquema.primary),
          const SizedBox(width: Espaciado.chico),
          Expanded(
            child: Text(
              mostrarContador ? '$titulo ($contador)' : titulo,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
