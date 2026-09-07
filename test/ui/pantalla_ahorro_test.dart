import 'package:finanzas/dominio/modelos/cobro_ingreso.dart';
import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/estado/estado_ahorro.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/pantallas/ahorro/pantalla_ahorro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../builders/aporte_ahorro_builder.dart';
import '../dobles/repositorios_en_memoria.dart';

/// Reglas de presentación del ahorro (HU5, SC-010).
void main() {
  late RepositorioAhorroEnMemoria repoAhorro;
  late RepositorioConfiguracionEnMemoria repoConfiguracion;
  late RepositorioCobrosIngresoEnMemoria repoCobrosIngreso;
  late EstadoMes estadoMes;
  late EstadoAhorro estadoAhorro;

  const agosto = Mes(2026, 8);
  final quinceDeAgosto = DateTime(2026, 8, 15);

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<RepositorioConfiguracion>.value(value: repoConfiguracion),
          ChangeNotifierProvider<EstadoMes>.value(value: estadoMes),
          ChangeNotifierProvider<EstadoAhorro>.value(value: estadoAhorro),
        ],
        child: const MaterialApp(home: PantallaAhorro()),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repoAhorro = RepositorioAhorroEnMemoria();
    repoConfiguracion = RepositorioConfiguracionEnMemoria();
    repoCobrosIngreso = RepositorioCobrosIngresoEnMemoria();
    estadoMes = EstadoMes(
      repoCobrosIngreso: repoCobrosIngreso,
      repoObligaciones: RepositorioObligacionesEnMemoria(),
      repoConfiguracion: repoConfiguracion,
      repoTransacciones: RepositorioTransaccionesEnMemoria(),
      repoDeudas: RepositorioDeudasEnMemoria(),
      ahora: () => quinceDeAgosto,
      mesInicial: agosto,
    );
    estadoAhorro = EstadoAhorro(
      repoAhorro: repoAhorro,
      repoConfiguracion: repoConfiguracion,
      ahora: () => quinceDeAgosto,
    );
  });

  group('aporte que excede el disponible (FR-042)', () {
    testWidgets('se acepta e informa, sin bloquear el registro', (
      tester,
    ) async {
      // El diálogo de aporte propone la fecha con `DateTime.now()` real
      // (`pantalla_ahorro.dart`), no con el reloj inyectado — así tiene que
      // ser, es el "hoy" de quien lo está llenando. Por eso acá "hoy" y el
      // mes cargado no pueden quedar fijos en agosto de 2026: apenas la
      // fecha real cruzara ese mes, el aporte se guardaría en un mes
      // distinto del que la prueba mira y `aportesDelMes` daría vacío. Se
      // reconstruyen `estadoMes`/`estadoAhorro` con el reloj real para que
      // ambos "hoy" coincidan siempre, sea cuando sea que esto se corra.
      final hoy = DateTime.now();
      final mesActual = Mes.deFecha(hoy);
      estadoMes = EstadoMes(
        repoCobrosIngreso: repoCobrosIngreso,
        repoObligaciones: RepositorioObligacionesEnMemoria(),
        repoConfiguracion: repoConfiguracion,
        repoTransacciones: RepositorioTransaccionesEnMemoria(),
        repoDeudas: RepositorioDeudasEnMemoria(),
        ahora: () => hoy,
        mesInicial: mesActual,
      );
      estadoAhorro = EstadoAhorro(
        repoAhorro: repoAhorro,
        repoConfiguracion: repoConfiguracion,
        ahora: () => hoy,
      );

      await repoCobrosIngreso.insertar(
        CobroIngreso(
          id: null,
          fecha: hoy,
          monto: const Dinero.deCentavos(50000),
        ),
      );
      await estadoMes.cargar();
      await estadoAhorro.cargar(mesActual);
      await montar(tester);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '600.00');
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();

      // Se guardó igual: no lo bloqueó.
      expect(estadoAhorro.aportesDelMes, hasLength(1));
      expect(estadoAhorro.aportesDelMes.single.monto, Dinero.deSoles(600));
      // Y lo informa.
      expect(
        find.text('Este aporte supera tu disponible del mes.'),
        findsOneWidget,
      );
    });
  });

  group('mes sin meta (FR-054)', () {
    testWidgets('figura sin veredicto, no como meta cumplida ni incumplida', (
      tester,
    ) async {
      await estadoMes.cargar();
      await estadoAhorro.cargar(agosto);
      await montar(tester);

      expect(
        find.text('Todavía no fijaste una meta para este mes.'),
        findsOneWidget,
      );
      expect(find.textContaining('cumplida'), findsNothing);
      expect(find.textContaining('no alcanzada'), findsNothing);
    });

    testWidgets('un mes del historial sin meta tampoco tiene veredicto', (
      tester,
    ) async {
      await repoAhorro.insertarAporte(
        AporteAhorroBuilder(fecha: DateTime(2026, 7, 10)).build(),
      );
      await estadoMes.cargar();
      await estadoAhorro.cargar(agosto);
      await montar(tester);

      expect(find.text('Sin meta fijada'), findsOneWidget);
    });
  });

  group('configurar ahorro', () {
    testWidgets('el ícono abre la pantalla de configuración sin romper', (
      tester,
    ) async {
      // Regresión: ConfiguracionAhorro se abre con Navigator.push, que la
      // saca del árbol del MultiProvider de main.dart. Si alguien vuelve a
      // usar Navigator.push sin reinyectar los providers, esto revienta con
      // un ProviderNotFoundException en vez de mostrar la pantalla.
      await estadoMes.cargar();
      await estadoAhorro.cargar(agosto);
      await montar(tester);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.text('Configurar ahorro'), findsOneWidget);
      expect(find.text('Regla de ahorro'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('propuesta de meta (FR-053)', () {
    testWidgets('no queda guardada hasta confirmarla', (tester) async {
      await repoAhorro.guardarMeta(
        const Mes(2026, 7),
        const Dinero.deCentavos(50000),
      );
      await estadoMes.cargar();
      await estadoAhorro.cargar(agosto);

      final propuesta = estadoAhorro.propuesta;
      expect(propuesta.montoPropuesto, const Dinero.deCentavos(50000));
      // Proponer no es guardar: agosto sigue sin meta propia.
      expect(
        estadoAhorro.progresoCon(disponibleProyectado: Dinero.cero).metaDelMes,
        isNull,
      );
      expect(await repoAhorro.metaDeMes(agosto), isNull);

      // Recién al confirmarla queda fijada.
      await estadoAhorro.fijarMeta(propuesta.montoPropuesto!);
      expect(
        await repoAhorro.metaDeMes(agosto),
        const Dinero.deCentavos(50000),
      );
    });
  });

  group('mes cerrado (FR-052, FR-055)', () {
    testWidgets('no admite registrar un aporte nuevo', (tester) async {
      // Marzo, con "hoy" en agosto y la ventana de gracia por defecto, está
      // completamente cerrado: ni siquiera entra en la ventana de gracia.
      const marzo = Mes(2026, 3);
      estadoMes = EstadoMes(
        repoCobrosIngreso: repoCobrosIngreso,
        repoObligaciones: RepositorioObligacionesEnMemoria(),
        repoConfiguracion: repoConfiguracion,
        repoTransacciones: RepositorioTransaccionesEnMemoria(),
        repoDeudas: RepositorioDeudasEnMemoria(),
        ahora: () => quinceDeAgosto,
        mesInicial: marzo,
      );
      await estadoMes.cargar();
      await estadoAhorro.cargar(marzo);
      await montar(tester);

      // Se comunica en pantalla, no solo con color (FR-058).
      expect(find.text('Mes cerrado'), findsOneWidget);

      final guardado = await estadoAhorro.agregarAporte(
        AporteAhorroBuilder(fecha: DateTime(2026, 3, 10)).build(),
      );

      expect(guardado, isFalse);
      expect(estadoAhorro.error, isNotNull);
      expect(await repoAhorro.aportesPorMes(marzo), isEmpty);
    });
  });
}
