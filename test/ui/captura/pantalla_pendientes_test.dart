import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/estado/estado_pendientes.dart';
import 'package:finanzas/ui/estado/estado_suscripcion.dart';
import 'package:finanzas/ui/estado/estado_tarjetas.dart';
import 'package:finanzas/ui/pantallas/captura/pantalla_pendientes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../builders/tarjeta_builder.dart';
import '../../dobles/repositorios_en_memoria.dart';

/// Reglas de presentación de la bandeja de pendientes (spec 002, FR-021,
/// FR-022, FR-023, FR-025, FR-028, FR-035 a FR-037).
void main() {
  late RepositorioPendientesEnMemoria repoPendientes;
  late RepositorioTransaccionesEnMemoria repoTransacciones;
  late RepositorioDeudasEnMemoria repoDeudas;
  late EstadoPendientes estado;
  late EstadoTarjetas estadoTarjetas;
  late EstadoSuscripcionPremium estadoSuscripcion;

  ConsumoPendiente pendiente({
    required String notificacionId,
    int centavos = 4500,
    String comercio = 'Comercio de prueba',
    DateTime? fecha,
    Categoria? categoriaPropuesta,
  }) => ConsumoPendiente(
    id: null,
    origenPaquete: 'com.ejemplo.banco',
    notificacionId: notificacionId,
    monto: Dinero.deCentavos(centavos),
    comercio: comercio,
    fecha: fecha ?? DateTime(2026, 8, 10),
    categoriaPropuesta: categoriaPropuesta,
    capturadoEn: DateTime(2026, 8, 10, 12),
  );

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EstadoPendientes>.value(value: estado),
          ChangeNotifierProvider<EstadoTarjetas>.value(value: estadoTarjetas),
          ChangeNotifierProvider<EstadoSuscripcionPremium>.value(
            value: estadoSuscripcion,
          ),
        ],
        child: const MaterialApp(home: PantallaPendientes()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Deja la suscripción en la situación pedida y la carga.
  ///
  /// Por omisión, vigente: la bandeja es de la spec 002 y sus pruebas no
  /// tienen por qué hablar de suscripciones. El grupo de US4 la vence.
  Future<void> conSuscripcion(SituacionSuscripcion situacion) async {
    estadoSuscripcion = EstadoSuscripcionPremium(
      repoSuscripcion: RepositorioSuscripcionEnMemoria(
        inicial: EstadoSuscripcion(
          situacion: situacion,
          plan: PlanSuscripcion.mensual,
          vigenteHasta: null,
          ultimaVerificacion: DateTime(2026, 8, 10),
        ),
      ),
    );
    await estadoSuscripcion.cargar();
  }

  setUp(() async {
    await conSuscripcion(SituacionSuscripcion.activa);
    repoPendientes = RepositorioPendientesEnMemoria();
    repoTransacciones = RepositorioTransaccionesEnMemoria();
    repoDeudas = RepositorioDeudasEnMemoria();
    final estadoMes = EstadoMes(
      repoCobrosIngreso: RepositorioCobrosIngresoEnMemoria(),
      repoObligaciones: RepositorioObligacionesEnMemoria(),
      repoConfiguracion: RepositorioConfiguracionEnMemoria(),
      repoTransacciones: repoTransacciones,
      repoDeudas: repoDeudas,
      ahora: () => DateTime(2026, 8, 10),
      mesInicial: const Mes(2026, 8),
    );
    await estadoMes.cargar();
    estado = EstadoPendientes(
      repoPendientes: repoPendientes,
      repoAsociaciones: RepositorioAsociacionesEnMemoria(),
      estadoMes: estadoMes,
    );
    final repoTarjetas = RepositorioTarjetasEnMemoria();
    await repoTarjetas.insertar(TarjetaBuilder().build());
    estadoTarjetas = EstadoTarjetas(repoTarjetas: repoTarjetas);
    await estadoTarjetas.cargar();
  });

  group('sin pendientes', () {
    testWidgets('invita a esperar, no muestra una lista vacía', (tester) async {
      await estado.cargar();
      await montar(tester);

      expect(
        find.textContaining('Nada esperando confirmación'),
        findsOneWidget,
      );
    });
  });

  group('orden y total (FR-021, FR-022)', () {
    testWidgets('lista del más reciente al más antiguo con el total', (
      tester,
    ) async {
      await repoPendientes.insertar(
        pendiente(
          notificacionId: 'a',
          comercio: 'Primero',
          fecha: DateTime(2026, 8, 1),
          centavos: 1000,
        ),
      );
      await repoPendientes.insertar(
        pendiente(
          notificacionId: 'b',
          comercio: 'Segundo',
          fecha: DateTime(2026, 8, 15),
          centavos: 2000,
        ),
      );
      await estado.cargar();
      await montar(tester);

      final titulos = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((fila) => (fila.title! as Text).data)
          .toList();
      expect(titulos, ['Segundo', 'Primero']);
      expect(find.text(r'S/ 30.00'), findsOneWidget);
      expect(find.text('2 consumos por confirmar'), findsOneWidget);
    });
  });

  group('confirmar de un toque (FR-023)', () {
    testWidgets('un pendiente con categoría se confirma sin abrir formulario', (
      tester,
    ) async {
      await repoPendientes.insertar(
        pendiente(notificacionId: 'a', categoriaPropuesta: Categoria.comida),
      );
      await estado.cargar();
      await montar(tester);

      await tester.tap(
        find.byWidgetPredicate((widget) => widget is PopupMenuButton),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(estado.pendientes, isEmpty);
      expect(await repoTransacciones.porMes(const Mes(2026, 8)), hasLength(1));
    });
  });

  group('descartar (FR-025)', () {
    testWidgets('pide confirmación antes de descartar', (tester) async {
      await repoPendientes.insertar(pendiente(notificacionId: 'a'));
      await estado.cargar();
      await montar(tester);

      await tester.tap(
        find.byWidgetPredicate((widget) => widget is PopupMenuButton),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Descartar este consumo?'), findsOneWidget);

      await tester.tap(find.text('Descartar').last);
      await tester.pumpAndSettle();

      expect(estado.pendientes, isEmpty);
      expect(await repoTransacciones.porMes(const Mes(2026, 8)), isEmpty);
    });

    testWidgets('un fallo al descartar se muestra, no se traga en silencio', (
      tester,
    ) async {
      await repoPendientes.insertar(pendiente(notificacionId: 'a'));
      await estado.cargar();
      await montar(tester);

      repoPendientes.errorEnLaProximaEscritura = Exception('disco lleno');
      await tester.tap(
        find.byWidgetPredicate((widget) => widget is PopupMenuButton),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Ocurrió un problema'), findsOneWidget);
      // No se perdió el pendiente: el fallo no se tragó en silencio.
      expect(estado.pendientes, hasLength(1));
    });
  });

  group('cantidad inusual (FR-028)', () {
    testWidgets('avisa con texto e ícono cuando hay demasiados', (
      tester,
    ) async {
      for (var i = 0; i < 21; i++) {
        await repoPendientes.insertar(pendiente(notificacionId: 'p$i'));
      }
      await estado.cargar();
      await montar(tester);

      expect(find.byIcon(Icons.event_busy_outlined), findsOneWidget);
      expect(find.textContaining('Son bastantes sin revisar'), findsOneWidget);
    });
  });

  group('marcar en cuotas (FR-035, FR-036, FR-037)', () {
    testWidgets('confirmarlo en cuotas crea una Deuda y no una Transaccion', (
      tester,
    ) async {
      await repoPendientes.insertar(
        pendiente(notificacionId: 'a', comercio: 'Tienda X', centavos: 15000),
      );
      await estado.cargar();
      await montar(tester);

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fue una compra en cuotas'));
      await tester.pumpAndSettle();
      expect(find.text('Tarjeta'), findsOneWidget);
      // Sin marcar en cuotas ya no se pide categoría.
      expect(find.text('Categoría'), findsNothing);

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(estado.pendientes, isEmpty);
      expect(await repoTransacciones.porMes(const Mes(2026, 8)), isEmpty);
      final deuda = (await repoDeudas.todas()).single;
      expect(deuda.descripcion, 'Tienda X');
      expect(deuda.cuotaMensual, const Dinero.deCentavos(15000));
      expect(deuda.numCuotas, 12); // valor por defecto del formulario
    });

    testWidgets(
      'sin tarjetas de crédito, la opción de marcarlo en cuotas ni se ofrece',
      (tester) async {
        estadoTarjetas = EstadoTarjetas(
          repoTarjetas: RepositorioTarjetasEnMemoria(),
        );
        await estadoTarjetas.cargar();
        await repoPendientes.insertar(pendiente(notificacionId: 'a'));
        await estado.cargar();
        await montar(tester);

        await tester.tap(find.byType(ListTile));
        await tester.pumpAndSettle();

        expect(find.text('Fue una compra en cuotas'), findsNothing);
      },
    );
  });

  group('con la suscripción vencida la bandeja no se cierra (FR-011)', () {
    /// La captura de notificaciones es premium, pero lo que ya está
    /// capturado y sin confirmar **no lo es**: dejarlo encerrado sería
    /// exactamente el "perder datos" que US4 promete que no pasa. Lo que se
    /// corta al vencer es que lleguen consumos nuevos, y eso ocurre en el
    /// callback headless (T035), no acá.
    testWidgets('los pendientes que ya existían se siguen viendo', (
      tester,
    ) async {
      await conSuscripcion(SituacionSuscripcion.vencida);
      await repoPendientes.insertar(
        pendiente(notificacionId: 'a', comercio: 'Rappi'),
      );
      await estado.cargar();
      await montar(tester);

      expect(find.text('Rappi'), findsOneWidget);
    });

    testWidgets('y se pueden descartar (FR-025)', (tester) async {
      await conSuscripcion(SituacionSuscripcion.vencida);
      await repoPendientes.insertar(pendiente(notificacionId: 'a'));
      await estado.cargar();
      await montar(tester);

      await tester.tap(
        find.byWidgetPredicate((widget) => widget is PopupMenuButton),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar').last);
      await tester.pumpAndSettle();

      expect(estado.pendientes, isEmpty);
    });
  });
}
