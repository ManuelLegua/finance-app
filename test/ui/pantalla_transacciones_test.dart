import 'package:finanzas/dominio/modelos/transaccion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/pantallas/transacciones/pantalla_transacciones.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../builders/obligacion_builder.dart';
import '../builders/transaccion_builder.dart';
import '../dobles/repositorios_en_memoria.dart';

/// Reglas de presentación del registro de gastos (HU3).
void main() {
  late RepositorioObligacionesEnMemoria repoObligaciones;
  late RepositorioTransaccionesEnMemoria repoTransacciones;
  late EstadoMes estado;

  const agosto = Mes(2026, 8);
  final quinceDeAgosto = DateTime(2026, 8, 15);

  Transaccion gasto({
    int dia = 15,
    int mes = 8,
    int centavos = 4500,
    Categoria categoria = Categoria.comida,
    String descripcion = 'Almuerzo',
  }) => TransaccionBuilder(
    fecha: DateTime(2026, mes, dia),
    categoria: categoria,
    centavos: centavos,
    descripcion: descripcion,
  ).build();

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<EstadoMes>.value(
          value: estado,
          child: const PantallaTransacciones(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repoObligaciones = RepositorioObligacionesEnMemoria();
    repoTransacciones = RepositorioTransaccionesEnMemoria();
    estado = EstadoMes(
      repoCobrosIngreso: RepositorioCobrosIngresoEnMemoria(),
      repoObligaciones: repoObligaciones,
      repoConfiguracion: RepositorioConfiguracionEnMemoria(),
      repoTransacciones: repoTransacciones,
      repoDeudas: RepositorioDeudasEnMemoria(),
      ahora: () => quinceDeAgosto,
      mesInicial: agosto,
    );
  });

  group('listado (FR-013)', () {
    testWidgets('ordena del gasto más reciente al más antiguo', (tester) async {
      await repoTransacciones.insertar(gasto(dia: 3, descripcion: 'primero'));
      await repoTransacciones.insertar(gasto(dia: 20, descripcion: 'tercero'));
      await repoTransacciones.insertar(gasto(dia: 11, descripcion: 'segundo'));
      await estado.cargar();
      await montar(tester);

      final titulos = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((fila) => (fila.title! as Text).data)
          .toList();
      expect(titulos, ['tercero', 'segundo', 'primero']);
    });

    testWidgets('un mes sin gastos invita a registrar el primero', (
      tester,
    ) async {
      await estado.cargar();
      await montar(tester);

      expect(find.textContaining('Todavía no anotaste gastos'), findsOneWidget);
    });

    testWidgets('un gasto sin descripción se titula con su categoría', (
      tester,
    ) async {
      await repoTransacciones.insertar(
        gasto(descripcion: '', categoria: Categoria.pasajes),
      );
      await estado.cargar();
      await montar(tester);

      expect(find.text('Pasajes'), findsOneWidget);
    });
  });

  group('total del mes', () {
    testWidgets('suma los gastos y los muestra formateados', (tester) async {
      await repoTransacciones.insertar(gasto(centavos: 4500));
      await repoTransacciones.insertar(gasto(centavos: 3300));
      await estado.cargar();
      await montar(tester);

      expect(find.text(r'S/ 78.00'), findsOneWidget);
    });
  });

  group('sobregiro (FR-011, FR-014)', () {
    testWidgets('un gasto que excede el presupuesto se guarda igual', (
      tester,
    ) async {
      // La app informa, no bloquea: no le impide al usuario gastar.
      await repoObligaciones.insertar(
        ObligacionBuilder(
          nombre: 'Pasajes',
          categoria: Categoria.pasajes,
          centavos: 20000,
          tipo: TipoObligacion.variable,
        ).build(),
      );
      await estado.cargar();

      final guardado = await estado.agregarTransaccion(
        gasto(categoria: Categoria.pasajes, centavos: 21500),
      );

      expect(guardado, isTrue);
      expect(estado.transacciones, hasLength(1));

      final pasajes = estado.desglose.firstWhere(
        (linea) => linea.categoria == Categoria.pasajes,
      );
      expect(pasajes.sobregirada, isTrue);
      expect(pasajes.exceso, const Dinero.deCentavos(1500));
    });

    testWidgets('un gasto sin presupuesto se registra y se marca', (
      tester,
    ) async {
      await estado.cargar();
      await estado.agregarTransaccion(gasto(categoria: Categoria.otros));

      final otros = estado.desglose.single;
      expect(otros.noPresupuestada, isTrue);
      expect(otros.gastado, const Dinero.deCentavos(4500));
    });
  });

  group('pago rezagado (FR-055, FR-056)', () {
    testWidgets('dentro de la ventana se admite la fecha del mes anterior', (
      tester,
    ) async {
      final tresDeAgosto = DateTime(2026, 8, 3);
      estado = EstadoMes(
        repoCobrosIngreso: RepositorioCobrosIngresoEnMemoria(),
        repoObligaciones: repoObligaciones,
        repoConfiguracion: RepositorioConfiguracionEnMemoria(),
        repoTransacciones: repoTransacciones,
        repoDeudas: RepositorioDeudasEnMemoria(),
        ahora: () => tresDeAgosto,
        mesInicial: agosto,
      );
      await estado.cargar();

      expect(estado.admiteRegistrarEn(DateTime(2026, 7, 28)), isTrue);
      expect(await estado.agregarTransaccion(gasto(mes: 7, dia: 28)), isTrue);
    });

    testWidgets('pasada la ventana, esa fecha se rechaza', (tester) async {
      // El 15 de agosto la ventana de cinco días ya cerró.
      await estado.cargar();

      expect(estado.admiteRegistrarEn(DateTime(2026, 7, 28)), isFalse);
      expect(await estado.agregarTransaccion(gasto(mes: 7, dia: 28)), isFalse);
      expect(estado.error, isNotNull);
    });

    testWidgets('lo registrado en un mes cerrado no ofrece editar', (
      tester,
    ) async {
      await repoTransacciones.insertar(gasto(mes: 7, dia: 28));
      estado = EstadoMes(
        repoCobrosIngreso: RepositorioCobrosIngresoEnMemoria(),
        repoObligaciones: repoObligaciones,
        repoConfiguracion: RepositorioConfiguracionEnMemoria(),
        repoTransacciones: repoTransacciones,
        repoDeudas: RepositorioDeudasEnMemoria(),
        ahora: () => quinceDeAgosto,
        mesInicial: const Mes(2026, 7),
      );
      await estado.cargar();
      await montar(tester);

      expect(find.byType(PopupMenuButton<AccionSobreGasto>), findsNothing);
      // La restricción se comunica con ícono, no dejando un hueco (FR-058).
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
    });
  });

  group('errores', () {
    testWidgets('un fallo al guardar se muestra, no se traga', (tester) async {
      await estado.cargar();
      repoTransacciones.errorEnLaProximaEscritura = Exception('disco lleno');

      await estado.agregarTransaccion(gasto());
      await montar(tester);

      expect(find.textContaining('Ocurrió un problema'), findsOneWidget);
      expect(estado.transacciones, isEmpty);
    });
  });
}
