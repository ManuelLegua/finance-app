import 'package:finanzas/dominio/modelos/cobro_ingreso.dart';
import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/estado/estado_ahorro.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/pantallas/resumen_mes/pantalla_resumen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../builders/deuda_builder.dart';
import '../builders/obligacion_builder.dart';
import '../dobles/repositorios_en_memoria.dart';

/// Reglas de presentación del resumen del mes (HU2).
void main() {
  late RepositorioCobrosIngresoEnMemoria repoCobrosIngreso;
  late RepositorioObligacionesEnMemoria repoObligaciones;
  late RepositorioDeudasEnMemoria repoDeudas;
  late EstadoMes estado;
  late EstadoAhorro estadoAhorro;

  const agosto = Mes(2026, 8);
  final quinceDeAgosto = DateTime(2026, 8, 15);

  Future<void> sembrarIngreso(int centavos) => repoCobrosIngreso.insertar(
    CobroIngreso(
      id: null,
      fecha: quinceDeAgosto,
      monto: Dinero.deCentavos(centavos),
    ),
  );

  EstadoMes crearEstado({Mes mes = agosto}) => EstadoMes(
    repoCobrosIngreso: repoCobrosIngreso,
    repoObligaciones: repoObligaciones,
    repoConfiguracion: RepositorioConfiguracionEnMemoria(),
    repoTransacciones: RepositorioTransaccionesEnMemoria(),
    repoDeudas: repoDeudas,
    ahora: () => quinceDeAgosto,
    mesInicial: mes,
  );

  Obligacion obligacionDe(int centavos, {Mes mes = agosto}) =>
      ObligacionBuilder(mes: mes, centavos: centavos).build();

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<EstadoMes>.value(value: estado),
              ChangeNotifierProvider<EstadoAhorro>.value(value: estadoAhorro),
            ],
            child: const PantallaResumen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repoCobrosIngreso = RepositorioCobrosIngresoEnMemoria();
    repoObligaciones = RepositorioObligacionesEnMemoria();
    repoDeudas = RepositorioDeudasEnMemoria();
    estadoAhorro = EstadoAhorro(
      repoAhorro: RepositorioAhorroEnMemoria(),
      repoConfiguracion: RepositorioConfiguracionEnMemoria(),
      ahora: () => quinceDeAgosto,
    );
  });

  group('caso normal', () {
    testWidgets('muestra ingreso, comprometido y disponible', (tester) async {
      await sembrarIngreso(300000);
      await repoObligaciones.insertar(obligacionDe(180000));
      estado = crearEstado();
      await estado.cargar();
      await montar(tester);

      // El ingreso aparece dos veces: como ingreso y como disponible real,
      // que sin gastos registrados vale lo mismo.
      expect(find.text(r'S/ 3,000.00'), findsNWidgets(2));
      expect(find.text(r'S/ 1,800.00'), findsOneWidget);
      // El disponible también: destacado arriba y en el desglose.
      expect(find.text(r'S/ 1,200.00'), findsNWidgets(2));
      expect(find.text('Disponible este mes'), findsOneWidget);
    });
  });

  group('déficit (FR-028, FR-029)', () {
    testWidgets('se comunica con texto e ícono, no solo con color', (
      tester,
    ) async {
      await sembrarIngreso(200000);
      await repoObligaciones.insertar(obligacionDe(235000));
      estado = crearEstado();
      await estado.cargar();
      await montar(tester);

      // El mensaje se lee sin distinguir colores.
      expect(find.text('Tus compromisos superan tu ingreso'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      // Y dice el faltante exacto.
      expect(find.textContaining(r'S/ 350.00'), findsWidgets);
      expect(find.text('Te falta'), findsOneWidget);
    });
  });

  group('límite: saldo exactamente cero (FR-030)', () {
    testWidgets('no se reporta como déficit', (tester) async {
      await sembrarIngreso(300000);
      await repoObligaciones.insertar(obligacionDe(300000));
      estado = crearEstado();
      await estado.cargar();
      await montar(tester);

      expect(find.text('Tus compromisos superan tu ingreso'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.text('Disponible este mes'), findsOneWidget);
      // El disponible en cero se muestra, y no se declara déficit: es
      // exactamente lo que exige FR-030. La cantidad de ceros en pantalla
      // depende de cuántas categorías haya, así que no se cuenta.
      expect(find.text(r'S/ 0.00'), findsWidgets);
    });
  });

  group('mes sin ingreso (HU2 escenario 4)', () {
    testWidgets('pide registrarlo en vez de mostrar totales en cero', (
      tester,
    ) async {
      await repoObligaciones.insertar(obligacionDe(90000));
      estado = crearEstado();
      await estado.cargar();
      await montar(tester);

      expect(find.text('Falta registrar tu ingreso'), findsOneWidget);
      // No se muestra un disponible que sería engañoso.
      expect(find.text('Disponible este mes'), findsNothing);
      // Los totales que dependen del ingreso salen como ausentes, no en cero.
      expect(find.text('sin registrar'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
    });
  });

  group('selector de mes', () {
    testWidgets('muestra el mes en curso y permite navegar', (tester) async {
      estado = crearEstado();
      await estado.cargar();
      await montar(tester);

      expect(find.text('Agosto 2026'), findsOneWidget);

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();

      expect(find.text('Julio 2026'), findsOneWidget);
    });

    testWidgets('rotula con texto que un mes pasado está cerrado', (
      tester,
    ) async {
      estado = crearEstado(mes: const Mes(2026, 5));
      await estado.cargar();
      await montar(tester);

      expect(find.text('Mes cerrado · solo lectura'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  group('disponible real (FR-027)', () {
    testWidgets('sin gastos registrados iguala al ingreso', (tester) async {
      await sembrarIngreso(300000);
      await repoObligaciones.insertar(obligacionDe(180000));
      estado = crearEstado();
      await estado.cargar();
      await montar(tester);

      expect(find.text('Disponible real'), findsOneWidget);
      expect(find.text('Gasto real'), findsOneWidget);
      // Ingreso y disponible real coinciden hasta que US3 registre gastos.
      expect(find.text(r'S/ 3,000.00'), findsNWidgets(2));
    });
  });

  group('ningún pago cambia una cifra del resumen (FR-002, D6/D7)', () {
    /// Ojo con `montar`: el árbol de estas pruebas **no tiene** nada de la
    /// spec 004 por ningún lado. Si alguien hiciera que el resumen consultara
    /// si el usuario pagó algo, esto no fallaría por mostrar una cifra
    /// distinta sino por un provider inexistente — que es exactamente la
    /// alarma que se quiere. El resumen dice la verdad completa del mes,
    /// haya apoyado el usuario o no.
    testWidgets('la cuota de deuda se cuenta en el comprometido', (
      tester,
    ) async {
      await sembrarIngreso(300000);
      await repoDeudas.insertar(
        DeudaBuilder(
          descripcion: 'Celular',
          cuotaCentavos: 15000,
          numCuotas: 12,
          mesInicio: agosto,
        ).build(),
      );
      estado = crearEstado();
      await estado.cargar();
      await montar(tester);

      // La cuota del mes son S/ 150.00, y el disponible sale de restarla:
      // omitirla lo dejaría inflado en S/ 3,000.00.
      expect(find.text(r'S/ 150.00'), findsWidgets);
      expect(find.text(r'S/ 2,850.00'), findsWidgets);
    });

    testWidgets('y el detalle por deuda se sigue pudiendo abrir (FR-017)', (
      tester,
    ) async {
      // El desglose por categoría queda debajo del pliegue en la pantalla de
      // 800 px que usa el resto del archivo, y un `ListView` no construye lo
      // que no se ve.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await sembrarIngreso(300000);
      await repoDeudas.insertar(
        DeudaBuilder(
          descripcion: 'Celular',
          cuotaCentavos: 15000,
          numCuotas: 12,
          mesInicio: agosto,
        ).build(),
      );
      estado = crearEstado();
      await estado.cargar();
      await montar(tester);

      await tester.tap(find.text('Una deuda en cuotas'));
      await tester.pumpAndSettle();

      // Ver de dónde sale el monto es información, no gestión: no es lo que
      // la suscripción bloquea.
      expect(find.text('Celular'), findsOneWidget);
    });
  });
}
