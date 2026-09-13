import 'package:finanzas/dominio/repositorios/repositorio_propinas.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/ui/estado/estado_propinas.dart';
import 'package:finanzas/ui/pantallas/propina/pantalla_propina.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// La puerta de entrada al apoyo voluntario, dentro de Ajustes (spec 004
/// revisada, FR-006).
///
/// **Es el único lugar de toda la app donde se menciona pagarle algo al que
/// la hizo.** No hay banner en el resumen, ni distintivo en el menú, ni
/// recordatorio después de usar la app un mes: quien quiera apoyar entra acá
/// por su cuenta, y quien no, no se entera nunca. Es el precio deliberado de
/// no interrumpir jamás.
///
/// Deja apenas una entrada y no la pantalla entera porque Ajustes es una lista
/// de ajustes: tres montos con sus precios necesitan aire propio.
class SeccionApoyo extends StatelessWidget {
  const SeccionApoyo({super.key});

  /// Abre la pantalla de apoyo con su propio estado.
  ///
  /// El `EstadoPropinas` se crea acá, en la ruta, y muere al cerrarla: **no
  /// vive en el árbol de providers de `main.dart`** a propósito. Así ninguna
  /// otra pantalla puede leer nada sobre el apoyo aunque quiera, que es lo que
  /// vuelve estructuralmente cierto el FR-002 —nada de la app cambia según si
  /// el usuario apoyó— en vez de dejarlo como una promesa.
  ///
  /// Una ruta empujada con `Navigator.push` no queda dentro del `MultiProvider`
  /// de `main.dart` (es una rama nueva del árbol), así que el repositorio se
  /// lee acá y se vuelve a proveer del otro lado — mismo patrón que
  /// `ConfiguracionAhorro` en la spec 001.
  void _abrir(BuildContext context) {
    final repoPropinas = context.read<RepositorioPropinas>();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<EstadoPropinas>(
          create: (_) => EstadoPropinas(repoPropinas: repoPropinas)..cargar(),
          child: const PantallaPropina(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(Icons.volunteer_activism_outlined, color: esquema.primary),
      title: const Text('Apoyar esta app'),
      subtitle: const Text(
        'La app es gratis y completa. Si querés, podés dejar una propina.',
      ),
      trailing: const Icon(Icons.chevron_right),
      contentPadding: const EdgeInsets.symmetric(horizontal: Espaciado.normal),
      onTap: () => _abrir(context),
    );
  }
}
