import 'package:finanzas/dominio/modelos/deuda.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/estado/estado_pendientes.dart';
import 'package:finanzas/ui/estado/estado_tarjetas.dart';
import 'package:finanzas/ui/pantallas/deudas/pantalla_deudas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../builders/deuda_builder.dart';
import '../builders/tarjeta_builder.dart';
import '../dobles/repositorios_en_memoria.dart';

/// Reglas de presentación de las deudas en cuotas (HU4).
void main() {
  late RepositorioDeudasEnMemoria repoDeudas;
  late RepositorioTarjetasEnMemoria repoTarjetas;
  late EstadoMes estado;
  late EstadoTarjetas estadoTarjetas;

  const agosto = Mes(2026, 8);
  final quinceDeAgosto = DateTime(2026, 8, 15);

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EstadoMes>.value(value: estado),
          ChangeNotifierProvider<EstadoTarjetas>.value(value: estadoTarjetas),
        ],
        child: const MaterialApp(home: PantallaDeudas()),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    repoDeudas = RepositorioDeudasEnMemoria();
    repoTarjetas = RepositorioTarjetasEnMemoria();
    await repoTarjetas.insertar(TarjetaBuilder().build());
    estado = EstadoMes(
      repoCobrosIngreso: RepositorioCobrosIngresoEnMemoria(),
      repoObligaciones: RepositorioObligacionesEnMemoria(),
      repoConfiguracion: RepositorioConfiguracionEnMemoria(),
      repoTransacciones: RepositorioTransaccionesEnMemoria(),
      repoDeudas: repoDeudas,
      ahora: () => quinceDeAgosto,
      mesInicial: agosto,
    );
    estadoTarjetas = EstadoTarjetas(repoTarjetas: repoTarjetas);
    await estadoTarjetas.cargar();
  });

  group('sin deudas', () {
    testWidgets('comunica el estado libre de deuda, no una lista vacía', (
      tester,
    ) async {
      await estado.cargar();
      await montar(tester);

      expect(find.text('No debés nada en cuotas'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      // No se muestra un panorama con puros ceros.
      expect(find.text('Debés en total'), findsNothing);
    });
  });

  group('panorama (FR-022, SC-006)', () {
    testWidgets('total, cuota del mes y mes libre en una sola pantalla', (
      tester,
    ) async {
      await repoDeudas.insertar(
        DeudaBuilder(cuotaCentavos: 15000, numCuotas: 12).build(),
      );
      await repoDeudas.insertar(
        DeudaBuilder(
          descripcion: 'Refri',
          cuotaCentavos: 8000,
          numCuotas: 6,
        ).build(),
      );
      await estado.cargar();
      await montar(tester);

      // 12 x 150 + 6 x 80 = 1800 + 480
      expect(find.text(r'S/ 2,280.00'), findsOneWidget);
      expect(find.text(r'S/ 230.00'), findsOneWidget);
      expect(
        find.textContaining('Quedás libre de deudas en julio 2027'),
        findsOneWidget,
      );
    });

    testWidgets('una deuda futura suma al total pero no a la cuota del mes', (
      tester,
    ) async {
      await repoDeudas.insertar(
        DeudaBuilder(mesInicio: const Mes(2026, 11)).build(),
      );
      await estado.cargar();
      await montar(tester);

      expect(find.text(r'S/ 1,800.00'), findsWidgets);
      expect(find.text(r'S/ 0.00'), findsOneWidget);
      expect(find.textContaining('Empieza en noviembre 2026'), findsOneWidget);
    });
  });

  group('detalle de la deuda', () {
    testWidgets('muestra cuotas pagadas, restantes y mes de término', (
      tester,
    ) async {
      await repoDeudas.insertar(DeudaBuilder().build());
      await estado.irAMes(const Mes(2026, 11));
      await montar(tester);

      // Tres meses después del inicio: 3 pagadas, 9 restantes (D4).
      expect(find.textContaining('3 de 12 pagadas'), findsOneWidget);
      expect(find.textContaining('quedan 9'), findsOneWidget);
      // Con una sola deuda, su saldo y el total adeudado coinciden: el monto
      // aparece dos veces, en el panorama y en la ficha.
      expect(find.text(r'S/ 1,350.00'), findsNWidgets(2));
    });

    testWidgets('identifica la tarjeta que la respalda', (tester) async {
      await repoDeudas.insertar(DeudaBuilder().build());
      await estado.cargar();
      await montar(tester);

      expect(find.text('BCP Visa · BCP'), findsOneWidget);
    });
  });

  group('saldar anticipadamente (FR-021)', () {
    testWidgets('pide confirmación antes de saldar', (tester) async {
      await repoDeudas.insertar(DeudaBuilder().build());
      await estado.cargar();
      await montar(tester);

      await tester.tap(find.byType(PopupMenuButton<AccionSobreDeuda>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saldar anticipadamente'));
      await tester.pumpAndSettle();

      expect(find.text('¿Saldar esta deuda?'), findsOneWidget);
      expect(find.textContaining('deja de sumar cuotas'), findsOneWidget);
    });

    testWidgets('al confirmar, deja de aportar y su saldo pasa a cero', (
      tester,
    ) async {
      await repoDeudas.insertar(DeudaBuilder().build());
      await estado.cargar();

      expect(estado.cuotasVigentes, const Dinero.deCentavos(15000));

      await estado.saldarDeuda(estado.deudas.single.id!, agosto);

      expect(estado.cuotasVigentes, Dinero.cero);
      expect(estado.panorama.totalAdeudado, Dinero.cero);
      expect(estado.panorama.sinDeudas, isTrue);
    });
  });

  group('cuotas en el presupuesto (FR-016)', () {
    testWidgets('se suman al comprometido del mes sin escribirse a mano', (
      tester,
    ) async {
      await repoDeudas.insertar(DeudaBuilder(cuotaCentavos: 15000).build());
      await repoDeudas.insertar(
        DeudaBuilder(descripcion: 'Refri', cuotaCentavos: 8000).build(),
      );
      await estado.cargar();

      expect(estado.cuotasVigentes, const Dinero.deCentavos(23000));
      expect(estado.resumen.totalComprometido, const Dinero.deCentavos(23000));

      // Y son desglosables deuda por deuda (FR-017).
      expect(estado.deudasDelMes, hasLength(2));
    });

    testWidgets('editar una deuda recalcula sin tocar meses guardados', (
      tester,
    ) async {
      // FR-023 y FR-057: es la única corrección admitida sobre un mes cerrado,
      // porque la cuota nunca fue un dato del mes (D3).
      await repoDeudas.insertar(
        DeudaBuilder(cuotaCentavos: 15000, numCuotas: 12).build(),
      );
      await estado.cargar();

      final guardada = estado.deudas.single;
      await estado.actualizarDeuda(
        guardada.copiarCon(cuotaMensual: const Dinero.deCentavos(20000)),
      );

      expect(estado.cuotasVigentes, const Dinero.deCentavos(20000));
    });
  });

  group('creada desde un pendiente confirmado (spec 002, FR-036, FR-037)', () {
    testWidgets(
      'aparece en Deudas igual que una creada a mano, y el presupuesto '
      'muestra solo la cuota, sin refrescar a mano',
      (tester) async {
        await estado.cargar();
        await montar(tester);
        expect(find.text('Tienda X'), findsNothing);

        // Simula lo que hace EstadoPendientes.confirmar(comoDeuda: ...) al
        // marcar un pendiente como compra en cuotas: usa el **mismo**
        // EstadoMes que ya está en pantalla (como pasa en la app real, donde
        // ambos son providers del mismo árbol) — no un repositorio aparte
        // que dejaría a Deudas/Presupuesto sin enterarse.
        final repoPendientes = RepositorioPendientesEnMemoria();
        final estadoPendientes = EstadoPendientes(
          repoPendientes: repoPendientes,
          repoAsociaciones: RepositorioAsociacionesEnMemoria(),
          estadoMes: estado,
        );
        await repoPendientes.insertar(
          ConsumoPendiente(
            id: null,
            origenPaquete: 'com.ejemplo.banco',
            notificacionId: 'notif-1',
            monto: const Dinero.deCentavos(15000),
            comercio: 'Tienda X',
            fecha: quinceDeAgosto,
            categoriaPropuesta: null,
            capturadoEn: quinceDeAgosto,
          ),
        );
        await estadoPendientes.cargar();

        final confirmado = await estadoPendientes.confirmar(
          estadoPendientes.pendientes.single,
          comoDeuda: const Deuda(
            id: null,
            descripcion: 'Tienda X',
            tarjetaId: 1,
            cuotaMensual: Dinero.deCentavos(15000),
            numCuotas: 12,
            mesInicio: agosto,
          ),
        );
        expect(confirmado, isTrue);

        // Sin llamar a estado.cargar() a mano: confirmar() pasó por
        // EstadoMes.agregarDeuda(), que ya recargó y notificó — la pantalla
        // solo necesita un frame para pintarlo.
        await tester.pump();

        // Aparece en la pantalla de Deudas como cualquier otra (FR-036).
        expect(find.text('Tienda X'), findsOneWidget);
        expect(find.text('BCP Visa · BCP'), findsOneWidget);

        // El presupuesto ve solo la cuota, no el total de la compra
        // (FR-037): 12 x S/ 150.00, no S/ 1,800.00 de una sola vez.
        expect(estado.cuotasVigentes, const Dinero.deCentavos(15000));
        expect(
          estado.resumen.totalComprometido,
          const Dinero.deCentavos(15000),
        );
      },
    );
  });
}
