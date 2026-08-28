import 'package:finanzas/dominio/modelos/deuda.dart';
import 'package:finanzas/dominio/modelos/tarjeta.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/estado/estado_tarjetas.dart';
import 'package:finanzas/ui/pantallas/deudas/pantalla_deudas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../dobles/repositorios_en_memoria.dart';

/// Reglas de presentación de las deudas en cuotas (HU4).
void main() {
  late RepositorioDeudasEnMemoria repoDeudas;
  late RepositorioTarjetasEnMemoria repoTarjetas;
  late EstadoMes estado;
  late EstadoTarjetas estadoTarjetas;

  const agosto = Mes(2026, 8);
  final quinceDeAgosto = DateTime(2026, 8, 15);

  Deuda deuda({
    String descripcion = 'Celular',
    int cuotaCentavos = 15000,
    int numCuotas = 12,
    Mes mesInicio = agosto,
    Mes? mesSaldadaAnticipada,
    int tarjetaId = 1,
  }) => Deuda(
    id: null,
    descripcion: descripcion,
    tarjetaId: tarjetaId,
    cuotaMensual: Dinero.deCentavos(cuotaCentavos),
    numCuotas: numCuotas,
    mesInicio: mesInicio,
    mesSaldadaAnticipada: mesSaldadaAnticipada,
  );

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
    await repoTarjetas.insertar(
      const Tarjeta(
        id: null,
        nombre: 'BCP Visa',
        entidad: 'BCP',
        tipo: TipoTarjeta.credito,
      ),
    );
    estado = EstadoMes(
      repoIngreso: RepositorioIngresoEnMemoria(),
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
      await repoDeudas.insertar(deuda(cuotaCentavos: 15000, numCuotas: 12));
      await repoDeudas.insertar(
        deuda(descripcion: 'Refri', cuotaCentavos: 8000, numCuotas: 6),
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
      await repoDeudas.insertar(deuda(mesInicio: const Mes(2026, 11)));
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
      await repoDeudas.insertar(deuda());
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
      await repoDeudas.insertar(deuda());
      await estado.cargar();
      await montar(tester);

      expect(find.text('BCP Visa · BCP'), findsOneWidget);
    });
  });

  group('saldar anticipadamente (FR-021)', () {
    testWidgets('pide confirmación antes de saldar', (tester) async {
      await repoDeudas.insertar(deuda());
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
      await repoDeudas.insertar(deuda());
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
      await repoDeudas.insertar(deuda(cuotaCentavos: 15000));
      await repoDeudas.insertar(
        deuda(descripcion: 'Refri', cuotaCentavos: 8000),
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
      await repoDeudas.insertar(deuda(cuotaCentavos: 15000, numCuotas: 12));
      await estado.cargar();

      final guardada = estado.deudas.single;
      await estado.actualizarDeuda(
        guardada.copiarCon(cuotaMensual: const Dinero.deCentavos(20000)),
      );

      expect(estado.cuotasVigentes, const Dinero.deCentavos(20000));
    });
  });
}
